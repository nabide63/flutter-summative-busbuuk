// Seat Selection Screen ("Pick Your Seat")
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/booking_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/booking_stepper.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/seat_grid.dart';

class SeatSelectionScreen extends StatelessWidget {
  const SeatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Pick Your Seat')),
      body: Column(
        children: [
          const BookingStepper(activeIndex: 2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: Colors.white, border: colorScheme.outline, label: 'Vacant'),
                const SizedBox(width: 20),
                _Legend(color: colorScheme.error.withValues(alpha: 0.1), border: colorScheme.error, label: 'Busy'),
                const SizedBox(width: 20),
                _Legend(color: colorScheme.primary, label: 'Choice'),
              ],
            ),
          ),
          Expanded(
            child: booking.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SeatGrid(
                      seats: booking.seats,
                      colorScheme: colorScheme,
                      onTapSeat: (seat) {
                        if (seat.isBooked) return; // can't select a seat that's already taken
                        booking.toggleSeat(seat.seatNumber);
                      },
                    ),
                  ),
          ),
          _BottomBar(
            totalAmount: booking.totalAmount,
            selectedSeats: booking.selectedSeatNumbers,
            onContinue: booking.selectedSeatNumbers.isEmpty
                ? null
                : () => context.push('/my-bookings/passenger-details'),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;

  const _Legend({required this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border != null ? Border.all(color: border!) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double totalAmount;
  final List<String> selectedSeats;
  final VoidCallback? onContinue;

  const _BottomBar({required this.totalAmount, required this.selectedSeats, required this.onContinue});

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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected Seats', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      Text(
                        selectedSeats.isEmpty ? 'No seats selected' : selectedSeats.join(', '),
                        style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Price', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    Text(
                      '${formatAmount(totalAmount)}rwf',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Passenger Details',
              icon: Icons.arrow_forward,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}