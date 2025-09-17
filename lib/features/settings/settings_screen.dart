// lib/features/settings/settings_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/search_providers.dart';   // languageCodeProvider
import 'feature_flags.dart';               // useTfliteProvider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageCodeProvider);     // 'en' or 'sw'
    final useTflite = ref.watch(useTfliteProvider);  // bool

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            const _SectionHeader('Language'),
            const SizedBox(height: 8),

            // Language segmented control
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
            const _SectionHeader('Experimental'),
            const SizedBox(height: 8),

            // TFLite engine toggle
            _ToggleTile(
              title: 'Use experimental ML engine (TFLite)',
              subtitle:
                  'For on-device QA. On web, it automatically falls back to the stub.',
              value: useTflite,
              onChanged: (v) =>
                  ref.read(useTfliteProvider.notifier).state = v,
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
