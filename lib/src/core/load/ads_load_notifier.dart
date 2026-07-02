import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import '../config/ad_placement.dart';
import '../enums/ad_load_status.dart';
import '../events/ads_load_event.dart';
import '../results/ad_failure.dart';

/// Listener for placement load state changes.
typedef AdsLoadListener = void Function(AdsLoadEvent event);

/// Notifies app UI about ad load state changes.
class AdsLoadNotifier {
  AdsLoadNotifier._();

  /// Shared load notifier.
  static final AdsLoadNotifier instance = AdsLoadNotifier._();

  final List<AdsLoadListener> _listeners = [];

  // (2) Queue giữ đúng thứ tự event khi event đầu tiên phải đợi hết frame hiện tại.
  // Nếu không queue, event sau như `ready` có thể chạy trước `loading` đang bị
  // defer, làm UI bị trạng thái cũ ghi đè.
  final List<AdsLoadEvent> _pendingEvents = [];
  bool _flushScheduled = false;

  /// Adds a load listener.
  void addListener(AdsLoadListener listener) {
    _listeners.add(listener);
  }

  /// Removes a load listener.
  void removeListener(AdsLoadListener listener) {
    _listeners.remove(listener);
  }

  /// Notifies listeners about a placement load state change.
  void notify(
    AdPlacement placement,
    AdLoadStatus status, {
    AdFailure? failure,
  }) {
    final event = AdsLoadEvent(
      placement: placement,
      status: status,
      failure: failure,
    );
    if (_flushScheduled || _isInBuildFrame) {
      _pendingEvents.add(event);
      _scheduleFlush();
      return;
    }

    _notifyListeners(event);
  }

  bool get _isInBuildFrame {
    return SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
  }

  void _scheduleFlush() {
    if (_flushScheduled) {
      return;
    }

    _flushScheduled = true;
    //(1) Khi notify phát ra trong lúc Flutter đang build/layout/paint, listener UI
    // có thể gọi setState và gây lỗi "setState during build". Đẩy sang
    // post-frame để frame hiện tại hoàn tất trước khi UI nhận event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      final events = List<AdsLoadEvent>.of(_pendingEvents);
      _pendingEvents.clear();

      for (final event in events) {
        _notifyListeners(event);
      }
    });
  }

  void _notifyListeners(AdsLoadEvent event) {
    for (final listener in List.of(_listeners)) {
      listener(event);
    }
  }
}
