// Manage Destinations (super-admin only) - the home screen carousel cards
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/destination_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AdminDestinationsScreen extends StatefulWidget {
  const AdminDestinationsScreen({super.key});

  @override
  State<AdminDestinationsScreen> createState() => _AdminDestinationsScreenState();
}

class _AdminDestinationsScreenState extends State<AdminDestinationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDestinations();
    });
  }

  Future<void> _confirmDelete(DestinationModel destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete destination?'),
        content: Text('"${destination.city}, ${destination.country}" will be removed from the home carousel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AdminProvider>().deleteDestination(destination.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final admin = context.watch<AdminProvider>();
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null || !user.isSuperAdmin) {
      return const Scaffold(body: Center(child: Text('super-admin access only')));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Manage Destinations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/destinations/new'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AdminProvider>().fetchDestinations(),
        child: admin.isLoading && admin.destinations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : admin.destinations.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No destinations yet - tap + to add one to the home carousel')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: admin.destinations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final destination = admin.destinations[index];
                      return _DestinationTile(
                        destination: destination,
                        onDelete: () => _confirmDelete(destination),
                      );
                    },
                  ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final DestinationModel destination;
  final VoidCallback onDelete;

  const _DestinationTile({required this.destination, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(destination.imageBase64),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        title: Text('${destination.city}, ${destination.country}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Order: ${destination.order}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/admin/destinations/edit', extra: destination);
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}