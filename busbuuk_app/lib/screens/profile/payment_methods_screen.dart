// Payment Methods Screen - lets the passenger pick which of the checkout
// payment options (MTN/Airtel/Card) should come preselected on the Payment
// Options step of booking, instead of always defaulting to MTN.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _isSaving = false;

  Future<void> _select(String method) async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser?.defaultPaymentMethod == method) return;

    setState(() => _isSaving = true);
    final success = await auth.updateDefaultPaymentMethod(method);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'could not save your default payment method')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final selected = user?.defaultPaymentMethod;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Choose the method used at checkout by default',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  _PaymentMethodTile(
                    color: const Color(0xFFFFCC00),
                    icon: Icons.phone_iphone_rounded,
                    label: 'MTN Mobile Money',
                    subtitle: 'Instant processing',
                    value: 'mtn',
                    selected: selected == 'mtn',
                    enabled: !_isSaving,
                    colorScheme: colorScheme,
                    onTap: () => _select('mtn'),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodTile(
                    color: const Color(0xFFED1C24),
                    icon: Icons.sim_card_rounded,
                    label: 'Airtel Money',
                    subtitle: 'Low transaction fees',
                    value: 'airtel',
                    selected: selected == 'airtel',
                    enabled: !_isSaving,
                    colorScheme: colorScheme,
                    onTap: () => _select('airtel'),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodTile(
                    color: colorScheme.secondary,
                    icon: Icons.credit_card_rounded,
                    label: 'Credit/Debit Card',
                    subtitle: 'Visa, Mastercard, Amex',
                    value: 'card',
                    selected: selected == 'card',
                    enabled: !_isSaving,
                    colorScheme: colorScheme,
                    onTap: () => _select('card'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final bool enabled;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}