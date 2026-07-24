// Shared seat-map layout, used by both the passenger seat picker and the
// admin walk-in toggle screen. `onTapSeat` is left up to the caller so each
// screen decides what a tap actually does.
import 'package:flutter/material.dart';
import '../models/seat_model.dart';

class SeatGrid extends StatelessWidget {
  final List<SeatModel> seats;
  final ColorScheme colorScheme;
  final void Function(SeatModel seat)? onTapSeat;

  const SeatGrid({
    super.key,
    required this.seats,
    required this.colorScheme,
    this.onTapSeat,
  });

  static final _seatNumberPattern = RegExp(r'^(\d+)([A-Za-z]+)$');

  List<List<SeatModel>> get _rows {
    final byRow = <int, List<SeatModel>>{};
    for (final seat in seats) {
      final match = _seatNumberPattern.firstMatch(seat.seatNumber);
      final row = match != null ? int.parse(match.group(1)!) : 0;
      byRow.putIfAbsent(row, () => []).add(seat);
    }
    final rowKeys = byRow.keys.toList()..sort();
    return [
      for (final key in rowKeys)
        (byRow[key]!..sort((a, b) => a.seatNumber.compareTo(b.seatNumber))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('no seat map available for this bus')),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(Icons.drive_eta_rounded, color: colorScheme.onSurfaceVariant, size: 22),
          const SizedBox(height: 14),
          for (final row in _rows) ...[
            _SeatRow(seats: row, colorScheme: colorScheme, onTapSeat: onTapSeat),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final List<SeatModel> seats;
  final ColorScheme colorScheme;
  final void Function(SeatModel seat)? onTapSeat;

  const _SeatRow({required this.seats, required this.colorScheme, required this.onTapSeat});

  @override
  Widget build(BuildContext context) {
    // 5 seats = the back row, no aisle. otherwise 2 seats, aisle gap, then the rest
    final slots = seats.length == 5
        ? seats
        : [
            ...seats.take(2),
            null,
            ...seats.skip(2),
          ];

    return Row(
      children: [
        for (final seat in slots) ...[
          Expanded(
            child: seat == null
                ? const SizedBox.shrink()
                : AspectRatio(
                    aspectRatio: 1,
                    child: _SeatTile(
                      seat: seat,
                      colorScheme: colorScheme,
                      onTap: onTapSeat == null ? null : () => onTapSeat!(seat),
                    ),
                  ),
          ),
          if (seat != slots.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SeatTile extends StatelessWidget {
  final SeatModel seat;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _SeatTile({required this.seat, required this.colorScheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color border;
    Color foreground;
    if (seat.isBooked) {
      background = colorScheme.error.withValues(alpha: 0.1);
      border = colorScheme.error.withValues(alpha: 0.6);
      foreground = colorScheme.error;
    } else if (seat.isSelected) {
      background = colorScheme.primary;
      border = colorScheme.primary;
      foreground = Colors.white;
    } else {
      background = Colors.white;
      border = colorScheme.outline;
      foreground = colorScheme.onSurface;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              seat.seatNumber,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
