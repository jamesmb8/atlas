// lib/app/screens/accountpage.dart
import 'dart:convert';

import 'package:atlas/features/themes/atlas_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ChangePasswordHandler = Future<void> Function({
required String currentPassword,
required String newPassword,
});

class AccountPage extends StatefulWidget {
  final String? userEmail;
  final ChangePasswordHandler? onChangePassword;

  const AccountPage({
    super.key,
    this.userEmail,
    this.onChangePassword,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with WidgetsBindingObserver {
  static const String _favoritesStorageKey = 'atlas_saved_favorites_v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  final TextEditingController _currentPasswordController =
  TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _loading = true;
  bool _passwordBusy = false;
  bool _locationBusy = false;

  int _savedPlacesCount = 0;
  bool _hasHome = false;
  bool _hasWork = false;

  bool _locationServicesEnabled = false;
  LocationPermission _locationPermission = LocationPermission.denied;

  bool get _canChangePassword => widget.onChangePassword != null;

  bool get _locationAllowed {
    return _locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse;
  }

  String get _locationStatusLabel {
    if (!_locationServicesEnabled) {
      return 'Off';
    }

    if (_locationAllowed) {
      return 'Yes';
    }

    return 'No';
  }

  String get _locationSubtitle {
    if (!_locationServicesEnabled) {
      return 'Location services are off on this device. Open settings to turn them on.';
    }

    switch (_locationPermission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return 'Atlas can use your current location.';
      case LocationPermission.deniedForever:
        return 'Location access is blocked. Open settings to change it.';
      case LocationPermission.denied:
        return 'Atlas cannot use your current location. Open settings to allow it.';
      case LocationPermission.unableToDetermine:
        return 'Location access could not be determined.';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocationStatus();
    }
  }

  Future<void> _loadPage() async {
    try {
      await Future.wait([
        _loadSavedPlacesSummary(),
        _loadLocationStatus(),
      ]);
    } finally {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedPlacesSummary() async {
    try {
      final favoritesRaw = await _prefs.getString(_favoritesStorageKey);

      bool hasHome = false;
      bool hasWork = false;
      int customCount = 0;

      if (favoritesRaw != null && favoritesRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(favoritesRaw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          hasHome = data['home'] is Map;
          hasWork = data['work'] is Map;

          final custom = data['custom'];
          if (custom is List) {
            customCount = custom.whereType<Map>().length;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasHome = hasHome;
        _hasWork = hasWork;
        _savedPlacesCount =
            (_hasHome ? 1 : 0) + (_hasWork ? 1 : 0) + customCount;
      });
    } catch (_) {
      // Keep defaults.
    }
  }

  Future<void> _loadLocationStatus() async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      if (!mounted) {
        return;
      }

      setState(() {
        _locationServicesEnabled = servicesEnabled;
        _locationPermission = permission;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationServicesEnabled = false;
        _locationPermission = LocationPermission.denied;
      });
    }
  }

  Future<void> _openRelevantLocationSettings() async {
    if (_locationBusy) {
      return;
    }

    setState(() => _locationBusy = true);

    try {
      final opened = !_locationServicesEnabled
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();

      if (!opened) {
        _showSnackBar('Could not open settings.');
      }
    } catch (_) {
      _showSnackBar('Could not open settings.');
    } finally {
      if (mounted) {
        setState(() => _locationBusy = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final handler = widget.onChangePassword;
    if (handler == null || _passwordBusy) {
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      _showSnackBar('Enter your current password.');
      return;
    }

    if (newPassword.isEmpty) {
      _showSnackBar('Enter a new password.');
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('New password must be at least 6 characters.');
      return;
    }

    if (newPassword == currentPassword) {
      _showSnackBar('New password must be different.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('New passwords do not match.');
      return;
    }

    setState(() => _passwordBusy = true);

    try {
      await handler(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnackBar('Password updated.');
    } catch (error) {
      _showSnackBar(_formatErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _passwordBusy = false);
      }
    }
  }

  String _formatErrorMessage(Object error) {
    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();

    return cleaned.isEmpty ? 'Could not update password.' : cleaned;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Scaffold(
      backgroundColor: atlas.background,
      body: SafeArea(
        child: _loading
            ? Center(
          child: CircularProgressIndicator(
            color: atlas.brandPrimary,
            strokeWidth: 2,
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconSurfaceButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: _AccountHeader()),
                ],
              ),
              const SizedBox(height: 18),
              _AccountOverviewCard(
                email: widget.userEmail,
                savedPlacesCount: _savedPlacesCount,
                hasHome: _hasHome,
                hasWork: _hasWork,
              ),
              if (_canChangePassword) ...[
                const SizedBox(height: 18),
                const _SectionLabel('Security'),
                const SizedBox(height: 8),
                _PasswordFormCard(
                  currentPasswordController:
                  _currentPasswordController,
                  newPasswordController: _newPasswordController,
                  confirmPasswordController:
                  _confirmPasswordController,
                  busy: _passwordBusy,
                  onSubmit: _changePassword,
                ),
              ],
              const SizedBox(height: 18),
              const _SectionLabel('Device access'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _LocationAccessTile(
                    title: 'Current location',
                    subtitle: _locationSubtitle,
                    status: _locationStatusLabel,
                    busy: _locationBusy,
                    onTap: _openRelevantLocationSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: tt.headlineSmall?.copyWith(
            color: atlas.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage the parts of your account that are actually wired up.',
          style: tt.bodySmall?.copyWith(
            color: atlas.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AccountOverviewCard extends StatelessWidget {
  final String? email;
  final int savedPlacesCount;
  final bool hasHome;
  final bool hasWork;

  const _AccountOverviewCard({
    required this.email,
    required this.savedPlacesCount,
    required this.hasHome,
    required this.hasWork,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: atlas.surfaceFeatured,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: atlas.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: atlas.brandTertiary.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: atlas.textPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signed in account',
                      style: tt.titleLarge?.copyWith(
                        color: atlas.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ?? 'No email available',
                      style: tt.bodyMedium?.copyWith(
                        color: atlas.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(
                label: 'Saved places',
                value: savedPlacesCount.toString(),
              ),
              _SummaryPill(
                label: 'Home',
                value: hasHome ? 'Set' : 'Empty',
              ),
              _SummaryPill(
                label: 'Work',
                value: hasWork ? 'Set' : 'Empty',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordFormCard extends StatelessWidget {
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool busy;
  final VoidCallback onSubmit;

  const _PasswordFormCard({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.busy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: atlas.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileText(
            title: 'Change password',
            subtitle:
            'Enter your current password and choose a new one.',
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: currentPasswordController,
            label: 'Current password',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: newPasswordController,
            label: 'New password',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: confirmPasswordController,
            label: 'Confirm new password',
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: busy ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: atlas.brandPrimary,
                disabledBackgroundColor: atlas.border,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: busy
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Update password',
                style: tt.labelLarge?.copyWith(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      style: tt.bodyLarge?.copyWith(
        color: atlas.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: tt.bodyMedium?.copyWith(
          color: atlas.textSecondary,
        ),
        filled: true,
        fillColor: atlas.surface.withOpacity(0.9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: atlas.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: atlas.brandPrimary),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Text(
      text,
      style: tt.labelMedium?.copyWith(
        fontSize: 13,
        color: atlas.textSecondary,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Container(
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: atlas.border),
      ),
      child: Column(children: children),
    );
  }
}

class _LocationAccessTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final bool busy;
  final VoidCallback onTap;

  const _LocationAccessTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _TileText(
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: atlas.brandPrimary,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: atlas.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: atlas.border),
                      ),
                      child: Text(
                        status,
                        style: tt.labelMedium?.copyWith(
                          color: atlas.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manage',
                      style: tt.labelMedium?.copyWith(
                        fontSize: 13,
                        color: atlas.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileText extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? titleColor;

  const _TileText({
    required this.title,
    required this.subtitle,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleMedium?.copyWith(
            fontSize: 15,
            color: titleColor ?? atlas.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: tt.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.25,
            color: atlas.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: atlas.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: atlas.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontSize: 15,
              color: atlas.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontSize: 12,
              color: atlas.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconSurfaceButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconSurfaceButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Material(
      color: atlas.surface.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: atlas.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: atlas.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}