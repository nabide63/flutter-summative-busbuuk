// Bus Details Screen ("Your Bus") - operator, route, map preview, amenities
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/bus_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/search_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/booking_stepper.dart';
import '../../widgets/primary_button.dart';

class BusDetailsScreen extends StatelessWidget {
  final BusModel bus;

  const BusDetailsScreen({super.key, required this.bus});

  Future<void> _selectSeats(BuildContext context) async {
    final booking = context.read<BookingProvider>();
    await booking.selectBus(bus);
    if (context.mounted) context.push('/my-bookings/seat-selection');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final search = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Your Bus')),
      body: Column(
        children: [
          const BookingStepper(activeIndex: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TripSummaryCard(
                    date: bus.departureTime,
                    passengers: search.passengers,
                    isRoundTrip: search.isRoundTrip,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _RouteCard(bus: bus, colorScheme: colorScheme),
                  const SizedBox(height: 20),
                  _MapPreview(colorScheme: colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    'Bus Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ServicesGrid(services: bus.busServices, colorScheme: colorScheme),
                ],
              ),
            ),
          ),
          _BottomBar(
            price: bus.price,
            onPressed: () => _selectSeats(context),
          ),
        ],
      ),
    );
  }
}

// ---- Trip summary: date, passenger count, one-way/round-trip chip ----

class _TripSummaryCard extends StatelessWidget {
  final DateTime date;
  final int passengers;
  final bool isRoundTrip;
  final ColorScheme colorScheme;

  const _TripSummaryCard({
    required this.date,
    required this.passengers,
    required this.isRoundTrip,
    required this.colorScheme,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _formattedDate => '${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            _formattedDate,
            style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(width: 18),
          Icon(Icons.people_alt_rounded, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            '$passengers Person${passengers == 1 ? '' : 's'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isRoundTrip ? 'Round-trip' : 'One-way',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Route card: operator + departure/arrival with terminal names ----

class _RouteCard extends StatelessWidget {
  final BusModel bus;
  final ColorScheme colorScheme;

  const _RouteCard({required this.bus, required this.colorScheme});

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatDuration() {
    final duration = bus.arrivalTime.difference(bus.departureTime);
    return '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                bus.operatorName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(bus.busType),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RoutePoint(
            time: _formatTime(bus.departureTime),
            place: bus.from,
            terminal: bus.fromTerminal,
            tag: 'DEPARTURE',
            dotFilled: false,
            colorScheme: colorScheme,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Row(
              children: [
                Container(width: 2, height: 36, color: colorScheme.outline),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDuration(),
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _RoutePoint(
            time: _formatTime(bus.arrivalTime),
            place: bus.to,
            terminal: bus.toTerminal,
            tag: 'ARRIVAL',
            dotFilled: true,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String time;
  final String place;
  final String? terminal;
  final String tag;
  final bool dotFilled;
  final ColorScheme colorScheme;

  const _RoutePoint({
    required this.time,
    required this.place,
    required this.terminal,
    required this.tag,
    required this.dotFilled,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotFilled ? colorScheme.secondary : Colors.white,
            border: Border.all(color: colorScheme.secondary, width: 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                place,
                style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              if (terminal != null)
                Text(
                  terminal!,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        Text(
          tag,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

// ---- Map preview placeholder ----

class _MapPreview extends StatelessWidget {
  final ColorScheme colorScheme;

  const _MapPreview({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF001856), Color(0xFF3B4B7A)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(left: 60, top: 30, child: _MapPin(size: 14)),
            const Positioned(left: 90, top: 100, child: _MapPin(size: 20)),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 15, color: Color(0xFF001856)),
                        SizedBox(width: 6),
                        Text(
                          'View Full Map',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF001856),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final double size;
  const _MapPin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, color: const Color(0xFFFEA619), size: size);
  }
}

// ---- Bus services grid: whatever the onboarder configured for this bus ----

class _ServicesGrid extends StatelessWidget {
  final List<String> services;
  final ColorScheme colorScheme;
  const _ServicesGrid({required this.services, required this.colorScheme});

  static IconData _iconFor(String service) {
    final normalized = service.trim().toLowerCase();
    if (normalized.contains('wifi')) return Icons.wifi_rounded;
    if (normalized.contains('ac') || normalized.contains('air')) return Icons.ac_unit_rounded;
    if (normalized.contains('toilet') || normalized.contains('wc') || normalized.contains('restroom')) {
      return Icons.wc_rounded;
    }
    if (normalized.contains('usb')) return Icons.usb_rounded;
    if (normalized.contains('charg') ||
        normalized.contains('power') ||
        normalized.contains('220') ||
        normalized.contains('socket') ||
        normalized.contains('plug')) {
      return Icons.power_rounded;
    }
    if (normalized.contains('drink') || normalized.contains('snack') || normalized.contains('refresh')) {
      return Icons.local_cafe_rounded;
    }
    if (normalized.contains('tv') || normalized.contains('screen') || normalized.contains('entertain')) {
      return Icons.tv_rounded;
    }
    if (normalized.contains('blanket') || normalized.contains('pillow')) return Icons.bed_rounded;
    if (normalized.contains('luggage') || normalized.contains('bag')) return Icons.luggage_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Text(
        'No services listed for this bus',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final service = services[index];
        return _ServiceTile(icon: _iconFor(service), label: service, colorScheme: colorScheme);
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _ServiceTile({required this.icon, required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colorScheme.secondary),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---- Bottom price bar ----

class _BottomBar extends StatelessWidget {
  final double price;
  final VoidCallback onPressed;

  const _BottomBar({required this.price, required this.onPressed});

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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Price',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatAmount(price),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'rwf',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                label: 'Pick Your Seat',
                icon: Icons.arrow_forward,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
