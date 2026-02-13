// lib/screens/assign_session_to_unit_sheet.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session.dart';
import '../providers/sessions_provider.dart';
import '../providers/units_provider.dart';
import '../models/unit.dart';
import '../core/utils/session_format.dart';

class AssignSessionToUnitSheet extends ConsumerStatefulWidget {
  final Session session;

  const AssignSessionToUnitSheet({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<AssignSessionToUnitSheet> createState() =>
      _AssignSessionToUnitSheetState();
}

class _AssignSessionToUnitSheetState
    extends ConsumerState<AssignSessionToUnitSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _assign(Unit unit) {
    ref.read(sessionsProvider.notifier).assignSessionToUnit(
          sessionId: widget.session.id,
          unitId: unit.id,
        );
    Navigator.pop(context);
  }

  void _createAndAssign() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final unit = ref.read(unitsProvider.notifier).createUnit(title);
    ref.read(sessionsProvider.notifier).assignSessionToUnit(
          sessionId: widget.session.id,
          unitId: unit.id,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final currentUnitId = widget.session.eventId;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Assign to Course',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(6),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displaySessionTitle(widget.session),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext,
                ),
              ),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                        'Create new course',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.add, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Course name (ex. Biology 101)',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _createAndAssign,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Create and assign',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: units.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final u = units[index];
                  final isSelected = currentUnitId == u.id;

                  return InkWell(
                    onTap: () => _assign(u),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.book_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              u.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          else
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}


