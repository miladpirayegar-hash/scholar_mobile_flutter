import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../services/recording/recording_providers.dart';
import '../../core/utils/permissions.dart';
import '../../features/recording/session_controller.dart';
import '../../providers/selected_unit_provider.dart';
import '../../screens/unit_picker_bottom_sheet.dart';
import '../../providers/recording_status_provider.dart';
import '../../providers/units_provider.dart';
import '../../providers/content_visibility_provider.dart';
import '../../providers/user_prefs_provider.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool isRecording = false;
  String? audioPath;
  int seconds = 0;
  bool _promptedForUnit = false;
  late final AnimationController _waveController;
  bool _isPaused = false;
  double _level = 0.0;
  StreamSubscription? _ampSub;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    Future.microtask(() async {
      final granted = await ensureMicrophonePermission();
      if (!mounted) return;
      if (!granted) {
        _showMicPermissionSheet();
        return;
      }
      final status = ref.read(recordingStatusProvider);
      if (status.isRecording) {
        _hydrateFromStatus(status);
      } else {
        await _ensureUnitSelected(forcePrompt: true);
        final unit = ref.read(selectedUnitProvider);
        if (unit != null && !isRecording) {
          await _startRecordingForUnit();
        }
      }
    });
  }

  Future<void> _ensureUnitSelected({bool forcePrompt = false}) async {
    final hasUnit = ref.read(selectedUnitProvider) != null;
    if (!forcePrompt && hasUnit) return;

    if (forcePrompt || !_promptedForUnit) {
      ref.read(selectedUnitProvider.notifier).state = null;
    }
    await AppModal.show(
      context: context,
      builder: (_) => const UnitPickerBottomSheet(),
    );
    _promptedForUnit = true;
  }

  Future<void> _startRecordingForUnit() async {
    final granted = await ensureMicrophonePermission();
    if (!granted) {
      if (mounted) {
        _showMicPermissionSheet();
      }
      return;
    }
    await _ensureUnitSelected();
    final unit = ref.read(selectedUnitProvider);
    if (unit == null) return;

    final status = ref.read(recordingStatusProvider);
    if (status.isRecording) {
      _hydrateFromStatus(status);
      return;
    }

    final recorder = ref.read(recordingServiceProvider);
    final path = await recorder.startRecording();

    ref.read(contentVisibilityProvider.notifier).markContentStarted();
    await ref
        .read(userPrefsProvider.notifier)
        .setHasRecordedSession(true);

    _startTimer();
    _startAmplitudeStream();

    setState(() {
      isRecording = true;
      _isPaused = false;
      audioPath = path;
      seconds = 0;
    });

    ref.read(recordingStatusProvider.notifier).start(
          unitId: unit.id,
          unitTitle: unit.title,
          audioPath: path,
        );
  }

  Future<void> _endRecording({bool exit = true}) async {
    final unit = ref.read(selectedUnitProvider);
    if (unit == null) return;

    _timer?.cancel();

    final recorder = ref.read(recordingServiceProvider);
    final stoppedPath = await recorder.stopRecording();
    _stopAmplitudeStream();
    final resolvedPath = (stoppedPath != null && stoppedPath.isNotEmpty)
        ? stoppedPath
        : audioPath;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording was captured.')),
        );
      }
      ref.read(recordingStatusProvider.notifier).stop();
      return;
    }

    ref.read(recordingStatusProvider.notifier).stop();

    if (exit && mounted) {
      Navigator.pop(context);
    }

    Future.microtask(() {
      ref.read(sessionControllerProvider.notifier)
          .uploadRecordingAndRefresh(
        audioPath: resolvedPath,
        eventId: unit.id,
        recordedAt: DateTime.now(),
      );
    });
  }

  Future<void> _togglePause() async {
    if (!isRecording) return;
    final recorder = ref.read(recordingServiceProvider);
    if (_isPaused) {
      await recorder.resumeRecording();
      _startTimer();
      ref.read(recordingStatusProvider.notifier).resume();
    } else {
      await recorder.pauseRecording();
      _timer?.cancel();
      ref.read(recordingStatusProvider.notifier).pause();
      if (mounted) {
        setState(() => _level = 0);
      }
    }
    setState(() => _isPaused = !_isPaused);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => seconds++),
    );
  }

  void _startAmplitudeStream() {
    _ampSub?.cancel();
    final recorder = ref.read(recordingServiceProvider);
    _ampSub = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      final current = amp.current;
      final level = ((current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) {
        setState(() => _level = level);
      }
    });
  }

  void _stopAmplitudeStream() {
    _ampSub?.cancel();
    _ampSub = null;
    if (mounted) {
      setState(() => _level = 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _hydrateFromStatus(RecordingStatus status) {
    final units = ref.read(unitsProvider);
    final matches = units.where((u) => u.id == status.unitId).toList();
    if (matches.isNotEmpty) {
      ref.read(selectedUnitProvider.notifier).state = matches.first;
    }
    setState(() {
      isRecording = status.isRecording;
      _isPaused = status.isPaused;
      audioPath = status.audioPath;
      seconds = status.currentElapsedSeconds();
    });
    if (isRecording && !_isPaused) {
      _startTimer();
      _startAmplitudeStream();
    }
  }

  void _handleClose() {
    if (!isRecording) {
      Navigator.of(context).pop();
      return;
    }
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stop recording?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This will stop the current recording and exit.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _endRecording(exit: true);
                },
                child: const Text('Stop & Exit'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep Recording'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(selectedUnitProvider);
    final title = unit?.title ?? 'Select a course';
    final timeLabel =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _handleClose,
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('Minimize'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? 'LIVE CAPTURE' : 'READY TO CAPTURE',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isRecording
                    ? 'Recording academic content...'
                    : 'Press record to begin.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 30),
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  final phase = _waveController.value * 2 * 3.1415;
                  final activity = isRecording
                      ? (0.15 + (_level * 0.85))
                      : 0.05;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 80,
                      child: CustomPaint(
                        painter: _WavePainter(
                          phase: phase,
                          activity: activity,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _SensitivityBar(
                active: isRecording,
                level: _level,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      if (isRecording) {
                        showDeleteConfirm(
                          context: context,
                          title: 'Change course?',
                          message:
                              'We will stop this recording and start a new one.',
                          onConfirm: () async {
                            await _endRecording(exit: false);
                            await _ensureUnitSelected(forcePrompt: true);
                            final unit =
                                ref.read(selectedUnitProvider);
                            if (unit != null) {
                              await _startRecordingForUnit();
                            }
                          },
                        );
                      } else {
                        await _ensureUnitSelected(forcePrompt: true);
                        final unit = ref.read(selectedUnitProvider);
                        if (unit != null) {
                          await _startRecordingForUnit();
                        }
                      }
                    },
                    child: const Text('Change course'),
                  ),
                  _ControlButton(
                    icon: _isPaused ? Icons.play_arrow : Icons.pause,
                    filled: false,
                    enabled: isRecording,
                    onPressed: _togglePause,
                  ),
                  const SizedBox(width: 18),
                  _ControlButton(
                    icon: isRecording ? Icons.stop : Icons.mic,
                    filled: true,
                    enabled: true,
                    onPressed: isRecording
                        ? () => _endRecording(exit: true)
                        : _startRecordingForUnit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMicPermissionSheet() {
    AppModal.show(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Microphone access needed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enable microphone access in system settings to start recording.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final granted = await ensureMicrophonePermission();
                  if (!mounted) return;
                  if (granted && !isRecording) {
                    await _startRecordingForUnit();
                  } else if (!granted) {
                    _showMicPermissionSheet();
                  }
                },
                child: const Text('Try Again'),
              ),
            ),
            const SizedBox(height: 8),
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
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.surface;
    final fg = filled ? Colors.white : AppColors.text;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: filled ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.line),
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: fg),
      ),
    );
  }
}

class _SensitivityBar extends StatelessWidget {
  final bool active;
  final double level;

  const _SensitivityBar({
    required this.active,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final pct = active ? (level * 100).clamp(0, 100) : 0;
    return Column(
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.02, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'INPUT SENSITIVITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.subtext,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              '${pct.round()}% ACTIVE',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.subtext,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  final double activity;
  final Color color;

  const _WavePainter({
    required this.phase,
    required this.activity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.5;
    final amp = 6 + activity * 18;
    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final progress = x / size.width;
      final y = baseY +
          amp * MathUtils.fastSin(progress * 6.0 * 3.1415 + phase);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.activity != activity ||
        oldDelegate.color != color;
  }
}

class MathUtils {
  static double fastSin(double x) {
    return math.sin(x);
  }
}

