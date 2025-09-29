import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'progress_providers.dart';

/// Wrap your scrollable with this to auto-track read %.
/// Works with ListView / SingleChildScrollView / CustomScrollView, etc.
class ProgressTracker extends ConsumerStatefulWidget {
  final String articleId;
  final String? sectionId;
  final Widget child;

  const ProgressTracker({
    super.key,
    required this.articleId,
    required this.child,
    this.sectionId,
  });

  @override
  ConsumerState<ProgressTracker> createState() => _ProgressTrackerState();
}

class _ProgressTrackerState extends ConsumerState<ProgressTracker> {
  double _lastSent = -1.0;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // On open, record section and 0% (fire-and-forget).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressProvider.notifier).update(
            widget.articleId,
            lastSection: widget.sectionId,
            percent: 0.0,
          );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final max = n.metrics.maxScrollExtent;
    final px = n.metrics.pixels.clamp(0, math.max(1.0, max));
    final pct = (px / math.max(1.0, max)).clamp(0.0, 1.0);

    // Only send if:
    //  - changed by ≥5% OR
    //  - at least 1.5s since last send (prevents spam)
    final changed = (_lastSent < 0) || ( (pct - _lastSent).abs() >= 0.05 );
    final old = _lastAt;
    final now = DateTime.now();
    final timed = now.difference(old).inMilliseconds >= 1500;

    if (changed || timed) {
      _lastSent = pct;
      _lastAt = now;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        ref.read(progressProvider.notifier).update(
              widget.articleId,
              lastSection: widget.sectionId,
              percent: pct,
            );
      });
    }
    return false; // don’t stop the notification
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}
