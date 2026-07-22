// Walk-in seat toggle - lets an onboarder mark seats occupied/vacant for
// passengers who booked physically at the terminal instead of in the app
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bus_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/seat_grid.dart';

class AdminSeatManagementScreen extends StatefulWidget {
  final BusModel bus;
  const AdminSeatManagementScreen({super.key, required this.bus});

  @override
  State<AdminSeatManagementScreen> createState() => _AdminSeatManagementScreenState();
}

class _AdminSeatManagementScreenState extends State<AdminSeatManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().selectBusForSeatManagement(widget.bus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: Text('${widget.bus.from} → ${widget.bus.to}')),
      body: admin.isLoading && admin.selectedBusSeats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap a seat to mark it occupied or vacant for a walk-in booking at the terminal.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SeatGrid(
                    seats: admin.selectedBusSeats,
                    colorScheme: colorScheme,
                    onTapSeat: (seat) => admin.toggleSeatOccupied(seat.seatNumber, !seat.isBooked),
                  ),
                ],
              ),
            ),
    );
  }
}