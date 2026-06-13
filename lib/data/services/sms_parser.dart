// ════════════════════════════════════════════════════════════
//  SmsParser v2 — محرك تحليل رسائل SMS
//
//  النهج الجديد:
//  بدلاً من بناء regex من السياق الحرفي (هش)،
//  نستخدم موضع العنصر في الرسالة النموذجية لبناء
//  نمط مرن يتعامل مع أي قيمة في نفس الموضع
// ════════════════════════════════════════════════════════════
import 'package:collection/collection.dart';
import '../models/sms_models.dart';

class SmsParser {

  // ══════════════════════════════════════
  //  المدخل الرئيسي
  // ══════════════════════════════════════
  SmsParseResult? parse({
    required String message,
    required String sender,
    required List<SmsTemplate> templates,
    required DateTime receivedAt,
  }) {
    final template = _findTemplate(sender, templates);
    if (template == null) return null;

    if (_isOtpOrVerification(message)) return null;

    final txType = _detectType(message, template);
    if (txType == 'unknown') return null;

    final amount = _extractAmount(message, template);
    if (amount == null || amount <= 0) return null;

    final description = _extractDescription(message, template);

    return SmsParseResult(
      isMatch    : true,
      templateId : template.id,
      bankName   : template.bankName,
      amount     : amount,
      description: description,
      txType     : txType,
      rawMessage : message,
      receivedAt : receivedAt,
    );
  }

  // ══════════════════════════════════════
  //  مطابقة القالب بالمُرسِل
  // ══════════════════════════════════════
  SmsTemplate? _findTemplate(String sender, List<SmsTemplate> templates) {
    final senderNorm = sender.trim().toLowerCase();
    for (final t in templates) {
      if (!t.isEnabled) continue;
      final tNorm = t.senderName.trim().toLowerCase();
      if (senderNorm == tNorm ||
          senderNorm.contains(tNorm) ||
          tNorm.contains(senderNorm)) {
        return t;
      }
    }
    return null;
  }

  // ══════════════════════════════════════
  //  تحديد نوع العملية
  // ══════════════════════════════════════
  String _detectType(String message, SmsTemplate template) {
    // نطبّع الرسالة: lowercase + إزالة التشكيل
    final msgNorm = _normalize(message);

    for (final kw in template.expenseKeywords) {
      if (kw.isNotEmpty && msgNorm.contains(_normalize(kw))) return 'expense';
    }
    for (final kw in template.incomeKeywords) {
      if (kw.isNotEmpty && msgNorm.contains(_normalize(kw))) return 'income';
    }
    return 'unknown';
  }

  // ══════════════════════════════════════
  //  استخراج المبلغ — نهج متعدد الطبقات
  // ══════════════════════════════════════
  double? _extractAmount(String message, SmsTemplate template) {
    final amountSpan = template.spans
        .where((s) => s.type == SmsFieldType.amount)
        .firstOrNull;

    // طبقة ١: بناء regex من الـ anchor قبل المبلغ في القالب
    if (amountSpan != null) {
      final result = _extractByAnchor(
        message       : message,
        sample        : template.sampleMessage,
        span          : amountSpan,
        isNumeric     : true,
      );
      if (result != null) {
        final val = double.tryParse(result.replaceAll(',', ''));
        if (val != null && val > 0) return val;
      }
    }

    // طبقة ٢: أنماط شائعة للبنوك العربية
    return _extractAmountByPatterns(message);
  }

  // ══════════════════════════════════════
  //  استخراج الوصف — نفس النهج
  // ══════════════════════════════════════
  String? _extractDescription(String message, SmsTemplate template) {
    final descSpan = template.spans
        .where((s) => s.type == SmsFieldType.description)
        .firstOrNull;

    if (descSpan != null) {
      final result = _extractByAnchor(
        message  : message,
        sample   : template.sampleMessage,
        span     : descSpan,
        isNumeric: false,
      );
      if (result != null && result.trim().isNotEmpty) return result.trim();
    }

    // fallback: أنماط نصية شائعة
    return _extractDescByPatterns(message);
  }

  // ══════════════════════════════════════
  //  النواة: استخراج بالـ Anchor
  //
  //  الفكرة:
  //  ١. خذ النص الذي يسبق القيمة مباشرةً في الرسالة النموذجية
  //     (كل السطر قبلها أو آخر 25 حرف)
  //  ٢. ابحث عن نفس الـ anchor في الرسالة الجديدة
  //  ٣. خذ ما يأتي بعده مباشرةً كقيمة
  // ══════════════════════════════════════
  String? _extractByAnchor({
    required String message,
    required String sample,
    required TaggedSpan span,
    required bool isNumeric,
  }) {
    // ── بناء الـ anchor ──────────────────────────────────
    // خذ آخر سطر كامل قبل القيمة (أو آخر 30 حرف)
    final beforeRaw = sample.substring(0, span.start);
    final anchor    = _buildAnchor(beforeRaw);

    if (anchor.isEmpty) return null;

    // ── نمط القيمة ───────────────────────────────────────
    // رقمي: أي رقم (صحيح أو عشري، مع فواصل أو بدونها)
    // نصي:  أي نص حتى نهاية السطر أو علامة ترقيم
    final valuePattern = isNumeric
        ? r'([\d,]+(?:\.\d+)?)'   // رقم — صحيح أو عشري
        : r'([^\n\r]+)';          // نص — حتى نهاية السطر (greedy)

    // ── بناء الـ suffix (ما بعد القيمة في النموذج) ───────
    final afterRaw  = sample.substring(span.end);
    final suffix    = _buildSuffix(afterRaw);

    // ── بناء الـ regex النهائي ────────────────────────────
    // anchor + مسافات اختيارية + قيمة + (suffix اختياري)
    final escapedAnchor = RegExp.escape(anchor);
    final escapedSuffix = suffix.isNotEmpty ? RegExp.escape(suffix) : '';

    final patterns = <String>[
      // ١. anchor + قيمة + suffix (الأدق)
      if (escapedSuffix.isNotEmpty)
        '$escapedAnchor\\s*$valuePattern\\s*$escapedSuffix',
      // ٢. anchor + قيمة فقط (أكثر مرونة)
      '$escapedAnchor\\s*$valuePattern',
    ];

    for (final pat in patterns) {
      try {
        final regex = RegExp(pat, caseSensitive: false, multiLine: true);
        final match = regex.firstMatch(message);
        if (match != null && match.groupCount >= 1) {
          return match.group(1);
        }
      } catch (_) { continue; }
    }

    return null;
  }

  // ── بناء anchor: آخر "وحدة معنوية" قبل القيمة ──────────
  // مثال: "بـSR 83.45" → anchor = "بـSR"
  // مثال: "لـASWAQ ALMOHSIN\n" → anchor = "لـ"
  String _buildAnchor(String before) {
    if (before.isEmpty) return '';

    // أزِل المسافات من الطرف الأيمن
    final trimmed = before.trimRight();
    if (trimmed.isEmpty) return '';

    // إن كان قبل القيمة سطر كامل، خذ ما بعد آخر newline
    final lastNewline = trimmed.lastIndexOf('\n');
    final lastLine    = lastNewline >= 0
        ? trimmed.substring(lastNewline + 1).trim()
        : trimmed;

    if (lastLine.isEmpty) return '';

    // خذ آخر "رمز + نص" بحد أقصى 8 أحرف — كافٍ كـ anchor فريد
    // هذا يتعامل مع "بـSR" و "لـ" و "مبلغ" و "SR "
    if (lastLine.length <= 8) return lastLine;

    // خذ آخر 8 أحرف
    return lastLine.substring(lastLine.length - 8);
  }

  // ── بناء suffix: أول "وحدة معنوية" بعد القيمة ───────────
  // للنص: نعتمد على نهاية السطر طبيعياً (الـ [^\n\r]+ يتوقف عنده)
  // للأرقام: نأخذ أول رمز/كلمة قصيرة كحد فاصل
  String _buildSuffix(String after) {
    if (after.isEmpty) return '';
    final trimmed = after.trimLeft();
    if (trimmed.isEmpty) return '';
    // إن كان أول حرف newline → القيمة تنتهي بالسطر، لا suffix مطلوب
    if (trimmed.startsWith('\n') || trimmed.startsWith('\r')) return '';
    // خذ أول كلمة/رمز فقط بحد أقصى 5 أحرف
    final firstToken = trimmed.split(RegExp(r'[\s\n\r]')).first;
    if (firstToken.length <= 5 && firstToken.isNotEmpty) {
      return firstToken;
    }
    return '';
  }

  // ══════════════════════════════════════
  //  Fallback: أنماط مبالغ شائعة
  // ══════════════════════════════════════
  double? _extractAmountByPatterns(String message) {
    final patterns = [
      // بـSR 83.45 أو بـSR 83 أو SR83.45
      RegExp(r'بـ?SR\s*([\d,]+(?:\.\d+)?)',       caseSensitive: false),
      RegExp(r'SR\s*([\d,]+(?:\.\d+)?)',           caseSensitive: false),
      // مبلغ 250.00 أو مبلغ: 250
      RegExp(r'مبلغ\s*:?\s*([\d,]+(?:\.\d+)?)',   caseSensitive: false),
      // بـ 250.00 ريال أو 250 ريال
      RegExp(r'بـ?\s*([\d,]+(?:\.\d+)?)\s*ريال',  caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d+)?)\s*ريال',        caseSensitive: false),
      // AED/KWD/BHD/QAR/EGP/USD
      RegExp(r'(?:AED|KWD|BHD|QAR|EGP|USD)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d+)?)\s*(?:AED|KWD|BHD|QAR|EGP|USD)', caseSensitive: false),
      // رقم عشري واضح (الأخير دائماً — أقل دقة)
      RegExp(r'([\d,]+\.\d{2})'),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(message);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '') ?? '';
        final val = double.tryParse(raw);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  // ══════════════════════════════════════
  //  Fallback: أنماط وصف/تاجر شائعة
  // ══════════════════════════════════════
  String? _extractDescByPatterns(String message) {
    final patterns = [
      // لـXXX أو لـ XXX (نمط رسائل مدى/الراجحي)
      RegExp(r'لـ\s*([A-Za-z0-9\u0600-\u06FF][^\n\r]{1,40})',  caseSensitive: false),
      // لدى XXX
      RegExp(r'لدى\s*:?\s*([^\n\r,،]{2,40})',                  caseSensitive: false),
      // at XXX
      RegExp(r'\bat\s+([A-Za-z0-9][^\n\r,،]{1,40})',           caseSensitive: false),
      // MERCHANT: XXX
      RegExp(r'merchant\s*:?\s*([^\n\r,،]{2,40})',             caseSensitive: false),
      // التاجر: XXX
      RegExp(r'التاجر\s*:?\s*([^\n\r,،]{2,40})',               caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(message);
      if (match != null) {
        final val = match.group(1)?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
    }
    return null;
  }

  // ══════════════════════════════════════
  //  أداة: تطبيع النص للمقارنة
  //  إزالة التشكيل + lowercase
  // ══════════════════════════════════════
  String _normalize(String text) {
    // إزالة التشكيل العربي (حركات)
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .toLowerCase()
        .trim();
  }

  // ══════════════════════════════════════
  //  اختبار قالب (من واجهة المستخدم)
  //  يُعيد تفاصيل أكثر لمساعدة التشخيص
  // ══════════════════════════════════════
  Map<String, dynamic> testTemplate(SmsTemplate template, String testMessage) {
    // تحقق من النوع أولاً
    final txType = _detectType(testMessage, template);
    if (txType == 'unknown') {
      final expKws = template.expenseKeywords.join('، ');
      final incKws = template.incomeKeywords.join('، ');
      return {
        'success': false,
        'error'  : 'لم يُعثر على كلمات المصروف ($expKws) '
                   'أو الدخل ($incKws) في الرسالة',
      };
    }

    // استخراج المبلغ
    final amount = _extractAmount(testMessage, template);
    if (amount == null) {
      return {
        'success': false,
        'error'  : 'لم يُعثر على المبلغ — تأكد من تحديد المبلغ في القالب',
      };
    }

    // استخراج الوصف
    final description = _extractDescription(testMessage, template);

    return {
      'success'    : true,
      'type'       : txType,
      'amount'     : amount,
      'description': description,
    };
  }

  bool _isOtpOrVerification(String message) {
    final msgNorm = _normalize(message);

    const otpKeywords = [
      'رمز التحقق',
      'رمز المرور',
      'كلمة المرور',
      'رمز تحقق',
      'verification code',
      'otp',
      'one time',
      'one-time',
      'كود التحقق',
      'رمز الدخول',
      'رمز الأمان',
      'رمز لمرة',
      'do not share',
      'لا تشاركه',
      'لا تشارك',
      'صالح لمدة',
      'ينتهي خلال',
    ];

    for (final kw in otpKeywords) {
      if (msgNorm.contains(_normalize(kw))) return true;
    }

    final otpPatterns = [
      RegExp(r'^[\s\u200f]*\d{4,8}[\s\n]', multiLine: false),
      RegExp(r'رمز\s*[:\s]\s*\d{4,8}'),
      RegExp(r'code\s*[:\s]\s*\d{4,8}', caseSensitive: false),
    ];

    for (final p in otpPatterns) {
      if (p.hasMatch(message)) return true;
    }

    return false;
  }
}
