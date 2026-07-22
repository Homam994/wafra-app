// ════════════════════════════════════════════════════════════
//  NavStackService — يحفظ مسار الشاشات الفرعية المفتوحة فوق
//  الشاشة الرئيسية (مثل: ربط رسائل البنوك، تعديل قالب...)
//  حتى تُعاد فتحها بنفس الترتيب إذا أعاد أندرويد تشغيل عملية
//  التطبيق بعد إغلاقها في الخلفية (مثلاً أثناء نسخ رسالة SMS
//  من تطبيق آخر ثم العودة).
// ════════════════════════════════════════════════════════════
import 'package:shared_preferences/shared_preferences.dart';

class NavStackService {
  static const _key = 'wafra_subnav_stack';

  /// يُستدعى فور دفع (push) شاشة فرعية جديدة
  static Future<void> push(String entry) async {
    final p     = await SharedPreferences.getInstance();
    final stack = p.getStringList(_key) ?? [];
    stack.add(entry);
    await p.setStringList(_key, stack);
  }

  /// يُستدعى عند إغلاق (pop) الشاشة الفرعية العلوية
  static Future<void> pop() async {
    final p     = await SharedPreferences.getInstance();
    final stack = p.getStringList(_key) ?? [];
    if (stack.isNotEmpty) {
      stack.removeLast();
      await p.setStringList(_key, stack);
    }
  }

  /// يُقرأ عند بدء التطبيق لمعرفة الشاشات التي يجب إعادة فتحها
  static Future<List<String>> restore() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? [];
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
