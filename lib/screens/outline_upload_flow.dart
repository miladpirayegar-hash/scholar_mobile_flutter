import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../theme/app_theme.dart';
import '../providers/unit_notes_provider.dart';
import '../providers/selected_unit_provider.dart';
import '../providers/outline_pending_provider.dart';
import '../providers/units_provider.dart';
import '../providers/content_visibility_provider.dart';
import '../providers/user_prefs_provider.dart';
import 'unit_detail_screen.dart';
import 'unit_picker_bottom_sheet.dart';
import '../services/api/api_providers.dart';
import '../config/api_config.dart';

Future<void> showOutlineUploadFlow(
  BuildContext context,
  WidgetRef ref, {
  String? unitId,
}) async {
  String? resolvedUnitId = unitId;
  if (resolvedUnitId == null) {
    await AppModal.show(
      context: context,
      builder: (_) => const UnitPickerBottomSheet(),
    );
    if (!context.mounted) return;
    final unit = ref.read(selectedUnitProvider);
    if (unit == null) return;
    resolvedUnitId = unit.id;
  }

  final notes = ref.read(unitNotesProvider)[resolvedUnitId] ?? const UnitNotes();
  await _showOutlineImport(context, ref, resolvedUnitId, notes);
}

Future<void> processCourseFileForUnit(
  BuildContext context,
  WidgetRef ref, {
  required String unitId,
  required PlatformFile file,
}) async {
  final notes = ref.read(unitNotesProvider)[unitId] ?? const UnitNotes();
  bool started = false;
  _OutlineImportResult? result;
  String stage = 'Uploading to Syntra...';
  double? progress;

  await AppModal.show(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          if (!started) {
            started = true;
            Future.microtask(() async {
              result = await _parseOutlineFromFile(
                ref,
                file,
                onStage: (s) {
                  if (context.mounted) {
                    setModalState(() => stage = s);
                  }
                },
                onProgress: (p) {
                  if (context.mounted) {
                    setModalState(() => progress = p);
                  }
                },
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Analyzing Course File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  stage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surface,
                color: AppColors.primary,
                minHeight: 6,
              ),
              if (progress != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress!.clamp(0, 1) * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.subtext,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          );
        },
      );
    },
  );

  if (result == null) return;
  if (result!.parsed != null) {
    if (!context.mounted) return;
    _showOutlineApproval(
      context,
      ref,
      unitId,
      notes,
      result!.parsed!,
    );
  } else if (result!.error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result!.error!)),
    );
  }
}

Future<void> _showOutlineImport(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  UnitNotes notes,
) async {
  final rootContext = context;
  PlatformFile? selectedFile;
  bool isBusy = false;
  String? errorText;
  bool? usedApi;
  String? stageText;
  double? progressValue;
  bool consented = ref.read(userPrefsProvider).aiProcessingConsent;
  const maxOutlineSizeBytes = 15 * 1024 * 1024; // 15 MB
  await AppModal.show(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          bool isValidFile(PlatformFile file) {
            final ext = (file.extension ?? '').toLowerCase();
            if (ext != 'pdf' && ext != 'docx') return false;
            if (file.size > maxOutlineSizeBytes) return false;
            return true;
          }

          String? validationMessage(PlatformFile file) {
            final ext = (file.extension ?? '').toLowerCase();
            if (ext != 'pdf' && ext != 'docx') {
              return 'Unsupported file type. Use PDF or DOCX.';
            }
            if (file.size > maxOutlineSizeBytes) {
              return 'File too large. Max 15 MB.';
            }
            return null;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upload Course Outline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Upload a PDF/DOCX syllabus so Syntra can auto-fill highlights, exams, and assignments for your course.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.upload_file, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedFile?.name ?? 'Choose a PDF or DOCX file',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final picked =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'docx'],
                                withData: true,
                                dialogTitle: 'Select course outline',
                              );
                              if (picked == null || picked.files.isEmpty) {
                                return;
                              }
                              final next = picked.files.first;
                              final msg = validationMessage(next);
                              setModalState(() {
                                selectedFile = next;
                                errorText = msg;
                              });
                            },
                      child: const Text('Browse'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 14, color: AppColors.subtext),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PDF or DOCX only. Max size 15 MB.',
                      style: TextStyle(fontSize: 11, color: AppColors.subtext),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: consented,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I consent to AI processing for this upload',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'We upload this file to generate highlights, exams, and assignments.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
                onChanged: (value) {
                  consented = value ?? false;
                  ref
                      .read(userPrefsProvider.notifier)
                      .setAiConsent(consented);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 8),
              if (!consented) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Consent is required to upload this file.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (usedApi != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    usedApi!
                        ? 'Using AI extraction'
                        : 'Using local extraction (API unavailable)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (isBusy && stageText != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stageText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtext,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
                if (progressValue != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progressValue!.clamp(0, 1) * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.subtext,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              if (errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (selectedFile == null ||
                          isBusy ||
                          !consented ||
                          (selectedFile != null &&
                              !isValidFile(selectedFile!)))
                      ? null
                      : () async {
                          setModalState(() {
                            isBusy = true;
                            stageText = 'Uploading to Syntra...';
                            progressValue = null;
                            errorText = null;
                          });
                          try {
                            final result = await _parseOutlineFromFile(
                              ref,
                              selectedFile!,
                              onStage: (text) {
                                if (context.mounted) {
                                  setModalState(() => stageText = text);
                                }
                              },
                              onProgress: (value) {
                                if (context.mounted) {
                                  setModalState(() => progressValue = value);
                                }
                              },
                            );
                            usedApi = result.usedApi;
                            errorText = result.error;
                            if (result.parsed != null) {
                              await ref
                                  .read(userPrefsProvider.notifier)
                                  .setHasUploadedOutline(true);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              _showOutlineApproval(
                                rootContext,
                                ref,
                                unitId,
                                notes,
                                result.parsed!,
                              );
                            } else {
                              if (context.mounted) {
                                setModalState(() {});
                              }
                            }
                          } finally {
                            if (context.mounted) {
                              setModalState(() => isBusy = false);
                            }
                          }
                        },
                  child: Text(isBusy ? 'Importing...' : 'Add To Course Profile'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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

class _OutlineParseResult {
  final List<_OutlineHighlight> highlights;
  final List<DatedItem> exams;
  final List<DatedItem> assignments;

  const _OutlineParseResult({
    required this.highlights,
    required this.exams,
    required this.assignments,
  });
}

class _OutlineImportResult {
  final _OutlineParseResult? parsed;
  final bool usedApi;
  final String? error;

  const _OutlineImportResult({
    required this.parsed,
    required this.usedApi,
    this.error,
  });
}

class _OutlineHighlight {
  final String text;
  final String category;
  final String reason;

  const _OutlineHighlight({
    required this.text,
    required this.category,
    required this.reason,
  });
}

_OutlineParseResult _parseOutline(String raw) {
  final lines = raw
      .split('\n')
      .map(_normalizeLine)
      .where((e) => e.isNotEmpty)
      .toList();

  final highlights = <String>[];
  final exams = <DatedItem>[];
  final assignments = <DatedItem>[];

  String? section;
  for (final line in lines) {
    final lower = line.toLowerCase();
    final dates = _extractDates(line);
    final header = _sectionHeader(lower);
    if (header != null) {
      section = header;
      continue;
    }

    final hasExam = _matchesKeyword(lower, _examKeywords);
    final hasAssignment = _matchesKeyword(lower, _assignmentKeywords);

    if (hasExam || section == 'exam') {
      if (_isMilestoneCandidate(line, dates, isExam: true)) {
        _addDatedItem(exams, line, dates);
      }
      continue;
    }

    if (hasAssignment || section == 'assignment') {
      if (_isMilestoneCandidate(line, dates, isExam: false)) {
        _addDatedItem(assignments, line, dates);
      }
      continue;
    }

    if (_isHighlightCandidate(line)) {
      highlights.add(_trimLine(line));
    }
  }

  final curated = _selectHighlights(highlights);

  return _OutlineParseResult(
    highlights: curated,
    exams: _dedupeDatedItems(exams).take(15).toList(),
    assignments: _dedupeDatedItems(assignments).take(20).toList(),
  );
}

_OutlineParseResult _parseOutlineResponse(Map<String, dynamic> decoded) {
  final highlights = <_OutlineHighlight>[];
  final exams = <DatedItem>[];
  final assignments = <DatedItem>[];

  final payload = _unwrapOutlinePayload(decoded);
  final rawHighlights = payload['highlights'] ?? decoded['highlights'];
  if (rawHighlights is List) {
    for (final h in rawHighlights) {
      if (h is Map<String, dynamic>) {
        final text = (h['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        highlights.add(
          _OutlineHighlight(
            text: text,
            category: (h['category'] ?? 'General').toString().trim(),
            reason: (h['reason'] ?? '').toString().trim(),
          ),
        );
      } else if (h is String) {
        final text = h.trim();
        if (text.isEmpty) continue;
        highlights.add(
          _OutlineHighlight(
            text: text,
            category: 'General',
            reason: 'Extracted from outline.',
          ),
        );
      }
    }
  }

  _addApiItemsToBuckets(
    _coerceApiList(payload['exams'] ?? decoded['exams']),
    exams: exams,
    assignments: assignments,
    categoryHint: 'exam',
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['assignments'] ?? decoded['assignments']),
    exams: exams,
    assignments: assignments,
    categoryHint: 'assignment',
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['assessments']),
    exams: exams,
    assignments: assignments,
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['milestones']),
    exams: exams,
    assignments: assignments,
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['deadlines']),
    exams: exams,
    assignments: assignments,
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['schedule']),
    exams: exams,
    assignments: assignments,
  );
  _addApiItemsToBuckets(
    _coerceApiList(payload['items']),
    exams: exams,
    assignments: assignments,
  );

  return _OutlineParseResult(
    highlights: highlights,
    exams: _dedupeDatedItems(exams),
    assignments: _dedupeDatedItems(assignments),
  );
}

Map<String, dynamic> _unwrapOutlinePayload(Map<String, dynamic> decoded) {
  final candidates = ['data', 'result', 'payload', 'outline', 'response'];
  for (final key in candidates) {
    final value = decoded[key];
    if (value is Map<String, dynamic>) return value;
  }
  return decoded;
}

List<dynamic> _coerceApiList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  if (value is Map<String, dynamic>) {
    final items = value['items'] ?? value['list'] ?? value['entries'];
    if (items is List) return items;
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n;\u2022]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

void _addApiItemsToBuckets(
  List<dynamic> raw, {
  required List<DatedItem> exams,
  required List<DatedItem> assignments,
  String? categoryHint,
}) {
  if (raw.isEmpty) return;
  for (final entry in raw) {
    if (entry is Map<String, dynamic>) {
      final text = _coerceApiText(entry);
      if (text.isEmpty) continue;
      final date = _parseApiDate(
        entry['date'] ??
            entry['dueDate'] ??
            entry['due_date'] ??
            entry['deadline'] ??
            entry['when'],
      );
      final type = (entry['type'] ??
              entry['category'] ??
              entry['kind'] ??
              entry['label'] ??
              categoryHint ??
              '')
          .toString()
          .toLowerCase();
      final lower = text.toLowerCase();
      final isExam = _matchesKeyword(lower, _examKeywords) ||
          type.contains('exam') ||
          type.contains('quiz') ||
          type.contains('test') ||
          type.contains('midterm') ||
          type.contains('final');
      final isAssignment = _matchesKeyword(lower, _assignmentKeywords) ||
          type.contains('assignment') ||
          type.contains('homework') ||
          type.contains('project') ||
          type.contains('lab') ||
          type.contains('paper') ||
          type.contains('essay');
      if (isExam) {
        exams.add(DatedItem(text: text, date: date));
      }
      if (isAssignment) {
        assignments.add(DatedItem(text: text, date: date));
      }
      continue;
    }
    if (entry is String) {
      final text = entry.trim();
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();
      final isExam = categoryHint == 'exam' ||
          _matchesKeyword(lower, _examKeywords);
      final isAssignment = categoryHint == 'assignment' ||
          _matchesKeyword(lower, _assignmentKeywords);
      if (isExam) exams.add(DatedItem(text: text));
      if (isAssignment) assignments.add(DatedItem(text: text));
    }
  }
}

String _coerceApiText(Map<String, dynamic> entry) {
  final text = (entry['text'] ??
          entry['title'] ??
          entry['name'] ??
          entry['item'] ??
          entry['label'] ??
          entry['description'] ??
          '')
      .toString()
      .trim();
  return text;
}

DateTime? _parseApiDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<_OutlineHighlight> _selectHighlights(List<String> lines) {
  final selected = <_OutlineHighlight>[];
  final seen = <String>{};
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (_isLearningOutcomeLine(lower)) continue;
    if (_matchesKeyword(lower, _highlightKeywords)) {
      final trimmed = _trimLine(line);
      if (seen.add(trimmed.toLowerCase())) {
        selected.add(
          _OutlineHighlight(
            text: trimmed,
            category: _highlightCategoryFor(lower),
            reason: 'Extracted from outline section keywords.',
          ),
        );
      }
    }
  }
  if (selected.length < 6) {
    for (final line in lines) {
      if (!_isHighlightCandidate(line)) continue;
      final trimmed = _trimLine(line);
      if (seen.add(trimmed.toLowerCase())) {
        selected.add(
          _OutlineHighlight(
            text: trimmed,
            category: 'General',
            reason: 'Promising student-facing detail.',
          ),
        );
      }
      if (selected.length >= 6) break;
    }
  }
  return selected.take(6).toList();
}

String _trimLine(String line) {
  final trimmed = line.trim();
  if (trimmed.length <= 120) return trimmed;
  return '${trimmed.substring(0, 120)}...';
}

String _normalizeLine(String line) {
  var cleaned = line.replaceAll(RegExp(r'^[\-\*\u2022]+\s*'), '');
  cleaned = cleaned.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned;
}

bool _matchesKeyword(String value, List<String> keywords) {
  return keywords.any((k) => value.contains(k));
}

String? _sectionHeader(String lower) {
  final trimmed = lower.trim();
  final words = trimmed.replaceAll(':', '').split(RegExp(r'\s+'));
  final isShort = words.length <= 3;
  final endsWithColon = trimmed.endsWith(':');
  if ((isShort || endsWithColon) && _matchesKeyword(trimmed, _examKeywords)) {
    return 'exam';
  }
  if ((isShort || endsWithColon) &&
      _matchesKeyword(trimmed, _assignmentKeywords)) {
    return 'assignment';
  }
  if ((isShort || endsWithColon) &&
      _matchesKeyword(trimmed, _highlightKeywords)) {
    return 'highlight';
  }
  return null;
}

bool _isHighlightCandidate(String line) {
  final lower = line.toLowerCase();
  if (_matchesKeyword(lower, _highlightKeywords)) return true;
  if (_isLikelyMetadata(lower)) return false;
  if (_isLearningOutcomeLine(lower)) return false;
  if (line.length < 6) return false;
  if (RegExp(r'^page \d+$', caseSensitive: false).hasMatch(line)) {
    return false;
  }
  if (RegExp(r'^\d+$').hasMatch(line)) return false;
  if (_looksLikeCourseCode(line)) return false;
  if (_looksLikeCrn(line)) return false;
  return true;
}

bool _isLearningOutcomeLine(String lower) {
  return lower.contains('learning outcome') ||
      lower.contains('learning outcomes') ||
      lower.contains('student learning') ||
      lower.contains('clo') ||
      lower.contains('slos') ||
      lower.contains('slo');
}

bool _isLikelyMetadata(String lower) {
  if (lower.contains('office hours')) return false;
  if (lower.contains('grading') ||
      lower.contains('attendance') ||
      lower.contains('policy') ||
      lower.contains('objective') ||
      lower.contains('overview') ||
      lower.contains('materials') ||
      lower.contains('prerequisite') ||
      lower.contains('textbook')) {
    return false;
  }
  final metadata = [
    'crn',
    'course number',
    'section',
    'credits',
    'credit hours',
    'semester',
    'term',
    'instructor',
    'email',
    'phone',
    'room',
    'location',
    'meeting',
    'days',
    'campus',
  ];
  return metadata.any((k) => lower.contains(k));
}

bool _looksLikeCourseCode(String line) {
  return RegExp(r'^[A-Z&]{2,}\s?\d{3,4}[A-Z]?$').hasMatch(line.trim()) ||
      RegExp(r'[A-Z]{2,}\s?\d{3,4}', caseSensitive: false).hasMatch(line);
}

bool _looksLikeCrn(String line) {
  return RegExp(r'\bcrn\b', caseSensitive: false).hasMatch(line) ||
      RegExp(r'\b\d{5}\b').hasMatch(line);
}

void _addDatedItem(List<DatedItem> items, String line, List<DateTime> dates) {
  if (dates.isEmpty) {
    items.add(DatedItem(text: _trimLine(line)));
    return;
  }
  for (final d in dates) {
    items.add(DatedItem(text: _trimLine(line), date: d));
  }
}

bool _isMilestoneCandidate(
  String line,
  List<DateTime> dates, {
  required bool isExam,
}) {
  final lower = line.toLowerCase();
  if (lower.length < 6) return false;
  if (_isLikelyMetadata(lower)) return false;
  if (lower.contains('learning outcome') || lower.contains('outcome')) {
    return false;
  }
  if (lower.contains('rubric') || lower.contains('grading')) return false;
  if (lower.contains('weight') || lower.contains('percentage')) return false;
  if (dates.isEmpty) {
    if (!_matchesKeyword(
        lower, isExam ? _examKeywords : _assignmentKeywords)) {
      return false;
    }
    if (line.length > 80) return false;
    if (_hasMilestoneSignal(lower, line)) return true;
    return false;
  }
  if (isExam) return _matchesKeyword(lower, _examKeywords);
  return _matchesKeyword(lower, _assignmentKeywords);
}

bool _hasMilestoneSignal(String lower, String line) {
  if (RegExp(r'\b(week|module|unit|chapter|lesson)\b').hasMatch(lower)) {
    return true;
  }
  if (RegExp(r'\b\d+\b').hasMatch(line)) return true;
  if (lower.contains('due')) return true;
  return false;
}
List<DatedItem> _dedupeDatedItems(List<DatedItem> items) {
  final seen = <String>{};
  final output = <DatedItem>[];
  for (final item in items) {
    final key = '${item.text.toLowerCase()}::${item.date?.toIso8601String() ?? ''}';
    if (seen.add(key)) output.add(item);
  }
  return output;
}

const List<String> _examKeywords = [
  'exam',
  'midterm',
  'final',
  'test',
  'quiz',
];

const List<String> _assignmentKeywords = [
  'assignment',
  'homework',
  'project',
  'paper',
  'lab',
  'presentation',
  'essay',
  'deliverable',
  'due',
];

const List<String> _highlightKeywords = [
  'textbook',
  'required',
  'grading',
  'attendance',
  'office hours',
  'prerequisite',
  'policy',
  'objective',
  'overview',
  'materials',
  'late',
  'syllabus',
  'participation',
  'expectations',
];

String _highlightCategoryFor(String lower) {
  if (lower.contains('grading')) return 'Grading';
  if (lower.contains('attendance')) return 'Attendance';
  if (lower.contains('late')) return 'Late Policy';
  if (lower.contains('office hours')) return 'Office Hours';
  if (lower.contains('textbook') || lower.contains('materials')) {
    return 'Materials';
  }
  if (lower.contains('policy')) return 'Policy';
  if (lower.contains('objective') || lower.contains('overview')) {
    return 'Objectives';
  }
  if (lower.contains('participation') || lower.contains('expectations')) {
    return 'Participation';
  }
  return 'General';
}

void _applyOutlineToNotes(
  WidgetRef ref,
  String unitId,
  UnitNotes notes,
  _OutlineParseResult parsed,
) {
  final notesController = ref.read(unitNotesProvider.notifier);
  final pending = ref.read(outlinePendingProvider.notifier);
  final newHighlights = [
    for (final h in parsed.highlights)
      if (!notes.highlights.contains(h.text)) h.text,
  ];
  if (newHighlights.isNotEmpty) {
    notesController.addHighlights(unitId, newHighlights);
  }
  if (parsed.exams.isNotEmpty || parsed.assignments.isNotEmpty) {
    pending.addPending(
      unitId: unitId,
      exams: parsed.exams,
      assignments: parsed.assignments,
    );
  }
}

Future<_OutlineImportResult> _parseOutlineFromFile(
  WidgetRef ref,
  PlatformFile file,
  {void Function(String stage)? onStage,
  void Function(double? progress)? onProgress}
) async {
  final ext = file.extension?.toLowerCase();
  final bytes = file.bytes ?? await _readFileBytes(file.path);
  if (bytes == null || ext == null) {
    return const _OutlineImportResult(
      parsed: null,
      usedApi: false,
      error: 'Could not read the outline file.',
    );
  }

  try {
    final api = ref.read(apiServiceProvider);
    debugPrint(
      '[outline] AI extract: ${ApiConfig.baseUrl}${ApiConfig.outlineExtractPath}',
    );
    onStage?.call('Uploading to Syntra...');
    onProgress?.call(null);
    final decoded = await api
        .extractOutline(
          filename: file.name,
          bytes: bytes,
          extension: ext,
        )
        .timeout(const Duration(seconds: 25));
    debugPrint(
      '[outline] AI response keys: ${decoded.keys.toList()}',
    );
    return _OutlineImportResult(
      parsed: _parseOutlineResponse(decoded),
      usedApi: true,
    );
  } catch (e) {
    debugPrint('[outline] AI extract failed: $e');
    onStage?.call('Parsing locally...');
    if (ext == 'pdf') {
      final text = _extractPdfText(bytes);
      return _OutlineImportResult(
        parsed: _parseOutline(text),
        usedApi: false,
        error:
            'AI extraction stalled or failed. Falling back to local parsing.\n'
            'URL: ${ApiConfig.baseUrl}${ApiConfig.outlineExtractPath}\n'
            'Error: ${e.toString()}',
      );
    }
    if (ext == 'docx') {
      final text = _extractDocxText(bytes);
      return _OutlineImportResult(
        parsed: _parseOutline(text),
        usedApi: false,
        error:
            'AI extraction stalled or failed. Falling back to local parsing.\n'
            'URL: ${ApiConfig.baseUrl}${ApiConfig.outlineExtractPath}\n'
            'Error: ${e.toString()}',
      );
    }
    return _OutlineImportResult(
      parsed: null,
      usedApi: false,
      error: 'Unsupported file type.',
    );
  }
}

Future<Uint8List?> _readFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

String _extractPdfText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(document);
  final text = extractor.extractText();
  document.dispose();
  return text;
}

String _extractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final docXml = archive.files
      .where((f) => f.name == 'word/document.xml')
      .map((f) => f.content as List<int>)
      .cast<List<int>>()
      .toList();
  if (docXml.isEmpty) return '';
  final xmlStr = utf8.decode(docXml.first);
  final document = XmlDocument.parse(xmlStr);
  final buffer = StringBuffer();

  for (final p in document.findAllElements('w:p')) {
    final runs = p.findAllElements('w:t');
    for (final t in runs) {
      buffer.write(t.innerText);
    }
    buffer.write('\n');
  }

  return buffer.toString();
}

void _showOutlineApproval(
  BuildContext rootContext,
  WidgetRef ref,
  String unitId,
  UnitNotes notes,
  _OutlineParseResult parsed,
) {
  AppModal.show(
    context: rootContext,
    builder: (modalContext) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Approve Imported Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (parsed.exams.isEmpty && parsed.assignments.isEmpty) ...[
            const Text(
              'No exams or assignments were detected. If you expected them, '
              'verify the AI API is reachable and returning exams/assignments. '
              'If dates were missing in the outline, add them manually after approving highlights.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (parsed.highlights.isNotEmpty) ...[
            const _OutlineSectionTitle('Highlights'),
            const SizedBox(height: 6),
            for (final h in parsed.highlights.take(6))
              _OutlineItem(
                text: h.text,
                subtitle: h.reason.trim().isEmpty
                    ? h.category
                    : '${h.category} - ${h.reason}',
              ),
            if (parsed.highlights.length > 6)
              _OutlineOverflow(count: parsed.highlights.length - 6),
            const SizedBox(height: 10),
          ],
          if (parsed.exams.isNotEmpty) ...[
            const _OutlineSectionTitle('Exams'),
            const SizedBox(height: 6),
            for (final e in parsed.exams.take(6))
              _OutlineItem(
                text: e.text,
                date: e.date,
              ),
            if (parsed.exams.length > 6)
              _OutlineOverflow(count: parsed.exams.length - 6),
            const SizedBox(height: 10),
          ],
          if (parsed.assignments.isNotEmpty) ...[
            const _OutlineSectionTitle('Assignments'),
            const SizedBox(height: 6),
            for (final a in parsed.assignments.take(6))
              _OutlineItem(
                text: a.text,
                date: a.date,
              ),
            if (parsed.assignments.length > 6)
              _OutlineOverflow(count: parsed.assignments.length - 6),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (!modalContext.mounted) return;
                    Navigator.of(modalContext).pop();
                  },
                  child: const Text('Decline'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                      ref
                          .read(contentVisibilityProvider.notifier)
                          .markContentStarted();
                      _applyOutlineToNotes(ref, unitId, notes, parsed);
                    if (!modalContext.mounted) return;
                    Navigator.of(modalContext).pop();
                    if (!rootContext.mounted) return;
                    final unitTitle = _unitTitle(ref, unitId);
                    if (unitTitle != null && unitTitle.isNotEmpty) {
                      Navigator.of(rootContext).push(
                        MaterialPageRoute(
                          builder: (_) => UnitDetailScreen(
                            unitTitle: unitTitle,
                            unitId: unitId,
                          ),
                        ),
                      );
                    }
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Highlights saved. Exams/assignments moved to Tasks for approval.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
      );
    },
  );
}

String? _unitTitle(WidgetRef ref, String unitId) {
  final units = ref.read(unitsProvider);
  final title = units
      .where((u) => u.id == unitId)
      .map((u) => u.title)
      .firstWhere((_) => true, orElse: () => '');
  return title.isEmpty ? null : title;
}

class _OutlineSectionTitle extends StatelessWidget {
  final String text;

  const _OutlineSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.subtext,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _OutlineItem extends StatelessWidget {
  final String text;
  final String? subtitle;
  final DateTime? date;

  const _OutlineItem({required this.text, this.subtitle, this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.subtext,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (date != null)
            Text(
              '${date!.month}/${date!.day}/${date!.year}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.subtext,
              ),
            ),
        ],
      ),
    );
  }
}

class _OutlineOverflow extends StatelessWidget {
  final int count;

  const _OutlineOverflow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '+ $count more',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.subtext,
        ),
      ),
    );
  }
}

List<DateTime> _extractDates(String text) {
  final dates = <DateTime>[];
  final nowYear = DateTime.now().year;
  final numeric =
      RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').allMatches(text);
  for (final m in numeric) {
    final month = int.tryParse(m.group(1) ?? '');
    final day = int.tryParse(m.group(2) ?? '');
    var year = int.tryParse(m.group(3) ?? '');
    if (month == null || day == null) continue;
    year = _normalizeYear(year, nowYear);
    _pushDate(dates, year, month, day);
  }

  final monthNames =
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
  final monthFirst = RegExp(
    r'\b' + monthNames + r'\.?\s+(\d{1,2})(?:,\s*(\d{2,4}))?\b',
    caseSensitive: false,
  );
  for (final m in monthFirst.allMatches(text)) {
    final month = _monthNumber(m.group(1));
    final day = int.tryParse(m.group(2) ?? '');
    var year = int.tryParse(m.group(3) ?? '');
    if (month == null || day == null) continue;
    year = _normalizeYear(year, nowYear);
    _pushDate(dates, year, month, day);
  }

  final dayFirst = RegExp(
    r'\b(\d{1,2})\s+' + monthNames + r'\.?\s*(\d{2,4})?\b',
    caseSensitive: false,
  );
  for (final m in dayFirst.allMatches(text)) {
    final day = int.tryParse(m.group(1) ?? '');
    final month = _monthNumber(m.group(2));
    var year = int.tryParse(m.group(3) ?? '');
    if (month == null || day == null) continue;
    year = _normalizeYear(year, nowYear);
    _pushDate(dates, year, month, day);
  }
  return dates;
}

int _normalizeYear(int? year, int fallback) {
  if (year == null) return fallback;
  if (year < 100) return 2000 + year;
  return year;
}

int? _monthNumber(String? raw) {
  if (raw == null) return null;
  final key = raw.toLowerCase().substring(0, 3);
  switch (key) {
    case 'jan':
      return 1;
    case 'feb':
      return 2;
    case 'mar':
      return 3;
    case 'apr':
      return 4;
    case 'may':
      return 5;
    case 'jun':
      return 6;
    case 'jul':
      return 7;
    case 'aug':
      return 8;
    case 'sep':
      return 9;
    case 'oct':
      return 10;
    case 'nov':
      return 11;
    case 'dec':
      return 12;
    default:
      return null;
  }
}

void _pushDate(List<DateTime> dates, int year, int month, int day) {
  if (month < 1 || month > 12) return;
  if (day < 1 || day > 31) return;
  final dt = DateTime(year, month, day);
  if (dt.month == month && dt.day == day) {
    dates.add(dt);
  }
}
