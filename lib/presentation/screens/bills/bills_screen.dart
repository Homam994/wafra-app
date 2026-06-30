import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../home/home_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap    = context.watch<AppProvider>();
    final l10n  = AppLocalizations.of(context);
    final bills = ap.bills;
    final overdue  = bills.where((b) => !b.isPaid && b.isOverdue).toList();
    final today    = bills.where((b) => !b.isPaid && b.isDueToday).toList();
    final soon     = bills.where((b) => !b.isPaid && b.isDueSoon).toList();
    final upcoming = bills.where((b) => !b.isPaid && !b.isOverdue && !b.isDueToday && !b.isDueSoon).toList();
    final now = DateTime.now();
    final monthTotal = bills.where((b) {
      final d = DateTime.tryParse(b.dueDate);
      return d != null && d.year == now.year && d.month == now.month && !b.isPaid;
    }).fold<double>(0, (a, b) => a + b.amount);
    final isAr = ap.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billsAndSubscriptions),
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
      body: bills.isEmpty
          ? _EmptyState(onAdd: () => _openAddSheet(context))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WaCard(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.dueThisMonth,
                      style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(ap.fmt(monthTotal),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: WaColors.gold)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _SummaryChip('${overdue.length + today.length} ${isAr ? 'متأخرة/اليوم' : 'overdue/today'}', WaColors.danger),
                    const SizedBox(height: 4),
                    _SummaryChip('${upcoming.length} ${isAr ? 'قادمة' : 'upcoming'}', WaColors.info),
                  ]),
                ])).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 16),
                if (overdue.isNotEmpty) ...[
                  _GroupHeader(isAr ? '🔴 متأخرة' : '🔴 Overdue', WaColors.danger),
                  ...overdue.map((b) => _BillCard(bill: b).animate().fadeIn()),
                  const SizedBox(height: 12),
                ],
                if (today.isNotEmpty) ...[
                  _GroupHeader(isAr ? '🟡 مستحقة اليوم' : '🟡 Due Today', WaColors.warning),
                  ...today.map((b) => _BillCard(bill: b).animate().fadeIn()),
                  const SizedBox(height: 12),
                ],
                if (soon.isNotEmpty) ...[
                  _GroupHeader(isAr ? '🔔 خلال 3 أيام' : '🔔 In 3 Days', WaColors.info),
                  ...soon.map((b) => _BillCard(bill: b).animate().fadeIn()),
                  const SizedBox(height: 12),
                ],
                if (upcoming.isNotEmpty) ...[
                  _GroupHeader(isAr ? '📅 قادمة' : '📅 Upcoming', WaColors.textMuted),
                  ...upcoming.map((b) => _BillCard(bill: b).animate().fadeIn()),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  void _openAddSheet(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddBillSheet(),
  );
}

class _GroupHeader extends StatelessWidget {
  final String label; final Color color;
  const _GroupHeader(this.label, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
  );
}

class _SummaryChip extends StatelessWidget {
  final String label; final Color color;
  const _SummaryChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _BillCard extends StatelessWidget {
  final BillModel bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final ap   = context.read<AppProvider>();
    final l10n = AppLocalizations.of(context);
    final isAr = ap.locale.languageCode == 'ar';
    final cat  = findCategory(bill.cat, 'expense');
    final color = bill.isOverdue ? WaColors.danger
        : bill.isDueToday ? WaColors.warning
        : bill.isDueSoon  ? WaColors.info
        : WaColors.textMuted;

    final daysLabel = bill.isOverdue
        ? (isAr ? 'متأخرة ${bill.daysUntilDue.abs()} يوم' : '${bill.daysUntilDue.abs()} days late')
        : bill.isDueToday
            ? l10n.dueToday
            : (isAr ? 'بعد ${bill.daysUntilDue} يوم' : 'in ${bill.daysUntilDue} days');

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: WaColors.danger.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: WaColors.danger),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.deleteBill),
          content: Text(l10n.deleteBillConfirm(bill.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: WaColors.danger),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
      onDismissed: (_) => ap.deleteBill(bill.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: WaCard(child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(child: Text(cat?.emoji ?? '📄', style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bill.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(daysLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(bill.freqLabel, style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
              if (bill.note.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text('· ${bill.note}', style: TextStyle(fontSize: 11, color: WaColors.textMuted), overflow: TextOverflow.ellipsis),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ap.fmt(bill.amount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: WaColors.danger)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _confirmPay(context, ap, bill, l10n),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WaColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: WaColors.success.withValues(alpha: 0.4)),
                ),
                child: Text(l10n.payBill,
                  style: const TextStyle(fontSize: 11, color: WaColors.success, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ])),
      ),
    );
  }

  void _confirmPay(BuildContext ctx, AppProvider ap, BillModel b, AppLocalizations l10n) =>
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(l10n.confirmPayment),
        content: Text('${b.name}\n${ap.fmt(b.amount)} ${ap.currency}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); ap.payBill(b); },
            child: Text(l10n.payBill),
          ),
        ],
      ),
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
        const Text('🧾', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        Text(l10n.noBills, style: TextStyle(fontSize: 15, color: WaColors.textMuted)),
        const SizedBox(height: 6),
        Text(l10n.noBillsSubtitle,
          style: TextStyle(fontSize: 12, color: WaColors.textMuted), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(l10n.addBill)),
      ]),
    );
  }
}

class _AddBillSheet extends StatefulWidget {
  const _AddBillSheet();
  @override State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  late final List<WaCategory> _billCats;
  late String _cat;
  BillFreq _freq = BillFreq.monthly;
  String _date = (() {
    final n = DateTime.now();
    return DateTime(n.year, n.month + 1, 1).toIso8601String().split('T').first;
  })();
  bool _saving = false;

  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _billCats = kExpenseCategories.where((c) => [
      'bills', 'transport', 'health', 'education', 'entertainment', 'food', 'shopping', 'other',
    ].contains(c.id)).toList();
    _cat = _billCats.any((c) => c.id == 'bills') ? 'bills' : _billCats.first.id;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final l10n  = AppLocalizations.of(context);
    final isAr  = context.read<AppProvider>().locale.languageCode == 'ar';
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (_nameCtrl.text.trim().isEmpty) { _snack(isAr ? 'أدخل اسم الفاتورة' : 'Enter bill name'); return; }
    if (amount == null || amount <= 0)  { _snack(isAr ? 'أدخل مبلغاً صحيحاً' : 'Enter a valid amount'); return; }
    setState(() => _saving = true);
    try {
      final b = BillModel(
        id: '', name: _nameCtrl.text.trim(), cat: _cat,
        note: _noteCtrl.text.trim(), amount: amount,
        freq: _freq, dueDate: _date, isPaid: false, createdAt: DateTime.now(),
      );
      await context.read<AppProvider>().addBill(b);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context);
    final ap      = context.read<AppProvider>();
    final isAr    = ap.locale.languageCode == 'ar';
    final lang    = ap.locale.languageCode;
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
          Text(isAr ? 'فاتورة / اشتراك' : 'Bill / Subscription',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: InputDecoration(
            labelText: isAr ? 'الاسم' : 'Name',
            hintText : isAr ? 'مثال: نتفليكس، إيجار...' : 'e.g. Netflix, Rent...',
            filled: true, fillColor: fieldBg)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amount, hintText: '0.00',
              suffixText: ap.currency, filled: true, fillColor: fieldBg)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _cat, dropdownColor: dropBg,
              decoration: InputDecoration(labelText: l10n.category),
              items: _billCats.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text('${c.emoji} ${c.localizedLabel(lang)}', style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => setState(() => _cat = v!),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<BillFreq>(
              value: _freq, dropdownColor: dropBg,
              decoration: InputDecoration(labelText: l10n.frequency),
              items: [
                DropdownMenuItem(value: BillFreq.once,    child: Text(isAr ? 'مرة واحدة' : 'Once')),
                DropdownMenuItem(value: BillFreq.weekly,  child: Text(l10n.weekly)),
                DropdownMenuItem(value: BillFreq.monthly, child: Text(l10n.monthly)),
                DropdownMenuItem(value: BillFreq.yearly,  child: Text(l10n.yearly)),
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
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime(2100),
              );
              if (p != null) setState(() => _date = p.toIso8601String().split('T').first);
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: WaColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: WaColors.goldDim),
                const SizedBox(width: 8),
                Text('${isAr ? 'تاريخ الاستحقاق' : 'Due date'}: $_date', style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _noteCtrl, decoration: InputDecoration(
            labelText: isAr ? 'ملاحظة (اختياري)' : 'Note (optional)',
            hintText : isAr ? 'مثال: الباقة الذهبية' : 'e.g. Gold plan',
            filled: true, fillColor: fieldBg)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: WaColors.obsidian))
                  : Text(isAr ? '💾 حفظ الفاتورة' : '💾 Save Bill'),
            ),
          ),
        ]),
      ),
    );
  }
}
