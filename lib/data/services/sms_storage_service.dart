// ════════════════════════════════════════════════════════════
//  SmsStorageService — تخزين القوالب وقاموس التجار محلياً
//  كل البيانات تبقى على الجهاز — لا شيء يُرفع للسيرفر
// ════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_models.dart';

class SmsStorageService {
  static const _kTemplates     = 'wafra_sms_templates';
  static const _kMerchants     = 'wafra_sms_merchants';
  static const _kUnclassified  = 'wafra_sms_unclassified';
  static const _kSmsEnabled    = 'wafra_sms_enabled';

  // ══════════════════════════════════════
  //  القوالب
  // ══════════════════════════════════════

  Future<List<SmsTemplate>> loadTemplates() async {
    final p    = await SharedPreferences.getInstance();
    final raw  = p.getString(_kTemplates);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SmsTemplate.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) { return []; }
  }

  Future<void> saveTemplates(List<SmsTemplate> templates) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kTemplates,
      jsonEncode(templates.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> addTemplate(SmsTemplate t) async {
    final list = await loadTemplates();
    // إن كان موجوداً بنفس الـ id → استبدله
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx >= 0) list[idx] = t;
    else          list.add(t);
    await saveTemplates(list);
  }

  Future<void> updateTemplate(SmsTemplate t) => addTemplate(t);

  Future<void> deleteTemplate(String id) async {
    final list = await loadTemplates();
    list.removeWhere((t) => t.id == id);
    await saveTemplates(list);
  }

  // ══════════════════════════════════════
  //  قاموس التجار  merchantName → categoryId
  // ══════════════════════════════════════

  Future<MerchantCache> loadMerchants() async {
    final p   = await SharedPreferences.getInstance();
    final raw = p.getString(_kMerchants);
    if (raw == null) return MerchantCache.empty();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MerchantCache.fromMap(map);
    } catch (_) { return MerchantCache.empty(); }
  }

  Future<void> saveMerchants(MerchantCache cache) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMerchants, jsonEncode(cache.toMap()));
  }

  Future<void> setMerchantCategory(String name, String categoryId) async {
    final cache = await loadMerchants();
    cache.set(name, categoryId);
    await saveMerchants(cache);
  }

  // ══════════════════════════════════════
  //  التجار غير المُصنَّفين
  // ══════════════════════════════════════

  Future<List<UnclassifiedMerchant>> loadUnclassified() async {
    final p   = await SharedPreferences.getInstance();
    final raw = p.getString(_kUnclassified);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => UnclassifiedMerchant.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) { return []; }
  }

  Future<void> saveUnclassified(List<UnclassifiedMerchant> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kUnclassified,
      jsonEncode(list.map((u) => u.toMap()).toList()),
    );
  }

  // إضافة أو تحديث تاجر غير مُصنَّف
  Future<void> addUnclassified(UnclassifiedMerchant merchant) async {
    final list = await loadUnclassified();
    final idx  = list.indexWhere(
      (u) => u.name.toLowerCase() == merchant.name.toLowerCase(),
    );
    if (idx >= 0) {
      // زِد العداد
      list[idx] = list[idx].incrementCount(merchant.lastAmount);
    } else {
      list.add(merchant);
    }
    await saveUnclassified(list);
  }

  // حذف تاجر بعد تصنيفه
  Future<void> removeUnclassified(String name) async {
    final list = await loadUnclassified();
    list.removeWhere((u) => u.name.toLowerCase() == name.toLowerCase());
    await saveUnclassified(list);
  }

  Future<int> unclassifiedCount() async {
    return (await loadUnclassified()).length;
  }

  // ══════════════════════════════════════
  //  تفعيل / تعطيل الميزة كاملاً
  // ══════════════════════════════════════

  Future<bool> isSmsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSmsEnabled) ?? false;
  }

  Future<void> setSmsEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmsEnabled, v);
  }

  // ══════════════════════════════════════
  //  مسح كل البيانات (للتطوير/الاختبار)
  // ══════════════════════════════════════
  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTemplates);
    await p.remove(_kMerchants);
    await p.remove(_kUnclassified);
    await p.remove(_kSmsEnabled);
  }
}
