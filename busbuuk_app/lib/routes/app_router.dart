// go_router setup - every route in the app gets registered here
import 'package:go_router/go_router.dart';

import '../models/bus_model.dart';
import '../models/destination_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/main_scaffold.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_results_screen.dart';
import '../screens/search/bus_details_screen.dart';
import '../screens/booking/seat_selection_screen.dart';
import '../screens/booking/passenger_details_screen.dart';
import '../screens/booking/payment_screen.dart';
import '../screens/booking/my_bookings_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/personal_info_screen.dart';
import '../screens/profile/payment_methods_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_bus_list_screen.dart';
import '../screens/admin/admin_bus_form_screen.dart';
import '../screens/admin/admin_seat_management_screen.dart';
import '../screens/admin/admin_bookings_screen.dart';
import '../screens/admin/admin_company_list_screen.dart';
import '../screens/admin/admin_create_onboarder_screen.dart';
import '../screens/admin/admin_destinations_screen.dart';
import '../screens/admin/admin_destination_form_screen.dart';

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    // rebuilds the redirect whenever auth state changes, e.g. sign in / sign out
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final onAuthScreen = loc == '/login' || loc == '/signup';
      final onAdminRoute = loc.startsWith('/admin');

      if (authProvider.isInitializing) {
        return onSplash ? null : '/splash';
      }
      if (!authProvider.isLoggedIn) {
        return onAuthScreen ? null : '/login';
      }

      // safe to read .role here since currentUser only gets set once the
      // Firestore profile fetch is done
      final user = authProvider.currentUser!;
      final isAdminRole = user.isCompanyAdmin || user.isSuperAdmin;

      if (onAuthScreen || onSplash) {
        return isAdminRole ? '/admin' : '/home';
      }
      // admin routes live outside the passenger bottom-nav shell, so guard
      // each side from wandering into the other's routes
      if (isAdminRole && !onAdminRoute) {
        return '/admin';
      }
      if (!isAdminRole && onAdminRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),

      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(path: 'buses', builder: (context, state) => const AdminBusListScreen()),
          GoRoute(
            path: 'buses/new',
            builder: (context, state) => const AdminBusFormScreen(),
          ),
          GoRoute(
            path: 'buses/edit',
            builder: (context, state) => AdminBusFormScreen(bus: state.extra as BusModel),
          ),
          GoRoute(
            path: 'buses/seats',
            builder: (context, state) => AdminSeatManagementScreen(bus: state.extra as BusModel),
          ),
          GoRoute(path: 'bookings', builder: (context, state) => const AdminBookingsScreen()),
          GoRoute(path: 'companies', builder: (context, state) => const AdminCompanyListScreen()),
          GoRoute(
            path: 'companies/onboarders/new',
            builder: (context, state) =>
                AdminCreateOnboarderScreen(companyId: state.extra as String),
          ),
          GoRoute(path: 'destinations', builder: (context, state) => const AdminDestinationsScreen()),
          GoRoute(
            path: 'destinations/new',
            builder: (context, state) => const AdminDestinationFormScreen(),
          ),
          GoRoute(
            path: 'destinations/edit',
            builder: (context, state) =>
                AdminDestinationFormScreen(destination: state.extra as DestinationModel),
          ),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainScaffold(navigationShell: navigationShell),
        branches: [
          // "Home" tab: search form, with results nested so the nav bar stays visible
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(path: 'search-results', builder: (context, state) => const SearchResultsScreen()),
              ],
            ),
          ]),
          // "Bookings" tab: my bookings, with the whole booking flow nested so the nav bar
          // stays visible throughout (matches the Figma design, unlike a full-screen push)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my-bookings',
              builder: (context, state) => const MyBookingsScreen(),
              routes: [
                GoRoute(
                  path: 'bus-details',
                  builder: (context, state) => BusDetailsScreen(bus: state.extra as BusModel),
                ),
                GoRoute(path: 'seat-selection', builder: (context, state) => const SeatSelectionScreen()),
                GoRoute(path: 'passenger-details', builder: (context, state) => const PassengerDetailsScreen()),
                GoRoute(path: 'payment', builder: (context, state) => const PaymentScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'personal-info', builder: (context, state) => const PersonalInfoScreen()),
                GoRoute(path: 'payment-methods', builder: (context, state) => const PaymentMethodsScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}