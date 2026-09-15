import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/sms_storage_service.dart';
import '../../data/services/sms_parser.dart';
import '../../data/services/notification_service.dart';
import '../../data/repositories/firestore_repo.dart';
import '../../data/models/sms_models.dart';
import '../../data/models/models.dart';

const _headlessChannel = MethodChannel('com.wafra.wafra/sms_headless');

/// يُعالج طابور رسائل SMS المعلَّقة في محرّك Flutter منفصل بلا واجهة،
/// يُشغَّل من الجانب الأصلي (HeadlessSmsEngine.kt) عندما يكون التطبيق
/// مغلقاً تماماً — لتسجيل المعاملة فور وصول الرسالة دون فتح التطبيق.
///
/// ⚠️ ملاحظة مهمة: هذه الدالة تُكرّر عمداً جزءاً من منطق
/// SmsProvider._processSms، لأنها تعمل في isolate/engine منفصل تماماً
/// بلا شجرة Provider. أي تعديل مستقبلي على منطق التحليل أو التصنيف
/// في SmsProvider (مثل خطوات التحقق من OTP، أو منطق التصنيف الافتراضي)
/// يجب تكراره هنا يدوياً أيضاً حتى لا يختلف سلوك الحالتين.
Future<void> runHeadlessSmsProcessing() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // لا يوجد مستخدم مسجَّل دخول محلياً

    final rawPending = await _headlessChannel.invokeMethod<String>('getPending');
    if (rawPending == null || rawPending == '[]') return;

    final List<dynamic> pending = jsonDecode(rawPending);
    if (pending.isEmpty) return;

    final storage   = SmsStorageService();
    final templates = await storage.loadTemplates();
    if (templates.isEmpty) return; // لا قوالب مُعرَّفة بعد

    final merchants = await storage.loadMerchants();
    final parser    = SmsParser();
    final repo      = FirestoreRepo(FirebaseFirestore.instance);
    await NotificationService.instance.init();

    for (final item in pending) {
      final map     = Map<String, dynamic>.from(item as Map);
      final sender  = map['sender']  as String? ?? '';
      final message = map['message'] as String? ?? '';
      final ts      = map['timestamp'] as int?;
      final receivedAt = ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now();

      final result = parser.parse(
        message   : message,
        sender    : sender,
        templates : templates,
        receivedAt: receivedAt,
      );
      if (result == null) continue;

      final desc     = result.description ?? '';
      final category = desc.isNotEmpty ? merchants.lookup(desc)    : null;
      final subCat   = desc.isNotEmpty ? merchants.lookupSub(desc) : null;
      final today    = receivedAt.toIso8601String().split('T').first;

      final tx = TxModel(
        id       : '',
        type     : result.txType == 'income' ? TxType.income : TxType.expense,
        cat      : category ?? (result.txType == 'income' ? 'other_income' : 'shopping'),
        sub      : subCat ?? '',
        amount   : result.amount!,
        note     : desc.isNotEmpty ? desc : result.bankName ?? '',
        date     : today,
        createdAt: receivedAt,
        updatedAt: null,
      );

      // fire-and-forget: لا ننتظر تأكيد السيرفر حتى لا نتعطّل بلا إنترنت
      // (نفس إصلاح مشكلة انقطاع الاتصال في SmsProvider._processSms)
      repo.addTx(uid, tx).catchError((e) {
        debugPrint('Headless SMS: failed to save tx: $e');
      });

      final amountStr  = result.amount!.toStringAsFixed(2);
      final notifTitle = result.txType == 'income'
          ? '📥 دخل مُسجَّل تلقائياً' : '📤 مصروف مُسجَّل تلقائياً';
      final bankLabel  = result.bankName ?? sender;
      final descLabel  = desc.isNotEmpty ? ' · $desc' : '';
      await NotificationService.instance.showGeneral(
        title: notifTitle,
        body : '$amountStr$descLabel — $bankLabel',
      );

      if (category == null && desc.isNotEmpty) {
        await storage.addUnclassified(UnclassifiedMerchant(
          name      : desc,
          lastAmount: result.amount!,
          count     : 1,
          txType    : result.txType,
          lastSeen  : receivedAt,
        ));
      }
    }

    await _headlessChannel.invokeMethod('clearPending');
  } catch (e) {
    debugPrint('Headless SMS processing error: $e');
  } finally {
    // أخبر الجانب الأصلي أننا انتهينا حتى يُغلق المحرّك ويوفّر الذاكرة
    try { await _headlessChannel.invokeMethod('done'); } catch (_) {}
  }
}
