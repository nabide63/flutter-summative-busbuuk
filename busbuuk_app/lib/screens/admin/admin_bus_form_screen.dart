// Add/Edit Bus - one form for both: bus == null means create mode
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/bus_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/primary_button.dart';

class AdminBusFormScreen extends StatefulWidget {
  final BusModel? bus;
  const AdminBusFormScreen({super.key, this.bus});

  @override
  State<AdminBusFormScreen> createState() => _AdminBusFormScreenState();
}

class _AdminBusFormScreenState extends State<AdminBusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _operatorNameController = TextEditingController(text: widget.bus?.operatorName);
  late final _operatorPhoneController = TextEditingController(text: widget.bus?.operatorPhone);
  late final _fromController = TextEditingController(text: widget.bus?.from);
  late final _toController = TextEditingController(text: widget.bus?.to);
  late final _fromTerminalController = TextEditingController(text: widget.bus?.fromTerminal);
  late final _toTerminalController = TextEditingController(text: widget.bus?.toTerminal);
  late final _priceController =
      TextEditingController(text: widget.bus == null ? null : formatAmount(widget.bus!.price));
  late final _originalPriceController = TextEditingController(
    text: widget.bus?.originalPrice == null ? null : formatAmount(widget.bus!.originalPrice!),
  );
  late final _totalSeatsController =
      TextEditingController(text: widget.bus?.totalSeats.toString() ?? '40');
  late final _busServicesController =
      TextEditingController(text: widget.bus?.busServices.join(', '));

  late String _busType = widget.bus?.busType ?? 'Standard';
  late DateTime _departureTime = widget.bus?.departureTime ?? DateTime.now().add(const Duration(hours: 1));
  late DateTime _arrivalTime = widget.bus?.arrivalTime ?? DateTime.now().add(const Duration(hours: 5));

  bool get _isEditing => widget.bus != null;

  @override
  void dispose() {
    _operatorNameController.dispose();
    _operatorPhoneController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fromTerminalController.dispose();
    _toTerminalController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _totalSeatsController.dispose();
    _busServicesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final initial = isDeparture ? _departureTime : _arrivalTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isDeparture) {
        _departureTime = combined;
      } else {
        _arrivalTime = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_arrivalTime.isAfter(_departureTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('arrival must be after departure - check the date for overnight trips')),
      );
      return;
    }

    final companyId = context.read<AuthProvider>().currentUser?.companyId;
    if (companyId == null) return;

    final admin = context.read<AdminProvider>();
    final busServices = _busServicesController.text
        .split(',')
        .map((service) => service.trim())
        .where((service) => service.isNotEmpty)
        .toList();
    final totalSeats = widget.bus?.totalSeats ?? int.tryParse(_totalSeatsController.text.trim()) ?? 0;

    final bus = BusModel(
      id: widget.bus?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      operatorName: _operatorNameController.text.trim(),
      operatorPhone: _operatorPhoneController.text.trim(),
      from: _fromController.text.trim(),
      to: _toController.text.trim(),
      fromTerminal: _fromTerminalController.text.trim(),
      toTerminal: _toTerminalController.text.trim().isEmpty ? null : _toTerminalController.text.trim(),
      departureTime: _departureTime,
      arrivalTime: _arrivalTime,
      price: parseAmount(_priceController.text)?.toDouble() ?? 0,
      totalSeats: totalSeats,
      availableSeats: widget.bus?.availableSeats ?? totalSeats,
      busType: _busType,
      originalPrice: parseAmount(_originalPriceController.text)?.toDouble(),
      companyId: companyId,
      busServices: busServices,
    );

    final success = _isEditing
        ? await admin.updateBus(bus)
        : await admin.createBus(bus, totalSeats: totalSeats);

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'could not save this bus, try again')),
      );
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'required';
    return null;
  }

  // parseAmount strips thousands separators so "20,000" is accepted alongside "20000"
  String? _requiredNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'required';
    if (parseAmount(value) == null) return 'enter a valid number';
    return null;
  }

  String? _optionalNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (parseAmount(value) == null) return 'enter a valid number';
    return null;
  }

  String? _requiredSeatCountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'required';
    final seats = int.tryParse(value.trim());
    if (seats == null) return 'enter a whole number';
    if (seats <= 0) return 'must be at least 1';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Bus' : 'Add Bus')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _operatorNameController,
                  decoration: const InputDecoration(labelText: 'Operator Name'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _operatorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Operator Phone',
                    helperText: 'Shown on the passenger\'s ticket so they can call for a followup',
                  ),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fromController,
                  decoration: const InputDecoration(labelText: 'From (e.g. Kigali, Rwanda)'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fromTerminalController,
                  decoration: const InputDecoration(
                    labelText: 'From Terminal',
                    helperText: 'Where passengers board - shown on their ticket',
                  ),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _toController,
                  decoration: const InputDecoration(labelText: 'To (e.g. Kampala, Uganda)'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _toTerminalController,
                  decoration: const InputDecoration(labelText: 'To Terminal (optional)'),
                ),
                const SizedBox(height: 14),
                _DateTimeField(
                  label: 'Departure',
                  value: _departureTime,
                  onTap: () => _pickDateTime(isDeparture: true),
                ),
                const SizedBox(height: 14),
                _DateTimeField(
                  label: 'Arrival',
                  value: _arrivalTime,
                  onTap: () => _pickDateTime(isDeparture: false),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price (rwf)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _requiredNumberValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _originalPriceController,
                  decoration: const InputDecoration(labelText: 'Original Price (optional, for a sale badge)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _optionalNumberValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _totalSeatsController,
                  enabled: !_isEditing,
                  decoration: InputDecoration(
                    labelText: 'Total Seats',
                    helperText: _isEditing ? "seat count can't change after creation" : null,
                  ),
                  keyboardType: TextInputType.number,
                  validator: _requiredSeatCountValidator,
                ),
                const SizedBox(height: 14),
                Text('Bus Type', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Standard', label: Text('Standard')),
                    ButtonSegment(value: 'VIP', label: Text('VIP')),
                  ],
                  selected: {_busType},
                  onSelectionChanged: (selection) => setState(() => _busType = selection.first),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _busServicesController,
                  decoration: const InputDecoration(
                    labelText: 'Services (comma-separated, e.g. WiFi, AC, Charging)',
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Create Bus',
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

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateTimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}