// holds state for the bus-company onboarder / super-admin screens: company
// list, the signed-in onboarder's own buses, seat management, provisioning
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/bus_company_model.dart';
import '../models/bus_model.dart';
import '../models/destination_model.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/firestore_service.dart';

typedef CompanyStreamer = Stream<List<BusCompanyModel>> Function();
typedef CompanyCreator = Future<void> Function(BusCompanyModel company);
typedef CompanyBusStreamer = Stream<List<BusModel>> Function(String companyId);
typedef BusCreator = Future<void> Function(BusModel bus);
typedef BusUpdater = Future<void> Function(BusModel bus);
typedef BusDeleter = Future<void> Function(String busId);
typedef CompanyBookingsStreamer = Stream<List<BookingModel>> Function(String companyId);
typedef SeatBatchCreator =
    Future<void> Function(String busId, List<SeatModel> seats);
typedef AdminSeatStreamer = Stream<List<SeatModel>> Function(String busId);
typedef SeatBookedSetter =
    Future<void> Function(String busId, String seatNumber, bool isBooked);
typedef OnboarderProvisioner =
    Future<UserModel> Function({
      required String name,
      required String email,
      required String password,
      required String phone,
      required String companyId,
    });
typedef DestinationStreamer = Stream<List<DestinationModel>> Function();
typedef DestinationCreator = Future<void> Function(DestinationModel destination);
typedef DestinationUpdater = Future<void> Function(DestinationModel destination);
typedef DestinationDeleter = Future<void> Function(String destinationId);

class AdminProvider extends ChangeNotifier {
  // all injectable so previews/tests can swap in mock data without needing
  // Firebase.initializeApp() to have run.
  AdminProvider({
    CompanyStreamer? streamCompanies,
    CompanyCreator? createCompany,
    CompanyBusStreamer? streamBusesForCompany,
    BusCreator? createBus,
    BusUpdater? updateBus,
    BusDeleter? deleteBus,
    SeatBatchCreator? createSeatsForBus,
    AdminSeatStreamer? streamSeatsForBus,
    SeatBookedSetter? setSeatBooked,
    OnboarderProvisioner? provisionOnboarder,
    CompanyBookingsStreamer? streamCompanyBookings,
    DestinationStreamer? streamDestinations,
    DestinationCreator? createDestination,
    DestinationUpdater? updateDestination,
    DestinationDeleter? deleteDestination,
  }) : _streamCompanies = streamCompanies ?? FirestoreService().streamCompanies,
       _createCompany = createCompany ?? FirestoreService().createCompany,
       _streamBusesForCompany =
           streamBusesForCompany ?? FirestoreService().streamBusesForCompany,
       _createBus = createBus ?? FirestoreService().createBus,
       _updateBus = updateBus ?? FirestoreService().updateBus,
       _deleteBus = deleteBus ?? FirestoreService().deleteBus,
       _createSeatsForBus =
           createSeatsForBus ?? FirestoreService().createSeatsForBus,
       _streamSeatsForBus = streamSeatsForBus ?? FirestoreService().streamSeatsForBus,
       _setSeatBooked = setSeatBooked ?? FirestoreService().setSeatBooked,
       _provisionOnboarder =
           provisionOnboarder ?? AdminService().provisionOnboarder,
       _streamCompanyBookings =
           streamCompanyBookings ?? FirestoreService().streamCompanyBookings,
       _streamDestinations = streamDestinations ?? FirestoreService().streamDestinations,
       _createDestination =
           createDestination ?? FirestoreService().createDestination,
       _updateDestination =
           updateDestination ?? FirestoreService().updateDestination,
       _deleteDestination =
           deleteDestination ?? FirestoreService().deleteDestination;

  final CompanyStreamer _streamCompanies;
  final CompanyCreator _createCompany;
  final CompanyBusStreamer _streamBusesForCompany;
  final BusCreator _createBus;
  final BusUpdater _updateBus;
  final BusDeleter _deleteBus;
  final SeatBatchCreator _createSeatsForBus;
  final AdminSeatStreamer _streamSeatsForBus;
  final SeatBookedSetter _setSeatBooked;
  final OnboarderProvisioner _provisionOnboarder;
  final CompanyBookingsStreamer _streamCompanyBookings;
  final DestinationStreamer _streamDestinations;
  final DestinationCreator _createDestination;
  final DestinationUpdater _updateDestination;
  final DestinationDeleter _deleteDestination;

  StreamSubscription<List<BusCompanyModel>>? _companiesSub;
  StreamSubscription<List<BusModel>>? _myBusesSub;
  StreamSubscription<List<SeatModel>>? _selectedBusSeatsSub;
  StreamSubscription<List<BookingModel>>? _companyBookingsSub;
  StreamSubscription<List<DestinationModel>>? _destinationsSub;

  List<BusCompanyModel> _companies = [];
  List<BusModel> _myBuses = [];
  BusModel? _selectedBus;
  List<SeatModel> _selectedBusSeats = [];
  List<BookingModel> _companyBookings = [];
  List<DestinationModel> _destinations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BusCompanyModel> get companies => _companies;
  List<BusModel> get myBuses => _myBuses;
  BusModel? get selectedBus => _selectedBus;
  List<SeatModel> get selectedBusSeats => _selectedBusSeats;
  List<BookingModel> get companyBookings => _companyBookings;
  List<DestinationModel> get destinations => _destinations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // live so a company added/renamed from the console (or another admin
  // session) shows up here without a manual refresh
  void listenCompanies() {
    _companiesSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _companiesSub = _streamCompanies().listen(
      (companies) {
        _companies = companies;
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

  void listenMyBuses(String companyId) {
    _myBusesSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _myBusesSub = _streamBusesForCompany(companyId).listen(
      (buses) {
        _myBuses = buses;
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

  // called when an onboarder taps into a bus from Manage Buses to mark
  // walk-in terminal seats occupied. stays subscribed so a seat toggled from
  // another device (or the console) updates live
  void selectBusForSeatManagement(BusModel bus) {
    _selectedBus = bus;
    _selectedBusSeatsSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _selectedBusSeatsSub = _streamSeatsForBus(bus.id).listen(
      (seats) {
        _selectedBusSeats = seats;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _errorMessage = e.toString();
        _selectedBusSeats = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> createCompany(String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      final company = BusCompanyModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
      );
      await _createCompany(company);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // creates the bus doc and its seat map (4-across rows, lettered A-D)
  Future<bool> createBus(BusModel bus, {required int totalSeats}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _createBus(bus);
      await _createSeatsForBus(bus.id, _generateSeats(totalSeats));
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // metadata edits only - not dealing with reconciling seat layout changes
  // against already-booked seats, that's out of scope for this project
  Future<bool> updateBus(BusModel bus) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _updateBus(bus);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBus(String busId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _deleteBus(busId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // flips a seat occupied/vacant for a walk-in terminal booking - the live
  // selectedBusSeats listener above picks up the result on its own
  Future<void> toggleSeatOccupied(String seatNumber, bool newValue) async {
    final bus = _selectedBus;
    if (bus == null) return;
    try {
      await _setSeatBooked(bus.id, seatNumber, newValue);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void listenCompanyBookings(String companyId) {
    _companyBookingsSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _companyBookingsSub = _streamCompanyBookings(companyId).listen(
      (bookings) {
        _companyBookings = bookings;
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

  Future<bool> provisionOnboarder({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String companyId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _provisionOnboarder(
        name: name,
        email: email,
        password: password,
        phone: phone,
        companyId: companyId,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // live so the home carousel and this list update the moment a destination
  // is added, edited, or removed from the console
  void listenDestinations() {
    _destinationsSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _destinationsSub = _streamDestinations().listen(
      (destinations) {
        _destinations = destinations;
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

  Future<bool> createDestination(DestinationModel destination) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _createDestination(destination);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDestination(DestinationModel destination) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _updateDestination(destination);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDestination(String destinationId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _deleteDestination(destinationId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<SeatModel> _generateSeats(int totalSeats) {
    const letters = ['A', 'B', 'C', 'D'];
    return [
      for (var i = 0; i < totalSeats; i++)
        SeatModel(
          seatNumber: '${(i ~/ letters.length) + 1}${letters[i % letters.length]}',
          isBooked: false,
        ),
    ];
  }

  @override
  void dispose() {
    _companiesSub?.cancel();
    _myBusesSub?.cancel();
    _selectedBusSeatsSub?.cancel();
    _companyBookingsSub?.cancel();
    _destinationsSub?.cancel();
    super.dispose();
  }
}
