// ════════════════════════════════════════════════════════════
//  SmsTemplatesScreen — قائمة قوالب البنوك المُضافة
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/sms_provider.dart';
import '../../../data/models/sms_models.dart';
import '../../widgets/common/wa_card.dart';
import 'sms_template_editor.dart';
import 'unclassified_merchants_screen.dart';

class SmsTemplatesScreen extends StatelessWidget {
  const SmsTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sms = context.watch<SmsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط رسائل البنوك'),
        actions: [
          // زر التجار غير المُصنَّفين مع badge
          if (sms.unclassifiedCount > 0)
            Stack(children: [
              IconButton(
                icon: const Icon(Icons.store_outlined),
                tooltip: 'تجار بدون تصنيف',
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const UnclassifiedMerchantsScreen())),
              ),
              Positioned(
                top: 6, left: 6,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                    color: WaColors.danger, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${sms.unclassifiedCount}',
                      style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                  ),
                ),
              ),
            ]),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── تفعيل/تعطيل الميزة ───────────────────────
          WaCard(child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('تفعيل ربط الرسائل',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 3),
                Text('يُسجِّل المعاملات تلقائياً عند وصول رسالة من بنكك',
                  style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
              ],
            )),
            Switch.adaptive(
              value      : sms.smsEnabled,
              onChanged  : (v) => _toggleSms(context, sms, v),
              activeColor: WaColors.gold,
            ),
          ])).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 16),

          // ── قسم القوالب ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('قوالب البنوك',
                style: TextStyle(
                  fontSize: 11, letterSpacing: 1.5,
                  color: WaColors.textMuted)),
              TextButton.icon(
                onPressed: () => _openEditor(context),
                icon : const Icon(Icons.add, size: 16, color: WaColors.gold),
                label: const Text('إضافة قالب',
                  style: TextStyle(fontSize: 13, color: WaColors.gold)),
              ),
            ],
          ),

          if (sms.templates.isEmpty)
            _emptyState(context)
          else
            ...sms.templates.asMap().entries.map((e) =>
              _TemplateCard(
                template: e.value,
              ).animate().fadeIn(
                delay   : Duration(milliseconds: e.key * 60),
                duration: 300.ms,
              ),
            ),

          const SizedBox(height: 24),

          // ── إرشادات ───────────────────────────────────
          _HowItWorksCard(),

          const SizedBox(height: 80),
        ],
      ),
      // FAB إضافة قالب جديد
      floatingActionButton: FloatingActionButton.extended(
        onPressed    : () => _openEditor(context),
        backgroundColor: WaColors.gold,
        foregroundColor: WaColors.obsidian,
        icon         : const Icon(Icons.add),
        label        : const Text('قالب جديد',
          style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── تفعيل مع طلب الصلاحية ────────────────────────────────
  Future<void> _toggleSms(
      BuildContext context, SmsProvider sms, bool v) async {
    if (!v) { await sms.setSmsEnabled(false); return; }

    // تحقق من وجود قالب واحد على الأقل
    if (sms.templates.isEmpty) {
      _showSnack(context, 'أضف قالب بنك أولاً قبل التفعيل', isErr: true);
      return;
    }

    // اطلب الصلاحية
    final has = await sms.hasSmsPermission();
    if (!has) {
      final granted = await sms.requestSmsPermission();
      if (!granted && context.mounted) {
        _showPermissionDialog(context, sms);
        return;
      }
    }
    await sms.setSmsEnabled(true);
    if (context.mounted) _showSnack(context, '✅ تم تفعيل ربط الرسائل');
  }

  void _openEditor(BuildContext context, [SmsTemplate? template]) {
    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => SmsTemplateEditor(template: template)));
  }

  Widget _emptyState(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      const Text('📱', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('لم تُضف أي قالب بعد',
        style: TextStyle(fontSize: 14, color: WaColors.textMuted)),
      const SizedBox(height: 8),
      const Text(
        'اضغط "قالب جديد" وألصق رسالة من بنكك\nلتعليم التطبيق كيف يقرأها',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: WaColors.textMuted, height: 1.6),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed  : () => _openEditor(context),
        icon       : const Icon(Icons.add),
        label      : const Text('أضف أول قالب'),
        style      : ElevatedButton.styleFrom(
          backgroundColor: WaColors.gold,
          foregroundColor: WaColors.obsidian,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  void _showPermissionDialog(BuildContext context, SmsProvider sms) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title  : const Text('صلاحية قراءة الرسائل'),
      content: const Text(
        'التطبيق يحتاج صلاحية استقبال الرسائل لتسجيل المعاملات تلقائياً.\n\n'
        'لن تُرفع أي رسالة للإنترنت — كل المعالجة تتم على جهازك.',
        style: TextStyle(height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child    : const Text('لاحقاً')),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await sms.requestSmsPermission();
          },
          child: const Text('منح الصلاحية',
            style: TextStyle(color: WaColors.gold)),
        ),
      ],
    ));
  }

  void _showSnack(BuildContext context, String msg, {bool isErr = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isErr ? WaColors.danger : WaColors.success,
    ));
  }
}

// ══════════════════════════════════════════════════════════
//  بطاقة قالب واحد
// ══════════════════════════════════════════════════════════
class _TemplateCard extends StatelessWidget {
  final SmsTemplate template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final sms = context.read<SmsProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WaCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color        : WaColors.gold.withValues(alpha: 0.12),
                borderRadius : BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🏦', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.bankName,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('المُرسِل: ${template.senderName}',
                  style: const TextStyle(
                    fontSize: 12, color: WaColors.textMuted)),
              ],
            )),
            // تفعيل/تعطيل
            Switch.adaptive(
              value      : template.isEnabled,
              onChanged  : (_) => sms.toggleTemplate(template.id),
              activeColor: WaColors.gold,
            ),
          ]),
          const SizedBox(height: 10),
          // معلومات القالب
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (template.expenseKeywords.isNotEmpty)
              _chip('📤 ${template.expenseKeywords.take(2).join('، ')}',
                WaColors.danger),
            if (template.incomeKeywords.isNotEmpty)
              _chip('📥 ${template.incomeKeywords.take(2).join('، ')}',
                WaColors.success),
            if (template.hasDescription)
              _chip('🏪 اسم التاجر', WaColors.info),
          ]),
          const SizedBox(height: 10),
          // أزرار التعديل والحذف
          Row(children: [
            _actionBtn(context, Icons.edit_outlined, 'تعديل', WaColors.gold,
              () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => SmsTemplateEditor(template: template)))),
            const SizedBox(width: 8),
            _actionBtn(context, Icons.delete_outline, 'حذف', WaColors.danger,
              () => _confirmDelete(context, sms)),
          ]),
        ],
      )),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color       : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _actionBtn(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) =>
    InkWell(
      onTap       : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color       : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border      : Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ),
    );

  Future<void> _confirmDelete(BuildContext context, SmsProvider sms) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : const Text('حذف القالب'),
        content: Text('سيتوقف التطبيق عن معالجة رسائل ${template.bankName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await sms.deleteTemplate(template.id);
  }
}

// ══════════════════════════════════════════════════════════
//  بطاقة "كيف يعمل"
// ══════════════════════════════════════════════════════════
class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('كيف يعمل؟',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      ...[
        ('١', 'أضف قالباً لكل بنك تستخدمه'),
        ('٢', 'الصق رسالة حقيقية وعلّم التطبيق أجزاءها'),
        ('٣', 'فعّل الميزة — ستُسجَّل المعاملات تلقائياً'),
        ('٤', 'صنّف التجار الجدد مرة واحدة فقط'),
      ].map((step) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color       : WaColors.gold.withValues(alpha: 0.15),
              shape       : BoxShape.circle,
            ),
            child: Center(child: Text(step.$1,
              style: const TextStyle(fontSize: 10, color: WaColors.gold,
                fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(step.$2,
            style: const TextStyle(fontSize: 12, color: WaColors.textSecondary))),
        ]),
      )),
      const SizedBox(height: 6),
      const Divider(height: 1, color: WaColors.border),
      const SizedBox(height: 8),
      const Row(children: [
        Icon(Icons.lock_outline, size: 14, color: WaColors.success),
        SizedBox(width: 6),
        Expanded(child: Text(
          'كل المعالجة تتم على جهازك — لا رسائل تُرفع للإنترنت',
          style: TextStyle(fontSize: 11, color: WaColors.success),
        )),
      ]),
    ]),
  );
}
