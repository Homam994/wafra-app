import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _fcm   = FirebaseMessaging.instance;

  static const _budgetChannelId    = 'wafra_budget';
  static const _budgetChannelName  = 'تنبيهات الميزانية';
  static const _generalChannelId   = 'wafra_general';
  static const _generalChannelName = 'إشعارات عامة';
  static const _prefKey            = 'notif_enabled';

  bool _initialized = false;
  bool _enabled     = true;
  bool get isEnabled => _enabled;

  // ── تهيئة ────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    // Android notification channels
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _budgetChannelId, _budgetChannelName,
        description: 'تنبيه عند اقتراب الميزانية أو تجاوزها',
        importance : Importance.high,
        playSound  : true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId, _generalChannelName,
        description: 'إشعارات تطبيق وفرة العامة',
        importance : Importance.defaultImportance,
      ),
    );

    // تهيئة flutter_local_notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) =>
          debugPrint('Notification tapped: ${r.payload}'),
    );

    // FCM permissions
    await _fcm.requestPermission(
        alert: true, badge: true, sound: true);

    // FCM handlers
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // التطبيق في المقدمة
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null && _enabled) {
        showGeneral(title: n.title ?? 'وفرة', body: n.body ?? '');
      }
    });

    // ضُغط على إشعار والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((msg) =>
        debugPrint('FCM opened from background: ${msg.data}'));

    // فتح التطبيق من إشعار وكان مغلقاً
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('FCM opened app from terminated: ${initial.data}');
    }

    debugPrint('✅ NotificationService initialized');
  }

  // ── FCM Token ─────────────────────────────────────────
  Future<String?> getFcmToken() => _fcm.getToken();

  // ── إشعار تجاوز/اقتراب الميزانية ────────────────────
  Future<void> showBudgetAlert({
    required String categoryLabel,
    required double spent,
    required double limit,
    required String currency,
    required bool   isOver,
  }) async {
    if (!_enabled) return;
    final pct   = (spent / limit * 100).round();
    final title = isOver
        ? '🚨 تجاوزت ميزانية $categoryLabel!'
        : '⚠️ تنبيه ميزانية $categoryLabel';
    final body  = isOver
        ? 'أنفقت ${spent.toStringAsFixed(0)} من أصل '
          '${limit.toStringAsFixed(0)} $currency'
        : '$pct٪ من الميزانية · ${spent.toStringAsFixed(0)} '
          'من ${limit.toStringAsFixed(0)} $currency';

    await _local.show(
      _budgetId(categoryLabel),
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _budgetChannelId, _budgetChannelName,
          importance      : Importance.high,
          priority        : Priority.high,
          color           : isOver
              ? const Color(0xFFE74C3C)
              : const Color(0xFFF39C12),
          styleInformation: BigTextStyleInformation(body),
          groupKey        : 'wafra_budget',
        ),
      ),
      payload: jsonEncode({'type': 'budget', 'cat': categoryLabel}),
    );
  }

  // ── إشعار عام ─────────────────────────────────────────
  Future<void> showGeneral({
    required String title,
    required String body,
  }) async {
    if (!_enabled) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title, body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId, _generalChannelName,
          importance: Importance.defaultImportance,
          priority  : Priority.defaultPriority,
        ),
      ),
    );
  }

  // ── تفعيل / تعطيل ─────────────────────────────────────
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v);
    if (!v) await _local.cancelAll();
  }

  Future<void> cancelBudgetAlert(String categoryLabel) =>
      _local.cancel(_budgetId(categoryLabel));

  // ID ثابت لكل تصنيف — يمنع تكرار الإشعار لنفس التصنيف
  int _budgetId(String label) => label.hashCode.abs() % 10000;
}
