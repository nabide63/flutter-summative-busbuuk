// root widget - MultiProvider + MaterialApp.router setup goes here
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/search_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/settings_provider.dart';
import 'routes/app_router.dart';

class BusbuukApp extends StatefulWidget {
  const BusbuukApp({super.key});

  @override
  State<BusbuukApp> createState() => _BusbuukAppState();
}

class _BusbuukAppState extends State<BusbuukApp> {
  late final AuthProvider _authProvider;
  late final SettingsProvider _settingsProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // built once here instead of via ChangeNotifierProvider.create, since the
    // router needs this exact instance to listen to for its auth redirect
    _authProvider = AuthProvider();
    _router = buildRouter(_authProvider);
    // loads saved preferences (notifications/language/text size) from disk so
    // they're restored on every cold start, not just kept in memory
    _settingsProvider = SettingsProvider()..load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp.router(
          title: 'Busbuuk',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          routerConfig: _router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(settings.textSize.scale),
            ),
            child: child!,
          ),
        ),
      ),
    );
  }
}

// fixed brand palette from the Figma design (not Material-You seed-generated)
const _busbuukOrange = Color(0xFFFEA619);
const _busbuukOrangeLight = Color(0xFFFFE8C2);
const _busbuukOrangeDark = Color(0xFF855300);
const _busbuukNavy = Color(0xFF001856);
const _busbuukLavender = Color(0xFFF0F3FF);
const _busbuukLavenderDeep = Color(0xFFDCE2F3);
const _busbuukTextSecondary = Color(0xFF757681);
const _busbuukBorder = Color(0xFFE5E7EB);
const _busbuukMint = Color(0xFF4EDEA3);

ThemeData _buildTheme() {
  const colorScheme = ColorScheme.light(
    primary: _busbuukOrange,
    onPrimary: Colors.white,
    primaryContainer: _busbuukOrangeLight,
    onPrimaryContainer: _busbuukOrangeDark,
    secondary: _busbuukNavy,
    onSecondary: Colors.white,
    secondaryContainer: _busbuukLavenderDeep,
    onSecondaryContainer: _busbuukNavy,
    tertiary: _busbuukMint,
    onTertiary: Colors.white,
    surface: Colors.white,
    onSurface: _busbuukNavy,
    onSurfaceVariant: _busbuukTextSecondary,
    surfaceContainerHighest: _busbuukLavender,
    surfaceContainerHigh: _busbuukLavenderDeep,
    outline: _busbuukBorder,
    outlineVariant: _busbuukLavenderDeep,
    error: Color(0xFFDC2626),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: _busbuukNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme().apply(bodyColor: _busbuukNavy, displayColor: _busbuukNavy),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _busbuukLavender,
      hintStyle: const TextStyle(color: _busbuukTextSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _busbuukLavender,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _busbuukOrange.withValues(alpha: 0.15),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _busbuukOrange,
        foregroundColor: _busbuukNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}