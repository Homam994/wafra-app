// ════════════════════════════════════════════════════════════
//  SMS Models — نماذج بيانات نظام ربط رسائل البنوك
// ════════════════════════════════════════════════════════════

// ── نمط عنصر مُعلَّم داخل الرسالة ────────────────────────
enum SmsFieldType {
  amount,          // المبلغ
  description,     // اسم التاجر / الوصف
  expenseKeyword,  // كلمة تدل على مصروف (خصم، سحب، شراء...)
  incomeKeyword,   // كلمة تدل على دخل (إيداع، واردة، راتب...)
  ignore,          // جزء يُتجاهل (رصيد، رقم حساب...)
}

extension SmsFieldTypeX on SmsFieldType {
  String get label {
    switch (this) {
      case SmsFieldType.amount:         return 'المبلغ';
      case SmsFieldType.description:    return 'اسم التاجر / الوصف';
      case SmsFieldType.expenseKeyword: return 'كلمة مصروف';
      case SmsFieldType.incomeKeyword:  return 'كلمة دخل';
      case SmsFieldType.ignore:         return 'تجاهل';
    }
  }

  String get emoji {
    switch (this) {
      case SmsFieldType.amount:         return '💰';
      case SmsFieldType.description:    return '🏪';
      case SmsFieldType.expenseKeyword: return '📤';
      case SmsFieldType.incomeKeyword:  return '📥';
      case SmsFieldType.ignore:         return '🚫';
    }
  }

  // اللون في واجهة التظليل
  int get colorValue {
    switch (this) {
      case SmsFieldType.amount:         return 0xFF2196F3; // أزرق
      case SmsFieldType.description:    return 0xFF9C27B0; // بنفسجي
      case SmsFieldType.expenseKeyword: return 0xFFE05C5C; // أحمر
      case SmsFieldType.incomeKeyword:  return 0xFF4CAF82; // أخضر
      case SmsFieldType.ignore:         return 0xFF888888; // رمادي
    }
  }
}

// ── عنصر مُعلَّم: نص + نوعه + موضعه في الرسالة ───────────
class TaggedSpan {
  final String text;
  final SmsFieldType type;
  final int start; // index في النص الأصلي
  final int end;

  const TaggedSpan({
    required this.text,
    required this.type,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toMap() => {
    'text' : text,
    'type' : type.name,
    'start': start,
    'end'  : end,
  };

  factory TaggedSpan.fromMap(Map<String, dynamic> m) => TaggedSpan(
    text : m['text']  ?? '',
    type : SmsFieldType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => SmsFieldType.ignore,
    ),
    start: m['start'] ?? 0,
    end  : m['end']   ?? 0,
  );
}

// ── قالب بنك كامل ─────────────────────────────────────────
class SmsTemplate {
  final String id;
  final String bankName;       // اسم البنك (للعرض فقط)
  final String senderName;     // اسم/رقم المُرسِل كما يظهر في SMS
  final String sampleMessage;  // الرسالة النموذجية التي عُلِّم منها القالب
  final List<TaggedSpan> spans; // العناصر المُعلَّمة
  final bool isEnabled;
  final DateTime createdAt;

  const SmsTemplate({
    required this.id,
    required this.bankName,
    required this.senderName,
    required this.sampleMessage,
    required this.spans,
    this.isEnabled = true,
    required this.createdAt,
  });

  // ── كلمات مفتاحية مستخرجة من الـ spans ─────────────────
  List<String> get expenseKeywords => spans
      .where((s) => s.type == SmsFieldType.expenseKeyword)
      .map((s) => s.text.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  List<String> get incomeKeywords => spans
      .where((s) => s.type == SmsFieldType.incomeKeyword)
      .map((s) => s.text.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  // ── هل يوجد نمط للمبلغ والوصف؟ ─────────────────────────
  bool get hasAmount      => spans.any((s) => s.type == SmsFieldType.amount);
  bool get hasDescription => spans.any((s) => s.type == SmsFieldType.description);

  // ── التحقق من صلاحية القالب قبل الحفظ ──────────────────
  String? validate() {
    if (bankName.trim().isEmpty)   return 'أدخل اسم البنك';
    if (senderName.trim().isEmpty) return 'أدخل اسم/رقم المُرسِل';
    if (sampleMessage.trim().isEmpty) return 'الصق رسالة نموذجية';
    if (!hasAmount) return 'حدّد المبلغ في الرسالة';
    if (expenseKeywords.isEmpty && incomeKeywords.isEmpty)
      return 'حدّد كلمة مصروف أو كلمة دخل على الأقل';
    return null; // صالح ✓
  }

  SmsTemplate copyWith({
    String?         id,
    String?         bankName,
    String?         senderName,
    String?         sampleMessage,
    List<TaggedSpan>? spans,
    bool?           isEnabled,
  }) => SmsTemplate(
    id           : id           ?? this.id,
    bankName     : bankName     ?? this.bankName,
    senderName   : senderName   ?? this.senderName,
    sampleMessage: sampleMessage ?? this.sampleMessage,
    spans        : spans        ?? this.spans,
    isEnabled    : isEnabled    ?? this.isEnabled,
    createdAt    : createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id'           : id,
    'bankName'     : bankName,
    'senderName'   : senderName,
    'sampleMessage': sampleMessage,
    'spans'        : spans.map((s) => s.toMap()).toList(),
    'isEnabled'    : isEnabled,
    'createdAt'    : createdAt.toIso8601String(),
  };

  factory SmsTemplate.fromMap(Map<String, dynamic> m) => SmsTemplate(
    id           : m['id']            ?? '',
    bankName     : m['bankName']      ?? '',
    senderName   : m['senderName']    ?? '',
    sampleMessage: m['sampleMessage'] ?? '',
    spans        : (m['spans'] as List? ?? [])
        .map((s) => TaggedSpan.fromMap(Map<String, dynamic>.from(s)))
        .toList(),
    isEnabled    : m['isEnabled']     ?? true,
    createdAt    : DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ── نتيجة تحليل رسالة SMS واردة ───────────────────────────
class SmsParseResult {
  final bool isMatch;           // هل طابقت أحد القوالب؟
  final String? templateId;     // معرّف القالب المُطابِق
  final String? bankName;
  final double? amount;
  final String? description;    // اسم التاجر (قد يكون فارغاً)
  final String txType;          // 'expense' | 'income' | 'unknown'
  final String rawMessage;
  final DateTime receivedAt;

  const SmsParseResult({
    required this.isMatch,
    this.templateId,
    this.bankName,
    this.amount,
    this.description,
    required this.txType,
    required this.rawMessage,
    required this.receivedAt,
  });

  // هل التصنيف معروف (عبر قاموس التجار)؟
  bool get hasCategory => false; // سيُحدَّث بعد البحث في MerchantCache
}

// ── قاموس التجار المحلي ────────────────────────────────────
// key   = اسم التاجر (lowercase, normalized)
// value = categoryId من kExpenseCategories / kIncomeCategories
class MerchantCache {
  final Map<String, String> _data; // merchantKey → categoryId

  MerchantCache(this._data);

  MerchantCache.empty() : _data = {};

  // ── بحث بالاسم الكامل أو جزء منه ─────────────────────
  String? lookup(String merchantName) {
    if (merchantName.isEmpty) return null;
    final key = _normalize(merchantName);
    // مطابقة تامة أولاً
    if (_data.containsKey(key)) return _data[key];
    // مطابقة جزئية — إن كان الاسم يحتوي على مفتاح محفوظ
    for (final entry in _data.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  void set(String merchantName, String categoryId) {
    _data[_normalize(merchantName)] = categoryId;
  }

  void remove(String merchantName) {
    _data.remove(_normalize(merchantName));
  }

  Map<String, String> get all => Map.unmodifiable(_data);

  int get length => _data.length;

  // تطبيع الاسم: lowercase + إزالة مسافات زائدة
  static String _normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_data);

  factory MerchantCache.fromMap(Map<String, dynamic> m) =>
      MerchantCache(m.map((k, v) => MapEntry(k, v.toString())));
}

// ── تاجر بدون تصنيف (ينتظر تصنيف المستخدم) ───────────────
class UnclassifiedMerchant {
  final String name;          // اسم التاجر الأصلي
  final double lastAmount;    // آخر مبلغ معاملة
  final int    count;         // عدد مرات الظهور
  final String txType;        // 'expense' | 'income'
  final DateTime lastSeen;

  const UnclassifiedMerchant({
    required this.name,
    required this.lastAmount,
    required this.count,
    required this.txType,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
    'name'      : name,
    'lastAmount': lastAmount,
    'count'     : count,
    'txType'    : txType,
    'lastSeen'  : lastSeen.toIso8601String(),
  };

  factory UnclassifiedMerchant.fromMap(Map<String, dynamic> m) =>
      UnclassifiedMerchant(
        name       : m['name']       ?? '',
        lastAmount : (m['lastAmount'] ?? 0).toDouble(),
        count      : m['count']      ?? 1,
        txType     : m['txType']     ?? 'expense',
        lastSeen   : DateTime.tryParse(m['lastSeen'] ?? '') ?? DateTime.now(),
      );

  UnclassifiedMerchant incrementCount(double amount) =>
      UnclassifiedMerchant(
        name      : name,
        lastAmount: amount,
        count     : count + 1,
        txType    : txType,
        lastSeen  : DateTime.now(),
      );
}
