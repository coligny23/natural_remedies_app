import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Off by default to keep web/Chrome flow working.
/// Turn on in Settings to try the TFLite path (currently delegates to stub).
final useTfliteProvider = StateProvider<bool>((_) => false);
