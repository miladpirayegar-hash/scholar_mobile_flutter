import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_prefs_provider.dart';

class ContentVisibilityController extends StateNotifier<bool> {
  ContentVisibilityController(this.ref) : super(true) {
    state = ref.read(userPrefsProvider).hideContent;
    ref.listen<UserPrefs>(userPrefsProvider, (prev, next) {
      if (state != next.hideContent) state = next.hideContent;
    });
  }

  final Ref ref;

  Future<void> markContentStarted() async {
    if (!state) return;
    state = false;
    await ref.read(userPrefsProvider.notifier).setHideContent(false);
  }

  Future<void> resetToEmpty() async {
    state = true;
    await ref.read(userPrefsProvider.notifier).setHideContent(true);
  }
}

final contentVisibilityProvider =
    StateNotifierProvider<ContentVisibilityController, bool>(
  (ref) => ContentVisibilityController(ref),
);
