// Manage Companies (super-admin only) - create bus companies, add onboarders
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class AdminCompanyListScreen extends StatefulWidget {
  const AdminCompanyListScreen({super.key});

  @override
  State<AdminCompanyListScreen> createState() => _AdminCompanyListScreenState();
}

class _AdminCompanyListScreenState extends State<AdminCompanyListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCompanies();
    });
  }

  Future<void> _showCreateCompanyDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Bus Company'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Company Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<AdminProvider>().createCompany(name);
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
      appBar: AppBar(title: const Text('Bus Companies')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCompanyDialog,
        child: const Icon(Icons.add),
      ),
      body: admin.isLoading && admin.companies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : admin.companies.isEmpty
              ? const Center(child: Text('No bus companies yet - tap + to add one'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: admin.companies.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final company = admin.companies[index];
                    return Card(
                      child: ListTile(
                        title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: TextButton(
                          onPressed: () =>
                              context.push('/admin/companies/onboarders/new', extra: company.id),
                          child: const Text('Add Onboarder'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}