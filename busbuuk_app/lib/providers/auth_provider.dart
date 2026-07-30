// login/signup/logout state, wraps AuthService + FirebaseAuth
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  // late: constructing these touches Firebase.instance eagerly, so a
  // provider built before Firebase.initializeApp() has run would crash
  // immediately instead of only once it's actually used.
  late final AuthService _authService = AuthService();
  late final FirestoreService _firestoreService = FirestoreService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // true until the very first authStateChanges event comes back, so the splash
  // screen/router know whether we're still checking or actually logged out
  bool _isInitializing = true;

  // keeps currentUser live so an edit made straight from the Firestore
  // console (or another device) reflects on the Profile screen instantly
  StreamSubscription<UserModel?>? _profileSub;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    // keep our own user profile in sync whenever firebase's auth state changes
    _authService.authStateChanges.listen((firebaseUser) {
      _profileSub?.cancel();
      if (firebaseUser == null) {
        _currentUser = null;
        _isInitializing = false;
        notifyListeners();
        return;
      }
      _profileSub = _firestoreService.streamUserProfile(firebaseUser.uid).listen((user) {
        _currentUser = user;
        _isInitializing = false;
        notifyListeners();
      });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  // network calls are wrapped in a timeout so a stalled connection surfaces
  // as an error instead of leaving the sign-in button spinning forever
  static const _networkTimeout = Duration(seconds: 15);

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final credential = await _authService
          .signUp(email: email, password: password)
          .timeout(_networkTimeout);
      final uid = credential.user!.uid;

      final newUser = UserModel(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUserProfile(newUser).timeout(_networkTimeout);

      _currentUser = newUser;
      _errorMessage = null;
      return true;
    } on TimeoutException {
      _errorMessage = 'Connection timed out. Check your internet and try again.';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      final credential = await _authService
          .signIn(email: email, password: password)
          .timeout(_networkTimeout);
      _currentUser = await _firestoreService
          .getUserProfile(credential.user!.uid)
          .timeout(_networkTimeout);
      _errorMessage = null;
      return true;
    } on TimeoutException {
      _errorMessage = 'Connection timed out. Check your internet and try again.';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfileImage(String base64Image) async {
    final user = _currentUser;
    if (user == null) return false;

    try {
      await _firestoreService.updateProfileImage(user.uid, base64Image);
      _currentUser = user.copyWith(profileImageBase64: base64Image);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updatePersonalInfo({required String name, required String phone}) async {
    final user = _currentUser;
    if (user == null) return false;

    try {
      await _firestoreService.updateUserFields(user.uid, {'name': name, 'phone': phone});
      _currentUser = user.copyWith(name: name, phone: phone);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateDefaultPaymentMethod(String method) async {
    final user = _currentUser;
    if (user == null) return false;

    try {
      await _firestoreService.updateUserFields(user.uid, {'defaultPaymentMethod': method});
      _currentUser = user.copyWith(defaultPaymentMethod: method);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}