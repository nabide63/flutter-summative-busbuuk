// holds seat selection, passenger details and payment state for the booking flow
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/bus_model.dart';
import '../models/seat_model.dart';
import '../models/passenger_model.dart';
import '../models/booking_model.dart';
import '../services/firestore_service.dart';

typedef SeatStreamer = Stream<List<SeatModel>> Function(String busId);
typedef BookingConfirmer =
    Future<void> Function(BookingModel booking, List<String> seatNumbers);
typedef BookingsStreamer = Stream<List<BookingModel>> Function(String userId);
typedef BookingDeleter = Future<void> Function(String bookingId);

class BookingProvider extends ChangeNotifier {
  // all injectable so previews/tests can swap in mock data without needing
  // Firebase.initializeApp() to have run.
  BookingProvider({
    SeatStreamer? streamSeatsForBus,
    BookingConfirmer? confirmBookingAndMarkSeats,
    BookingsStreamer? streamUserBookings,
    BookingDeleter? deleteBooking,
  }) : _streamSeatsForBus = streamSeatsForBus ?? FirestoreService().streamSeatsForBus,
       _confirmBookingAndMarkSeats =
           confirmBookingAndMarkSeats ??
           FirestoreService().confirmBookingAndMarkSeats,
       _streamUserBookings = streamUserBookings ?? FirestoreService().streamUserBookings,
       _deleteBooking = deleteBooking ?? FirestoreService().deleteBooking;

  final SeatStreamer _streamSeatsForBus;
  final BookingConfirmer _confirmBookingAndMarkSeats;
  final BookingsStreamer _streamUserBookings;
  final BookingDeleter _deleteBooking;

  StreamSubscription<List<SeatModel>>? _seatsSub;
  StreamSubscription<List<BookingModel>>? _bookingsSub;

  BusModel? _selectedBus;
  List<SeatModel> _seats = [];
  List<PassengerModel> _passengers = [];
  String _paymentMethod = 'mtn';
  bool _isLoading = false;
  String? _errorMessage;

  List<BookingModel> _myBookings = [];

  BusModel? get selectedBus => _selectedBus;
  List<SeatModel> get seats => _seats;
  List<String> get selectedSeatNumbers =>
      _seats.where((s) => s.isSelected).map((s) => s.seatNumber).toList();
  List<PassengerModel> get passengers => _passengers;
  String get paymentMethod => _paymentMethod;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BookingModel> get myBookings => _myBookings;

  double get totalAmount =>
      (_selectedBus?.price ?? 0) * selectedSeatNumbers.length;

  // called when the user taps into a bus from search results. stays
  // subscribed afterwards so a seat booked by someone else (or toggled from
  // the console) while this screen is open updates live
  Future<void> selectBus(BusModel bus) async {
    _selectedBus = bus;
    _isLoading = true;
    notifyListeners();

    _seatsSub?.cancel();
    final firstSnapshot = Completer<void>();
    _seatsSub = _streamSeatsForBus(bus.id).listen(
      (freshSeats) {
        // preserve local seat picks across snapshots - a fresh SeatModel
        // comes back on every emission, so isSelected would otherwise reset
        // whenever an unrelated seat changes
        final previouslySelected =
            _seats.where((s) => s.isSelected).map((s) => s.seatNumber).toSet();
        _seats = [
          for (final seat in freshSeats)
            SeatModel(seatNumber: seat.seatNumber, isBooked: seat.isBooked)
              ..isSelected = !seat.isBooked && previouslySelected.contains(seat.seatNumber),
        ];
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        if (!firstSnapshot.isCompleted) firstSnapshot.complete();
      },
      onError: (Object e) {
        _errorMessage = e.toString();
        _seats = [];
        _isLoading = false;
        notifyListeners();
        if (!firstSnapshot.isCompleted) firstSnapshot.complete();
      },
    );

    await firstSnapshot.future;
  }

  void toggleSeat(String seatNumber) {
    final index = _seats.indexWhere((s) => s.seatNumber == seatNumber);
    if (index == -1) return;

    final seat = _seats[index];
    if (seat.isBooked) return; // can't select a seat that's already taken

    seat.isSelected = !seat.isSelected;
    notifyListeners();
  }

  void setPassengers(List<PassengerModel> passengers) {
    _passengers = passengers;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  // creates the booking doc once payment goes through
  Future<BookingModel?> confirmBooking({required String userId}) async {
    final bus = _selectedBus;
    if (bus == null || selectedSeatNumbers.isEmpty) {
      _errorMessage = 'pick a bus and at least one seat first';
      notifyListeners();
      return null;
    }
    if (!bus.departureTime.isAfter(DateTime.now())) {
      _errorMessage = 'this trip has already departed, please pick another one';
      notifyListeners();
      return null;
    }
    if (!bus.arrivalTime.isAfter(DateTime.now())) {
      _errorMessage = 'this trip has an invalid schedule, please pick another one';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final booking = BookingModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: userId,
        busId: bus.id,
        seatNumbers: selectedSeatNumbers,
        passengers: _passengers,
        totalAmount: totalAmount,
        bookingDate: DateTime.now(),
        status: 'confirmed',
        operatorName: bus.operatorName,
        operatorPhone: bus.operatorPhone,
        from: bus.from,
        to: bus.to,
        fromTerminal: bus.fromTerminal,
        departureTime: bus.departureTime,
        arrivalTime: bus.arrivalTime,
        companyId: bus.companyId,
      );

      await _confirmBookingAndMarkSeats(booking, selectedSeatNumbers);
      // optimistic local update so My Bookings shows this trip immediately if
      // its listener hasn't been started yet (or hasn't caught up); once the
      // live stream is running it reflects the write on its own
      _myBookings = [booking, ..._myBookings];
      _errorMessage = null;
      return booking;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // live so a booking made/cancelled elsewhere (or edited from the console)
  // shows up here instantly, without needing to leave and reopen the screen
  void listenMyBookings(String userId) {
    _bookingsSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _bookingsSub = _streamUserBookings(userId).listen(
      (fetched) {
        // merge rather than overwrite, so a booking just confirmed locally
        // (see confirmBooking) survives an emission that hasn't caught up yet
        final fetchedIds = fetched.map((b) => b.id).toSet();
        final localOnly = _myBookings.where((b) => !fetchedIds.contains(b.id));
        _myBookings = [...localOnly, ...fetched]
          ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // removes a trip from the user's history. optimistic so the tile
  // disappears immediately; put back on failure so nothing silently vanishes
  Future<bool> deleteBooking(String bookingId) async {
    final index = _myBookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) return true;

    final removed = _myBookings[index];
    _myBookings = [..._myBookings]..removeAt(index);
    notifyListeners();

    try {
      await _deleteBooking(bookingId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _myBookings = [..._myBookings]..insert(index, removed);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // wipe the booking flow state once a booking is done (or abandoned)
  void resetBookingFlow() {
    _seatsSub?.cancel();
    _seatsSub = null;
    _selectedBus = null;
    _seats = [];
    _passengers = [];
    _paymentMethod = 'mtn';
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _seatsSub?.cancel();
    _bookingsSub?.cancel();
    super.dispose();
  }
}