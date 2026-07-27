// Payment Screen ("Payment Options")
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/booking_stepper.dart';
import '../../widgets/primary_button.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    // preselect whatever the passenger picked as their default under
    // Profile > Payment Methods, instead of always defaulting to MTN
    final defaultMethod = context.read<AuthProvider>().currentUser?.defaultPaymentMethod;
    if (defaultMethod != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<BookingProvider>().setPaymentMethod(defaultMethod);
      });
    }
  }

  Future<void> _pay(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final booking = context.read<BookingProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    // MTN/Airtel go through a simulated USSD-style PIN prompt first; card
    // payments (no mobile wallet involved) skip straight to confirming.
    if (booking.paymentMethod == 'mtn' || booking.paymentMethod == 'airtel') {
      final approved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _MomoPinSheet(
          isMtn: booking.paymentMethod == 'mtn',
          phone: booking.passengers.isNotEmpty ? booking.passengers.first.phone : '',
          amount: booking.totalAmount,
        ),
      );
      if (approved != true || !context.mounted) return;
    }

    final result = await booking.confirmBooking(userId: uid);
    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(booking.errorMessage ?? 'payment failed, try again')),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Booking confirmed!'),
        content: Text('Your ${booking.selectedSeatNumbers.length} seat(s) are booked. Have a safe trip.'),
        actions: [
          FilledButton(
            onPressed: () {
              context.pop();
              booking.resetBookingFlow();
              context.go('/my-bookings');
            },
            child: const Text('View My Bookings'),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDateTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]}, ${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final bus = booking.selectedBus;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Payment Options')),
      body: Column(
        children: [
          const BookingStepper(activeIndex: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                if (bus != null) _TripSummaryCard(colorScheme: colorScheme, dateTimeLabel: _formatDateTime(bus.departureTime), busType: bus.busType, route: '${bus.from} → ${bus.to}', seatsLabel: '${booking.selectedSeatNumbers.join(', ')} (${booking.passengers.length} Adults)', passengersLabel: booking.passengers.map((p) => p.fullName).join(', ')),
                const SizedBox(height: 20),
                Text('Select Payment Method', style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _PaymentOption(
                  color: const Color(0xFFFFCC00),
                  icon: Icons.phone_iphone_rounded,
                  label: 'MTN Mobile Money',
                  subtitle: 'Instant processing',
                  value: 'mtn',
                  selected: booking.paymentMethod == 'mtn',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                _PaymentOption(
                  color: const Color(0xFFED1C24),
                  icon: Icons.sim_card_rounded,
                  label: 'Airtel Money',
                  subtitle: 'Low transaction fees',
                  value: 'airtel',
                  selected: booking.paymentMethod == 'airtel',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                _PaymentOption(
                  color: colorScheme.secondary,
                  icon: Icons.credit_card_rounded,
                  label: 'Credit/Debit Card',
                  subtitle: 'Visa, Mastercard, Amex',
                  value: 'card',
                  selected: booking.paymentMethod == 'card',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/profile/payment-methods'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Add New Payment Method', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BottomBar(
            totalAmount: booking.totalAmount,
            isLoading: booking.isLoading,
            onPay: () => _pay(context),
          ),
        ],
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String dateTimeLabel;
  final String busType;
  final String route;
  final String seatsLabel;
  final String passengersLabel;

  const _TripSummaryCard({
    required this.colorScheme,
    required this.dateTimeLabel,
    required this.busType,
    required this.route,
    required this.seatsLabel,
    required this.passengersLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROUTE', style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(route, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(busType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onPrimaryContainer)),
              ),
            ],
          ),
          const Divider(height: 24),
          _SummaryRow(label: 'Date & Time', value: dateTimeLabel, colorScheme: colorScheme),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Seats', value: seatsLabel, colorScheme: colorScheme),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Passengers', value: passengersLabel, colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _SummaryRow({required this.label, required this.value, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final ColorScheme colorScheme;

  const _PaymentOption({
    required this.color,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.read<BookingProvider>().setPaymentMethod(value),
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

class _BottomBar extends StatelessWidget {
  final double totalAmount;
  final bool isLoading;
  final VoidCallback onPay;

  const _BottomBar({required this.totalAmount, required this.isLoading, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total Amount', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatAmount(totalAmount)}rwf',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                    ),
                    Text('Inc. all taxes', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'Pay Now', icon: Icons.lock_outline, isLoading: isLoading, onPressed: onPay),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                children: const [
                  TextSpan(text: 'By clicking Pay Now, you agree to our '),
                  TextSpan(text: 'Terms of Service', style: TextStyle(decoration: TextDecoration.underline)),
                  TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policy', style: TextStyle(decoration: TextDecoration.underline)),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// fake USSD PIN prompt so "Pay Now" feels like a real mobile money payment
// instead of just instantly succeeding. Returns true once "approved",
// false/null if the user backs out.

enum _MomoStage { enterPin, processing, success }

class _MomoPinSheet extends StatefulWidget {
  final bool isMtn;
  final String phone;
  final double amount;

  const _MomoPinSheet({required this.isMtn, required this.phone, required this.amount});

  @override
  State<_MomoPinSheet> createState() => _MomoPinSheetState();
}

class _MomoPinSheetState extends State<_MomoPinSheet> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  _MomoStage _stage = _MomoStage.enterPin;
  String? _error;

  String get _providerName => widget.isMtn ? 'MTN Mobile Money' : 'Airtel Money';
  Color get _providerColor => widget.isMtn ? const Color(0xFFFFCC00) : const Color(0xFFED1C24);
  IconData get _providerIcon => widget.isMtn ? Icons.phone_iphone_rounded : Icons.sim_card_rounded;

  String get _displayPhone => widget.phone.trim().isEmpty ? 'your registered number' : widget.phone.trim();

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pinController.text.length != 4) {
      setState(() => _error = 'Enter your 4-digit Mobile Money PIN');
      return;
    }

    setState(() {
      _error = null;
      _stage = _MomoStage.processing;
    });
    FocusScope.of(context).unfocus();

    // fake delay to feel like the operator sent a prompt to the phone
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    setState(() => _stage = _MomoStage.success);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _stage == _MomoStage.enterPin,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_stage) {
                  _MomoStage.enterPin => _buildEnterPin(colorScheme),
                  _MomoStage.processing => _buildProcessing(colorScheme),
                  _MomoStage.success => _buildSuccess(colorScheme),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterPin(ColorScheme colorScheme) {
    return Column(
      key: const ValueKey('enterPin'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: colorScheme.outline, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _providerColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(_providerIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_providerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text('Requesting payment from $_displayPhone', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text('Amount to pay', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                '${formatAmount(widget.amount)}rwf',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter your Mobile Money PIN to authorize this payment',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _buildPinBoxes(colorScheme),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error, fontSize: 12)),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(label: 'Confirm Payment', onPressed: _submit),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinBoxes(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++) ...[
                _PinBox(filled: i < _pinController.text.length, colorScheme: colorScheme),
                if (i != 3) const SizedBox(width: 14),
              ],
            ],
          ),
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _pinController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing(ColorScheme colorScheme) {
    return Padding(
      key: const ValueKey('processing'),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _providerColor),
          const SizedBox(height: 20),
          Text(
            'Confirm the payment on your phone',
            style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'A $_providerName prompt was sent to $_displayPhone',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ColorScheme colorScheme) {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 52),
          const SizedBox(height: 16),
          Text('Payment Approved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(
            '${formatAmount(widget.amount)}rwf sent via $_providerName',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  final bool filled;
  final ColorScheme colorScheme;

  const _PinBox({required this.filled, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filled ? colorScheme.primary : colorScheme.outline, width: filled ? 2 : 1),
        color: filled ? colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: filled
          ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary))
          : null,
    );
  }
}