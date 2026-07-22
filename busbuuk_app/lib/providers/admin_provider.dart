// holds state for the bus-company onboarder / super-admin screens: company
// list, the signed-in onboarder's own buses, seat management, provisioning
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/bus_company_model.dart';
import '../models/bus_model.dart';
import '../models/destination_model.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/firestore_service.dart';

typedef CompanyLister = Future<List<BusCompanyModel>> Function();
typedef CompanyCreator = Future<void> Function(BusCompanyModel company);
typedef CompanyBusLister = Future<List<BusModel>> Function(String companyId);
typedef BusCreator = Future<void> Function(BusModel bus);
typedef BusUpdater = Future<void> Function(BusModel bus);
typedef BusDeleter = Future<void> Function(String busId);
typedef CompanyBookingsLister = Future<List<BookingModel>> Function(String companyId);
typedef SeatBatchCreator =
    Future<void> Function(String busId, List<SeatModel> seats);
typedef AdminSeatFetcher = Future<List<SeatModel>> Function(String busId);
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
typedef DestinationLister = Future<List<DestinationModel>> Function();
typedef DestinationCreator = Future<void> Function(DestinationModel destination);
typedef DestinationUpdater = Future<void> Function(DestinationModel destination);
typedef DestinationDeleter = Future<void> Function(String destinationId);

class AdminProvider extends ChangeNotifier {
  // all injectable so previews/tests can swap in mock data without needing
  // Firebase.initializeApp() to have run.
  AdminProvider({
    CompanyLister? getCompanies,
    CompanyCreator? createCompany,
    CompanyBusLister? getBusesForCompany,
    BusCreator? createBus,
    BusUpdater? updateBus,
    BusDeleter? deleteBus,
    SeatBatchCreator? createSeatsForBus,
    AdminSeatFetcher? getSeatsForBus,
    SeatBookedSetter? setSeatBooked,
    OnboarderProvisioner? provisionOnboarder,
    CompanyBookingsLister? getCompanyBookings,
    DestinationLister? getDestinations,
    DestinationCreator? createDestination,
    DestinationUpdater? updateDestination,
    DestinationDeleter? deleteDestination,
  }) : _getCompanies = getCompanies ?? FirestoreService().getCompanies,
       _createCompany = createCompany ?? FirestoreService().createCompany,
       _getBusesForCompany =
           getBusesForCompany ?? FirestoreService().getBusesForCompany,
       _createBus = createBus ?? FirestoreService().createBus,
       _updateBus = updateBus ?? FirestoreService().updateBus,
       _deleteBus = deleteBus ?? FirestoreService().deleteBus,
       _createSeatsForBus =
           createSeatsForBus ?? FirestoreService().createSeatsForBus,
       _getSeatsForBus = getSeatsForBus ?? FirestoreService().getSeatsForBus,
       _setSeatBooked = setSeatBooked ?? FirestoreService().setSeatBooked,
       _provisionOnboarder =
           provisionOnboarder ?? AdminService().provisionOnboarder,
       _getCompanyBookings =
           getCompanyBookings ?? FirestoreService().getCompanyBookings,
       _getDestinations = getDestinations ?? FirestoreService().getDestinations,
       _createDestination =
           createDestination ?? FirestoreService().createDestination,
       _updateDestination =
           updateDestination ?? FirestoreService().updateDestination,
       _deleteDestination =
           deleteDestination ?? FirestoreService().deleteDestination;

  final CompanyLister _getCompanies;
  final CompanyCreator _createCompany;
  final CompanyBusLister _getBusesForCompany;
  final BusCreator _createBus;
  final BusUpdater _updateBus;
  final BusDeleter _deleteBus;
  final SeatBatchCreator _createSeatsForBus;
  final AdminSeatFetcher _getSeatsForBus;
  final SeatBookedSetter _setSeatBooked;
  final OnboarderProvisioner _provisionOnboarder;
  final CompanyBookingsLister _getCompanyBookings;
  final DestinationLister _getDestinations;
  final DestinationCreator _createDestination;
  final DestinationUpdater _updateDestination;
  final DestinationDeleter _deleteDestination;

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

  Future<void> fetchCompanies() async {
    _isLoading = true;
    notifyListeners();
    try {
      _companies = await _getCompanies();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyBuses(String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _myBuses = await _getBusesForCompany(companyId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // called when an onboarder taps into a bus from Manage Buses to mark
  // walk-in terminal seats occupied
  Future<void> selectBusForSeatManagement(BusModel bus) async {
    _selectedBus = bus;
    _isLoading = true;
    notifyListeners();
    try {
      _selectedBusSeats = await _getSeatsForBus(bus.id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _selectedBusSeats = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _companies = [..._companies, company];
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
      _myBuses = [..._myBuses, bus];
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
      _myBuses = [for (final b in _myBuses) if (b.id == bus.id) bus else b];
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
      _myBuses = _myBuses.where((b) => b.id != busId).toList();
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

  // flips a seat occupied/vacant for a walk-in terminal booking
  Future<void> toggleSeatOccupied(String seatNumber, bool newValue) async {
    final bus = _selectedBus;
    if (bus == null) return;
    try {
      await _setSeatBooked(bus.id, seatNumber, newValue);
      _selectedBusSeats = [
        for (final seat in _selectedBusSeats)
          if (seat.seatNumber == seatNumber)
            SeatModel(seatNumber: seat.seatNumber, isBooked: newValue)
          else
            seat,
      ];
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchCompanyBookings(String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _companyBookings = await _getCompanyBookings(companyId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> fetchDestinations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _destinations = await _getDestinations();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDestination(DestinationModel destination) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _createDestination(destination);
      _destinations = [..._destinations, destination]
        ..sort((a, b) => a.order.compareTo(b.order));
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
      _destinations = [
        for (final d in _destinations)
          if (d.id == destination.id) destination else d,
      ]..sort((a, b) => a.order.compareTo(b.order));
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
      _destinations = _destinations.where((d) => d.id != destinationId).toList();
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
}