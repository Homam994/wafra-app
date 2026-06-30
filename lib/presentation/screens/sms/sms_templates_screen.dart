import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/sms_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../data/models/sms_models.dart';
import '../../widgets/common/wa_card.dart';
import 'sms_template_editor.dart';
import 'unclassified_merchants_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class SmsTemplatesScreen extends StatelessWidget {
  const SmsTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sms  = context.watch<SmsProvider>();
    final isAr = context.watch<AppProvider>().locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'ربط رسائل البنوك' : 'Bank SMS Link'),
        actions: [
          if (sms.unclassifiedCount > 0)
            Stack(children: [
              IconButton(
                icon: const Icon(Icons.store_outlined),
                tooltip: isAr ? 'تجار بدون تصنيف' : 'Unclassified merchants',
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
                  child: Center(child: Text('${sms.unclassifiedCount}',
                    style: const TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ]),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Toggle ──
          WaCard(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'تفعيل ربط الرسائل' : 'Enable SMS Link',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                isAr
                  ? 'يُسجِّل المعاملات تلقائياً عند وصول رسالة من بنكك'
                  : 'Auto-records transactions when a bank SMS arrives',
                style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
            ])),
            Switch.adaptive(
              value: sms.smsEnabled,
              onChanged: (v) => _toggleSms(context, sms, v, isAr),
              activeColor: WaColors.gold,
            ),
          ])).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 16),

          // ── Templates header ──
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isAr ? 'قوالب البنوك' : 'Bank Templates',
              style: const TextStyle(fontSize: 11, letterSpacing: 1.5,
                color: WaColors.textMuted)),
            TextButton.icon(
              onPressed: () => _openEditor(context),
              icon : const Icon(Icons.add, size: 16, color: WaColors.gold),
              label: Text(isAr ? 'إضافة قالب' : 'Add Template',
                style: const TextStyle(fontSize: 13, color: WaColors.gold)),
            ),
          ]),

          if (sms.templates.isEmpty)
            _EmptyState(isAr: isAr, onAdd: () => _openEditor(context))
          else
            ...sms.templates.asMap().entries.map((e) =>
              _TemplateCard(template: e.value, isAr: isAr)
                .animate().fadeIn(
                  delay: Duration(milliseconds: e.key * 60),
                  duration: 300.ms)),

          const SizedBox(height: 24),
          _HowItWorksCard(isAr: isAr),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: WaColors.gold,
        foregroundColor: WaColors.obsidian,
        icon : const Icon(Icons.add),
        label: Text(isAr ? 'قالب جديد' : 'New Template',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _toggleSms(BuildContext context, SmsProvider sms, bool v, bool isAr) async {
    if (!v) { await sms.setSmsEnabled(false); return; }
    if (sms.templates.isEmpty) {
      _snack(context,
        isAr ? 'أضف قالب بنك أولاً قبل التفعيل' : 'Add a bank template first',
        isErr: true);
      return;
    }
    final has = await sms.hasSmsPermission();
    if (!has) {
      final granted = await sms.requestSmsPermission();
      if (!granted && context.mounted) {
        _showPermissionDialog(context, sms, isAr);
        return;
      }
    }
    await sms.setSmsEnabled(true);
    if (context.mounted)
      _snack(context, isAr ? '✅ تم تفعيل ربط الرسائل' : '✅ SMS link enabled');
  }

  void _openEditor(BuildContext context, [SmsTemplate? template]) =>
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => SmsTemplateEditor(template: template)));

  void _showPermissionDialog(BuildContext context, SmsProvider sms, bool isAr) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(isAr ? 'صلاحية قراءة الرسائل' : 'SMS Permission'),
      content: Text(
        isAr
          ? 'التطبيق يحتاج صلاحية استقبال الرسائل لتسجيل المعاملات تلقائياً.\n\nلن تُرفع أي رسالة للإنترنت — كل المعالجة تتم على جهازك.'
          : 'The app needs SMS permission to auto-record transactions.\n\nNo messages are uploaded — all processing is done on your device.',
        style: const TextStyle(height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isAr ? 'لاحقاً' : 'Later')),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await sms.requestSmsPermission();
          },
          child: Text(isAr ? 'منح الصلاحية' : 'Grant Permission',
            style: const TextStyle(color: WaColors.gold))),
      ],
    ));
  }

  void _snack(BuildContext ctx, String msg, {bool isErr = false}) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isErr ? WaColors.danger : WaColors.success,
    ));
}

// ── Empty State ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isAr;
  final VoidCallback onAdd;
  const _EmptyState({required this.isAr, required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      const Text('📱', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(isAr ? 'لم تُضف أي قالب بعد' : 'No templates added yet',
        style: const TextStyle(fontSize: 14, color: WaColors.textMuted)),
      const SizedBox(height: 8),
      Text(
        isAr
          ? 'اضغط "قالب جديد" وألصق رسالة من بنكك\nلتعليم التطبيق كيف يقرأها'
          : 'Tap "New Template" and paste a bank SMS\nto teach the app how to read it',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: WaColors.textMuted, height: 1.6),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon : const Icon(Icons.add),
        label: Text(isAr ? 'أضف أول قالب' : 'Add First Template'),
        style: ElevatedButton.styleFrom(
          backgroundColor: WaColors.gold,
          foregroundColor: WaColors.obsidian,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

// ── Template Card ─────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final SmsTemplate template;
  final bool isAr;
  const _TemplateCard({required this.template, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final sms = context.read<SmsProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: WaColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('🏦', style: TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(template.bankName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${isAr ? 'المُرسِل' : 'Sender'}: ${template.senderName}',
              style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
          ])),
          Switch.adaptive(
            value: template.isEnabled,
            onChanged: (_) => sms.toggleTemplate(template.id),
            activeColor: WaColors.gold,
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (template.expenseKeywords.isNotEmpty)
            _chip('📤 ${template.expenseKeywords.take(2).join(isAr ? '، ' : ', ')}', WaColors.danger),
          if (template.incomeKeywords.isNotEmpty)
            _chip('📥 ${template.incomeKeywords.take(2).join(isAr ? '، ' : ', ')}', WaColors.success),
          if (template.hasDescription)
            _chip(isAr ? '🏪 اسم التاجر' : '🏪 Merchant name', WaColors.info),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _actionBtn(context, Icons.edit_outlined, isAr ? 'تعديل' : 'Edit',
            WaColors.gold, () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => SmsTemplateEditor(template: template)))),
          const SizedBox(width: 8),
          _actionBtn(context, Icons.delete_outline, isAr ? 'حذف' : 'Delete',
            WaColors.danger, () => _confirmDelete(context, sms)),
        ]),
      ])),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6)),
    child: Text(label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _actionBtn(BuildContext ctx, IconData icon, String label,
      Color color, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
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
        title: Text(isAr ? 'حذف القالب' : 'Delete Template'),
        content: Text(isAr
          ? 'سيتوقف التطبيق عن معالجة رسائل ${template.bankName}'
          : 'The app will stop processing ${template.bankName} messages'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: Text(isAr ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (ok == true) await sms.deleteTemplate(template.id);
  }
}

// ── How It Works Card ─────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  final bool isAr;
  const _HowItWorksCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final steps = isAr
      ? [
          ('١', 'أضف قالباً لكل بنك تستخدمه'),
          ('٢', 'الصق رسالة حقيقية وعلّم التطبيق أجزاءها'),
          ('٣', 'فعّل الميزة — ستُسجَّل المعاملات تلقائياً'),
          ('٤', 'صنّف التجار الجدد مرة واحدة فقط'),
        ]
      : [
          ('1', 'Add a template for each bank you use'),
          ('2', 'Paste a real SMS and mark its parts'),
          ('3', 'Enable the feature — transactions auto-record'),
          ('4', 'Classify new merchants just once'),
        ];

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isAr ? 'كيف يعمل؟' : 'How does it work?',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      ...steps.map((step) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: WaColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle),
            child: Center(child: Text(step.$1,
              style: const TextStyle(fontSize: 10, color: WaColors.gold,
                fontWeight: FontWeight.w700)))),
          const SizedBox(width: 8),
          Expanded(child: Text(step.$2,
            style: const TextStyle(fontSize: 12, color: WaColors.textSecondary))),
        ]),
      )),
      const SizedBox(height: 6),
      const Divider(height: 1, color: WaColors.border),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.lock_outline, size: 14, color: WaColors.success),
        const SizedBox(width: 6),
        Expanded(child: Text(
          isAr
            ? 'كل المعالجة تتم على جهازك — لا رسائل تُرفع للإنترنت'
            : 'All processing is on-device — no messages are uploaded',
          style: const TextStyle(fontSize: 11, color: WaColors.success))),
      ]),
    ]));
  }
}
