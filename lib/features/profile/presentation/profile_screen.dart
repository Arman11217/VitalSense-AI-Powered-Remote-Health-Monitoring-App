import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/animated_gradient_bg.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/models/app_user.dart';
import '../application/profile_providers.dart';
import '../domain/profile_details.dart';

/// Placeholder for the Profile feature (Module 10).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Profile'),
        ),
        body: user == null
            ? const Center(child: Text('Not signed in'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _ProfileHeader(user: user),
                  const SizedBox(height: 24),
                  _SettingsGroup(
                    title: 'Health data',
                    tiles: <_SettingsTile>[
                      _SettingsTile(
                        icon: Icons.assignment_rounded,
                        title: 'Reports',
                        subtitle: 'Export your readings as CSV or PDF',
                        onTap: () => context.go('/home/profile/reports'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Safety',
                    tiles: <_SettingsTile>[
                      _SettingsTile(
                        icon: Icons.emergency_rounded,
                        title: 'Emergency',
                        subtitle: 'SOS, contacts & last known location',
                        onTap: () => context.go('/home/profile/emergency'),
                      ),
                      _SettingsTile(
                        icon: Icons.bluetooth_audio_rounded,
                        title: 'Device',
                        subtitle:
                            'ESP32 pairing, signal & firmware updates',
                        onTap: () => context.go('/home/profile/device'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Account',
                    tiles: <_SettingsTile>[
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        subtitle: 'End the current session',
                        destructive: true,
                        onTap: () =>
                            ref.read(authRepositoryProvider).signOut(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EditProfileSection(),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    title: 'Danger zone',
                    tiles: <_SettingsTile>[
                      _SettingsTile(
                        icon: Icons.delete_forever_rounded,
                        title: 'Delete account',
                        subtitle:
                            'Permanently delete your data and sign out',
                        destructive: true,
                        onTap: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primary,
            child: Text(
              ((user.displayName ?? '').isNotEmpty
                      ? (user.displayName ?? '')[0]
                      : user.email[0])
                  .toUpperCase(),
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (user.displayName ?? '').isEmpty
                      ? 'VitalSense User'
                      : user.displayName!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.tiles});
  final String title;
  final List<_SettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < tiles.length; i++) ...<Widget>[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      indent: 56,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.primary;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: destructive ? scheme.error : null,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}

// ───────────────────── Editable Profile Section ─────────────────────

class _EditProfileSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EditProfileSection> createState() => _EditProfileSectionState();
}

class _EditProfileSectionState extends ConsumerState<_EditProfileSection> {
  late TextEditingController _name;
  late TextEditingController _age;
  late TextEditingController _height;
  late TextEditingController _weight;
  late TextEditingController _notes;
  late String _bloodGroup;

  static const List<String> _bloodGroups = <String>[
    'Unknown', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
  ];

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileDetailsProvider);
    _name = TextEditingController(text: p.fullName);
    _age = TextEditingController(text: p.age);
    _height = TextEditingController(text: p.heightCm);
    _weight = TextEditingController(text: p.weightKg);
    _notes = TextEditingController(text: p.emergencyNotes);
    _bloodGroup =
        _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : 'Unknown';
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = ProfileDetails(
      fullName: _name.text.trim(),
      age: _age.text.trim(),
      bloodGroup: _bloodGroup,
      heightCm: _height.text.trim(),
      weightKg: _weight.text.trim(),
      emergencyNotes: _notes.text.trim(),
      photoPath:
          ref.read(profileDetailsProvider).photoPath,
    );
    await ref.read(profileDetailsProvider.notifier).update(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Personal details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _bloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Blood group',
                    prefixIcon: Icon(Icons.bloodtype_rounded),
                  ),
                  items: _bloodGroups
                      .map((b) => DropdownMenuItem<String>(
                            value: b,
                            child: Text(b),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _bloodGroup = v ?? 'Unknown'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(Icons.height_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.scale_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Medical notes (allergies, conditions…)',
              prefixIcon: Icon(Icons.medical_information_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'This will sign you out and forget your local profile data. '
        'Your cloud data is governed by Firebase Auth deletion.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(profileDetailsProvider.notifier).reset();
    await ref.read(authRepositoryProvider).signOut();
  }
}
