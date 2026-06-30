import '../home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../../../generated/l10n/app_localizations.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap   = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.autoRecurring),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu(),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: WaColors.gold),
            onPressed: () => _openAddSheet(context),
          ),
        ],
      ),
      body: ap.recurring.isEmpty
          ? _EmptyState(onAdd: () => _openAddSheet(context))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WaCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ap.recurring.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _RecurItem(r: ap.recurring[i]).animate(delay: (i * 40).ms).fadeIn(),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  void _openAddSheet(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddRecurSheet(),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔄', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(l10n.noRecurring, style: TextStyle(fontSize: 15, color: WaColors.textMuted)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(l10n.addFirstRecurring),
        ),
      ]),
    );
  }
}

class _RecurItem extends StatelessWidget {
  final RecurModel r;
  const _RecurItem({required this.r});

  @override
  Widget build(BuildContext context) {
    final ap   = context.read<AppProvider>();
    final lang = ap.locale.languageCode;
    final cat  = findCategory(r.cat, r.type == TxType.income ? 'income' : 'expense');
    final color = WaColors.catColor(r.cat);
    final isAr  = lang == 'ar';
    return Dismissible(
      key: Key(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: WaColors.danger.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: WaColors.danger),
      ),
      onDismissed: (_) => ap.deleteRecur(r.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(cat?.emoji ?? '🔄', style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: WaColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(r.freqLabel, style: const TextStyle(fontSize: 10, color: WaColors.goldDim, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text('${cat?.localizedLabel(lang) ?? r.cat} · ${isAr ? 'بدءاً' : 'from'} ${r.startDate}',
                style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
            ]),
            if (r.lastRun.isNotEmpty)
              Text('${isAr ? 'آخر تطبيق' : 'Last applied'}: ${r.lastRun}',
                style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
          ])),
          Text(
            '${r.type == TxType.income ? '+' : '-'}${ap.fmt(r.amount)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: r.type == TxType.income ? WaColors.success : WaColors.danger),
          ),
        ]),
      ),
    );
  }
}

class _AddRecurSheet extends StatefulWidget {
  const _AddRecurSheet();
  @override State<_AddRecurSheet> createState() => _AddRecurSheetState();
}

class _AddRecurSheetState extends State<_AddRecurSheet> {
  TxType    _type   = TxType.expense;
  RecurFreq _freq   = RecurFreq.monthly;
  String    _cat    = kExpenseCategories.first.id;
  String    _date   = DateTime.now().toIso8601String().split('T').first;
  bool      _saving = false;

  final _amountCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();

  List<WaCategory> get _cats =>
      _type == TxType.expense ? kExpenseCategories : kIncomeCategories;

  @override
  void dispose() { _amountCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) { _snack(isAr ? 'أدخل مبلغاً صحيحاً' : 'Enter a valid amount'); return; }
    if (_nameCtrl.text.trim().isEmpty) { _snack(isAr ? 'أدخل اسماً للمعاملة' : 'Enter a name'); return; }
    setState(() => _saving = true);
    final r = RecurModel(
      id: '', type: _type, name: _nameCtrl.text.trim(),
      cat: _cat, amount: amount, freq: _freq,
      startDate: _date, lastRun: '', createdAt: DateTime.now(),
    );
    await context.read<AppProvider>().addRecur(r);
    if (mounted) { Navigator.pop(context); _snack(isAr ? '✓ تم الحفظ' : '✓ Saved'); }
    setState(() => _saving = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final ap     = context.watch<AppProvider>();
    final isAr   = ap.locale.languageCode == 'ar';
    final lang   = ap.locale.languageCode;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? WaColors.obsidian2 : Colors.white;
    final fieldBg = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final dropBg  = isDark ? WaColors.obsidian3 : Colors.white;

    return Container(
      decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: WaColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(l10n.recurringTx, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0.00', suffixText: ap.currency,
              labelText: l10n.amount, filled: true, fillColor: fieldBg),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _typeBtn(TxType.expense, isAr ? '📤 مصروف' : '📤 Expense'),
              _typeBtn(TxType.income,  isAr ? '📥 دخل'    : '📥 Income'),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: isAr ? 'الاسم / الوصف' : 'Name / Description',
              hintText : isAr ? 'مثال: إيجار، راتب...' : 'e.g. Rent, Salary...',
              filled: true, fillColor: fieldBg),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _cat, dropdownColor: dropBg,
              decoration: InputDecoration(labelText: l10n.category),
              items: _cats.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text('${c.emoji} ${c.localizedLabel(lang)}', style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _cat = v!),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<RecurFreq>(
              value: _freq, dropdownColor: dropBg,
              decoration: InputDecoration(labelText: l10n.frequency),
              items: [
                DropdownMenuItem(value: RecurFreq.monthly, child: Text(l10n.monthly)),
                DropdownMenuItem(value: RecurFreq.weekly,  child: Text(l10n.weekly)),
                DropdownMenuItem(value: RecurFreq.yearly,  child: Text(l10n.yearly)),
              ],
              onChanged: (v) => setState(() => _freq = v!),
            )),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                firstDate: DateTime(2000), lastDate: DateTime(2100),
              );
              if (p != null) setState(() => _date = p.toIso8601String().split('T').first);
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: WaColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: WaColors.goldDim),
                const SizedBox(width: 8),
                Text('${isAr ? 'تاريخ البدء' : 'Start date'}: $_date', style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: WaColors.obsidian))
                  : Text(isAr ? '💾 حفظ' : '💾 Save'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _typeBtn(TxType t, String label) {
    final active = _type == t;
    final color  = t == TxType.expense ? WaColors.danger : WaColors.success;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = t;
          _cat  = (t == TxType.expense ? kExpenseCategories : kIncomeCategories).first.id;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? color : WaColors.textMuted)),
        ),
      ),
    );
  }
}
