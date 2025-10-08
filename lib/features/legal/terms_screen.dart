import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple in-app Terms screen for evaluation/testing.
/// - Saves acceptance in Hive('legal')
/// - Use a GoRoute to present it at /legal, or push it manually.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agree = false;
  bool _loading = false;

  static const _tosVersion = 1; // bump when you change the terms text

  Future<void> _accept() async {
    setState(() => _loading = true);
    final box = Hive.box('legal');
    await box.put('tosAccepted', true);
    await box.put('tosAcceptedAt', DateTime.now().toIso8601String());
    await box.put('tosVersion', _tosVersion);
    setState(() => _loading = false);

    if (!mounted) return;
    // If you're using GoRouter, prefer: context.go('/');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _tosText,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I have read and agree to the Terms of Use.'),
                    subtitle: const Text(
                      'I will not copy, redistribute, reverse-engineer, or claim ownership of this app. '
                      'Access is provided only for internal evaluation and feedback.',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!_agree || _loading) ? null : _accept,
                  icon: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Agree & Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep this plain text (easy to tweak & version).
const String _tosText = '''
APP EVALUATION & FEEDBACK TERMS

1) Purpose
You are receiving a pre-release version of the “AfyaBomba” mobile application solely for internal testing and feedback.

2) Ownership
All code, designs, content, data models, and related materials are the exclusive property of the developer. No license or ownership is transferred.

3) Confidentiality
You agree not to share, distribute, post, or otherwise disclose the app, its assets, or screenshots to third parties without written permission.

4) Use Restrictions
You will not copy, modify, extract data/models, decompile, reverse-engineer, or create derivative works from the app. Use is limited to evaluation and non-commercial research within your organization.

5) Feedback
Suggestions and feedback may be used by the developer without restriction to improve the application.

6) Termination
Access may be revoked at any time. Upon request, you agree to delete all copies of the app and related materials.

By checking the box below and tapping “Agree & Continue,” you confirm that you have read and agree to these Terms.
''';

