import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// يُحدّث SharedPreferences التي يقرأها الـ Widget
/// ثم يُخبر Android بتحديث الـ Widget
class WidgetService {
  static const _ch = MethodChannel('com.wafra.wafra/widget');

  static Future<void> update({
    required double income,
    required double expense,
    required String currency,
    required String month,
  }) async {
    try {
      // 1. احفظ البيانات في SharedPreferences المشتركة مع الـ Widget
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('widget_income',  income);
      await prefs.setDouble('widget_expense', expense);
      await prefs.setString('widget_currency', currency);
      await prefs.setString('widget_month',   month);

      // 2. أخبر Android بتحديث الـ Widget
      await _ch.invokeMethod('updateWidget');
    } catch (_) {
      // الـ Widget غير مُضاف — تجاهل الخطأ
    }
  }
}
