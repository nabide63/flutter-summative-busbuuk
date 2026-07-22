// Landing screen after a company-admin or super-admin login
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // run after the first frame so we can safely read providers here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null && user.isCompanyAdmin) {
        context.read<AdminProvider>().fetchCompanies();
      }
    });
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign back in to manage this account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  String? _companyName(AdminProvider admin, String? companyId) {
    if (companyId == null) return null;
    for (final company in admin.companies) {
      if (company.id == companyId) return company.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().currentUser;
    final admin = context.watch<AdminProvider>();

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final companyName = _companyName(admin, user.companyId);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Busbuuk Admin'),
        actions: [
          IconButton(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            user.isSuperAdmin ? 'Super Admin' : (companyName ?? 'Bus Company Admin'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(user.name, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          if (user.isCompanyAdmin) ...[
            _DashboardCard(
              icon: Icons.directions_bus_rounded,
              title: 'Manage Buses',
              subtitle: 'Routes, timetables, seats & services',
              onTap: () => context.push('/admin/buses'),
              colorScheme: colorScheme,
            ),
            _DashboardCard(
              icon: Icons.people_alt_rounded,
              title: 'Client Bookings',
              subtitle: 'See who\'s booked your buses & call them',
              onTap: () => context.push('/admin/bookings'),
              colorScheme: colorScheme,
            ),
          ],
          if (user.isSuperAdmin) ...[
            _DashboardCard(
              icon: Icons.apartment_rounded,
              title: 'Manage Companies',
              subtitle: 'Bus companies & onboarder accounts',
              onTap: () => context.push('/admin/companies'),
              colorScheme: colorScheme,
            ),
            _DashboardCard(
              icon: Icons.image_rounded,
              title: 'Manage Destinations',
              subtitle: 'Home screen carousel cities & photos',
              onTap: () => context.push('/admin/destinations'),
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(icon, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}