// Manage Buses - lists the signed-in onboarder's own company's buses/routes
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/bus_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AdminBusListScreen extends StatefulWidget {
  const AdminBusListScreen({super.key});

  @override
  State<AdminBusListScreen> createState() => _AdminBusListScreenState();
}

class _AdminBusListScreenState extends State<AdminBusListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<AuthProvider>().currentUser?.companyId;
    if (companyId != null) {
      context.read<AdminProvider>().listenMyBuses(companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Manage Buses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/buses/new'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: admin.isLoading && admin.myBuses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : admin.myBuses.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No buses yet - tap + to add your first route')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: admin.myBuses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _BusTile(
                      bus: admin.myBuses[index],
                      colorScheme: colorScheme,
                    ),
                  ),
      ),
    );
  }
}

class _BusTile extends StatelessWidget {
  final BusModel bus;
  final ColorScheme colorScheme;

  const _BusTile({required this.bus, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          '${bus.from} → ${bus.to}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${bus.operatorName} · ${bus.busType} · ${bus.totalSeats} seats'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/admin/buses/edit', extra: bus);
              case 'seats':
                context.push('/admin/buses/seats', extra: bus);
              case 'delete':
                context.read<AdminProvider>().deleteBus(bus.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'seats', child: Text('Manage Seats')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}