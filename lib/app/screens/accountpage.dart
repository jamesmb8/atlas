// lib/app/screens/accountpage.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountPalette {
  static const background = Color(0xFFF7F6F2);
  static const primaryText = Color(0xFF1F1F1F);
  static const secondaryText = Color(0xFF6B6E6A);
  static const accent = Color(0xFF9FC8B2);
  static const divider = Color(0xFFE3E4DE);
  static const destructive = Color(0xFFB85C5C);
}

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
      notificationsEnabled:
      notificationsEnabled ?? this.notificationsEnabled,
      voiceGuidanceEnabled:
      voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
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
    return _settings.distanceUnit == DistanceUnit.miles ? 'Miles' : 'Kilometres';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AccountPalette.background,
          title: const Text(
            'Reset settings',
            style: TextStyle(
              color: AccountPalette.primaryText,
              fontWeight: FontWeight.w400,
            ),
          ),
          content: const Text(
            'This will restore all account and app settings to their defaults.',
            style: TextStyle(
              color: AccountPalette.secondaryText,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AccountPalette.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountPalette.accent,
                foregroundColor: AccountPalette.primaryText,
                elevation: 0,
              ),
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
    return Scaffold(
      backgroundColor: AccountPalette.background,
      body: SafeArea(
        child: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: AccountPalette.primaryText,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account',
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.0,
                                  fontWeight: FontWeight.w400,
                                  color: AccountPalette.primaryText,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage your app settings and route preferences.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AccountPalette.secondaryText,
                                ),
                              ),
                            ],
                          ),
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
                                distanceUnit:
                                DistanceUnit.kilometres,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AccountPalette.divider),
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
                  color: AccountPalette.accent.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AccountPalette.primaryText,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atlas account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: AccountPalette.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Personalise routes, app behaviour, and saved places.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AccountPalette.secondaryText,
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AccountPalette.secondaryText,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AccountPalette.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AccountPalette.divider,
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
            activeColor: AccountPalette.primaryText,
            activeTrackColor: AccountPalette.accent,
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
    final titleColor = isDestructive
        ? AccountPalette.destructive
        : AccountPalette.primaryText;

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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDestructive
                      ? AccountPalette.destructive
                      : AccountPalette.secondaryText,
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AccountPalette.secondaryText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: titleColor ?? AccountPalette.primaryText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: AccountPalette.secondaryText,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AccountPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AccountPalette.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AccountPalette.secondaryText,
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
    return Material(
      color: selected
          ? AccountPalette.accent.withOpacity(0.8)
          : Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AccountPalette.divider),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AccountPalette.primaryText,
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
    return Material(
      color: Colors.white.withOpacity(0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AccountPalette.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: AccountPalette.primaryText,
            size: 20,
          ),
        ),
      ),
    );
  }
}
