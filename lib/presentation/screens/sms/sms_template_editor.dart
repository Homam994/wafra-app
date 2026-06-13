// ════════════════════════════════════════════════════════════
//  SmsTemplateEditor — محرر القالب التفاعلي
//  المستخدم يُظلّل أجزاء الرسالة ويحدد نوع كل جزء
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sms_models.dart';
import '../../../providers/sms_provider.dart';
import '../../widgets/common/wa_card.dart';

class SmsTemplateEditor extends StatefulWidget {
  final SmsTemplate? template; // null = إنشاء جديد، وإلا تعديل
  const SmsTemplateEditor({super.key, this.template});

  @override
  State<SmsTemplateEditor> createState() => _SmsTemplateEditorState();
}

class _SmsTemplateEditorState extends State<SmsTemplateEditor> {

  // ── Controllers ─────────────────────────────────────────
  final _bankCtrl   = TextEditingController();
  final _senderCtrl = TextEditingController();
  final _msgCtrl    = TextEditingController();
  final _testCtrl   = TextEditingController();

  // ── الحالة ───────────────────────────────────────────────
  List<TaggedSpan> _spans      = [];
  int              _step       = 0; // 0=معلومات, 1=التعليم, 2=الاختبار
  bool             _saving     = false;
  Map<String, dynamic>? _testResult;

  // النوع المختار حالياً في شريط الأدوات
  SmsFieldType _selectedType = SmsFieldType.amount;

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
    _bankCtrl.dispose();
    _senderCtrl.dispose();
    _msgCtrl.dispose();
    _testCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  //  Build
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'قالب جديد' : 'تعديل القالب'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepIndicator(step: _step),
        ),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          _buildStep0(),
          _buildStep1(),
          _buildStep2(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  // ══════════════════════════════════════
  //  الخطوة ٠ — معلومات البنك
  // ══════════════════════════════════════
  Widget _buildStep0() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _StepHeader(
        icon : '🏦',
        title: 'معلومات البنك',
        sub  : 'أدخل اسم البنك والمُرسِل كما يظهر في رسائل SMS',
      ),
      const SizedBox(height: 20),
      WaCard(child: Column(children: [
        _field(_bankCtrl, 'اسم البنك',
          'مثال: البنك الأهلي، الراجحي...', Icons.account_balance_outlined),
        const Divider(height: 1, color: WaColors.border),
        _field(_senderCtrl, 'اسم/رقم المُرسِل',
          'مثال: ALAHLI، 1900، BankSMS...', Icons.phone_outlined),
      ])),
      const SizedBox(height: 16),
      WaCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الصق رسالة نموذجية من البنك',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('ستُستخدم لتعليم التطبيق كيف يقرأ رسائل هذا البنك',
            style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller : _msgCtrl,
            maxLines   : 6,
            textDirection: TextDirection.rtl,
            decoration : InputDecoration(
              hintText     : 'الصق الرسالة هنا...\n\nمثال:\nتم الخصم من حسابك مبلغ 250.00 ريال\nلدى مطعم الباشا',
              hintStyle    : const TextStyle(fontSize: 12, color: WaColors.textMuted),
              filled       : true,
              fillColor    : WaColors.obsidian3,
              border       : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.goldDim),
              ),
            ),
          ),
        ],
      )),
    ]),
  );

  Widget _field(TextEditingController ctrl, String label,
      String hint, IconData icon) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: WaColors.gold),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText : hint,
                hintStyle: const TextStyle(fontSize: 12, color: WaColors.textMuted),
                isDense  : true,
                filled   : true,
                fillColor: WaColors.obsidian3,
                border   : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide  : const BorderSide(color: WaColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide  : const BorderSide(color: WaColors.goldDim),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              ),
            ),
          ],
        )),
      ]),
    );

  // ══════════════════════════════════════
  //  الخطوة ١ — التعليم التفاعلي
  // ══════════════════════════════════════
  Widget _buildStep1() => Column(children: [
    // شريط أدوات التظليل
    _TypeToolbar(
      selected : _selectedType,
      onSelect : (t) => setState(() => _selectedType = t),
    ),
    const SizedBox(height: 8),
    // إرشاد سريع
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'ظلّل جزءاً من الرسالة بإصبعك ثم اختر نوعه من الأزرار أعلاه',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: WaColors.textMuted),
      ),
    ),
    const SizedBox(height: 12),
    // الرسالة التفاعلية
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: WaCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TaggedMessageView(
            message : _msgCtrl.text,
            spans   : _spans,
            onTag   : _handleTag,
          ),
          if (_spans.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: WaColors.border),
            const SizedBox(height: 8),
            const Text('العناصر المُعلَّمة:',
              style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4,
              children: _spans.map((s) => _SpanChip(
                span   : s,
                onDelete: () => setState(() =>
                  _spans.removeWhere((x) =>
                    x.start == s.start && x.end == s.end)),
              )).toList(),
            ),
          ],
        ],
      )),
    )),
  ]);

  void _handleTag(int start, int end) {
    final text = _msgCtrl.text.substring(start, end).trim();
    if (text.isEmpty) return;

    setState(() {
      // أزِل أي span يتداخل مع الاختيار الجديد
      _spans.removeWhere((s) =>
        !(s.end <= start || s.start >= end));
      _spans.add(TaggedSpan(
        text : text,
        type : _selectedType,
        start: start,
        end  : end,
      ));
      _spans.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  // ══════════════════════════════════════
  //  الخطوة ٢ — الاختبار
  // ══════════════════════════════════════
  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _StepHeader(
        icon : '🧪',
        title: 'اختبر القالب',
        sub  : 'الصق رسالة أخرى من نفس البنك للتأكد من صحة القالب',
      ),
      const SizedBox(height: 16),
      WaCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('رسالة اختبار',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller : _testCtrl,
            maxLines   : 5,
            textDirection: TextDirection.rtl,
            decoration : InputDecoration(
              hintText : 'الصق رسالة مختلفة من نفس البنك...',
              hintStyle: const TextStyle(fontSize: 12, color: WaColors.textMuted),
              filled   : true,
              fillColor: WaColors.obsidian3,
              border   : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide  : const BorderSide(color: WaColors.goldDim),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runTest,
              icon : const Icon(Icons.play_arrow_rounded),
              label: const Text('اختبر الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WaColors.gold,
                foregroundColor: WaColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      )),
      if (_testResult != null) ...[
        const SizedBox(height: 16),
        _TestResultCard(result: _testResult!),
      ],
    ]),
  );

  void _runTest() {
    if (_testCtrl.text.trim().isEmpty) return;
    final sms = context.read<SmsProvider>();
    final tmpTemplate = _buildTemplate();
    final result = sms.testTemplate(tmpTemplate, _testCtrl.text.trim());
    setState(() => _testResult = result);
  }

  // ══════════════════════════════════════
  //  شريط التنقل السفلي
  // ══════════════════════════════════════
  Widget _buildNavBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    decoration: const BoxDecoration(
      color: WaColors.obsidian2,
      border: Border(top: BorderSide(color: WaColors.border)),
    ),
    child: Row(children: [
      if (_step > 0)
        Expanded(flex: 1, child: OutlinedButton(
          onPressed: () => setState(() => _step--),
          style: OutlinedButton.styleFrom(
            side   : const BorderSide(color: WaColors.border),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape  : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('السابق'),
        )),
      if (_step > 0) const SizedBox(width: 10),
      Expanded(flex: 2, child: ElevatedButton(
        onPressed: _saving ? null : _handleNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: WaColors.gold,
          foregroundColor: WaColors.obsidian,
          disabledBackgroundColor: WaColors.gold.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),
        child: _saving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: WaColors.obsidian))
            : Text(
                _step == 0 ? 'التالي ←' :
                _step == 1 ? 'اختبار القالب' :
                '💾 حفظ القالب',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
      )),
    ]),
  );

  Future<void> _handleNext() async {
    if (_step == 0) {
      final err = _validateStep0();
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

  String? _validateStep0() {
    if (_bankCtrl.text.trim().isEmpty)   return 'أدخل اسم البنك';
    if (_senderCtrl.text.trim().isEmpty) return 'أدخل اسم/رقم المُرسِل';
    if (_msgCtrl.text.trim().isEmpty)    return 'الصق رسالة نموذجية';
    return null;
  }

  String? _validateStep1() {
    final tmp = _buildTemplate();
    return tmp.validate();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sms      = context.read<SmsProvider>();
      final template = _buildTemplate();
      if (widget.template == null) {
        await sms.addTemplate(template);
      } else {
        await sms.updateTemplate(template);
      }
      if (mounted) {
        _snack('✅ تم حفظ القالب بنجاح');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('فشل الحفظ: $e', isErr: true);
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
      content        : Text(msg),
      backgroundColor: isErr ? WaColors.danger : WaColors.success,
    ));
  }
}

// ══════════════════════════════════════════════════════════
//  عرض الرسالة مع ألوان التظليل — النص قابل للتحديد
// ══════════════════════════════════════════════════════════
class _TaggedMessageView extends StatelessWidget {
  final String           message;
  final List<TaggedSpan> spans;
  final void Function(int start, int end) onTag;

  const _TaggedMessageView({
    required this.message,
    required this.spans,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildTextSpan(),
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 14, height: 1.7),
      onSelectionChanged: (selection, _) {
        if (selection.isCollapsed) return;
        final base   = selection.baseOffset;
        final extent = selection.extentOffset;
        final start  = base < extent ? base   : extent;
        final end    = base < extent ? extent : base;
        if (start >= 0 && end > start && end <= message.length) {
          onTag(start, end);
        }
      },
    );
  }

  TextSpan _buildTextSpan() {
    if (spans.isEmpty) {
      return TextSpan(text: message,
        style: const TextStyle(color: WaColors.textSecondary));
    }

    final children = <TextSpan>[];
    int cursor = 0;

    for (final span in spans) {
      // نص قبل الـ span
      if (span.start > cursor) {
        children.add(TextSpan(
          text : message.substring(cursor, span.start),
          style: const TextStyle(color: WaColors.textSecondary),
        ));
      }
      // الـ span المُعلَّم
      final color = Color(span.type.colorValue);
      children.add(TextSpan(
        text : message.substring(span.start, span.end),
        style: TextStyle(
          color      : color,
          fontWeight : FontWeight.w700,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ));
      cursor = span.end;
    }
    // النص المتبقي
    if (cursor < message.length) {
      children.add(TextSpan(
        text : message.substring(cursor),
        style: const TextStyle(color: WaColors.textSecondary),
      ));
    }

    return TextSpan(children: children);
  }
}

// ══════════════════════════════════════════════════════════
//  شريط أدوات اختيار نوع التظليل
// ══════════════════════════════════════════════════════════
class _TypeToolbar extends StatelessWidget {
  final SmsFieldType               selected;
  final ValueChanged<SmsFieldType> onSelect;

  const _TypeToolbar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = [
      SmsFieldType.amount,
      SmsFieldType.description,
      SmsFieldType.expenseKeyword,
      SmsFieldType.incomeKeyword,
    ];
    return Container(
      height     : 52,
      color      : WaColors.obsidian2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children       : types.map((t) {
          final isSelected = t == selected;
          final color = Color(t.colorValue);
          return GestureDetector(
            onTap: () => onSelect(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin : const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color : isSelected
                    ? color.withValues(alpha: 0.2)
                    : WaColors.obsidian3,
                border: Border.all(
                  color: isSelected ? color : WaColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(t.label,
                  style: TextStyle(
                    fontSize  : 12,
                    color     : isSelected ? color : WaColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  )),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Chip للـ span مع زر حذف
// ══════════════════════════════════════════════════════════
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
        style: TextStyle(fontSize: 11, color: color),
      ),
      backgroundColor  : color.withValues(alpha: 0.12),
      side             : BorderSide(color: color.withValues(alpha: 0.3)),
      deleteIcon        : Icon(Icons.close, size: 14, color: color),
      onDeleted        : onDelete,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  بطاقة نتيجة الاختبار
// ══════════════════════════════════════════════════════════
class _TestResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _TestResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final success = result['success'] as bool? ?? false;
    return WaCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(success ? '✅' : '❌', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            success ? 'القالب يعمل بشكل صحيح!' : 'لم يُطابق القالب الرسالة',
            style: TextStyle(
              fontSize  : 14,
              fontWeight: FontWeight.w700,
              color     : success ? WaColors.success : WaColors.danger,
            ),
          ),
        ]),
        if (!success) ...[
          const SizedBox(height: 8),
          Text(result['error']?.toString() ?? '',
            style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
        ] else ...[
          const SizedBox(height: 12),
          _row('النوع',
            result['type'] == 'income' ? '📥 دخل' : '📤 مصروف'),
          _row('المبلغ',
            result['amount']?.toString() ?? '—'),
          _row('التاجر / الوصف',
            result['description']?.toString() ?? 'غير محدد'),
        ],
      ],
    ));
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 120,
        child: Text(label,
          style: const TextStyle(fontSize: 12, color: WaColors.textMuted))),
      Expanded(child: Text(val,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ── Step Indicator ──────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [0, 1, 2].map((i) {
        final isActive = i == step;
        final isDone   = i < step;
        return Expanded(child: Container(
          height: 3,
          margin: EdgeInsets.only(left: i < 2 ? 2 : 0, right: i > 0 ? 2 : 0),
          color: isDone   ? WaColors.success
               : isActive ? WaColors.gold
               : WaColors.border,
        ));
      }).toList(),
    );
  }
}

// ── Step Header ────────────────────────────────────────
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
