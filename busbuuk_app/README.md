# Busbuuk 

Busbuuk is a cross-border bus ticket booking app built with Flutter for our Mobile App Development Summative assignment. The idea is simple: let a passenger search for a bus route, pick a seat, fill in their details, pay, and keep track of their bookings — all from their phone, without needing to queue at a physical terminal.

This is a group project built and submitted by:

- Yusuf Nabide
- Esther Mahoro
- Esther Irakoze
- Frank Nkrunziza
- Crispin Hirwa

## What the app does

From a passenger's point of view, the flow goes:

**Splash → Login/Sign Up → Home → Search Results → Bus Details → Seat Selection → Passenger Details → Payment → My Bookings**, with a Profile tab alongside it. Home, Bookings and Profile sit behind a shared bottom navigation bar.

Main features:

- Search for a bus by route/destination and see available operators
- View a bus's details (departure/arrival time, operator, terminal, price)
- Pick a seat off a live seat map
- Fill in passenger details and "pay" for the ticket
- View past and upcoming bookings under "My Bookings"
- Manage a profile (personal info, payment methods, profile photo)

On top of the passenger side, there's an admin side for people running the bus companies:

- **Super Admin** — onboards bus companies and creates the first login (a "Company Admin") for each one
- **Company Admin** — manages their own company's buses, seat layouts and destinations, and can view/manage bookings made against their buses

Neither admin role can sign up through the normal Sign Up screen — they're only created by another admin, in-app (see the Admin Setup section below for the one manual exception).

## Tech stack

- **Flutter** (Dart) for the front end, targeting Android/iOS (and the desktop/web targets Flutter scaffolds by default)
- **Provider** for state management
- **go_router** for navigation, using a `StatefulShellRoute` so the bottom nav bar stays put across nested screens
- **Firebase Authentication** for login/sign up
- **Cloud Firestore** for storing users, bus companies, buses, seats, destinations and bookings
- Profile photos are compressed with `image_picker` and stored as base64 directly on the user's Firestore document (no Firebase Storage — that needs the paid Blaze plan, so we worked around it instead of paying for it)

## Project structure

```
lib/
  models/       data classes (User, Bus, BusCompany, Booking, Seat, Passenger, Payment, Destination)
  providers/    Provider-based state management (auth, search, booking, admin)
  routes/       go_router route setup and auth-aware redirects
  screens/      one folder per feature area:
    splash/       splash screen while Firebase auth state resolves
    auth/         login + sign up
    home/         home tab (search bar, recent searches, promos)
    search/       search results + bus details
    booking/      seat selection, passenger details, payment, my bookings
    profile/      profile, personal info, payment methods
    admin/        super-admin and company-admin screens
  services/     talks to Firebase directly (auth_service, firestore_service, admin_service)
  utils/        small helpers (formatters, call launcher, etc.)
  widgets/      shared UI pieces (buttons, seat grid, booking stepper, bottom nav scaffold)
```

## Getting it running

1. Make sure Flutter is installed and `flutter doctor` is happy.
2. Install dependencies:
   ```
   flutter pub get
   ```
3. This project needs its own Firebase project connected (Authentication + Cloud Firestore enabled, Email/Password sign-in turned on). We already generated `lib/firebase_options.dart` via `flutterfire configure` and committed the Android `google-services.json`, so cloning the repo should be enough to run it — but if you're wiring up a fresh Firebase project of your own, run `flutterfire configure` again and swap in your own config files.
4. Run the app:
   ```
   flutter run
   ```
5. Run the tests:
   ```
   flutter test
   ```

Firestore security rules live in `firestore.rules` and are deployed with `firebase deploy --only firestore:rules` (needs the Firebase CLI logged in).

## Admin setup (the one manual step)

Every company admin after the first one gets created in-app by a super-admin, from **Manage Companies → Add Onboarder**. But the very first super-admin has no one above them to do that — and since we're on Firebase's free Spark plan, there's no Cloud Functions/Admin SDK available to run a one-off privileged seed script. So that one account has to be created by hand, once, straight in the Firebase console:

1. **Firebase Console → Authentication → Users → Add user.** Set the super-admin's email + password.
2. Copy that user's **UID** from the Users table.
3. **Firestore Console → `users` collection → Add document.** Set the document ID to that same UID, with these fields (matches `UserModel.toMap()` in `lib/models/user_model.dart`):

   | Field | Type | Value |
   |---|---|---|
   | `uid` | string | the UID from step 2 |
   | `name` | string | e.g. `"Busbuuk Admin"` |
   | `email` | string | the email from step 1 |
   | `phone` | string | e.g. `"+250780000000"` |
   | `role` | string | `"superAdmin"` |
   | `companyId` | — | leave unset/null |
   | `profileImageBase64` | — | leave unset/null |
   | `createdAt` | string | an ISO8601 timestamp, e.g. `2026-01-01T00:00:00.000Z` |

4. Log in to the app with that email/password. The router (`lib/routes/app_router.dart`) checks for `role == 'superAdmin'` and sends you to `/admin` instead of the normal passenger home screen.
5. From `/admin` → **Manage Companies**, add a bus company, then **Add Onboarder** to create that company's first Company Admin login. After this one bootstrap step, everything else is done in-app.

