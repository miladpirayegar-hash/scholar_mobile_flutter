import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api/api_providers.dart';

final exploreSessionCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.fetchSessionCount();
});
