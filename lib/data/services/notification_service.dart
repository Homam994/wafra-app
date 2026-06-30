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
  static const _generalChannelId   = 'wafra_general';
  static const _weeklyChannelId    = 'wafra_weekly';
  static const _unusualChannelId   = 'wafra_unusual';
  static const _billsChannelId     = 'wafra_bills';
  static const _prefKey            = 'notif_enabled';
  static const _prefLastWeekly     = 'notif_last_weekly';

  bool _initialized = false;
  bool _enabled     = true;
  bool get isEnabled => _enabled;

  // ── Init ──────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    final lang = prefs.getString('language') ?? 'ar';
    final isAr = lang == 'ar';

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _budgetChannelId,
      isAr ? 'تنبيهات الميزانية' : 'Budget Alerts',
      description: isAr
          ? 'تنبيه عند اقتراب الميزانية أو تجاوزها'
          : 'Alert when budget is approaching or exceeded',
      importance: Importance.high, playSound: true,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _generalChannelId,
      isAr ? 'إشعارات عامة' : 'General Notifications',
      description: isAr ? 'إشعارات تطبيق وفرة العامة' : 'General Wafra app notifications',
      importance: Importance.defaultImportance,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _weeklyChannelId,
      isAr ? 'الملخص الأسبوعي' : 'Weekly Summary',
      description: isAr ? 'ملخص أسبوعي لإنفاقك' : 'Weekly spending summary',
      importance: Importance.defaultImportance,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _unusualChannelId,
      isAr ? 'تنبيه إنفاق غير معتاد' : 'Unusual Spending Alert',
      description: isAr
          ? 'تنبيه عند إنفاق غير معتاد في يوم واحد'
          : 'Alert when unusual spending detected in one day',
      importance: Importance.high, playSound: true,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _billsChannelId,
      isAr ? 'تنبيهات الفواتير' : 'Bill Alerts',
      description: isAr
          ? 'تذكير باستحقاق الفواتير والاشتراكات'
          : 'Reminder for upcoming bills and subscriptions',
      importance: Importance.high, playSound: true,
    ));

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) =>
          debugPrint('Notification tapped: ${r.payload}'),
    );

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null && _enabled) {
        showGeneral(title: n.title ?? 'Wafra', body: n.body ?? '');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) =>
        debugPrint('FCM opened from background: ${msg.data}'));

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      debugPrint('FCM opened app from terminated: ${initial.data}');
    }

    debugPrint('✅ NotificationService initialized');
  }

  // ── FCM Token ─────────────────────────────────────────
  Future<String?> getFcmToken() => _fcm.getToken();

  // ── Helper: read language from prefs ─────────────────
  Future<bool> _isAr() async {
    final p = await SharedPreferences.getInstance();
    return (p.getString('language') ?? 'ar') == 'ar';
  }

  // ── Budget Alert ──────────────────────────────────────
  Future<void> showBudgetAlert({
    required String categoryLabel,
    required double spent,
    required double limit,
    required String currency,
    required bool   isOver,
  }) async {
    if (!_enabled) return;
    final ar   = await _isAr();
    final pct  = (spent / limit * 100).round();

    final title = isOver
        ? (ar ? '🚨 تجاوزت ميزانية $categoryLabel!' : '🚨 Budget exceeded: $categoryLabel!')
        : (ar ? '⚠️ تنبيه ميزانية $categoryLabel'   : '⚠️ Budget alert: $categoryLabel');

    final body = isOver
        ? (ar
            ? 'أنفقت ${spent.toStringAsFixed(0)} من أصل ${limit.toStringAsFixed(0)} $currency'
            : 'Spent ${spent.toStringAsFixed(0)} of ${limit.toStringAsFixed(0)} $currency')
        : (ar
            ? '$pct٪ من الميزانية · ${spent.toStringAsFixed(0)} من ${limit.toStringAsFixed(0)} $currency'
            : '$pct% of budget · ${spent.toStringAsFixed(0)} of ${limit.toStringAsFixed(0)} $currency');

    final channelName = ar ? 'تنبيهات الميزانية' : 'Budget Alerts';

    await _local.show(
      _budgetId(categoryLabel),
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _budgetChannelId, channelName,
          importance      : Importance.high,
          priority        : Priority.high,
          color           : isOver ? const Color(0xFFE74C3C) : const Color(0xFFF39C12),
          styleInformation: BigTextStyleInformation(body),
          groupKey        : 'wafra_budget',
        ),
      ),
      payload: jsonEncode({'type': 'budget', 'cat': categoryLabel}),
    );
  }

  // ── General Notification ──────────────────────────────
  Future<void> showGeneral({
    required String title,
    required String body,
  }) async {
    if (!_enabled) return;
    final ar = await _isAr();
    final channelName = ar ? 'إشعارات عامة' : 'General Notifications';
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId, channelName,
          importance: Importance.defaultImportance,
          priority  : Priority.defaultPriority,
        ),
      ),
    );
  }

  // ── Weekly Summary ────────────────────────────────────
  Future<void> maybeShowWeeklySummary({
    required double weekExpense,
    required double weekIncome,
    required String currency,
    required int    txCount,
  }) async {
    if (!_enabled) return;
    final prefs    = await SharedPreferences.getInstance();
    final lastWeek = prefs.getString(_prefLastWeekly) ?? '';
    final now      = DateTime.now();
    if (now.weekday != DateTime.friday) return;
    final thisWeekKey = '${now.year}-W${_weekNumber(now)}';
    if (lastWeek == thisWeekKey) return;

    final ar    = (prefs.getString('language') ?? 'ar') == 'ar';
    final saved = weekIncome - weekExpense;

    final savedStr = ar
        ? (saved >= 0
            ? 'وفّرت ${saved.toStringAsFixed(0)} $currency 🎉'
            : 'تجاوزت دخلك بـ ${saved.abs().toStringAsFixed(0)} $currency')
        : (saved >= 0
            ? 'Saved ${saved.toStringAsFixed(0)} $currency 🎉'
            : 'Exceeded income by ${saved.abs().toStringAsFixed(0)} $currency');

    final title = ar ? '📊 ملخص أسبوعك' : '📊 Your Weekly Summary';
    final body  = ar
        ? 'أنفقت ${weekExpense.toStringAsFixed(0)} $currency في $txCount معاملة · $savedStr'
        : 'Spent ${weekExpense.toStringAsFixed(0)} $currency in $txCount transactions · $savedStr';

    final bigText = ar
        ? 'مداخيل الأسبوع: ${weekIncome.toStringAsFixed(0)} $currency\n'
          'مصاريف الأسبوع: ${weekExpense.toStringAsFixed(0)} $currency\n'
          'عدد المعاملات: $txCount\n$savedStr'
        : 'Week income: ${weekIncome.toStringAsFixed(0)} $currency\n'
          'Week expenses: ${weekExpense.toStringAsFixed(0)} $currency\n'
          'Transactions: $txCount\n$savedStr';

    final channelName = ar ? 'الملخص الأسبوعي' : 'Weekly Summary';

    await _local.show(
      9001,
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklyChannelId, channelName,
          importance      : Importance.defaultImportance,
          priority        : Priority.defaultPriority,
          color           : const Color(0xFFD4AF37),
          styleInformation: BigTextStyleInformation(bigText),
        ),
      ),
    );
    await prefs.setString(_prefLastWeekly, thisWeekKey);
  }

  // ── Unusual Spending Alert ────────────────────────────
  Future<void> showUnusualSpending({
    required double todayTotal,
    required double dailyAvg,
    required String currency,
  }) async {
    if (!_enabled) return;
    final ar = await _isAr();

    final title = ar
        ? '⚠️ إنفاق غير معتاد اليوم'
        : '⚠️ Unusual spending today';
    final body  = ar
        ? 'أنفقت ${todayTotal.toStringAsFixed(0)} $currency — '
          'ضعف متوسطك اليومي (${dailyAvg.toStringAsFixed(0)} $currency)'
        : 'Spent ${todayTotal.toStringAsFixed(0)} $currency — '
          'double your daily average (${dailyAvg.toStringAsFixed(0)} $currency)';
    final bigText = ar
        ? 'متوسطك اليومي المعتاد: ${dailyAvg.toStringAsFixed(0)} $currency\n'
          'إنفاقك اليوم: ${todayTotal.toStringAsFixed(0)} $currency'
        : 'Your usual daily average: ${dailyAvg.toStringAsFixed(0)} $currency\n'
          'Today\'s spending: ${todayTotal.toStringAsFixed(0)} $currency';

    final channelName = ar ? 'تنبيه إنفاق غير معتاد' : 'Unusual Spending Alert';

    await _local.show(
      9002,
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _unusualChannelId, channelName,
          importance      : Importance.high,
          priority        : Priority.high,
          color           : const Color(0xFFF39C12),
          styleInformation: BigTextStyleInformation(bigText),
        ),
      ),
    );
  }

  // ── Bill Due Alert ────────────────────────────────────
  Future<void> showBillDue({
    required String billName,
    required double amount,
    required String currency,
    required int    daysLeft,
  }) async {
    if (!_enabled) return;
    final ar = await _isAr();

    final title = daysLeft < 0
        ? (ar ? '🔴 فاتورة متأخرة!'                      : '🔴 Overdue bill!')
        : daysLeft == 0
            ? (ar ? '🟡 فاتورة مستحقة اليوم'             : '🟡 Bill due today')
            : (ar ? '🔔 فاتورة قادمة خلال $daysLeft أيام' : '🔔 Bill due in $daysLeft days');

    final body = '$billName — ${amount.toStringAsFixed(0)} $currency';
    final id   = billName.hashCode.abs() % 9000 + 1000;
    final channelName = ar ? 'تنبيهات الفواتير' : 'Bill Alerts';

    await _local.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _billsChannelId, channelName,
          importance: Importance.high,
          priority  : Priority.high,
          color     : daysLeft < 0
              ? const Color(0xFFE74C3C)
              : const Color(0xFFF39C12),
        ),
      ),
    );
  }

  // ── Enable / Disable ──────────────────────────────────
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v);
    if (!v) await _local.cancelAll();
  }

  Future<void> cancelBudgetAlert(String categoryLabel) =>
      _local.cancel(_budgetId(categoryLabel));

  int _budgetId(String label) => label.hashCode.abs() % 10000;

  int _weekNumber(DateTime d) {
    final startOfYear = DateTime(d.year, 1, 1);
    return ((d.difference(startOfYear).inDays) / 7).ceil();
  }
}
