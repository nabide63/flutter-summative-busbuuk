// holds seat selection, passenger details and payment state for the booking flow
import 'package:flutter/foundation.dart';
import '../models/bus_model.dart';
import '../models/seat_model.dart';
import '../models/passenger_model.dart';
import '../models/booking_model.dart';
import '../services/firestore_service.dart';

typedef SeatFetcher = Future<List<SeatModel>> Function(String busId);
typedef BookingConfirmer =
    Future<void> Function(BookingModel booking, List<String> seatNumbers);
typedef BookingsFetcher = Future<List<BookingModel>> Function(String userId);
typedef BookingDeleter = Future<void> Function(String bookingId);

class BookingProvider extends ChangeNotifier {
  // all injectable so previews/tests can swap in mock data without needing
  // Firebase.initializeApp() to have run.
  BookingProvider({
    SeatFetcher? getSeatsForBus,
    BookingConfirmer? confirmBookingAndMarkSeats,
    BookingsFetcher? getUserBookings,
    BookingDeleter? deleteBooking,
  }) : _getSeatsForBus = getSeatsForBus ?? FirestoreService().getSeatsForBus,
       _confirmBookingAndMarkSeats =
           confirmBookingAndMarkSeats ??
           FirestoreService().confirmBookingAndMarkSeats,
       _getUserBookings = getUserBookings ?? FirestoreService().getUserBookings,
       _deleteBooking = deleteBooking ?? FirestoreService().deleteBooking;

  final SeatFetcher _getSeatsForBus;
  final BookingConfirmer _confirmBookingAndMarkSeats;
  final BookingsFetcher _getUserBookings;
  final BookingDeleter _deleteBooking;

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

  // called when the user taps into a bus from search results
  Future<void> selectBus(BusModel bus) async {
    _selectedBus = bus;
    _isLoading = true;
    notifyListeners();

    try {
      _seats = await _getSeatsForBus(bus.id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _seats = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      // optimistic local update so My Bookings shows this trip immediately,
      // without waiting on a re-fetch from Firestore
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

  Future<void> fetchMyBookings(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fetched = await _getUserBookings(userId);
      // merge rather than overwrite, so a booking just confirmed locally
      // (see confirmBooking) survives a fetch that hasn't caught up yet
      final fetchedIds = fetched.map((b) => b.id).toSet();
      final localOnly = _myBookings.where((b) => !fetchedIds.contains(b.id));
      _myBookings = [...localOnly, ...fetched]
        ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _selectedBus = null;
    _seats = [];
    _passengers = [];
    _paymentMethod = 'mtn';
    _errorMessage = null;
    notifyListeners();
  }
}