// New Onboarder (super-admin only) - provisions a companyAdmin login for the
// given bus company via AdminProvider.provisionOnboarder (secondary-app trick)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../widgets/primary_button.dart';

class AdminCreateOnboarderScreen extends StatefulWidget {
  final String companyId;
  const AdminCreateOnboarderScreen({super.key, required this.companyId});

  @override
  State<AdminCreateOnboarderScreen> createState() => _AdminCreateOnboarderScreenState();
}

class _AdminCreateOnboarderScreenState extends State<AdminCreateOnboarderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final admin = context.read<AdminProvider>();
    final success = await admin.provisionOnboarder(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      companyId: widget.companyId,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('onboarder account created')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'could not create this account, try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('New Onboarder')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'enter an email';
                    if (!value.contains('@')) return 'enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'enter a password';
                    if (value.length < 6) return 'password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Create Onboarder',
                  isLoading: admin.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}