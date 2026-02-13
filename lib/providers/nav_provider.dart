import 'package:flutter_riverpod/flutter_riverpod.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);
final tasksModeProvider = StateProvider<String>((ref) => 'tasks');
