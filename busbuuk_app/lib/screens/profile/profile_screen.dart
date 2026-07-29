// Profile Screen
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/settings_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUpdatingPhoto = false;

  // build() re-decodes this on every AuthProvider notifyListeners() (sign-out
  // fires it multiple times in quick succession), which was janky enough to
  // stall the UI - cache the decoded bytes per base64 string like
  // _DestinationCard does on the home screen.
  static final Map<String, Uint8List> _decodedImageCache = {};

  Uint8List _decodedImage(String base64Image) =>
      _decodedImageCache.putIfAbsent(base64Image, () => base64Decode(base64Image));

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign back in to book another trip."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );

    // router redirect handles sending us back to /login once isLoggedIn flips
    if (confirmed == true && context.mounted) {
      // drop any stray buses listener left over from an earlier search -
      // otherwise it outlives sign-out and gets rejected by Firestore rules
      // once the auth token clears (harmless, but noisy)
      context.read<SearchProvider>().clearResults();
      await context.read<AuthProvider>().signOut();
    }
  }

  Future<void> _pickAndSavePhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // keep it small on purpose - this gets stored as base64 text right on the
      // Firestore user doc (no Storage bucket, that needs the paid plan), so a
      // full-res photo would blow past the 1MB document limit fast
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    setState(() => _isUpdatingPhoto = true);
    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);
    final success = await authProvider.updateProfileImage(base64Image);

    if (!mounted) return;
    setState(() => _isUpdatingPhoto = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('could not update your photo, try again')),
      );
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSavePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSavePhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  Future<void> _pickLanguage(SettingsProvider settings) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final option in const ['English', 'French', 'Swahili'])
              ListTile(
                title: Text(option),
                trailing: option == settings.language ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (choice != null) settings.setLanguage(choice);
  }

  Future<void> _pickTextSize(SettingsProvider settings) async {
    final choice = await showModalBottomSheet<TextSizeOption>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final option in TextSizeOption.values)
              ListTile(
                title: Text(option.label),
                trailing: option == settings.textSize ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (choice != null) settings.setTextSize(choice);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(context, colorScheme, user),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(40)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                      children: [
                        _SectionCard(
                          title: 'Account Settings',
                          colorScheme: colorScheme,
                          rows: [
                            _SettingsTile(
                              icon: Icons.person_outline,
                              label: 'Personal Info',
                              colorScheme: colorScheme,
                              onTap: () => context.push('/profile/personal-info'),
                            ),
                            _SettingsTile(
                              icon: Icons.people_outline,
                              label: 'Saved Passengers',
                              colorScheme: colorScheme,
                              onTap: () => _comingSoon('Saved Passengers'),
                            ),
                            _SettingsTile(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Payment Methods',
                              colorScheme: colorScheme,
                              onTap: () => context.push('/profile/payment-methods'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SectionCard(
                          title: 'Preferences',
                          colorScheme: colorScheme,
                          rows: [
                            _SettingsTile(
                              icon: Icons.notifications_none_outlined,
                              label: 'Notifications',
                              colorScheme: colorScheme,
                              trailingText: settings.notificationsEnabled ? 'On' : 'Off',
                              trailingTextColor: colorScheme.primary,
                              showChevron: false,
                              onTap: () =>
                                  settings.setNotificationsEnabled(!settings.notificationsEnabled),
                            ),
                            _SettingsTile(
                              icon: Icons.language_outlined,
                              label: 'Language',
                              colorScheme: colorScheme,
                              trailingText: settings.language,
                              onTap: () => _pickLanguage(settings),
                            ),
                            _SettingsTile(
                              icon: Icons.text_fields_outlined,
                              label: 'Text Size',
                              colorScheme: colorScheme,
                              trailingText: settings.textSize.label,
                              onTap: () => _pickTextSize(settings),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SectionCard(
                          title: 'Support & About',
                          colorScheme: colorScheme,
                          rows: [
                            _SettingsTile(
                              icon: Icons.help_outline,
                              label: 'Help Center',
                              colorScheme: colorScheme,
                              onTap: () => _comingSoon('Help Center'),
                            ),
                            _SettingsTile(
                              icon: Icons.info_outline,
                              label: 'About Us',
                              colorScheme: colorScheme,
                              onTap: () => _comingSoon('About Us'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SectionCard(
                          title: null,
                          colorScheme: colorScheme,
                          rows: [
                            _SettingsTile(
                              icon: Icons.logout,
                              label: 'Sign Out',
                              colorScheme: colorScheme,
                              iconColor: colorScheme.error,
                              labelColor: colorScheme.error,
                              showChevron: false,
                              onTap: () => _confirmSignOut(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, UserModel user) {
    final canPop = Navigator.canPop(context);

    return Container(
      width: double.infinity,
      color: colorScheme.secondary,
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                )
              else
                const SizedBox(width: 16),
              const Text(
                'Profile',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colorScheme.primary,
                      backgroundImage: user.profileImageBase64 != null
                          ? MemoryImage(_decodedImage(user.profileImageBase64!))
                          : null,
                      child: user.profileImageBase64 == null
                          ? Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _busbuukOrangeDark,
                              ),
                            )
                          : null,
                    ),
                    if (_isUpdatingPhoto && user.profileImageBase64 != null)
                      Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          child: const CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Material(
                        color: _busbuukOrangeDark,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUpdatingPhoto ? null : _showPhotoSourceSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// matches the dark-orange accent used for the avatar initials + edit badge
// in the Figma design (same tone as the theme's onPrimaryContainer)
const _busbuukOrangeDark = Color(0xFF855300);

class _SectionCard extends StatelessWidget {
  final String? title;
  final ColorScheme colorScheme;
  final List<Widget> rows;

  const _SectionCard({required this.title, required this.colorScheme, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final String? trailingText;
  final Color? trailingTextColor;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.onTap,
    this.trailingText,
    this.trailingTextColor,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? colorScheme.onSurface),
      title: Text(label, style: TextStyle(color: labelColor ?? colorScheme.onSurface, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: TextStyle(color: trailingTextColor ?? colorScheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(width: 4),
          ],
          if (showChevron)
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}