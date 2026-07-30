// Firestore reads/writes - users, buses, bookings
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/bus_company_model.dart';
import '../models/destination_model.dart';
import '../models/seat_model.dart';
import '../models/booking_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- users ----

  Future<void> createUserProfile(UserModel user) {
    return _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // live so a profile edit made straight from the Firestore console (or from
  // another device) shows up on the Profile screen without a re-login
  Stream<UserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  // no Firebase Storage on the free plan, so just save the pic as base64 on the user doc
  Future<void> updateProfileImage(String uid, String base64Image) {
    return _db.collection('users').doc(uid).update({
      'profileImageBase64': base64Image,
    });
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) {
    return _db.collection('users').doc(uid).update(fields);
  }

  // ---- buses / search ----

  // live query so seat counts on the Timetable screen update in real time
  // as people book (or an onboarder toggles a walk-in seat elsewhere)
  Stream<List<BusModel>> streamBuses({
    required String from,
    required String to,
  }) {
    return _db.collection('buses').snapshots().map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((d) => BusModel.fromMap(d.data()))
          .where(
            (bus) =>
                _matchesCity(bus.from, from) &&
                _matchesCity(bus.to, to) &&
                // skip buses that already left, no point booking a trip that's over
                bus.departureTime.isAfter(now),
          )
          .toList();
    });
  }

  // bus docs store "City, Country" but the user just types the city,
  // so a straight equality check would never match - compare city names only
  bool _matchesCity(String stored, String query) {
    final storedCity = stored.split(',').first.trim().toLowerCase();
    final queryCity = query.split(',').first.trim().toLowerCase();
    return storedCity.contains(queryCity) || queryCity.contains(storedCity);
  }

  // ---- seats ----

  // live so a seat booked/toggled by someone else (or from the console)
  // while this screen is open updates instantly instead of going stale
  Stream<List<SeatModel>> streamSeatsForBus(String busId) {
    return _db
        .collection('buses')
        .doc(busId)
        .collection('seats')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => SeatModel.fromMap(d.data())).toList());
  }

  // ---- bookings ----

  Future<void> createBooking(BookingModel booking) {
    return _db.collection('bookings').doc(booking.id).set(booking.toMap());
  }

  // one batch write: create the booking, flip the seats to booked, and drop
  // availableSeats - all or nothing so we never end up with a half-booked state
  Future<void> confirmBookingAndMarkSeats(
    BookingModel booking,
    List<String> seatNumbers,
  ) async {
    final batch = _db.batch();
    final busRef = _db.collection('buses').doc(booking.busId);
    batch.set(_db.collection('bookings').doc(booking.id), booking.toMap());
    for (final seatNumber in seatNumbers) {
      batch.update(busRef.collection('seats').doc(seatNumber), {
        'isBooked': true,
      });
    }
    batch.update(busRef, {
      'availableSeats': FieldValue.increment(-seatNumbers.length),
    });
    await batch.commit();
  }

  // live so a booking made/cancelled elsewhere (or edited from the console)
  // shows up on My Bookings instantly
  Stream<List<BookingModel>> streamUserBookings(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => BookingModel.fromMap(d.data())).toList());
  }

  // just clears a completed trip from history, nothing to undo seat-wise
  // since the trip already happened
  Future<void> deleteBooking(String bookingId) {
    return _db.collection('bookings').doc(bookingId).delete();
  }

  // so an onboarder can see who booked their buses and call them if needed
  Stream<List<BookingModel>> streamCompanyBookings(String companyId) {
    return _db
        .collection('bookings')
        .where('companyId', isEqualTo: companyId)
        .orderBy('bookingDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => BookingModel.fromMap(d.data())).toList());
  }

  // ---- admin: companies ----

  Future<void> createCompany(BusCompanyModel company) {
    return _db.collection('companies').doc(company.id).set(company.toMap());
  }

  // live so a company added/renamed from the console shows up without a refresh
  Stream<List<BusCompanyModel>> streamCompanies() {
    return _db
        .collection('companies')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => BusCompanyModel.fromMap(d.data())).toList());
  }

  // ---- admin: buses & seats ----

  Future<void> createBus(BusModel bus) {
    return _db.collection('buses').doc(bus.id).set(bus.toMap());
  }

  Future<void> updateBus(BusModel bus) {
    return _db.collection('buses').doc(bus.id).update(bus.toMap());
  }

  // Firestore won't cascade-delete the seats subcollection on its own
  // (and we've got no Cloud Function to do it server-side), so wipe it by hand first
  Future<void> deleteBus(String busId) async {
    final busRef = _db.collection('buses').doc(busId);
    final seats = await busRef.collection('seats').get();
    final batch = _db.batch();
    for (final seat in seats.docs) {
      batch.delete(seat.reference);
    }
    batch.delete(busRef);
    await batch.commit();
  }

  // live so an onboarder's own bus list stays in sync with the console
  Stream<List<BusModel>> streamBusesForCompany(String companyId) {
    return _db
        .collection('buses')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => BusModel.fromMap(d.data())).toList());
  }

  Future<void> createSeatsForBus(String busId, List<SeatModel> seats) async {
    final batch = _db.batch();
    for (final seat in seats) {
      batch.set(
        _db
            .collection('buses')
            .doc(busId)
            .collection('seats')
            .doc(seat.seatNumber),
        seat.toMap(),
      );
    }
    await batch.commit();
  }

  // transaction instead of a plain update, so availableSeats can't drift
  // if two onboarders toggle the same seat at the same time
  Future<void> setSeatBooked(String busId, String seatNumber, bool isBooked) {
    final busRef = _db.collection('buses').doc(busId);
    final seatRef = busRef.collection('seats').doc(seatNumber);
    return _db.runTransaction((tx) async {
      final seatSnap = await tx.get(seatRef);
      final wasBooked = seatSnap.data()?['isBooked'] as bool? ?? false;
      if (wasBooked == isBooked) return;
      tx.update(seatRef, {'isBooked': isBooked});
      tx.update(busRef, {
        'availableSeats': FieldValue.increment(isBooked ? -1 : 1),
      });
    });
  }

  // ---- admin: destinations (home carousel) ----

  Future<void> createDestination(DestinationModel destination) {
    return _db
        .collection('destinations')
        .doc(destination.id)
        .set(destination.toMap());
  }

  Future<void> updateDestination(DestinationModel destination) {
    return _db
        .collection('destinations')
        .doc(destination.id)
        .update(destination.toMap());
  }

  Future<void> deleteDestination(String destinationId) {
    return _db.collection('destinations').doc(destinationId).delete();
  }

  // live so the home carousel updates the moment a destination is added,
  // edited, or removed from the console
  Stream<List<DestinationModel>> streamDestinations() {
    return _db
        .collection('destinations')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => DestinationModel.fromMap(d.data())).toList());
  }
}
