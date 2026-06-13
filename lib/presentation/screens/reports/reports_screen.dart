import '../home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../../widgets/transaction/tx_list_item.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _year, _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now(); _year = n.year; _month = n.month;
  }

  void _change(int d) => setState(() {
    _month += d;
    if (_month < 1)  { _month = 12; _year--; }
    if (_month > 12) { _month = 1;  _year++; }
  });

  @override
  Widget build(BuildContext context) {
    // ✅ ألوان تتبع الثيم
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final chipBg   = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final chipFg   = isDark ? WaColors.textSecondary : const Color(0xFF5A4E3E);
    final progBg   = isDark ? WaColors.obsidian3 : const Color(0xFFE0DBD0);

    final ap  = context.watch<AppProvider>();
    final txs = ap.txForMonth(_year, _month);
    final inc = ap.totalIncome(txs);
    final exp = ap.totalExpense(txs);
    final net = inc - exp;
    final expBycat = ap.expenseByCategory(txs);
    final incBycat = ap.incomeByCategory(txs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير الشهرية'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Month Nav ───────────────────────────
          WaCard(child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ أسهم تتبع الثيم
              // ✅ RTL: زر اليمين = شهر تالٍ، زر اليسار = شهر سابق
              _navBtn(Icons.arrow_back_ios_new, () => _change(1),
                  chipBg, chipFg),
              Text('${kMonthsAr[_month-1]} $_year',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              _navBtn(Icons.arrow_forward_ios, () => _change(-1),
                  chipBg, chipFg),
            ],
          )).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),

          // ── Stats ────────────────────────────────
          Row(children: [
            Expanded(child: _stat('المداخيل', ap.fmt(inc), WaColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('المصاريف', ap.fmt(exp), WaColors.danger)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _stat('الصافي', ap.fmt(net),
                net >= 0 ? WaColors.success : WaColors.danger)),
            const SizedBox(width: 10),
            Expanded(child: _stat('المعاملات', '${txs.length}', WaColors.gold)),
          ]),
          const SizedBox(height: 14),

          // ── Expense Breakdown ────────────────────
          if (expBycat.isNotEmpty) ...[
            WaCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تفصيل المصاريف',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ..._breakdown(expBycat, exp, ap, 'expense', progBg),
            ])).animate(delay: 100.ms).fadeIn(),
            const SizedBox(height: 12),
          ],

          // ── Income Breakdown ─────────────────────
          if (incBycat.isNotEmpty) ...[
            WaCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تفصيل المداخيل',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ..._breakdown(incBycat, inc, ap, 'income', progBg),
            ])).animate(delay: 150.ms).fadeIn(),
            const SizedBox(height: 12),
          ],

          // ── Transactions list ────────────────────
          WaCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('معاملات الشهر — ${txs.length}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (txs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد معاملات هذا الشهر',
                    style: TextStyle(color: WaColors.textMuted))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      TxListItem(tx: txs[i], showActions: false),
                ),
            ]),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ✅ progBg من الثيم
  List<Widget> _breakdown(Map<String, double> bycat, double total,
      AppProvider ap, String type, Color progBg) {
    final sorted = bycat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) {
      final cat   = findCategory(e.key, type);
      final pct   = total > 0 ? (e.value / total * 100).round() : 0;
      final color = WaColors.catColor(e.key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Row(children: [
            Text(cat?.emoji ?? '•', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(cat?.label ?? e.key,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500))),
            Text(ap.fmt(e.value),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('$pct%',
              style: TextStyle(fontSize: 11, color: color)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: progBg,           // ✅ ثيم
              valueColor: AlwaysStoppedAnimation(color)),
          ),
        ]),
      );
    }).toList();
  }

  Widget _stat(String label, String value, Color color) => WaCard(
    padding: const EdgeInsets.all(13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(fontSize: 11, color: WaColors.textMuted)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  // ✅ chipBg/chipFg تُمرَّر من build
  Widget _navBtn(IconData icon, VoidCallback onTap,
      Color bg, Color fg) => IconButton(
    icon: Icon(icon, size: 16),
    onPressed: onTap,
    style: IconButton.styleFrom(
        backgroundColor: bg, foregroundColor: fg),
  );
}
