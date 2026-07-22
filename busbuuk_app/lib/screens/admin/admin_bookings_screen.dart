// Client Bookings - lets a company's onboarder see who's booked their buses,
// with each passenger's contact details so they can call and confirm the trip
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import '../../models/passenger_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/call_launcher.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<AuthProvider>().currentUser?.companyId;
    if (companyId != null) {
      await context.read<AdminProvider>().fetchCompanyBookings(companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Client Bookings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: admin.isLoading && admin.companyBookings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : admin.errorMessage != null && admin.companyBookings.isEmpty
            ? _ErrorState(message: admin.errorMessage!, colorScheme: colorScheme)
            : admin.companyBookings.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No bookings yet on your buses')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: admin.companyBookings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _BookingCard(booking: admin.companyBookings[index], colorScheme: colorScheme),
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;
  const _ErrorState({required this.message, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
      children: [
        Icon(Icons.error_outline_rounded, size: 40, color: colorScheme.error),
        const SizedBox(height: 10),
        const Text(
          'Couldn\'t load bookings',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          'Pull down to try again',
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final ColorScheme colorScheme;

  const _BookingCard({required this.booking, required this.colorScheme});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _departureLabel {
    final d = booking.departureTime;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('${booking.from} → ${booking.to}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Departs $_departureLabel • ${booking.seatNumbers.join(', ')}'),
        trailing: _StatusChip(status: booking.status, colorScheme: colorScheme),
        children: [
          for (final passenger in booking.passengers)
            _PassengerTile(passenger: passenger, colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final ColorScheme colorScheme;

  const _StatusChip({required this.status, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'confirmed' => colorScheme.primary,
      'cancelled' => colorScheme.error,
      _ => colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _PassengerTile extends StatelessWidget {
  final PassengerModel passenger;
  final ColorScheme colorScheme;

  const _PassengerTile({required this.passenger, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          passenger.fullName.isNotEmpty ? passenger.fullName[0].toUpperCase() : '?',
          style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(passenger.fullName),
      subtitle: Text('Seat ${passenger.seatNumber} • ${passenger.phone}'),
      trailing: IconButton(
        onPressed: () => launchPhoneCall(context, passenger.phone),
        icon: Icon(Icons.call_rounded, color: colorScheme.primary),
        tooltip: 'Call ${passenger.fullName}',
      ),
    );
  }
}