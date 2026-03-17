// lib/features/settings/settings_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/telemetry/telemetry_providers.dart';
import '../../shared/telemetry/telemetry.dart';
import '../settings/reminder_providers.dart';
import '../../shared/ml/profile_repository.dart';
import '../../l10n/app_strings.dart';

import '../search/search_providers.dart'; // languageCodeProvider
import 'feature_flags.dart'; // useTfliteProvider

// ✅ Global background wrapper
import '../../widgets/app_background.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageCodeProvider); // 'en' or 'sw'
    final useTflite = ref.watch(useTfliteProvider); // bool
    final telemetryOn = ref.watch(telemetryEnabledProvider); // bool
    final t = AppStrings.of(context);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // transparent
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.settings),
      ),
      child: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            children: [
              // ------------ Language ------------
              _SectionHeader(t.language),
              const SizedBox(height: 8),
              CupertinoSegmentedControl<String>(
                groupValue: lang,
                onValueChanged: (v) =>
                    ref.read(languageCodeProvider.notifier).state = v,
                children: {
                  'en': Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(t.english),
                  ),
                  'sw': Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(t.kiswahili),
                  ),
                },
              ),

              const SizedBox(height: 24),

              // ------------ Experimental ------------
              _SectionHeader(t.experimental),
              const SizedBox(height: 8),
              _ToggleTile(
                title: t.useExperimentalMl,
                subtitle: t.useExperimentalMlSubtitle,
                value: useTflite,
                onChanged: (v) =>
                    ref.read(useTfliteProvider.notifier).state = v,
              ),
              const SizedBox(height: 8),
              Text(
                t.experimentalNote,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),

              const SizedBox(height: 24),

              // ------------ Personalization ------------
              _SectionHeader(t.personalization),
              const SizedBox(height: 8),
              CupertinoButton(
                color: CupertinoColors.systemGrey2,
                onPressed: () async {
                  final confirm = await _confirmDialog(
                    context,
                    title: t.resetPersonalizationTitle,
                    message: t.resetPersonalizationMessage,
                    okText: t.reset,
                  );
                  if (confirm != true) return;

                  final repo = ProfileRepo();
                  await repo.init();
                  await repo.clear();

                  await _showInfoDialog(
                    context,
                    title: t.done,
                    message: t.personalizationResetDone,
                  );
                },
                child: Text(t.resetPersonalization),
              ),

              const SizedBox(height: 24),

              // ------------ Privacy & Telemetry ------------
              _SectionHeader(t.privacyTelemetry),
              const SizedBox(height: 8),
              _ToggleTile(
                title: t.allowAnonymousLogs,
                subtitle: t.allowAnonymousLogsSubtitle,
                value: telemetryOn,
                onChanged: (v) =>
                    ref.read(telemetryEnabledProvider.notifier).state = v,
              ),
              const SizedBox(height: 12),

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
                            title: t.nothingToExportTitle,
                            message: t.nothingToExportMessage,
                          );
                          return;
                        }

                        await SharePlus.instance.share(
                          ShareParams(
                            text: content,
                            subject: t.telemetrySubject,
                          ),
                        );
                      },
                      child: Text(t.exportLogs),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemRed,
                      onPressed: () async {
                        final confirm = await _confirmDialog(
                          context,
                          title: t.clearLogsTitle,
                          message: t.clearLogsMessage,
                          okText: t.clearLogs,
                        );
                        if (confirm != true) return;

                        final repo = ref.read(telemetryRepoProvider);
                        await repo.clear();

                        await _showInfoDialog(
                          context,
                          title: t.done,
                          message: t.logsCleared,
                        );
                      },
                      child: Text(t.clearLogs),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                t.privacyNote,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
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
      label: '$title. ${AppStrings.of(context).onOff(value)}',
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
          child: Text(AppStrings.of(context).ok),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? okText,
}) async {
  final t = AppStrings.of(context);

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
          child: Text(t.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(okText ?? t.ok),
        ),
      ],
    ),
  );
}