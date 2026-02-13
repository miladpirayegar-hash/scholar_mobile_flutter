import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api/api_providers.dart';
import 'auth_provider.dart';

class SyntraMessage {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const SyntraMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory SyntraMessage.fromJson(Map<String, dynamic> json) {
    return SyntraMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
    );
  }
}

class SyntraThread {
  final String id;
  final String title;
  final List<SyntraMessage> messages;
  final DateTime updatedAt;

  const SyntraThread({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  SyntraThread copyWith({
    String? title,
    List<SyntraMessage>? messages,
    DateTime? updatedAt,
  }) {
    return SyntraThread(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory SyntraThread.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'] as List<dynamic>? ?? const [];
    return SyntraThread(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New chat',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: raw
          .map((e) =>
              SyntraMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class SyntraChatState {
  final List<SyntraThread> threads;
  final String? currentThreadId;

  const SyntraChatState({
    required this.threads,
    required this.currentThreadId,
  });

  SyntraThread? get currentThread {
    if (currentThreadId == null) return null;
    return threads.firstWhere(
      (t) => t.id == currentThreadId,
      orElse: () => SyntraThread(
        id: '',
        title: '',
        messages: [],
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }
}

class SyntraChatController extends StateNotifier<SyntraChatState> {
  static const _storageKey = 'syntra_threads_v1';

  SyntraChatController(this.ref)
      : super(const SyntraChatState(threads: [], currentThreadId: null)) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId != next.userId) {
        _bind();
      }
    });
    _bind();
  }

  final Ref ref;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _threadsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSub;

  CollectionReference<Map<String, dynamic>> _threadsCol(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('syntra_threads');
  }

  DocumentReference<Map<String, dynamic>> _metaDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('syntra_chat');
  }

  void _bind() {
    _threadsSub?.cancel();
    _metaSub?.cancel();
    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      state = const SyntraChatState(threads: [], currentThreadId: null);
      return;
    }
    _threadsSub = _threadsCol(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snap) {
      final threads = [
        for (final doc in snap.docs)
          SyntraThread.fromJson({
            ...doc.data(),
            'id': doc.id,
          }),
      ].map((t) {
        final hasUser = t.messages.any((m) => m.isUser);
        if (hasUser) return t;
        return SyntraThread(
          id: t.id,
          title: 'New chat',
          messages: const [],
          updatedAt: t.updatedAt,
        );
      }).toList();
      final hasAnyMessages = threads.any((t) => t.messages.isNotEmpty);
      final current = state.currentThreadId;
      state = SyntraChatState(
        threads: threads,
        currentThreadId: !hasAnyMessages
            ? null
            : threads.isEmpty
                ? null
                : (threads.any((t) => t.id == current)
                    ? current
                    : threads.first.id),
      );
    });
    _metaSub = _metaDoc(uid).snapshots().listen((snap) {
      final data = snap.data();
      final current = data?['currentThreadId'] as String?;
      if (current == null) return;
      if (current == state.currentThreadId) return;
      state = SyntraChatState(
        threads: state.threads,
        currentThreadId: current,
      );
    });
    unawaited(_migrateFromPrefs(uid));
  }

  bool _isGreeting(String message) {
    final t = message.trim().toLowerCase();
    return t == 'hi' ||
        t == 'hello' ||
        t == 'hey' ||
        t == 'yo' ||
        t == 'sup' ||
        t.startsWith('hi ') ||
        t.startsWith('hello ') ||
        t.startsWith('hey ');
  }

  Future<void> _persistMeta() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    await _metaDoc(uid).set(
      {'currentThreadId': state.currentThreadId},
      SetOptions(merge: true),
    );
  }

  SyntraThread _ensureCurrentThread([String? seedTitle]) {
    if (state.currentThreadId != null) {
      final existing = state.currentThread;
      if (existing != null && existing.id.isNotEmpty) return existing;
    }

    final now = DateTime.now();
    final id = 'thread-${now.microsecondsSinceEpoch}';
    final title = seedTitle?.trim().isNotEmpty == true
        ? seedTitle!.trim()
        : 'New chat';
    final thread = SyntraThread(
      id: id,
      title: title,
      messages: const [],
      updatedAt: now,
    );

    state = SyntraChatState(
      threads: [thread, ...state.threads],
      currentThreadId: id,
    );
    _saveThread(thread);
    _persistMeta();
    return thread;
  }

  void newThread() {
    final now = DateTime.now();
    final id = 'thread-${now.microsecondsSinceEpoch}';
    final thread = SyntraThread(
      id: id,
      title: 'New chat',
      messages: const [],
      updatedAt: now,
    );

    state = SyntraChatState(
      threads: [thread, ...state.threads],
      currentThreadId: id,
    );
    _saveThread(thread);
    _persistMeta();
  }

  void selectThread(String id) {
    if (!state.threads.any((t) => t.id == id)) return;
    state = SyntraChatState(
      threads: state.threads,
      currentThreadId: id,
    );
    _persistMeta();
  }

  void renameThread(String id, String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    final threads = [...state.threads];
    final idx = threads.indexWhere((thread) => thread.id == id);
    if (idx == -1) return;
    threads[idx] = threads[idx].copyWith(
      title: t,
      updatedAt: DateTime.now(),
    );
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = SyntraChatState(
      threads: threads,
      currentThreadId: state.currentThreadId,
    );
    _saveThread(threads[idx]);
  }

  void deleteThread(String id) {
    final threads = state.threads.where((t) => t.id != id).toList();
    String? nextCurrent = state.currentThreadId;
    if (nextCurrent == id) {
      nextCurrent = threads.isEmpty ? null : threads.first.id;
    }
    state = SyntraChatState(
      threads: threads,
      currentThreadId: nextCurrent,
    );
    final uid = ref.read(authProvider).userId;
    if (uid != null) {
      _threadsCol(uid).doc(id).delete();
    }
    _persistMeta();
  }

  Future<void> clearAll() async {
    state = const SyntraChatState(
      threads: [],
      currentThreadId: null,
    );
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    final col = _threadsCol(uid);
    final snap = await col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    await _metaDoc(uid).delete();
  }

  Future<void> send({
    required String message,
    String? context,
    List<String> sessionIds = const [],
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;

    final thread = _ensureCurrentThread(text);
    final updatedTitle = thread.title == 'New chat'
        ? (text.length > 36 ? '${text.substring(0, 36)}...' : text)
        : thread.title;

    _replaceThread(
      thread.copyWith(
        title: updatedTitle,
        messages: [
          ...thread.messages,
          SyntraMessage(text: text, isUser: true),
          const SyntraMessage(text: '', isUser: false, isStreaming: true),
        ],
        updatedAt: DateTime.now(),
      ),
    );

    if (_isGreeting(text)) {
      _updateLastAssistant(_greetingResponse(context), streaming: false);
      return;
    }

    final apiMessage = _composeMessageWithContext(text, context);

    try {
      final api = ref.read(apiServiceProvider);
      final buffer = StringBuffer();
      await for (final chunk in api.syntraChatStream(
        message: apiMessage,
        sessionIds: sessionIds,
      )) {
        buffer.write(chunk);
        _updateLastAssistant(buffer.toString(), streaming: true);
      }
      _updateLastAssistant(buffer.toString(), streaming: false);
    } catch (_) {
      try {
        final api = ref.read(apiServiceProvider);
        final reply = await api.syntraChat(
          message: apiMessage,
          sessionIds: sessionIds,
        );
        _updateLastAssistant(reply, streaming: false);
      } catch (_) {
        _updateLastAssistant(
          'Sorry, Syntra ran into an issue. Please try again.',
          streaming: false,
        );
      }
    }
  }

  String _composeMessageWithContext(String message, String? context) {
    final policy = 'You are Syntra, an academic assistant. '
        'Focus on coursework, studying, exams, assignments, and the provided academic context. '
        'If the question is not academic or not related to the provided context, respond briefly and steer the user '
        'toward what you can help with (course materials, exams, assignments, study planning).';
    final noCourseNames = _isGreeting(message) &&
            (context == null || context.trim().isEmpty)
        ? 'Do not mention any specific course names or subjects. '
          'Respond with a general, friendly prompt for how you can help.'
        : '';
    if (context == null || context.trim().isEmpty) {
      return '''
$policy
$noCourseNames

User question:
$message
  '''.trim();
    }
    return '''
$policy
$noCourseNames

User tasks context:
$context

User question:
$message
'''.trim();
  }

  String _greetingResponse(String? context) {
    final hasContext = context != null && context.trim().isNotEmpty;
    if (hasContext) {
      return 'Hi! I can help summarize your course materials, explain concepts '
          'from your uploaded files, and answer questions about upcoming exams '
          'or assignments. What would you like to focus on?';
    }
    return 'Hi! I’m Syntra — your study copilot. I can summarize course '
        'materials, explain concepts, and help plan for exams and assignments. '
        'Tell me which course or topic you want help with.';
  }

  void _replaceThread(SyntraThread nextThread, {bool persist = true}) {
    final threads = [...state.threads];
    final idx = threads.indexWhere((t) => t.id == nextThread.id);
    if (idx == -1) return;
    threads[idx] = nextThread;
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = SyntraChatState(
      threads: threads,
      currentThreadId: state.currentThreadId,
    );
    if (persist) _saveThread(nextThread);
  }

  void _updateLastAssistant(String text, {required bool streaming}) {
    final thread = state.currentThread;
    if (thread == null || thread.id.isEmpty) return;
    if (thread.messages.isEmpty) return;

    final safeText =
        (!streaming && text.trim().isEmpty) ? _emptyResponse() : text;

    final idx = thread.messages.lastIndexWhere((m) => !m.isUser);
    if (idx == -1) return;

    final updated = SyntraMessage(
      text: safeText,
      isUser: false,
      isStreaming: streaming,
    );
    final messages = [...thread.messages];
    messages[idx] = updated;

    _replaceThread(
      thread.copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
      ),
      persist: !streaming,
    );
  }

  String _emptyResponse() {
    return 'I’m Syntra — I can summarize your course materials, explain '
        'concepts, and help you plan for exams and assignments. What do you '
        'want to work on?';
  }

  void _saveThread(SyntraThread thread) {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    _threadsCol(uid).doc(thread.id).set(thread.toJson());
  }

  Future<void> _migrateFromPrefs(String uid) async {
    final existing = await _threadsCol(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final threads = (decoded['threads'] as List<dynamic>? ?? const [])
          .map((e) =>
              SyntraThread.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final t in threads) {
        await _threadsCol(uid).doc(t.id).set(t.toJson());
      }
      final current = decoded['currentThreadId'] as String?;
      if (current != null) {
        await _metaDoc(uid).set(
          {'currentThreadId': current},
          SetOptions(merge: true),
        );
      }
      await prefs.remove(_storageKey);
    } catch (_) {
      // ignore corrupted storage
    }
  }
}

final syntraChatProvider =
    StateNotifierProvider<SyntraChatController, SyntraChatState>(
  (ref) => SyntraChatController(ref),
);
