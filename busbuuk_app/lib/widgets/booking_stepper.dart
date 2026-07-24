// Shared booking-flow progress bar used on the Bus/Seat/Passenger/Payment
// screens: Timetable -> Bus -> Seat -> Passenger -> Payment. Steps before
// activeIndex show as done (checkmark), the current step is highlighted,
// steps after are muted.
import 'package:flutter/material.dart';

class BookingStepper extends StatelessWidget {
  final int activeIndex;

  const BookingStepper({super.key, required this.activeIndex});

  static const _steps = [
    (Icons.calendar_today_rounded, 'Timetable'),
    (Icons.directions_bus_rounded, 'Bus'),
    (Icons.event_seat_rounded, 'Seats'),
    (Icons.person_rounded, 'Passenger'),
    (Icons.payment_rounded, 'Pay'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            _StepNode(
              icon: _steps[i].$1,
              label: _steps[i].$2,
              state: i < activeIndex
                  ? _StepState.done
                  : i == activeIndex
                  ? _StepState.active
                  : _StepState.pending,
              colorScheme: colorScheme,
            ),
            if (i != _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: i < activeIndex
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final _StepState state;
  final ColorScheme colorScheme;

  const _StepNode({
    required this.icon,
    required this.label,
    required this.state,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final active = state == _StepState.active;

    Color circleColor;
    Widget icon0;
    Color labelColor;
    FontWeight labelWeight;

    switch (state) {
      case _StepState.done:
        circleColor = colorScheme.tertiary;
        icon0 = const Icon(Icons.check_rounded, color: Colors.white, size: 18);
        labelColor = colorScheme.onSurfaceVariant;
        labelWeight = FontWeight.normal;
      case _StepState.active:
        circleColor = colorScheme.primary;
        icon0 = Icon(icon, color: Colors.white, size: 20);
        labelColor = colorScheme.onSurface;
        labelWeight = FontWeight.bold;
      case _StepState.pending:
        circleColor = colorScheme.surfaceContainerHighest;
        icon0 = Icon(icon, color: colorScheme.onSurfaceVariant, size: 16);
        labelColor = colorScheme.onSurfaceVariant;
        labelWeight = FontWeight.normal;
    }

    return Column(
      children: [
        Container(
          width: active ? 44 : 34,
          height: active ? 44 : 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Center(child: icon0),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: labelWeight,
          ),
        ),
      ],
    );
  }
}