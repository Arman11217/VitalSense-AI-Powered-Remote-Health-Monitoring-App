import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import '../application/emergency_providers.dart';
import '../domain/emergency_models.dart';

/// Emergency feature (Module 9) — SOS trigger + contacts + last location.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);
    final latestEvent = ref.watch(latestEmergencyEventProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Emergency'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SosCard(),
              const SizedBox(height: 16),
              _EventBanner(latest: latestEvent),
              const SizedBox(height: 16),
              Text(
                'Emergency contacts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              contacts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Could not load contacts: $e'),
                data: (list) => list.isEmpty
                    ? _EmptyContacts()
                    : Column(
                        children: <Widget>[
                          for (final c in list) ...<Widget>[
                            _ContactTile(contact: c),
                            const SizedBox(height: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showAddContactSheet(context, ref),
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label: const Text('Add contact'),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _LastLocationCard(event: latestEvent.valueOrNull),
              const SizedBox(height: 24),
              Text(
                'VitalSense is not a substitute for professional medical care. '
                'In a life-threatening emergency call your local emergency number '
                'immediately.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddContactSheet(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Family');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Add emergency contact',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone (with country code)')),
              TextField(
                  controller: relCtrl,
                  decoration: const InputDecoration(labelText: 'Relation')),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      phoneCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final uid = ref.read(currentPatientIdProvider);
                  await ref.read(emergencyRepositoryProvider).addContact(
                        uid,
                        EmergencyContact(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relation: relCtrl.text.trim(),
                        ),
                      );
                  ref.invalidate(emergencyContactsProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SosCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SosCard> createState() => _SosCardState();
}

class _SosCardState extends ConsumerState<_SosCard> {
  EmergencySeverity _severity = EmergencySeverity.high;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFF6B6B), Color(0xFFE74C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.critical.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.emergency_rounded,
              color: Colors.white, size: 48),
          const SizedBox(height: 8),
          const Text(
            'Trigger SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hold the button for 2 seconds to alert your contacts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final s in EmergencySeverity.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _severity == s,
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: _severity == s ? AppColors.critical : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => setState(() => _severity = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onLongPress: _trigger,
            child: Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Text(
                'HOLD 2s',
                style: TextStyle(
                  color: AppColors.critical,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _trigger() async {
    final uid = ref.read(currentPatientIdProvider);
    final event =
        await ref.read(emergencyRepositoryProvider).triggerEmergency(
              uid: uid,
              severity: _severity,
              note: 'Manual SOS via VitalSense app',
            );
    ref.invalidate(latestEmergencyEventProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.critical,
        content: Text('SOS triggered · ${event.severity.label}'),
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.latest});
  final AsyncValue<EmergencyEvent> latest;

  @override
  Widget build(BuildContext context) {
    final event = latest.valueOrNull;
    if (event == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.critical.withValues(alpha: 0.10),
        border: Border.all(
          color: AppColors.critical.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.critical, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Last SOS · ${event.severity.label}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.critical,
                          fontWeight: FontWeight.w800,
                        )),
                Text(
                  'Status: ${event.status.name.toUpperCase()} · '
                  '${_formatTime(event.triggeredAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              AppColors.primary.withValues(alpha: 0.18),
          child: Text(
            contact.name.isEmpty ? '?' : contact.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(contact.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        subtitle: Text('${contact.relation} · ${contact.phone}'),
        trailing: IconButton(
          icon: const Icon(Icons.call_rounded, color: AppColors.critical),
          tooltip: 'Call',
          onPressed: () async {
            final uri = Uri(scheme: 'tel', path: contact.phone);
            await launchUrl(uri);
          },
        ),
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: <Widget>[
          const Icon(Icons.contact_emergency_outlined,
              size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No emergency contacts yet',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _LastLocationCard extends StatelessWidget {
  const _LastLocationCard({required this.event});
  final EmergencyEvent? event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLoc = event != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.location_on_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Last known location',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                Text(
                  hasLoc
                      ? '${event!.lat.toStringAsFixed(4)}, '
                          '${event!.lng.toStringAsFixed(4)}'
                      : 'No emergency recorded yet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (hasLoc)
            IconButton(
              icon: const Icon(Icons.map_rounded),
              tooltip: 'Open in maps',
              onPressed: () async {
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query='
                  '${event!.lat},${event!.lng}',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }
}