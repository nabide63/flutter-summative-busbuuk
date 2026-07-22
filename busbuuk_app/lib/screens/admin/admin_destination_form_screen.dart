// Add/Edit Destination - one form for both: destination == null means create mode
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/destination_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/primary_button.dart';

class AdminDestinationFormScreen extends StatefulWidget {
  final DestinationModel? destination;
  const AdminDestinationFormScreen({super.key, this.destination});

  @override
  State<AdminDestinationFormScreen> createState() => _AdminDestinationFormScreenState();
}

class _AdminDestinationFormScreenState extends State<AdminDestinationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _cityController = TextEditingController(text: widget.destination?.city);
  late final _countryController = TextEditingController(text: widget.destination?.country);
  late final _orderController =
      TextEditingController(text: (widget.destination?.order ?? 0).toString());

  String? _imageBase64;

  bool get _isEditing => widget.destination != null;

  @override
  void initState() {
    super.initState();
    _imageBase64 = widget.destination?.imageBase64;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // compress it since it ends up as base64 on the doc (no Storage bucket)
      maxWidth: 800,
      maxHeight: 1000,
      imageQuality: 70,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _imageBase64 = base64Encode(bytes));
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('pick a background photo first')),
      );
      return;
    }

    final admin = context.read<AdminProvider>();
    final destination = DestinationModel(
      id: widget.destination?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      imageBase64: _imageBase64!,
      order: int.tryParse(_orderController.text.trim()) ?? 0,
      createdAt: widget.destination?.createdAt ?? DateTime.now(),
    );

    final success = _isEditing
        ? await admin.updateDestination(destination)
        : await admin.createDestination(destination);

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(admin.errorMessage ?? 'could not save this destination, try again')),
      );
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Destination' : 'Add Destination')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: colorScheme.surfaceContainerHighest,
                      child: _imageBase64 == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: colorScheme.onSurfaceVariant, size: 32),
                                const SizedBox(height: 8),
                                Text('Tap to add a background photo', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              ],
                            )
                          : Image.memory(base64Decode(_imageBase64!), fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City (e.g. Kigali)'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country (e.g. Rwanda)'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _orderController,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    helperText: 'Lower numbers show first in the carousel',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Create Destination',
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