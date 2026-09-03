import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// A single in-app alert raised by the current user's device.
class LocalAlert {
  const LocalAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool read;

  LocalAlert copyWith({bool? read}) => LocalAlert(
    id: id,
    title: title,
    body: body,
    time: time,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'read': read,
  };

  factory LocalAlert.fromJson(Map<String, dynamic> json) => LocalAlert(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
    read: json['read'] as bool? ?? false,
  );
}

/// Device-level notification centre for VoltEZ.
///
/// Keeps a small local inbox (persisted to SharedPreferences) that powers the
/// unread badge on the notification bells and prepends recent alerts to the
/// server notification feed. Every raised alert also surfaces a floating
/// SnackBar through [scaffoldMessengerKey] so drivers/business owners get
/// immediate feedback for booking confirmations, session start/end and other
/// key moments — without needing Firebase credentials.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Global messenger key wired into [MaterialApp] so alerts can be shown
  /// from any screen (including provider code that has no BuildContext).
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const String _storageKey = 'voltez_local_alerts';
  static const int _maxAlerts = 50;

  final List<LocalAlert> _alerts = [];
  bool _loaded = false;
  Future<void>? _loadFuture;
  int _sequence = 0;

  /// Newest-first immutable snapshot of local alerts.
  List<LocalAlert> get alerts => List.unmodifiable(_alerts.reversed);

  int get unreadCount => _alerts.where((alert) => !alert.read).length;

  /// Hydrate persisted alerts once (safe to call repeatedly).
  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _alerts
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map(
                  (item) => LocalAlert.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(),
          );
      }
    } catch (_) {
      // Corrupt/absent store is non-fatal — start with an empty inbox.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Raise a local alert and (optionally) show a floating banner.
  Future<void> notify({
    required String title,
    required String body,
    bool showBanner = true,
  }) async {
    await ensureLoaded();
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}-${_sequence++}';
    _alerts.add(
      LocalAlert(id: id, title: title, body: body, time: now),
    );
    if (_alerts.length > _maxAlerts) {
      _alerts.removeRange(0, _alerts.length - _maxAlerts);
    }
    notifyListeners();
    _persist();

    if (showBanner) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AppColors.card,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary, width: 1),
              ),
              duration: const Duration(seconds: 5),
              content: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
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
  }

  Future<void> markAllRead() async {
    await ensureLoaded();
    if (unreadCount == 0) return;
    for (var i = 0; i < _alerts.length; i++) {
      if (!_alerts[i].read) {
        _alerts[i] = _alerts[i].copyWith(read: true);
      }
    }
    notifyListeners();
    _persist();
  }

  /// Called on sign-out so one account's alerts never leak to another.
  Future<void> clear() async {
    _alerts.clear();
    _loaded = true;
    notifyListeners();
    _persist();
  }

  void _persist() {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey,
          jsonEncode(_alerts.map((alert) => alert.toJson()).toList()),
        );
      } catch (_) {
        // Persistence is best-effort.
      }
    }());
  }
}
