import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/academic_profile_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _name = TextEditingController(text: auth.userName ?? '');
    _email = TextEditingController(text: auth.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(academicProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'Tell us about your studies',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This helps Syntra tailor insights, reminders, and study support.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Academic Profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          AcademicProfileForm(
            initial: profile,
            onSave: (next) {
              ref.read(academicProfileProvider.notifier).updateProfile(next);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated')),
              );
            },
            submitLabel: 'Save Profile',
          ),
        ],
      ),
    );
  }
}

class AcademicProfileForm extends StatefulWidget {
  final AcademicProfile initial;
  final ValueChanged<AcademicProfile> onSave;
  final String submitLabel;
  final bool showHeader;

  const AcademicProfileForm({
    super.key,
    required this.initial,
    required this.onSave,
    required this.submitLabel,
    this.showHeader = false,
  });

  @override
  State<AcademicProfileForm> createState() => _AcademicProfileFormState();
}

class _AcademicProfileFormState extends State<AcademicProfileForm> {
  late final TextEditingController _university;
  late final TextEditingController _field;
  late final TextEditingController _goals;
  String _degree = '';
  String _year = '';

  @override
  void initState() {
    super.initState();
    _university = TextEditingController(text: widget.initial.university);
    _field = TextEditingController(text: widget.initial.fieldOfStudy);
    _goals = TextEditingController(text: widget.initial.studyGoals);
    _degree = widget.initial.degreeLevel;
    _year = widget.initial.yearTerm;
  }

  @override
  void dispose() {
    _university.dispose();
    _field.dispose();
    _goals.dispose();
    super.dispose();
  }

  void _submit() {
    final next = AcademicProfile(
      university: _university.text.trim(),
      fieldOfStudy: _field.text.trim(),
      degreeLevel: _degree.trim(),
      yearTerm: _year.trim(),
      studyGoals: _goals.text.trim(),
    );
    if (!next.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.onSave(next);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _university,
          decoration: const InputDecoration(
            labelText: 'University / College *',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _field,
          decoration: const InputDecoration(
            labelText: 'Field of Study *',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _degree.isEmpty ? null : _degree,
          decoration: const InputDecoration(
            labelText: 'Degree Level *',
          ),
          items: const [
            DropdownMenuItem(value: 'Bachelor', child: Text('Bachelor')),
            DropdownMenuItem(value: 'Master', child: Text('Master')),
            DropdownMenuItem(value: 'PhD', child: Text('PhD')),
            DropdownMenuItem(value: 'Associate', child: Text('Associate')),
            DropdownMenuItem(value: 'Certificate', child: Text('Certificate')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _degree = value ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _year.isEmpty ? null : _year,
          decoration: const InputDecoration(
            labelText: 'Year of Study *',
          ),
          items: const [
            DropdownMenuItem(value: 'Year 1', child: Text('Year 1')),
            DropdownMenuItem(value: 'Year 2', child: Text('Year 2')),
            DropdownMenuItem(value: 'Year 3', child: Text('Year 3')),
            DropdownMenuItem(value: 'Year 4', child: Text('Year 4')),
            DropdownMenuItem(value: 'Year 5+', child: Text('Year 5+')),
            DropdownMenuItem(value: 'Graduate', child: Text('Graduate')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _year = value ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goals,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Study Goals (Optional)',
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.text),
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
