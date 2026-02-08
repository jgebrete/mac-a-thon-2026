import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/user_settings.dart';
import '../providers/user_settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(userSettingsProvider);
    final uid = ref.watch(currentUserProvider)?.uid;

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (settings) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AppThemeMode>(
              segments: const <ButtonSegment<AppThemeMode>>[
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment<AppThemeMode>(
                  value: AppThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: <AppThemeMode>{settings.themeMode},
              onSelectionChanged: (selection) async {
                if (uid == null || selection.isEmpty) {
                  return;
                }
                await ref
                    .read(userSettingsRepositoryProvider)
                    .updateThemeMode(uid, selection.first);
              },
            ),
            const SizedBox(height: 24),
            Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Notify me this many days before expiry:'),
            Slider(
              min: 1,
              max: 14,
              divisions: 13,
              value: settings.notificationThresholdDays.toDouble(),
              label: '${settings.notificationThresholdDays} days',
              onChanged: uid == null
                  ? null
                  : (value) async {
                      await ref
                          .read(userSettingsRepositoryProvider)
                          .updateThreshold(uid, value.round());
                    },
            ),
            Text('${settings.notificationThresholdDays} day(s)'),
            const SizedBox(height: 16),
            const Text('Remind me to check perishable items after:'),
            Slider(
              min: 1,
              max: 21,
              divisions: 20,
              value: settings.perishableReminderDays.toDouble(),
              label: '${settings.perishableReminderDays} days',
              onChanged: uid == null
                  ? null
                  : (value) async {
                      await ref
                          .read(userSettingsRepositoryProvider)
                          .updatePerishableReminderDays(uid, value.round());
                    },
            ),
            Text('${settings.perishableReminderDays} day(s)'),
            const SizedBox(height: 24),
            Text('Safety Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _SafetyNoteRow(
                      icon: Icons.warning_amber_rounded,
                      text:
                          'AI-extracted dates are drafts. Always verify before saving.',
                    ),
                    SizedBox(height: 8),
                    _SafetyNoteRow(
                      icon: Icons.schedule,
                      text:
                          'Perishable items with no fixed date are prioritized as "use soon".',
                    ),
                    SizedBox(height: 8),
                    _SafetyNoteRow(
                      icon: Icons.health_and_safety_outlined,
                      text:
                          'If smell, texture, or appearance seems off, discard the food.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Demo Tools', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: uid == null
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final callable = FirebaseFunctions.instance
                            .httpsCallable('debugSendExpiryRemindersNow');
                        final result = await callable.call(<String, dynamic>{});
                        final data = Map<String, dynamic>.from(
                          result.data as Map<dynamic, dynamic>,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Demo reminders run. Attempts: ${data['notificationsAttempted'] ?? 0}, Success: ${data['successCount'] ?? 0}',
                            ),
                          ),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Demo trigger failed: $error')),
                        );
                      }
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Send Reminder Now (Demo)'),
            ),
            const SizedBox(height: 6),
            Text(
              'Works only for allowlisted demo users in functions env.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _SafetyNoteRow extends StatelessWidget {
  const _SafetyNoteRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
