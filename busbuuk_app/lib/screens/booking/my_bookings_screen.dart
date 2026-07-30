// My Bookings Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../utils/call_launcher.dart';
import '../../utils/formatters.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    // run after the first frame so we can safely read providers here
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      context.read<BookingProvider>().listenMyBookings(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // recompute ongoing/previous on every build instead of storing it, so a
    // trip flips status on its own once its time passes
    final now = DateTime.now();
    bool isPrevious(BookingModel b) => !b.arrivalTime.isAfter(now);
    bool isOngoing(BookingModel b) => !isPrevious(b) && !b.departureTime.isAfter(now);

    final ongoingTrips = booking.myBookings.where(isOngoing).toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
    final previousTrips = booking.myBookings.where(isPrevious).toList()
      ..sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
    // whatever trip is currently happening gets the big featured card
    final ongoingTrip = ongoingTrips.isEmpty ? null : ongoingTrips.first;
    // everything else not yet arrived goes in the regular ticket list below
    final bookedTickets = booking.myBookings.where((b) => !isPrevious(b) && b.id != ongoingTrip?.id).toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
    final previousTripsByYear = _groupByYear(previousTrips);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('My Bookings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: booking.isLoading && booking.myBookings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : booking.errorMessage != null && booking.myBookings.isEmpty
            ? _ErrorState(message: booking.errorMessage!, colorScheme: colorScheme)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (ongoingTrip != null) ...[
                    _SectionHeader(
                      title: 'Ongoing Trip',
                      trailing: _StatusChip(status: ongoingTrip.status, colorScheme: colorScheme),
                    ),
                    const SizedBox(height: 12),
                    _TicketTile(trip: ongoingTrip, colorScheme: colorScheme, initiallyExpanded: true),
                    const SizedBox(height: 28),
                  ] else ...[
                    _EmptyNextTrip(colorScheme: colorScheme),
                    const SizedBox(height: 28),
                  ],
                  // tap a row to expand into the full ticket, tap again to collapse
                  if (bookedTickets.isNotEmpty) ...[
                    const Text(
                      'All Booked Bus Tickets',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    for (final trip in bookedTickets) ...[
                      _TicketTile(trip: trip, colorScheme: colorScheme),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'Previous Trips',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (previousTripsByYear.isEmpty)
                    Text(
                      'Trips you\'ve taken will show up here once they\'re done',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    )
                  else
                    for (final group in previousTripsByYear) ...[
                      Text(
                        group.year,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      for (final trip in group.trips) ...[
                        _PreviousTripTile(trip: trip, colorScheme: colorScheme),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                    ],
                ],
              ),
      ),
    );
  }
}

// groups finished trips by year, newest year (and newest trip) first
List<_YearGroup> _groupByYear(List<BookingModel> trips) {
  final byYear = <int, List<BookingModel>>{};
  for (final trip in trips) {
    byYear.putIfAbsent(trip.arrivalTime.year, () => []).add(trip);
  }
  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final year in years) _YearGroup(year.toString(), byYear[year]!)];
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        trailing,
      ],
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
          'Couldn\'t load your bookings',
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

class _EmptyNextTrip extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyNextTrip({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.confirmation_number_outlined, size: 40, color: colorScheme.outline),
          const SizedBox(height: 10),
          const Text('No trip in progress', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('A trip shows up here once its departure time arrives', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

// full ticket card, used for both the auto-open ongoing trip and any
// booked ticket the user taps open

class _ExpandedTicketCard extends StatelessWidget {
  final BookingModel booking;
  final ColorScheme colorScheme;
  final VoidCallback onCollapse;

  const _ExpandedTicketCard({required this.booking, required this.colorScheme, required this.onCollapse});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String get _departureLabel {
    final d = booking.departureTime;
    return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} • ${_formatTime(d)}';
  }

  String get _duration {
    final duration = booking.arrivalTime.difference(booking.departureTime);
    return '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  // edge letters (A/D on normal rows, A/E on the back row) are window seats
  String _seatPosition(String seatNumber) {
    final letter = seatNumber.substring(seatNumber.length - 1).toUpperCase();
    return (letter == 'A' || letter == 'D' || letter == 'E') ? 'Window' : 'Aisle';
  }

  // e.g. "1A (Window), 1B (Aisle)" for a multi-seat booking
  String get _seatsLabel => booking.seatNumbers.map((s) => '$s (${_seatPosition(s)})').join(', ');

  @override
  Widget build(BuildContext context) {
    final hasSeats = booking.seatNumbers.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCollapse,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        booking.operatorName.toUpperCase(),
                        style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Text(
                        'ARRIVAL',
                        style: TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(booking.from, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                            const SizedBox(height: 4),
                            Text(_departureLabel, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(Icons.directions_bus_rounded, size: 18, color: colorScheme.primary),
                          const SizedBox(height: 2),
                          Text(_duration, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(booking.to, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                            const SizedBox(height: 4),
                            Text(_formatTime(booking.arrivalTime), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _TicketDivider(color: colorScheme.outline, notchColor: colorScheme.surfaceContainerHighest),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.qr_code_2_rounded, color: colorScheme.secondary, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasSeats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                              children: [
                                TextSpan(text: booking.seatNumbers.length > 1 ? 'Seats: ' : 'Seat: '),
                                TextSpan(
                                  text: _seatsLabel,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            children: [
                              const TextSpan(text: 'Bus Terminal: '),
                              TextSpan(
                                text: booking.fromTerminal,
                                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Price Paid: '),
                            TextSpan(
                              text: '${formatAmount(booking.totalAmount)} Rwf',
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (booking.operatorPhone.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => launchPhoneCall(context, booking.operatorPhone),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text('Call ${booking.operatorName}'),
                  )
                else
                  TextButton(onPressed: onCollapse, child: const Text('Hide Details')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 4, width: double.infinity, color: colorScheme.primary),
        ],
      ),
    );
  }
}

// dashed line with two little notch cutouts, like a real ticket stub
class _TicketDivider extends StatelessWidget {
  final Color color;
  final Color notchColor;

  const _TicketDivider({required this.color, required this.notchColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const segment = 8.0;
                final count = (constraints.maxWidth / segment).floor().clamp(1, 999);
                return Row(
                  children: List.generate(
                    count,
                    (_) => Expanded(
                      child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 1.4, color: color),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(left: -8, child: _Notch(color: notchColor)),
          Positioned(right: -8, child: _Notch(color: notchColor)),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  final Color color;
  const _Notch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

// tap to expand into the full ticket card, tap again to collapse

class _TicketTile extends StatefulWidget {
  final BookingModel trip;
  final ColorScheme colorScheme;
  final bool initiallyExpanded;

  const _TicketTile({required this.trip, required this.colorScheme, this.initiallyExpanded = false});

  @override
  State<_TicketTile> createState() => _TicketTileState();
}

class _TicketTileState extends State<_TicketTile> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: _CollapsedTicketRow(trip: widget.trip, colorScheme: widget.colorScheme, onTap: _toggle),
      secondChild: _ExpandedTicketCard(booking: widget.trip, colorScheme: widget.colorScheme, onCollapse: _toggle),
    );
  }
}

class _CollapsedTicketRow extends StatelessWidget {
  final BookingModel trip;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CollapsedTicketRow({required this.trip, required this.colorScheme, required this.onTap});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _dateLabel {
    final d = trip.departureTime;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = trip.status[0].toUpperCase() + trip.status.substring(1);
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.directions_bus_rounded, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${trip.from} → ${trip.to}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Departs $_dateLabel • $statusLabel', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trip.operatorPhone.isNotEmpty)
                IconButton(
                  onPressed: () => launchPhoneCall(context, trip.operatorPhone),
                  icon: Icon(Icons.call_rounded, color: colorScheme.primary, size: 20),
                  tooltip: 'Call ${trip.operatorName}',
                ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// previous trips = real bookings that have already arrived

class _YearGroup {
  final String year;
  final List<BookingModel> trips;
  const _YearGroup(this.year, this.trips);
}

class _PreviousTripTile extends StatelessWidget {
  final BookingModel trip;
  final ColorScheme colorScheme;

  const _PreviousTripTile({required this.trip, required this.colorScheme});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _dateLabel {
    final d = trip.arrivalTime;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text('${trip.from} → ${trip.to} will be removed from your booking history. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = trip.status[0].toUpperCase() + trip.status.substring(1);
    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        final bookingProvider = context.read<BookingProvider>();
        final messenger = ScaffoldMessenger.of(context);
        final ok = await bookingProvider.deleteBooking(trip.id);
        if (!ok) {
          messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t delete this trip, please try again')));
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: colorScheme.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.history_rounded, size: 18, color: colorScheme.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${trip.from} → ${trip.to}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$_dateLabel • $statusLabel', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
