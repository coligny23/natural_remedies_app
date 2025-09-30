// lib/features/settings/settings_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/telemetry/telemetry_providers.dart';
import '../../shared/telemetry/telemetry.dart';
import '../settings/reminder_providers.dart';

import '../search/search_providers.dart'; // languageCodeProvider
import 'feature_flags.dart'; // useTfliteProvider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageCodeProvider); // 'en' or 'sw'
    final useTflite = ref.watch(useTfliteProvider); // bool
    final telemetryOn = ref.watch(telemetryEnabledProvider); // bool

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            // ------------ Language ------------
            const _SectionHeader('Language'),
            const SizedBox(height: 8),
            CupertinoSegmentedControl<String>(
              groupValue: lang,
              onValueChanged: (v) =>
                  ref.read(languageCodeProvider.notifier).state = v,
              children: const {
                'en': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('English'),
                ),
                'sw': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Kiswahili'),
                ),
              },
            ),

            const SizedBox(height: 24),

            // ------------ Experimental ------------
            const _SectionHeader('Experimental'),
            const SizedBox(height: 8),
            _ToggleTile(
              title: 'Use experimental ML engine (TFLite)',
              subtitle:
                  'For on-device QA. On web, it automatically falls back to the stub.',
              value: useTflite,
              onChanged: (v) => ref.read(useTfliteProvider.notifier).state = v,
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This switch prepares the app to use a local TFLite model. '
              'It currently delegates to the stub until you add the real model.',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),

            const SizedBox(height: 24),

            // ------------ Privacy & Telemetry ------------
            const _SectionHeader('Privacy & Telemetry'),
            const SizedBox(height: 8),
            _ToggleTile(
              title: 'Allow anonymous usage logs',
              subtitle:
                  'Events are stored locally (offline). You can export or clear them anytime.',
              value: telemetryOn,
              onChanged: (v) =>
                  ref.read(telemetryEnabledProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),

            // Export / Clear buttons
            Row(
              children: [
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: () async {
                      final repo = ref.read(telemetryRepoProvider);
                      final lines = await repo.dumpLines();
                      final content = lines.join('\n');
                      if (content.isEmpty) {
                        await _showInfoDialog(
                          context,
                          title: 'Nothing to export',
                          message: 'No logs available yet.',
                        );
                        return;
                      }
                      await SharePlus.instance.share(
                        ShareParams(
                          text: content,
                          subject: 'telemetry.jsonl',
                        ),
                      );
                    },
                    child: const Text('Export logs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    color: CupertinoColors.systemRed,
                    onPressed: () async {
                      final confirm = await _confirmDialog(
                        context,
                        title: 'Clear logs?',
                        message:
                            'This will delete all locally stored usage logs. This cannot be undone.',
                        okText: 'Clear',
                      );
                      if (confirm != true) return;
                      final repo = ref.read(telemetryRepoProvider);
                      await repo.clear();
                      await _showInfoDialog(
                        context,
                        title: 'Done',
                        message: 'Logs cleared.',
                      );
                    },
                    child: const Text('Clear logs'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text(
              'No personal data is collected. Logs contain only anonymous events '
              '(e.g., “opened article”, “saved”, “search query length”).',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.label,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. ${value ? "On" : "Off"}',
      toggled: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            CupertinoSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ---------- Helpers: simple Cupertino dialogs ----------

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showCupertinoDialog<void>(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          isDefaultAction: true,
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okText = 'OK',
}) async {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(okText),
        ),
      ],
    ),
  );
}

