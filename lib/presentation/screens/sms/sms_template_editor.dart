import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sms_models.dart';
import '../../../providers/sms_provider.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../../../generated/l10n/app_localizations.dart';

class SmsTemplateEditor extends StatefulWidget {
  final SmsTemplate? template;
  const SmsTemplateEditor({super.key, this.template});
  @override State<SmsTemplateEditor> createState() => _SmsTemplateEditorState();
}

class _SmsTemplateEditorState extends State<SmsTemplateEditor> {
  final _bankCtrl   = TextEditingController();
  final _senderCtrl = TextEditingController();
  final _msgCtrl    = TextEditingController();
  final _testCtrl   = TextEditingController();

  List<TaggedSpan>      _spans      = [];
  int                   _step       = 0;
  bool                  _saving     = false;
  Map<String, dynamic>? _testResult;
  SmsFieldType          _selectedType = SmsFieldType.amount;

  bool get _isAr => context.read<AppProvider>().locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      final t = widget.template!;
      _bankCtrl.text   = t.bankName;
      _senderCtrl.text = t.senderName;
      _msgCtrl.text    = t.sampleMessage;
      _spans           = List.from(t.spans);
    }
  }

  @override
  void dispose() {
    _bankCtrl.dispose(); _senderCtrl.dispose();
    _msgCtrl.dispose();  _testCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null
            ? (isAr ? 'قالب جديد' : 'New Template')
            : (isAr ? 'تعديل القالب' : 'Edit Template')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepIndicator(step: _step),
        ),
      ),
      body: IndexedStack(
        index: _step,
        children: [_buildStep0(), _buildStep1(), _buildStep2()],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  // ── Step 0: Bank Info ────────────────────────────────
  Widget _buildStep0() {
    final isAr = _isAr;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon : '🏦',
          title: isAr ? 'معلومات البنك' : 'Bank Info',
          sub  : isAr
              ? 'أدخل اسم البنك والمُرسِل كما يظهر في رسائل SMS'
              : 'Enter the bank name and sender as shown in SMS messages',
        ),
        const SizedBox(height: 20),
        WaCard(child: Column(children: [
          _field(_bankCtrl,
            isAr ? 'اسم البنك'          : 'Bank Name',
            isAr ? 'مثال: البنك الأهلي، الراجحي...' : 'e.g. National Bank, Al Rajhi...',
            Icons.account_balance_outlined),
          const Divider(height: 1, color: WaColors.border),
          _field(_senderCtrl,
            isAr ? 'اسم/رقم المُرسِل'  : 'Sender Name/Number',
            isAr ? 'مثال: ALAHLI، 1900، BankSMS...' : 'e.g. ALAHLI, 1900, BankSMS...',
            Icons.phone_outlined),
        ])),
        const SizedBox(height: 16),
        WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isAr ? 'الصق رسالة نموذجية من البنك' : 'Paste a sample bank SMS',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            isAr
                ? 'ستُستخدم لتعليم التطبيق كيف يقرأ رسائل هذا البنك'
                : 'Used to teach the app how to read this bank\'s messages',
            style: const TextStyle(fontSize: 11, color: WaColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller : _msgCtrl,
            maxLines   : 6,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            decoration : InputDecoration(
              hintText : isAr
                  ? 'الصق الرسالة هنا...\n\nمثال:\nتم الخصم من حسابك مبلغ 250.00 ريال\nلدى مطعم الباشا'
                  : 'Paste the message here...\n\nExample:\nYour account was debited 250.00 SAR\nat Al-Basha Restaurant',
              hintStyle    : const TextStyle(fontSize: 12, color: WaColors.textMuted),
              border       : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.goldDim)),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: WaColors.gold),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText : hint,
              hintStyle: const TextStyle(fontSize: 12, color: WaColors.textMuted),
              isDense  : true,
              border       : OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: WaColors.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide  : const BorderSide(color: WaColors.goldDim)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ])),
      ]),
    );

  // ── Step 1: Interactive Tagging ──────────────────────
  Widget _buildStep1() {
    final isAr = _isAr;
    return Column(children: [
      _TypeToolbar(selected: _selectedType, onSelect: (t) => setState(() => _selectedType = t)),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          isAr
              ? 'ظلّل جزءاً من الرسالة بإصبعك ثم اختر نوعه من الأزرار أعلاه'
              : 'Select part of the message with your finger then choose its type above',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: WaColors.textMuted)),
      ),
      const SizedBox(height: 12),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TaggedMessageView(
            message: _msgCtrl.text, spans: _spans, onTag: _handleTag),
          if (_spans.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: WaColors.border),
            const SizedBox(height: 8),
            Text(
              isAr ? 'العناصر المُعلَّمة:' : 'Tagged elements:',
              style: const TextStyle(fontSize: 11, color: WaColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: _spans.map((s) => _SpanChip(
                span: s,
                onDelete: () => setState(() =>
                    _spans.removeWhere((x) => x.start == s.start && x.end == s.end)),
              )).toList(),
            ),
          ],
        ])),
      )),
    ]);
  }

  void _handleTag(int start, int end) {
    final text = _msgCtrl.text.substring(start, end).trim();
    if (text.isEmpty) return;
    setState(() {
      _spans.removeWhere((s) => !(s.end <= start || s.start >= end));
      _spans.add(TaggedSpan(text: text, type: _selectedType, start: start, end: end));
      _spans.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  // ── Step 2: Test ─────────────────────────────────────
  Widget _buildStep2() {
    final isAr = _isAr;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepHeader(
          icon : '🧪',
          title: isAr ? 'اختبر القالب' : 'Test the Template',
          sub  : isAr
              ? 'الصق رسالة أخرى من نفس البنك للتأكد من صحة القالب'
              : 'Paste another message from the same bank to verify the template',
        ),
        const SizedBox(height: 16),
        WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isAr ? 'رسالة اختبار' : 'Test Message',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _testCtrl, maxLines: 5,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            decoration: InputDecoration(
              hintText : isAr
                  ? 'الصق رسالة مختلفة من نفس البنك...'
                  : 'Paste a different message from the same bank...',
              hintStyle: const TextStyle(fontSize: 12, color: WaColors.textMuted),
              border       : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.goldDim)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runTest,
              icon : const Icon(Icons.play_arrow_rounded),
              label: Text(isAr ? 'اختبر الآن' : 'Run Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WaColors.gold, foregroundColor: WaColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ])),
        if (_testResult != null) ...[
          const SizedBox(height: 16),
          _TestResultCard(result: _testResult!, isAr: isAr),
        ],
      ]),
    );
  }

  void _runTest() {
    if (_testCtrl.text.trim().isEmpty) return;
    final sms = context.read<SmsProvider>();
    setState(() => _testResult = sms.testTemplate(_buildTemplate(), _testCtrl.text.trim()));
  }

  // ── Bottom Nav ───────────────────────────────────────
  Widget _buildNavBar() {
    final isAr = _isAr;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: WaColors.border))),
      child: Row(children: [
        if (_step > 0)
          Expanded(flex: 1, child: OutlinedButton(
            onPressed: () => setState(() => _step--),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: WaColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(isAr ? 'السابق' : 'Back'),
          )),
        if (_step > 0) const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: _saving ? null : _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: WaColors.gold, foregroundColor: WaColors.obsidian,
            disabledBackgroundColor: WaColors.gold.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: WaColors.obsidian))
              : Text(
                  _step == 0 ? (isAr ? 'التالي ←' : 'Next →')
                : _step == 1 ? (isAr ? 'اختبار القالب' : 'Test Template')
                             : (isAr ? '💾 حفظ القالب' : '💾 Save Template'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ]),
    );
  }

  Future<void> _handleNext() async {
    final isAr = _isAr;
    if (_step == 0) {
      final err = _validateStep0(isAr);
      if (err != null) { _snack(err, isErr: true); return; }
      setState(() => _step = 1);
    } else if (_step == 1) {
      final err = _validateStep1();
      if (err != null) { _snack(err, isErr: true); return; }
      setState(() { _step = 2; _testResult = null; });
    } else {
      await _save();
    }
  }

  String? _validateStep0(bool isAr) {
    if (_bankCtrl.text.trim().isEmpty)   return isAr ? 'أدخل اسم البنك'         : 'Enter bank name';
    if (_senderCtrl.text.trim().isEmpty) return isAr ? 'أدخل اسم/رقم المُرسِل' : 'Enter sender name/number';
    if (_msgCtrl.text.trim().isEmpty)    return isAr ? 'الصق رسالة نموذجية'     : 'Paste a sample message';
    return null;
  }

  String? _validateStep1() => _buildTemplate().validate();

  Future<void> _save() async {
    final isAr = _isAr;
    setState(() => _saving = true);
    try {
      final sms = context.read<SmsProvider>();
      final tpl = _buildTemplate();
      if (widget.template == null) await sms.addTemplate(tpl);
      else                         await sms.updateTemplate(tpl);
      if (mounted) {
        _snack(isAr ? '✅ تم حفظ القالب بنجاح' : '✅ Template saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack(isAr ? 'فشل الحفظ: $e' : 'Save failed: $e', isErr: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SmsTemplate _buildTemplate() {
    final sms = context.read<SmsProvider>();
    return SmsTemplate(
      id           : widget.template?.id ?? sms.generateId(),
      bankName     : _bankCtrl.text.trim(),
      senderName   : _senderCtrl.text.trim(),
      sampleMessage: _msgCtrl.text.trim(),
      spans        : List.from(_spans),
      createdAt    : widget.template?.createdAt ?? DateTime.now(),
    );
  }

  void _snack(String msg, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isErr ? WaColors.danger : WaColors.success));
  }
}

// ── Tagged Message View ───────────────────────────────────────
class _TaggedMessageView extends StatelessWidget {
  final String message;
  final List<TaggedSpan> spans;
  final void Function(int, int) onTag;
  const _TaggedMessageView({required this.message, required this.spans, required this.onTag});

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildSpan(),
      style: const TextStyle(fontSize: 14, height: 1.7),
      contextMenuBuilder: (_, __) => const SizedBox.shrink(),
      onSelectionChanged: (sel, _) {
        if (sel.isCollapsed) return;
        final s = sel.baseOffset < sel.extentOffset ? sel.baseOffset : sel.extentOffset;
        final e = sel.baseOffset < sel.extentOffset ? sel.extentOffset : sel.baseOffset;
        if (s >= 0 && e > s && e <= message.length) onTag(s, e);
      },
    );
  }

  TextSpan _buildSpan() {
    if (spans.isEmpty) return TextSpan(text: message,
        style: const TextStyle(color: WaColors.textSecondary));
    final children = <TextSpan>[];
    int cursor = 0;
    for (final span in spans) {
      if (span.start > cursor)
        children.add(TextSpan(text: message.substring(cursor, span.start),
            style: const TextStyle(color: WaColors.textSecondary)));
      final color = Color(span.type.colorValue);
      children.add(TextSpan(
        text : message.substring(span.start, span.end),
        style: TextStyle(color: color, fontWeight: FontWeight.w700,
            backgroundColor: color.withValues(alpha: 0.15))));
      cursor = span.end;
    }
    if (cursor < message.length)
      children.add(TextSpan(text: message.substring(cursor),
          style: const TextStyle(color: WaColors.textSecondary)));
    return TextSpan(children: children);
  }
}

// ── Type Toolbar ─────────────────────────────────────────────
class _TypeToolbar extends StatelessWidget {
  final SmsFieldType selected;
  final ValueChanged<SmsFieldType> onSelect;
  const _TypeToolbar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    final types = [
      SmsFieldType.amount,
      SmsFieldType.description,
      SmsFieldType.expenseKeyword,
      SmsFieldType.incomeKeyword,
    ];
    return Container(
      height: 52,
      color : Theme.of(context).colorScheme.surface,
      child : ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: types.map((t) {
          final isSelected = t == selected;
          final color = Color(t.colorValue);
          // Bilingual label
          final label = isAr ? t.label : _labelEn(t);
          return GestureDetector(
            onTap: () => onSelect(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin  : const EdgeInsets.only(left: 8),
              padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color : isSelected ? color.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: isSelected ? color : WaColors.border,
                  width: isSelected ? 1.5 : 1),
                borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(
                  fontSize  : 12,
                  color     : isSelected ? color : WaColors.textMuted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _labelEn(SmsFieldType t) => switch (t) {
    SmsFieldType.amount         => 'Amount',
    SmsFieldType.description    => 'Merchant',
    SmsFieldType.expenseKeyword => 'Expense keyword',
    SmsFieldType.incomeKeyword  => 'Income keyword',
    _                           => t.label,
  };
}

// ── Span Chip ─────────────────────────────────────────────────
class _SpanChip extends StatelessWidget {
  final TaggedSpan span;
  final VoidCallback onDelete;
  const _SpanChip({required this.span, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = Color(span.type.colorValue);
    return Chip(
      label: Text(
        '${span.type.emoji} ${span.text.length > 15 ? '${span.text.substring(0, 15)}…' : span.text}',
        style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      deleteIcon: Icon(Icons.close, size: 14, color: color),
      onDeleted : onDelete,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Test Result Card ─────────────────────────────────────────
class _TestResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool isAr;
  const _TestResultCard({required this.result, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final success = result['success'] as bool? ?? false;
    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(success ? '✅' : '❌', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          success
              ? (isAr ? 'القالب يعمل بشكل صحيح!' : 'Template works correctly!')
              : (isAr ? 'لم يُطابق القالب الرسالة' : 'Template did not match the message'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: success ? WaColors.success : WaColors.danger)),
      ]),
      if (!success) ...[
        const SizedBox(height: 8),
        Text(result['error']?.toString() ?? '',
            style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
      ] else ...[
        const SizedBox(height: 12),
        _row(isAr ? 'النوع'            : 'Type',
          result['type'] == 'income'
              ? (isAr ? '📥 دخل'    : '📥 Income')
              : (isAr ? '📤 مصروف'  : '📤 Expense')),
        _row(isAr ? 'المبلغ'           : 'Amount',
          result['amount']?.toString() ?? '—'),
        _row(isAr ? 'التاجر / الوصف'  : 'Merchant / Description',
          result['description']?.toString() ?? (isAr ? 'غير محدد' : 'Not found')),
      ],
    ]));
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 130,
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: WaColors.textMuted))),
      Expanded(child: Text(val,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ── Step Indicator ────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) => Row(
    children: [0, 1, 2].map((i) => Expanded(child: Container(
      height: 3,
      margin: EdgeInsets.only(left: i < 2 ? 2 : 0, right: i > 0 ? 2 : 0),
      color: i < step ? WaColors.success : i == step ? WaColors.gold : WaColors.border,
    ))).toList(),
  );
}

// ── Step Header ───────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final String icon, title, sub;
  const _StepHeader({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 32)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(sub, style: const TextStyle(fontSize: 11, color: WaColors.textMuted, height: 1.4)),
    ])),
  ]);
}
