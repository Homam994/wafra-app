// ════════════════════════════════════════════════════════════
//  SmsProvider — إدارة نظام ربط رسائل البنوك كاملاً
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/sms_models.dart';
import '../data/models/models.dart';
import '../data/services/sms_storage_service.dart';
import '../data/services/sms_parser.dart';
import '../data/services/notification_service.dart';
import '../data/repositories/firestore_repo.dart';

class SmsProvider extends ChangeNotifier {
  final SmsStorageService _storage;
  final SmsParser         _parser;
  final FirestoreRepo     _repo;

  SmsProvider(this._storage, this._parser, this._repo);

  // ── الحالة ──────────────────────────────────────────────
  List<SmsTemplate>        _templates      = [];
  MerchantCache            _merchants      = MerchantCache.empty();
  List<UnclassifiedMerchant> _unclassified = [];
  bool                     _smsEnabled     = false;
  bool                     _loading        = false;
  String?                  _currentUid;

  // callback لإشعار HomeScreen بمعاملة جديدة
  Function(String, bool)? onAlert;

  // ── MethodChannel للتواصل مع Kotlin ──────────────────────
  static const _channel = MethodChannel('com.wafra.wafra/sms');

  // ── Getters ──────────────────────────────────────────────
  List<SmsTemplate>          get templates      => List.unmodifiable(_templates);
  MerchantCache              get merchants      => _merchants;
  List<UnclassifiedMerchant> get unclassified   => List.unmodifiable(_unclassified);
  bool                       get smsEnabled     => _smsEnabled;
  bool                       get isLoading      => _loading;
  int                        get unclassifiedCount => _unclassified.length;

  // ══════════════════════════════════════
  //  تهيئة — يُستدعى عند تسجيل الدخول
  // ══════════════════════════════════════
  Future<void> init(String uid) async {
    _currentUid = uid;
    _loading    = true;
    notifyListeners();

    _templates     = await _storage.loadTemplates();
    _merchants     = await _storage.loadMerchants();
    _unclassified  = await _storage.loadUnclassified();
    _smsEnabled    = await _storage.isSmsEnabled();

    _loading = false;
    notifyListeners();

    // ابدأ الاستماع لرسائل SMS القادمة من Kotlin
    if (_smsEnabled) _startListening();
  }

  Future<void> clear() async {
    _currentUid   = null;
    _templates    = [];
    _merchants    = MerchantCache.empty();
    _unclassified = [];
    _smsEnabled   = false;
    _stopListening();
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  الاستماع لـ SMS من Kotlin
  // ══════════════════════════════════════
  void _startListening() {
    // استخدام setMethodCallHandler مع ضمان إرجاع النتيجة لـ Kotlin
    // بعد اكتمال المعالجة الكاملة (await) — هذا يُمكّن الإرسال المتسلسل
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final sender     = args['sender']    as String? ?? '';
        final message    = args['message']   as String? ?? '';
        final timestamp  = args['timestamp'] as int?;
        final receivedAt = timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();
        // await يضمن انتهاء الحفظ في Firestore قبل إعادة النتيجة لـ Kotlin
        await _processSms(sender: sender, message: message, receivedAt: receivedAt);
        return null; // → يُطلق result.success(null) في Kotlin → flushNext يكمل
      }
    });
    _flushPending();
  }

  void _stopListening() {
    _channel.setMethodCallHandler(null);
  }

  // طلب صريح من Flutter لمعالجة الرسائل المعلّقة
  Future<void> _flushPending() async {
    try {
      await _channel.invokeMethod('flushPendingMessages');
    } catch (_) {}
  }

  // يُستدعى من AppLifecycleListener عند العودة للمقدمة
  Future<void> onAppResumed() async {
    if (_smsEnabled) await _flushPending();
  }


  // ══════════════════════════════════════
  //  معالجة رسالة SMS واردة
  // ══════════════════════════════════════
  Future<void> _processSms({
    required String sender,
    required String message,
    required DateTime receivedAt,
  }) async {
    if (_currentUid == null || _templates.isEmpty) return;

    // ١. حلّل الرسالة
    final result = _parser.parse(
      message  : message,
      sender   : sender,
      templates: _templates,
      receivedAt: receivedAt,
    );
    if (result == null) return;

    // ٢. ابحث عن التصنيف في قاموس التجار
    final desc     = result.description ?? '';
    final category = desc.isNotEmpty ? _merchants.lookup(desc) : null;

    // ٣. أنشئ المعاملة
    final today = receivedAt.toIso8601String().split('T').first;
    final tx = TxModel(
      id       : '',
      type     : result.txType == 'income' ? TxType.income : TxType.expense,
      cat      : category ?? _defaultCategory(result.txType),
      sub      : '',
      amount   : result.amount!,
      note     : desc.isNotEmpty ? desc : result.bankName ?? '',
      date     : today,
      createdAt: receivedAt,
      updatedAt: null,
    );

    // ٤. سجّل في Firestore تلقائياً
    try {
      await _repo.addTx(_currentUid!, tx);
    } catch (e) {
      debugPrint('SmsProvider: failed to save tx: $e');
      return;
    }

    // ٥. أشعر المستخدم (snackbar داخل التطبيق)
    final amountStr = result.amount!.toStringAsFixed(2);
    final typeStr   = result.txType == 'income' ? '📥 دخل' : '📤 مصروف';
    onAlert?.call(
      '$typeStr · $amountStr من ${result.bankName ?? sender}',
      false,
    );

    // ٥ب. إشعار فوري على الهاتف
    final notifTitle = result.txType == 'income'
        ? '📥 دخل مُسجَّل تلقائياً'
        : '📤 مصروف مُسجَّل تلقائياً';
    final bankLabel = result.bankName ?? sender;
    final descLabel = desc.isNotEmpty ? ' · $desc' : '';
    await NotificationService.instance.showGeneral(
      title: notifTitle,
      body : '$amountStr$descLabel — $bankLabel',
    );

    // ٦. إن لم يكن التاجر في القاموس → أضفه للقائمة غير المُصنَّفة
    if (category == null && desc.isNotEmpty) {
      final merchant = UnclassifiedMerchant(
        name      : desc,
        lastAmount: result.amount!,
        count     : 1,
        txType    : result.txType,
        lastSeen  : receivedAt,
      );
      await _storage.addUnclassified(merchant);
      _unclassified = await _storage.loadUnclassified();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════
  //  اختبار رسالة يدوياً (من واجهة الإعداد)
  // ══════════════════════════════════════
  Future<void> processManualSms({
    required String sender,
    required String message,
  }) async {
    await _processSms(
      sender    : sender,
      message   : message,
      receivedAt: DateTime.now(),
    );
  }

  // ══════════════════════════════════════
  //  إدارة القوالب
  // ══════════════════════════════════════
  Future<void> addTemplate(SmsTemplate t) async {
    await _storage.addTemplate(t);
    _templates = await _storage.loadTemplates();
    notifyListeners();
  }

  Future<void> updateTemplate(SmsTemplate t) async {
    await _storage.updateTemplate(t);
    _templates = await _storage.loadTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _storage.deleteTemplate(id);
    _templates = await _storage.loadTemplates();
    notifyListeners();
  }

  Future<void> toggleTemplate(String id) async {
    final idx = _templates.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final updated = _templates[idx].copyWith(
      isEnabled: !_templates[idx].isEnabled,
    );
    await updateTemplate(updated);
  }

  // ══════════════════════════════════════
  //  إدارة التجار
  // ══════════════════════════════════════

  // تصنيف تاجر غير مُصنَّف + حذفه من القائمة
  Future<void> classifyMerchant(String merchantName, String categoryId) async {
    await _storage.setMerchantCategory(merchantName, categoryId);
    await _storage.removeUnclassified(merchantName);
    _merchants    = await _storage.loadMerchants();
    _unclassified = await _storage.loadUnclassified();
    notifyListeners();
  }

  // تجاهل تاجر بدون تصنيف (حذفه من القائمة)
  Future<void> dismissMerchant(String merchantName) async {
    await _storage.removeUnclassified(merchantName);
    _unclassified = await _storage.loadUnclassified();
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  تفعيل / تعطيل الميزة
  // ══════════════════════════════════════
  Future<void> setSmsEnabled(bool v) async {
    _smsEnabled = v;
    await _storage.setSmsEnabled(v);
    if (v) {
      _startListening();
    } else {
      _stopListening();
    }
    notifyListeners();
  }

  // ══════════════════════════════════════
  //  طلب صلاحية SMS من النظام
  // ══════════════════════════════════════
  Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } catch (_) { return false; }
  }

  Future<bool> hasSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result ?? false;
    } catch (_) { return false; }
  }

  // ══════════════════════════════════════
  //  اختبار قالب
  // ══════════════════════════════════════
  Map<String, dynamic> testTemplate(SmsTemplate template, String message) {
    return _parser.testTemplate(template, message);
  }

  // ══════════════════════════════════════
  //  مساعدات
  // ══════════════════════════════════════
  String _defaultCategory(String txType) =>
      txType == 'income' ? 'other_income' : 'shopping';

  // توليد ID فريد للقالب
  String generateId() =>
      'tpl_${DateTime.now().millisecondsSinceEpoch}';
}
