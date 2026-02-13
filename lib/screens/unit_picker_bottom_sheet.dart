import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/units_provider.dart';
import '../providers/selected_unit_provider.dart';
import '../providers/sessions_provider.dart';

class UnitPickerBottomSheet extends ConsumerStatefulWidget {
  const UnitPickerBottomSheet({super.key});

  @override
  ConsumerState<UnitPickerBottomSheet> createState() =>
      _UnitPickerBottomSheetState();
}

class _UnitPickerBottomSheetState
    extends ConsumerState<UnitPickerBottomSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final sessions = ref.watch(sessionsProvider);

    final counts = <String, int>{};
    for (final s in sessions) {
      final key =
          (s.eventId == null || s.eventId!.isEmpty) ? 'general' : s.eventId!;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Destination Course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...units.map((unit) {
          final initial = unit.title.isEmpty
              ? 'U'
              : unit.title.characters.first.toUpperCase();
          final count = counts[unit.id] ?? 0;
          return GestureDetector(
            onTap: () {
              ref.read(selectedUnitProvider.notifier).state = unit;
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count Sessions',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showCreateUnit(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Center(
              child: Text(
                '+   Create New Course',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateUnit(BuildContext context) {
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create New Course',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Course name',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  final unit = ref
                      .read(unitsProvider.notifier)
                      .createUnit(_controller.text.trim());
                  ref.read(selectedUnitProvider.notifier).state = unit;
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Create & Continue'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        );
      },
    );
  }
}


