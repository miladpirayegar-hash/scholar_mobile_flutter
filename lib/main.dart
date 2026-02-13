import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/upload_worker_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/academic_profile_provider.dart';
import 'providers/tasks_providers.dart';
import 'providers/user_prefs_provider.dart';

import 'screens/explore_screen.dart';
import 'screens/notebook_screen.dart';
import 'screens/tasks_tab_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/syntra_screen.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate_screen.dart';
import 'providers/recording_status_provider.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  try {
    await _initializeFirebase();
  } catch (e) {
    startupError = e.toString();
  }
  runApp(
    ProviderScope(
      child: startupError == null
          ? const ScholarApp()
          : StartupErrorApp(message: startupError),
    ),
  );
}

class StartupErrorApp extends StatelessWidget {
  final String message;

  const StartupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Startup configuration error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeFirebase() async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    return;
  }
  final options = _WebFirebaseConfig.fromEnvironment();
  if (options == null) {
    throw StateError(
      'Missing Firebase web config. Provide FIREBASE_WEB_* via --dart-define.',
    );
  }
  await Firebase.initializeApp(options: options);
}

class _WebFirebaseConfig {
  static const String _apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
  );
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const String _measurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
  );

  static FirebaseOptions? fromEnvironment() {
    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _messagingSenderId.isEmpty ||
        _projectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _authDomain.isEmpty ? null : _authDomain,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      measurementId: _measurementId.isEmpty ? null : _measurementId,
    );
  }
}

class ScholarApp extends ConsumerWidget {
  const ScholarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // STEP 8N.2 + 8N.3
    // Start upload worker at app boot
    ref.watch(uploadWorkerProvider);

    return MaterialApp(
      title: 'Scholar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) {
        final app = child ?? const SizedBox.shrink();
        if (!kIsWeb) return app;
        return _WebMobileFrame(child: app);
      },
      home: const AuthGateScreen(child: MainShell()),
    );
  }
}

class _WebMobileFrame extends StatelessWidget {
  final Widget child;

  const _WebMobileFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) return child;
        final height = constraints.maxHeight;
        final frameHeight = (height - 24).clamp(680.0, 920.0).toDouble();
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5F4F8),
                Color(0xFFE8E7ED),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 430,
              height: frameHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFD8D8DF), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 36,
                    spreadRadius: 2,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _tourRequested = false;
  bool _showStartHighlights = false;
  final _uploadKey = GlobalKey();
  final _recordFabKey = GlobalKey();

  void _onTap(int newIndex) {
    ref.read(navIndexProvider.notifier).state = newIndex;
  }

  void _onRecordPressed() {
    _dismissStartHighlights();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RecordingScreen(),
      ),
    );
  }

  void _maybeStartTour({
    required AuthState auth,
    required AcademicProfile profile,
  }) {
    if (_tourRequested) return;
    if (!auth.isSignedIn || !profile.isComplete) return;
    _tourRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final seen = ref.read(userPrefsProvider).didShowGetStarted;
      if (seen || !mounted) return;
      setState(() => _showStartHighlights = true);
    });
  }

  Future<void> _dismissStartHighlights() async {
    if (!_showStartHighlights) return;
    setState(() => _showStartHighlights = false);
    await ref
        .read(userPrefsProvider.notifier)
        .setDidShowGetStarted(true);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);
    final recordingStatus = ref.watch(recordingStatusProvider);
    final auth = ref.watch(authProvider);
    final profile = ref.watch(academicProfileProvider);
    final isProfileLocked = auth.isSignedIn && !profile.isComplete;
    ref.watch(tasksProvider);
    ref.watch(completedTasksProvider);
    _maybeStartTour(auth: auth, profile: profile);

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(navIndexProvider.notifier).state = 0;
      },
      child: Stack(
        children: [
          Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              [
                ExploreScreen(
                  uploadKey: _uploadKey,
                  showStartHighlights: _showStartHighlights && index == 0,
                  onUploadTap: () async {
                    await _dismissStartHighlights();
                  },
                ),
                NotebookScreen(),
                TasksTabScreen(),
                InsightsScreen(),
                SyntraScreen(),
              ][index],
              if (_showStartHighlights && index == 0)
                _StartHighlightOverlay(
                  uploadKey: _uploadKey,
                  recordKey: _recordFabKey,
                  onClose: _dismissStartHighlights,
                ),
              if (recordingStatus.isRecording)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: SafeArea(
                    bottom: false,
                    child: _RecordingBanner(
                      status: recordingStatus,
                      onTap: _onRecordPressed,
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: index == 4
              ? null
              : IgnorePointer(
                  ignoring: isProfileLocked,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isProfileLocked ? 0.5 : 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        boxShadow: _showStartHighlights && index == 0
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 22,
                                  spreadRadius: 4,
                                ),
                              ]
                            : const [],
                      ),
                      child: KeyedSubtree(
                        key: _recordFabKey,
                        child: _RecordingFab(
                          onTap: _onRecordPressed,
                        ),
                      ),
                    ),
                  ),
                ),
          bottomNavigationBar: Container(
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.line, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'EXPLORE',
                      active: index == 0,
                      onTap: () => _onTap(0),
                      enabled: !isProfileLocked,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book,
                      label: 'NOTEBOOK',
                      active: index == 1,
                      onTap: () => _onTap(1),
                      enabled: !isProfileLocked,
                    ),
                  ),

                  Expanded(
                    child: _NavItem(
                      icon: Icons.check_box_outlined,
                      activeIcon: Icons.check_box,
                      label: 'TASKS',
                      active: index == 2,
                      onTap: () => _onTap(2),
                      enabled: !isProfileLocked,
                    ),
                  ),

                  Expanded(
                    child: _NavItem(
                      icon: Icons.lightbulb_outline,
                      activeIcon: Icons.lightbulb,
                      label: 'INSIGHTS',
                      active: index == 3,
                      onTap: () => _onTap(3),
                      enabled: !isProfileLocked,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.auto_awesome_outlined,
                      activeIcon: Icons.auto_awesome,
                      label: 'SYNTRA',
                      active: index == 4,
                      onTap: () => _onTap(4),
                      enabled: !isProfileLocked,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          if (isProfileLocked) ...[
            Positioned.fill(
              child: AbsorbPointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: _ProfileGate(
                  profile: profile,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingFab extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordingFab({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: AppColors.primary,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 3),
        ),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.mic,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  final RecordingStatus status;
  final VoidCallback onTap;

  const _RecordingBanner({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = status.unitTitle?.isNotEmpty == true
        ? status.unitTitle!
        : 'Recording in progress';
    final label = status.isPaused ? 'Paused' : 'Recording';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: status.isPaused ? AppColors.warning : AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGate extends ConsumerWidget {
  final AcademicProfile profile;

  const _ProfileGate({
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxHeight;
              final formMaxHeight =
                  (available - 220).clamp(240.0, 520.0);
              return Center(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete your academic profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please fill this out to unlock the app.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: formMaxHeight,
                        child: SingleChildScrollView(
                          child: AcademicProfileForm(
                            initial: profile,
                            submitLabel: 'Save & Continue',
                            onSave: (next) {
                              ref
                                  .read(academicProfileProvider.notifier)
                                  .updateProfile(next);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : (enabled ? AppColors.text : AppColors.subtext);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? activeIcon : icon,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class _StartHighlightOverlay extends StatelessWidget {
  final GlobalKey uploadKey;
  final GlobalKey recordKey;
  final VoidCallback onClose;

  const _StartHighlightOverlay({
    required this.uploadKey,
    required this.recordKey,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
            child: ClipPath(
              clipper: _SpotlightClipper(
                targets: [
                  _TargetRect.fromKey(uploadKey),
                  _TargetRect.fromKey(recordKey),
                ],
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 18),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'Get started: upload a course outline so we can auto-extract highlights, exams, and assignments - or tap the mic to record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.subtext,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetRect {
  final Rect? rect;

  const _TargetRect(this.rect);

  factory _TargetRect.fromKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return const _TargetRect(null);
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return const _TargetRect(null);
    final offset = box.localToGlobal(Offset.zero);
    return _TargetRect(offset & box.size);
  }
}

class _SpotlightClipper extends CustomClipper<Path> {
  final List<_TargetRect> targets;

  const _SpotlightClipper({
    required this.targets,
  });

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    for (final target in targets) {
      final rect = target.rect;
      if (rect == null) continue;
      final isMic = rect.width >= 50 && rect.width <= 72 && rect.height >= 50;
      if (isMic) {
        path.addOval(
          Rect.fromCircle(
            center: rect.center,
            radius: rect.width * 0.6,
          ),
        );
      } else {
        path.addRRect(
          RRect.fromRectAndRadius(rect.inflate(12), const Radius.circular(18)),
        );
      }
    }
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant _SpotlightClipper oldDelegate) {
    return oldDelegate.targets != targets;
  }
}



