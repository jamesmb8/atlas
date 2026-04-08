// lib/app/screens/accountpage.dart
import 'dart:convert';

import 'package:atlas/features/themes/atlas_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit { kilometres, miles }

class AccountSettings {
  final bool notificationsEnabled;
  final bool voiceGuidanceEnabled;
  final bool avoidTolls;
  final bool avoidMotorways;
  final bool hapticsEnabled;
  final bool autoOpenRouteOptions;
  final DistanceUnit distanceUnit;

  const AccountSettings({
    this.notificationsEnabled = true,
    this.voiceGuidanceEnabled = true,
    this.avoidTolls = false,
    this.avoidMotorways = false,
    this.hapticsEnabled = true,
    this.autoOpenRouteOptions = false,
    this.distanceUnit = DistanceUnit.kilometres,
  });

  AccountSettings copyWith({
    bool? notificationsEnabled,
    bool? voiceGuidanceEnabled,
    bool? avoidTolls,
    bool? avoidMotorways,
    bool? hapticsEnabled,
    bool? autoOpenRouteOptions,
    DistanceUnit? distanceUnit,
  }) {
    return AccountSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidMotorways: avoidMotorways ?? this.avoidMotorways,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      autoOpenRouteOptions:
      autoOpenRouteOptions ?? this.autoOpenRouteOptions,
      distanceUnit: distanceUnit ?? this.distanceUnit,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notificationsEnabled': notificationsEnabled,
      'voiceGuidanceEnabled': voiceGuidanceEnabled,
      'avoidTolls': avoidTolls,
      'avoidMotorways': avoidMotorways,
      'hapticsEnabled': hapticsEnabled,
      'autoOpenRouteOptions': autoOpenRouteOptions,
      'distanceUnit':
      distanceUnit == DistanceUnit.miles ? 'miles' : 'kilometres',
    };
  }

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    return AccountSettings(
      notificationsEnabled:
      (json['notificationsEnabled'] as bool?) ?? true,
      voiceGuidanceEnabled:
      (json['voiceGuidanceEnabled'] as bool?) ?? true,
      avoidTolls: (json['avoidTolls'] as bool?) ?? false,
      avoidMotorways: (json['avoidMotorways'] as bool?) ?? false,
      hapticsEnabled: (json['hapticsEnabled'] as bool?) ?? true,
      autoOpenRouteOptions:
      (json['autoOpenRouteOptions'] as bool?) ?? false,
      distanceUnit: (json['distanceUnit'] as String?) == 'miles'
          ? DistanceUnit.miles
          : DistanceUnit.kilometres,
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const String _settingsStorageKey = 'atlas_account_settings_v1';
  static const String _favoritesStorageKey = 'atlas_saved_favorites_v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  AccountSettings _settings = const AccountSettings();
  bool _loading = true;

  int _savedPlacesCount = 0;
  bool _hasHome = false;
  bool _hasWork = false;

  int get _activePreferencesCount {
    final active = <bool>[
      _settings.notificationsEnabled,
      _settings.voiceGuidanceEnabled,
      _settings.avoidTolls,
      _settings.avoidMotorways,
      _settings.hapticsEnabled,
      _settings.autoOpenRouteOptions,
    ];

    return active.where((value) => value).length;
  }

  String get _distanceLabel {
    return _settings.distanceUnit == DistanceUnit.miles
        ? 'Miles'
        : 'Kilometres';
  }

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      final settingsRaw = await _prefs.getString(_settingsStorageKey);
      final favoritesRaw = await _prefs.getString(_favoritesStorageKey);

      AccountSettings loadedSettings = const AccountSettings();

      if (settingsRaw != null && settingsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(settingsRaw);
        if (decoded is Map) {
          loadedSettings = AccountSettings.fromJson(
            Map<String, dynamic>.from(decoded as Map),
          );
        }
      }

      bool hasHome = false;
      bool hasWork = false;
      int customCount = 0;

      if (favoritesRaw != null && favoritesRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(favoritesRaw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded as Map);
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
        _settings = loadedSettings;
        _hasHome = hasHome;
        _hasWork = hasWork;
        _savedPlacesCount =
            (_hasHome ? 1 : 0) + (_hasWork ? 1 : 0) + customCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loading = false);
    }
  }

  Future<void> _updateSettings(AccountSettings updated) async {
    setState(() => _settings = updated);
    await _prefs.setString(
      _settingsStorageKey,
      jsonEncode(updated.toJson()),
    );
  }

  Future<void> _resetSettings() async {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: atlas.background,
          title: Text(
            'Reset settings',
            style: tt.titleLarge?.copyWith(
              color: atlas.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This will restore all account and app settings to their defaults.',
            style: tt.bodyMedium?.copyWith(
              color: atlas.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: tt.labelLarge?.copyWith(
                  color: atlas.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    const defaults = AccountSettings();
    await _prefs.setString(
      _settingsStorageKey,
      jsonEncode(defaults.toJson()),
    );

    if (!mounted) {
      return;
    }

    setState(() => _settings = defaults);
    _showSnackBar('Settings reset.');
  }

  void _showComingSoon(String label) {
    _showSnackBar('$label coming soon.');
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
            : CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                        const Expanded(
                          child: _AccountHeader(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AccountSummaryCard(
                      savedPlacesCount: _savedPlacesCount,
                      hasHome: _hasHome,
                      hasWork: _hasWork,
                      activePreferencesCount: _activePreferencesCount,
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Navigation'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SwitchSettingTile(
                          title: 'Voice guidance',
                          subtitle: 'Read directions aloud while navigating.',
                          value: _settings.voiceGuidanceEnabled,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(
                                voiceGuidanceEnabled: value,
                              ),
                            );
                          },
                        ),
                        const _CardDivider(),
                        _SwitchSettingTile(
                          title: 'Open route options automatically',
                          subtitle:
                          'Jump straight to route choices after picking a destination.',
                          value: _settings.autoOpenRouteOptions,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(
                                autoOpenRouteOptions: value,
                              ),
                            );
                          },
                        ),
                        const _CardDivider(),
                        _ChoiceSettingTile(
                          title: 'Distance units',
                          subtitle: 'Choose how distances are displayed.',
                          currentValueLabel: _distanceLabel,
                          firstLabel: 'km',
                          secondLabel: 'mi',
                          isFirstSelected:
                          _settings.distanceUnit ==
                              DistanceUnit.kilometres,
                          onFirstPressed: () {
                            _updateSettings(
                              _settings.copyWith(
                                distanceUnit: DistanceUnit.kilometres,
                              ),
                            );
                          },
                          onSecondPressed: () {
                            _updateSettings(
                              _settings.copyWith(
                                distanceUnit: DistanceUnit.miles,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Route preferences'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SwitchSettingTile(
                          title: 'Avoid toll roads',
                          subtitle:
                          'Prefer routes without tolls when possible.',
                          value: _settings.avoidTolls,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(avoidTolls: value),
                            );
                          },
                        ),
                        const _CardDivider(),
                        _SwitchSettingTile(
                          title: 'Avoid motorways',
                          subtitle:
                          'Prefer local roads over faster major roads.',
                          value: _settings.avoidMotorways,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(
                                avoidMotorways: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('App'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SwitchSettingTile(
                          title: 'Notifications',
                          subtitle:
                          'Allow reminders and useful route updates.',
                          value: _settings.notificationsEnabled,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(
                                notificationsEnabled: value,
                              ),
                            );
                          },
                        ),
                        const _CardDivider(),
                        _SwitchSettingTile(
                          title: 'Haptic feedback',
                          subtitle:
                          'Use subtle vibration for key actions.',
                          value: _settings.hapticsEnabled,
                          onChanged: (value) {
                            _updateSettings(
                              _settings.copyWith(
                                hapticsEnabled: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Support & about'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _ActionSettingTile(
                          title: 'Saved places',
                          subtitle:
                          'You currently have $_savedPlacesCount saved place${_savedPlacesCount == 1 ? '' : 's'}.',
                          trailingLabel: 'View',
                          onTap: () => _showComingSoon('Saved places manager'),
                        ),
                        const _CardDivider(),
                        _ActionSettingTile(
                          title: 'Privacy',
                          subtitle:
                          'Control how Atlas handles your data.',
                          trailingLabel: 'Open',
                          onTap: () => _showComingSoon('Privacy settings'),
                        ),
                        const _CardDivider(),
                        _ActionSettingTile(
                          title: 'Help',
                          subtitle:
                          'Get support and learn how Atlas works.',
                          trailingLabel: 'Open',
                          onTap: () => _showComingSoon('Help centre'),
                        ),
                        const _CardDivider(),
                        const _StaticInfoTile(
                          title: 'App version',
                          subtitle: 'Atlas preview build',
                          trailingLabel: 'v1',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Danger zone'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _ActionSettingTile(
                          title: 'Reset settings',
                          subtitle:
                          'Restore all account preferences to defaults.',
                          trailingLabel: 'Reset',
                          isDestructive: true,
                          onTap: _resetSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your app settings and route preferences.',
          style: tt.bodySmall?.copyWith(
            color: atlas.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  final int savedPlacesCount;
  final bool hasHome;
  final bool hasWork;
  final int activePreferencesCount;

  const _AccountSummaryCard({
    required this.savedPlacesCount,
    required this.hasHome,
    required this.hasWork,
    required this.activePreferencesCount,
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
                      'Atlas account',
                      style: tt.titleLarge?.copyWith(
                        color: atlas.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalise routes, app behaviour, and saved places.',
                      style: tt.bodySmall?.copyWith(
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
              _SummaryPill(
                label: 'Active prefs',
                value: activePreferencesCount.toString(),
              ),
            ],
          ),
        ],
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

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Divider(
      height: 1,
      thickness: 1,
      color: atlas.border,
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: _TileText(
              title: title,
              subtitle: subtitle,
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: atlas.brandPrimary,
            inactiveThumbColor: atlas.surface,
            inactiveTrackColor: atlas.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ChoiceSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String currentValueLabel;
  final String firstLabel;
  final String secondLabel;
  final bool isFirstSelected;
  final VoidCallback onFirstPressed;
  final VoidCallback onSecondPressed;

  const _ChoiceSettingTile({
    required this.title,
    required this.subtitle,
    required this.currentValueLabel,
    required this.firstLabel,
    required this.secondLabel,
    required this.isFirstSelected,
    required this.onFirstPressed,
    required this.onSecondPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileText(
            title: title,
            subtitle: '$subtitle Currently: $currentValueLabel.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OptionChipButton(
                  label: firstLabel,
                  selected: isFirstSelected,
                  onPressed: onFirstPressed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OptionChipButton(
                  label: secondLabel,
                  selected: !isFirstSelected,
                  onPressed: onSecondPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionSettingTile({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    final titleColor = isDestructive ? atlas.danger : atlas.textPrimary;
    final trailingColor = isDestructive ? atlas.danger : atlas.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _TileText(
                  title: title,
                  subtitle: subtitle,
                  titleColor: titleColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                trailingLabel,
                style: tt.labelMedium?.copyWith(
                  fontSize: 13,
                  color: trailingColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticInfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailingLabel;

  const _StaticInfoTile({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Padding(
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
          Text(
            trailingLabel,
            style: tt.labelMedium?.copyWith(
              fontSize: 13,
              color: atlas.textSecondary,
            ),
          ),
        ],
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

class _OptionChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _OptionChipButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = context.atlas;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: selected
          ? atlas.brandHighlight
          : atlas.surface.withOpacity(0.8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? atlas.brandPrimary : atlas.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              fontSize: 15,
              color: atlas.textPrimary,
            ),
          ),
        ),
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