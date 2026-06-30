import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../home/home_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _initialized = false;
  bool _dirty = false; // هل يوجد تعديل غير محفوظ

  @override
  void initState() {
    super.initState();
    for (final c in kExpenseCategories) {
      _ctrls[c.id] = TextEditingController()
        ..addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _syncControllers(Map<String, double> budgets) {
    if (_initialized) return;
    _initialized = true;
    for (final e in budgets.entries) {
      _ctrls[e.key]?.text = e.value > 0 ? e.value.toStringAsFixed(0) : '';
    }
  }

  void _saveAll(Map<String, double> current) {
    final updated = Map<String, double>.from(current);
    for (final cat in kExpenseCategories) {
      final v = double.tryParse(_ctrls[cat.id]?.text ?? '') ?? 0;
      if (v > 0) updated[cat.id] = v;
      else updated.remove(cat.id);
    }
    context.read<AppProvider>().saveBudgets(updated);
    FocusScope.of(context).unfocus();
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(AppLocalizations.of(context).budgetSaved),
        ]),
        backgroundColor: WaColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final ap      = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);
    final budgets = ap.budgets;
    final now     = DateTime.now();
    final mTxs    = ap.txForMonth(now.year, now.month);
    final bycat   = ap.expenseByCategory(mTxs);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    _syncControllers(budgets);

    final totalBudget = budgets.values.fold<double>(0, (a, v) => a + v);
    final totalSpent  = ap.totalExpense(mTxs);
    final totalPct    = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final summaryColor = totalPct >= 0.9 ? WaColors.danger
        : totalPct >= 0.7 ? WaColors.warning : WaColors.success;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monthlyBudget),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu())),
        actions: [
          // ── زر الحفظ ─────────────────────────────
          AnimatedOpacity(
            opacity: _dirty ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: TextButton.icon(
              onPressed: _dirty ? () => _saveAll(budgets) : null,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(l10n.save, style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: WaColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [

          // ── ملخص الإجمالي ──────────────────────────
          WaCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.totalThisMonth,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (totalBudget > 0) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.spent,
                      style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                    Text('${ap.fmt(totalSpent)} / ${ap.fmt(totalBudget)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: summaryColor)),
                  ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalPct, minHeight: 10,
                    backgroundColor: isDark ? WaColors.obsidian3
                        : const Color(0xFFEDE9E0),
                    valueColor: AlwaysStoppedAnimation(summaryColor))),
                const SizedBox(height: 6),
                Text(l10n.percentOfBudget((totalPct * 100).round()),
                  style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
              ] else
                Text(l10n.noBudgetSet,
                  style: TextStyle(fontSize: 13, color: WaColors.textMuted)),
            ],
          )).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 14),

          // ── صفوف التصنيفات ─────────────────────────
          WaCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: kExpenseCategories.asMap().entries.map((entry) {
                final cat   = entry.value;
                final limit = budgets[cat.id] ?? 0;
                final spent = bycat[cat.id]   ?? 0;
                final pct   = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                final color = pct >= 0.9 ? WaColors.danger
                    : pct >= 0.7 ? WaColors.warning : WaColors.success;
                return _BudgetRow(
                  cat: cat, limit: limit, spent: spent, pct: pct,
                  color: color, currency: ap.currency,
                  ctrl: _ctrls[cat.id]!,
                  isDark: isDark,
                ).animate(delay: (entry.key * 35).ms).fadeIn();
              }).toList(),
            ),
          ),

          // ── زر حفظ سفلي ─────────────────────────────
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _dirty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _dirty ? () => _saveAll(budgets) : null,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: Text(l10n.saveChanges,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WaColors.gold,
                  foregroundColor: WaColors.obsidian,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
class _BudgetRow extends StatelessWidget {
  final WaCategory cat;
  final double limit, spent, pct;
  final Color color;
  final String currency;
  final TextEditingController ctrl;
  final bool isDark;

  const _BudgetRow({
    required this.cat, required this.limit, required this.spent,
    required this.pct, required this.color, required this.currency,
    required this.ctrl, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = context.read<AppProvider>().locale.languageCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

          // أيقونة + اسم
          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cat.localizedLabel(lang),
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600)),
                    if (limit > 0 && pct >= 0.8)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text('${(pct * 100).round()}%',
                          style: TextStyle(fontSize: 10, color: color,
                              fontWeight: FontWeight.w700)),
                      ),
                  ]),
                if (limit > 0) ...[
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 4,
                      backgroundColor: isDark ? WaColors.obsidian3
                          : const Color(0xFFEDE9E0),
                      valueColor: AlwaysStoppedAnimation(color))),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.spentAmount(spent.toStringAsFixed(0)),
                        style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
                      Text(l10n.limitAmount(limit.toStringAsFixed(0), currency),
                        style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
                    ]),
                ] else
                  Text(l10n.spentNoLimit(spent.toStringAsFixed(0), currency),
                    style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── حقل الإدخال — بنفس حجم حقول المعاملات ────
          SizedBox(
            width: 90,
            height: 44,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(fontSize: 15, color: WaColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                isDense: false,
                filled: true,
                fillColor: isDark ? WaColors.obsidian3
                    : const Color(0xFFF5F2EB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: WaColors.gold, width: 1.5)),
              ),
            ),
          ),
        ]),
        const Divider(height: 12, thickness: 0.5),
      ]),
    );
  }
}
