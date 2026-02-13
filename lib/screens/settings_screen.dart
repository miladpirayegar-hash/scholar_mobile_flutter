import 'package:flutter/material.dart';
import 'dart:async';

import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/academic_profile_provider.dart';
import '../providers/user_prefs_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _privacyPolicyContent =
      'We collect data you provide (profile details, course info) and '
      'content you upload (audio recordings and course outlines) to deliver '
      'transcripts, summaries, flashcards, and reminders. We store only what '
      'is needed to operate the app and improve reliability. We do not sell '
      'your personal data. You can revoke AI processing consent at any time '
      'in Settings. If you delete your account, we remove your profile data '
      'from our systems, subject to legal retention requirements.';

  static const String _termsContent =
      'By using Scholar, you agree to use the app for lawful, personal study '
      'purposes. You are responsible for the content you record or upload and '
      'must have permission to record any audio. Do not upload confidential or '
      'restricted materials without authorization. We provide AI-generated '
      'insights as study aids and they may contain errors; you should verify '
      'critical information. We may update features and policies over time. '
      'If you do not agree with these terms, please stop using the app.';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final prefs = ref.watch(userPrefsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const _SectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
            _SettingTile(
              title: 'Edit Profile',
              subtitle: auth.userName?.isNotEmpty == true
                  ? auth.userName!
                  : 'Update your name and email',
              leading: Icons.badge_outlined,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEditProfile(context, auth),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('HARDWARE CONTROLS'),
          const SizedBox(height: 10),
          _SettingTile(
            title: 'Preferred Mic',
            subtitle: prefs.preferredMic,
            trailing: const Icon(Icons.expand_more),
            onTap: () => _showPreferredMic(context),
          ),
          _SettingTile(
            title: 'Audio Test',
            subtitle: 'Run 4s hardware diagnostic',
            leading: Icons.mic_none,
            onTap: () => _showAudioTest(context),
          ),
          _SettingTile(
            title: 'Recording Quality',
            subtitle: 'High fidelity is recommended',
            leading: Icons.high_quality,
            trailing: Text(
              prefs.recordingQuality,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            onTap: () => _showRecordingQuality(context),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('APP PREFERENCES'),
          const SizedBox(height: 10),
          _SettingTile(
            title: 'Push Notifications',
            subtitle: 'Session & insight alerts',
            leading: Icons.notifications_none,
            trailing: Switch(
              value: prefs.notificationsEnabled,
              onChanged: (v) => _setNotificationsEnabled(v),
            ),
            onTap: () =>
                _setNotificationsEnabled(!prefs.notificationsEnabled),
          ),
          const SizedBox(height: 14),
            _SettingTile(
              title: 'AI Processing Consent',
              subtitle:
                  'Required to upload outlines for AI extraction',
              leading: Icons.shield_outlined,
              trailing: Switch(
                value: prefs.aiProcessingConsent,
                onChanged: (v) => _setAiConsent(v),
              ),
              onTap: () => _setAiConsent(!prefs.aiProcessingConsent),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 22),
            const _SectionLabel('LEGAL & TRUST'),
          const SizedBox(height: 10),
          _SettingTile(
            title: 'Recording & AI Processing',
            subtitle: 'How we use audio and outline data',
            leading: Icons.info_outline,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDataUsage(context),
          ),
          _SettingTile(
            title: 'Privacy Policy',
            subtitle: 'How we collect and use data',
            leading: Icons.privacy_tip_outlined,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLegalDoc(
              context,
              title: 'Privacy Policy',
              content: _privacyPolicyContent,
            ),
          ),
            _SettingTile(
              title: 'Terms of Service',
              subtitle: 'Rules for using the app',
              leading: Icons.description_outlined,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLegalDoc(
                context,
                title: 'Terms of Service',
                content: _termsContent,
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('ACCOUNT ACTIONS'),
            const SizedBox(height: 10),
            _SettingTile(
              title: 'Delete Account',
              subtitle: 'Remove account data from this device',
              leading: Icons.delete_forever_outlined,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmDelete(context),
            ),
            const SizedBox(height: 8),
            _SettingTile(
              title: 'Deactivate Account',
              subtitle: 'Sign out and keep data on this device',
              leading: Icons.remove_circle_outline,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmDeactivate(context),
            ),
          ],
        ),
      );
    }

  void _showEditProfile(BuildContext context, AuthState auth) {
    final name = TextEditingController(text: auth.userName ?? '');
    final email = TextEditingController(text: auth.email ?? '');

    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (name.text.trim().isEmpty ||
                      email.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name and email are required.'),
                      ),
                    );
                    return;
                  }
                  ref.read(authProvider.notifier).updateProfile(
                        name: name.text.trim(),
                        email: email.text.trim(),
                      );
                  Navigator.of(context).pop();
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeactivate(BuildContext context) {
    AppModal.show(
      context: context,
      builder: (_) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Deactivate Account?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This will sign you out. Your local data stays on this device.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setModalState(() => busy = true);
                            await ref
                                .read(authProvider.notifier)
                                .deactivateAccount();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account deactivated.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    child: Text(busy ? 'Deactivating...' : 'Deactivate'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    AppModal.show(
      context: context,
      builder: (_) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Delete Account?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This will remove your account and academic profile data from this device.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setModalState(() => busy = true);
                            await ref
                                .read(authProvider.notifier)
                                .deactivateAccount();
                            await ref
                                .read(academicProfileProvider.notifier)
                                .reset();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account deleted.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    child: Text(busy ? 'Deleting...' : 'Delete Account'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPreferredMic(BuildContext context) {
    final options = [
      'Default - Microphone (HD Pro Webcam C920)',
      'Built-in Microphone',
      'External USB Mic',
    ];

    AppModal.show(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final prefs = ref.read(userPrefsProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Preferred Mic',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final o in options)
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    value: o,
                    // ignore: deprecated_member_use
                    groupValue: prefs.preferredMic,
                    // ignore: deprecated_member_use
                    onChanged: (v) {
                      if (v == null) return;
                      _setPreferredMic(v);
                      Navigator.of(context).pop();
                    },
                    title: Text(o),
                    activeColor: AppColors.primary,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordingQuality(BuildContext context) {
    final options = ['Lossless', 'Balanced', 'Data Saver'];
    AppModal.show(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final prefs = ref.read(userPrefsProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recording Quality',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final o in options)
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    value: o,
                    // ignore: deprecated_member_use
                    groupValue: prefs.recordingQuality,
                    // ignore: deprecated_member_use
                    onChanged: (v) {
                      if (v == null) return;
                      _setRecordingQuality(v);
                      Navigator.of(context).pop();
                    },
                    title: Text(o),
                    activeColor: AppColors.primary,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    await ref
        .read(userPrefsProvider.notifier)
        .setNotificationsEnabled(value);
  }

  Future<void> _setPreferredMic(String value) async {
    await ref.read(userPrefsProvider.notifier).setPreferredMic(value);
  }

  Future<void> _setRecordingQuality(String value) async {
    await ref.read(userPrefsProvider.notifier).setRecordingQuality(value);
  }

  Future<void> _setAiConsent(bool value) async {
    await ref.read(userPrefsProvider.notifier).setAiConsent(value);
  }

  void _showLegalDoc(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDataUsage(BuildContext context) {
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recording & AI Processing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'When you record a session or upload a course outline, we '
              'upload that file to generate transcripts, summaries, '
              'flashcards, and tasks. We do not process uploads unless '
              'you consent. You can toggle AI processing consent in Settings.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAudioTest(BuildContext context) {
    AppModal.show(
      context: context,
      builder: (_) {
        int secondsLeft = 4;
        bool running = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Audio Test',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  running
                      ? 'Listening... $secondsLeft'
                      : 'We will run a 4-second microphone diagnostic.',
                  style: const TextStyle(color: AppColors.subtext),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: running
                        ? null
                        : () {
                            setModalState(() {
                              running = true;
                              secondsLeft = 4;
                            });
                            Timer.periodic(
                              const Duration(seconds: 1),
                              (t) {
                                if (secondsLeft == 1) {
                                  t.cancel();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Audio test complete'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setModalState(() => secondsLeft--);
                              },
                            );
                          },
                    child: const Text('Start Test'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leading, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.subtext,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.subtext,
        letterSpacing: 1.2,
      ),
    );
  }
}
