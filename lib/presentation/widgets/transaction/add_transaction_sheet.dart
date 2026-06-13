import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';

class AddTransactionSheet extends StatefulWidget {
  final TxModel? editing;
  final TxType?  forceType;
  const AddTransactionSheet({super.key, this.editing, this.forceType});
  @override State<AddTransactionSheet> createState() => _State();
}

class _State extends State<AddTransactionSheet> {
  TxType  _type    = TxType.expense;
  double? _amount;
  String? _mainCat, _subCat;
  String  _date    = DateTime.now().toIso8601String().split('T').first;
  bool    _saving  = false;
  bool    _catOpen = false;

  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type    = e.type;
      _amount  = e.amount;
      _mainCat = e.cat;
      _subCat  = e.sub.isNotEmpty ? e.sub : null;
      _date    = e.date;
      _amountCtrl.text = e.amount % 1 == 0
          ? e.amount.toInt().toString()
          : e.amount.toStringAsFixed(2);
      _noteCtrl.text = e.note;
    } else {
      _type = widget.forceType ?? TxType.expense;
      _loadLastUsed();
    }
  }

  Future<void> _loadLastUsed() async {
    final last = await context.read<AppProvider>().getLastUsed();
    if (!mounted) return;
    if (widget.forceType == null) {
      final t = last['type'];
      if (t != null) _type = t == 'income' ? TxType.income : TxType.expense;
    }
    final key = _type == TxType.income ? 'income' : 'expense';
    if (mounted) setState(() {
      _mainCat = last['${key}_cat'];
      _subCat  = last['${key}_sub'];
    });
  }

  @override void dispose() { _amountCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  List<WaCategory> get _cats =>
      _type == TxType.expense ? kExpenseCategories : kIncomeCategories;

  WaCategory? get _selectedCat => _mainCat == null ? null
      : _cats.firstWhere((c) => c.id == _mainCat, orElse: () => _cats.first);

  Future<void> _save() async {
    if (_amount == null || _amount! <= 0) { _snack('أدخل مبلغاً صحيحاً'); return; }
    if (_mainCat == null)                 { _snack('اختر التصنيف');        return; }
    setState(() => _saving = true);
    final ap = context.read<AppProvider>();
    final tx = TxModel(
      id: widget.editing?.id ?? '',
      type: _type, cat: _mainCat!, sub: _subCat ?? '',
      amount: _amount!, note: _noteCtrl.text.trim(), date: _date,
      createdAt: widget.editing?.createdAt ?? DateTime.now(),
      updatedAt: widget.editing != null ? DateTime.now() : null,
    );
    // ✅ Firestore offline-first: يحفظ محلياً فوراً دون انتظار الشبكة
    // لا نحتاج try/catch هنا — لن يرمي exception عند غياب الإنترنت
    if (widget.editing != null) {
      await ap.updateTx(widget.editing!.id, tx);
    } else {
      await ap.addTx(tx);
      // ✅ حفظ آخر تصنيف مستخدم
      await ap.saveLastUsed(
          _type == TxType.income ? 'income' : 'expense', _mainCat!, _subCat);
    }
    if (mounted) {
      Navigator.pop(context);
      _snack(widget.editing != null ? '✓ تم التعديل' : '✓ تم الحفظ');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: 2.seconds));

  @override
  Widget build(BuildContext context) {
    // ✅ كل الألوان تتبع الثيم
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final sheetBg  = isDark ? WaColors.obsidian2 : Colors.white;
    final fieldBg  = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final catShBg  = isDark ? WaColors.obsidian2 : const Color(0xFFF8F5EF);
    final catItBg  = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final rowBorder= isDark ? WaColors.border     : const Color(0x40C9A84C);

    return Container(
      decoration: BoxDecoration(
        color        : sheetBg,
        borderRadius : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin     : const EdgeInsets.only(top: 10),
          width: 36, height: 4,
          decoration : BoxDecoration(
              color        : WaColors.border,
              borderRadius : BorderRadius.circular(2))),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.editing != null ? 'تعديل المعاملة' : 'معاملة جديدة',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: fieldBg,      // ✅ ثيم
                  foregroundColor: WaColors.textSecondary,
                  padding: const EdgeInsets.all(6))),
            ]),
        ),

        // Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

              // ── المبلغ ─────────────────────────
              Container(
                decoration: BoxDecoration(
                  color        : fieldBg,         // ✅ ثيم
                  borderRadius : BorderRadius.circular(14),
                  border       : Border.all(color: rowBorder),
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  Expanded(child: TextField(
                    controller   : _amountCtrl,
                    autofocus    : true,
                    keyboardType : const TextInputType.numberWithOptions(decimal: true),
                    textAlign    : TextAlign.center,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText  : '0.00',
                      border    : InputBorder.none,
                      filled    : false,
                      hintStyle : TextStyle(
                          fontSize: 26, color: WaColors.textMuted)),
                    onChanged: (v) => setState(
                        () => _amount = double.tryParse(v)),
                  )),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      context.read<AppProvider>().currency,
                      style: const TextStyle(
                          fontSize: 14, color: WaColors.goldDim,
                          fontWeight: FontWeight.w600))),
                  const SizedBox(width: 14),
                ]),
              ),
              const SizedBox(height: 12),

              // ── مصروف / دخل ────────────────────
              Container(
                decoration: BoxDecoration(
                  color        : fieldBg,         // ✅ ثيم
                  borderRadius : BorderRadius.circular(10)),
                padding: const EdgeInsets.all(3),
                child: Row(children: [
                  _typeBtn(context, TxType.expense, '📤 مصروف',
                      WaColors.danger,  fieldBg),
                  _typeBtn(context, TxType.income,  '📥 دخل',
                      WaColors.success, fieldBg),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Cat picker row ──────────────────
              GestureDetector(
                onTap: () => setState(() => _catOpen = !_catOpen),
                child: AnimatedContainer(
                  duration: 180.ms,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: fieldBg,               // ✅ ثيم
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _catOpen ? WaColors.goldDim : rowBorder,
                      width: 1.5)),
                  child: Row(children: [
                    Text(_selectedCat?.emoji ?? '🏷️',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedCat?.label ?? 'اختر التصنيف',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(_subCat ?? (_selectedCat != null
                            ? 'اضغط لتغيير التصنيف الفرعي'
                            : 'اضغط لاختيار التصنيف'),
                          style: const TextStyle(
                              fontSize: 11, color: WaColors.textMuted)),
                      ])),
                    AnimatedRotation(
                      turns: _catOpen ? 0.25 : 0, duration: 200.ms,
                      child: const Icon(Icons.chevron_left_rounded,
                          color: WaColors.textMuted, size: 20)),
                  ]),
                ),
              ),

              // ── Cat sheet ───────────────────────
              AnimatedCrossFade(
                duration      : 200.ms,
                crossFadeState: _catOpen
                    ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: _buildCatSheet(
                    catShBg, catItBg, rowBorder),
                secondChild: const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // ── التاريخ والملاحظة ───────────────
              Row(children: [
                Expanded(child: _dateField(fieldBg, rowBorder)),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText : 'ملاحظة',
                    hintText  : 'اختياري',
                    filled    : true,
                    fillColor : fieldBg,   // ✅ ثيم
                    prefixIcon: const Icon(Icons.note_outlined,
                        color: WaColors.goldDim, size: 18)),
                  onSubmitted: (_) => _save())),
              ]),
              const SizedBox(height: 18),

              // ── حفظ ────────────────────────────
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WaColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: WaColors.obsidian))
                    : const Text('💾 حفظ',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: WaColors.obsidian)),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _typeBtn(BuildContext ctx, TxType t, String label,
      Color color, Color bg) {
    final active = _type == t;
    return Expanded(child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() { _type = t; _mainCat = null; _subCat = null;
                      _catOpen = false; });
      },
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? color : WaColors.textMuted)),
      ),
    ));
  }

  Widget _buildCatSheet(Color shBg, Color itBg, Color border) {
    final sel = _selectedCat;
    return Container(
      margin  : const EdgeInsets.only(top: 4),
      padding : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color        : shBg,              // ✅ ثيم
        borderRadius : BorderRadius.circular(12),
        border       : Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main cats grid
          GridView.count(
            shrinkWrap: true,
            physics   : const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 6, mainAxisSpacing: 6,
            childAspectRatio: 0.9,
            children: _cats.map((cat) {
              final active = _mainCat == cat.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() { _mainCat = cat.id; _subCat = null; });
                },
                child: AnimatedContainer(
                  duration: 160.ms,
                  decoration: BoxDecoration(
                    color: active
                        ? cat.color.withValues(alpha: 0.14) : itBg, // ✅
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color : active ? cat.color : border,
                      width : active ? 1.5 : 1)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Text(cat.emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 3),
                    Text(cat.label, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9,
                        fontWeight: active
                            ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? cat.color : WaColors.textSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),

          // Subcats
          if (sel != null) ...[
            const Divider(height: 16),
            const Text('تصنيف فرعي',
              style: TextStyle(fontSize: 10, letterSpacing: 1.5,
                  color: WaColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: sel.subs.map((sub) {
                final active = _subCat == sub.label;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() { _subCat = sub.label; });
                    Future.delayed(200.ms, () {
                      if (mounted) setState(() => _catOpen = false);
                    });
                  },
                  child: AnimatedContainer(
                    duration: 140.ms,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? sel.color.withValues(alpha: 0.14) : itBg, // ✅
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? sel.color : border,
                        width: active ? 1.5 : 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(sub.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(sub.label, style: TextStyle(fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w600 : FontWeight.w400,
                        color: active ? sel.color : WaColors.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField(Color bg, Color border) => GestureDetector(
    onTap: () async {
      final p = await showDatePicker(
        context    : context,
        locale     : const Locale('ar', 'SA'),
        initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
        firstDate  : DateTime(2000),
        lastDate   : DateTime(2100),
      );
      if (p != null) setState(
          () => _date = p.toIso8601String().split('T').first);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color        : bg,                // ✅ ثيم
        borderRadius : BorderRadius.circular(8),
        border       : Border.all(color: border)),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined,
            color: WaColors.goldDim, size: 16),
        const SizedBox(width: 6),
        Text(_date, style: const TextStyle(fontSize: 13)),
      ]),
    ),
  );
}
