import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';

final selectedUnitProvider = StateProvider<Unit?>(
  (ref) => null,
);
