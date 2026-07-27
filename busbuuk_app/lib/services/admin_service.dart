// Lets a super-admin create a new companyAdmin login without getting logged
// out of their own account.
//
// Problem: createUserWithEmailAndPassword() auto-signs you into the account
// it just made. If we called that on the main app, it'd boot the super-admin
// out of their own session. Workaround: spin up a second, separate
// FirebaseApp just for this - its auth state doesn't touch the primary
// app's, so the super-admin stays logged in. No Cloud Functions/Admin SDK
// needed either, which is good since we're on the free Spark plan.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

const _provisioningAppName = 'onboarderProvisioning';

class AdminService {
  AdminService({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_provisioningAppName);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _provisioningAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<UserModel> provisionOnboarder({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String companyId,
  }) async {
    final secondaryApp = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      final onboarder = UserModel(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime.now(),
        role: 'companyAdmin',
        companyId: companyId,
      );
      // write goes through the primary Firestore instance, since that's the
      // one signed in as the super-admin (firestore.rules checks against it)
      await _firestoreService.createUserProfile(onboarder);

      return onboarder;
    } finally {
      // just sign out of the secondary session - keep the app instance
      // around so the next onboarder we create can reuse it
      await secondaryAuth.signOut();
    }
  }
}