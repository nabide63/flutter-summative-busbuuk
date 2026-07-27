// Passenger Details Screen
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/passenger_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/booking_stepper.dart';
import '../../widgets/primary_button.dart';

const _nationalities = ['Rwandan', 'Burundian', 'Ugandan', 'Kenyan', 'Tanzanian', 'Congolese'];
const _countryCodes = ['+250', '+257', '+256', '+254', '+243'];

// no Storage bucket, so the ID PDF gets saved as base64 on the passenger data -
// keeping this well under Firestore's 1MB limit since base64 bloats the size
const _maxDocumentBytes = 600 * 1024;

class _PickedDocument {
  final String name;
  final String base64Data;
  const _PickedDocument({required this.name, required this.base64Data});
}

class _SavedPassenger {
  final String firstName;
  final String lastName;
  const _SavedPassenger(this.firstName, this.lastName);
}

const _savedPassengers = [
  _SavedPassenger('Kofi', 'Mensah'),
  _SavedPassenger('Abena', 'Osei'),
];

class PassengerDetailsScreen extends StatefulWidget {
  const PassengerDetailsScreen({super.key});

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _firstNameControllers = {};
  final Map<String, TextEditingController> _lastNameControllers = {};
  final Map<String, TextEditingController> _emailControllers = {};
  final Map<String, TextEditingController> _phoneControllers = {};
  final Map<String, String> _nationalitiesBySeat = {};
  final Map<String, String> _countryCodesBySeat = {};
  final Map<String, bool> _saveForFuture = {};
  final Map<String, bool> _expanded = {};
  final Map<String, _PickedDocument> _documentsBySeat = {};

  @override
  void dispose() {
    for (final controller in [
      ..._firstNameControllers.values,
      ..._lastNameControllers.values,
      ..._emailControllers.values,
      ..._phoneControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(Map<String, TextEditingController> map, String seat) =>
      map.putIfAbsent(seat, () => TextEditingController());

  void _applySavedPassenger(String seat, _SavedPassenger saved) {
    setState(() {
      _controllerFor(_firstNameControllers, seat).text = saved.firstName;
      _controllerFor(_lastNameControllers, seat).text = saved.lastName;
    });
  }

  Future<void> _pickDocument(String seat) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    if (bytes.length > _maxDocumentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That PDF is too large - please pick one under 600KB')),
      );
      return;
    }

    setState(() {
      _documentsBySeat[seat] = _PickedDocument(name: file.name, base64Data: base64Encode(bytes));
    });
  }

  void _removeDocument(String seat) {
    setState(() => _documentsBySeat.remove(seat));
  }

  void _continue(List<String> seatNumbers) {
    if (!_formKey.currentState!.validate()) return;

    final passengers = seatNumbers
        .map((seat) => PassengerModel(
              firstName: _controllerFor(_firstNameControllers, seat).text.trim(),
              lastName: _controllerFor(_lastNameControllers, seat).text.trim(),
              nationality: _nationalitiesBySeat[seat] ?? _nationalities.first,
              email: _controllerFor(_emailControllers, seat).text.trim(),
              phone: _controllerFor(_phoneControllers, seat).text.trim(),
              seatNumber: seat,
              documentFileName: _documentsBySeat[seat]?.name,
              documentBase64: _documentsBySeat[seat]?.base64Data,
            ))
        .toList();

    context.read<BookingProvider>().setPassengers(passengers);
    context.push('/my-bookings/payment');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final booking = context.watch<BookingProvider>();
    final seatNumbers = booking.selectedSeatNumbers;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('Passenger Details')),
      body: Column(
        children: [
          const BookingStepper(activeIndex: 3),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    'Saved Passengers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _AddNewChip(colorScheme: colorScheme),
                        for (final saved in _savedPassengers) ...[
                          const SizedBox(width: 10),
                          _SavedPassengerChip(
                            saved: saved,
                            colorScheme: colorScheme,
                            onTap: seatNumbers.isEmpty
                                ? null
                                : () => _applySavedPassenger(seatNumbers.first, saved),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < seatNumbers.length; i++)
                    _PassengerCard(
                      index: i,
                      seatNumber: seatNumbers[i],
                      isPrimary: i == 0,
                      expanded: i == 0 || (_expanded[seatNumbers[i]] ?? false),
                      onExpand: () => setState(() => _expanded[seatNumbers[i]] = true),
                      firstNameController: _controllerFor(_firstNameControllers, seatNumbers[i]),
                      lastNameController: _controllerFor(_lastNameControllers, seatNumbers[i]),
                      emailController: _controllerFor(_emailControllers, seatNumbers[i]),
                      phoneController: _controllerFor(_phoneControllers, seatNumbers[i]),
                      nationality: _nationalitiesBySeat[seatNumbers[i]] ?? _nationalities.first,
                      onNationalityChanged: (v) => setState(() => _nationalitiesBySeat[seatNumbers[i]] = v),
                      countryCode: _countryCodesBySeat[seatNumbers[i]] ?? _countryCodes.first,
                      onCountryCodeChanged: (v) => setState(() => _countryCodesBySeat[seatNumbers[i]] = v),
                      saveForFuture: _saveForFuture[seatNumbers[i]] ?? true,
                      onSaveChanged: (v) => setState(() => _saveForFuture[seatNumbers[i]] = v),
                      document: _documentsBySeat[seatNumbers[i]],
                      onPickDocument: () => _pickDocument(seatNumbers[i]),
                      onRemoveDocument: () => _removeDocument(seatNumbers[i]),
                    ),
                ],
              ),
            ),
          ),
          _BottomBar(
            totalAmount: booking.totalAmount,
            passengerCount: seatNumbers.length,
            onPay: seatNumbers.isEmpty ? null : () => _continue(seatNumbers),
          ),
        ],
      ),
    );
  }
}

class _AddNewChip extends StatelessWidget {
  final ColorScheme colorScheme;
  const _AddNewChip({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('saved passengers coming soon')),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.primary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text('Add New', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPassengerChip extends StatelessWidget {
  final _SavedPassenger saved;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  const _SavedPassengerChip({required this.saved, required this.colorScheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Text('${saved.firstName} ${saved.lastName}', style: TextStyle(color: colorScheme.onSurface)),
        ),
      ),
    );
  }
}

class _PassengerCard extends StatelessWidget {
  final int index;
  final String seatNumber;
  final bool isPrimary;
  final bool expanded;
  final VoidCallback onExpand;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String nationality;
  final ValueChanged<String> onNationalityChanged;
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;
  final bool saveForFuture;
  final ValueChanged<bool> onSaveChanged;
  final _PickedDocument? document;
  final VoidCallback onPickDocument;
  final VoidCallback onRemoveDocument;

  const _PassengerCard({
    required this.index,
    required this.seatNumber,
    required this.isPrimary,
    required this.expanded,
    required this.onExpand,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.nationality,
    required this.onNationalityChanged,
    required this.countryCode,
    required this.onCountryCodeChanged,
    required this.saveForFuture,
    required this.onSaveChanged,
    required this.document,
    required this.onPickDocument,
    required this.onRemoveDocument,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isPrimary ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                Text(
                  'Passenger ${index + 1} (Adult)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                ),
                const Spacer(),
                if (isPrimary)
                  Text(
                    'PRIMARY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: colorScheme.secondary,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'required' : null,
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: nationality,
                    decoration: const InputDecoration(
                      labelText: 'Nationality',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: [for (final n in _nationalities) DropdownMenuItem(value: n, child: Text(n))],
                    onChanged: (v) {
                      if (v != null) onNationalityChanged(v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Mobile Number', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          initialValue: countryCode,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: [for (final c in _countryCodes) DropdownMenuItem(value: c, child: Text(c))],
                          onChanged: (v) {
                            if (v != null) onCountryCodeChanged(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(hintText: '24 123 4567'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DocumentUpload(
                    document: document,
                    onPick: onPickDocument,
                    onRemove: onRemoveDocument,
                  ),
                  if (isPrimary) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => onSaveChanged(!saveForFuture),
                      child: Row(
                        children: [
                          Checkbox(value: saveForFuture, onChanged: (v) => onSaveChanged(v ?? false)),
                          Expanded(
                            child: Text('Save this Passenger for future trips', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onExpand,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline, style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 18, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text('Add Detailed Info', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUpload extends StatelessWidget {
  final _PickedDocument? document;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _DocumentUpload({required this.document, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDocument = document != null;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: hasDocument ? null : onPick,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Passport / National ID (PDF)',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(Icons.picture_as_pdf_outlined),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasDocument ? document!.name : 'Tap to upload PDF',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasDocument ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasDocument)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                tooltip: 'Remove document',
                visualDensity: VisualDensity.compact,
              )
            else
              Icon(Icons.upload_file, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double totalAmount;
  final int passengerCount;
  final VoidCallback? onPay;

  const _BottomBar({required this.totalAmount, required this.passengerCount, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    'Total Price ($passengerCount Passenger${passengerCount == 1 ? '' : 's'})',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatAmount(totalAmount)}Rwf',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: PrimaryButton(label: 'Payment', onPressed: onPay),
            ),
          ],
        ),
      ),
    );
  }
}