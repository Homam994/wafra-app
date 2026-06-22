import '../home/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../providers/app_provider.dart';
import '../../../data/models/models.dart';
import '../../widgets/common/wa_card.dart';
import '../../widgets/transaction/tx_list_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0 = الشهر الحالي، -1 = الشهر الماضي، إلخ
  int _monthOffset = 0;

  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset);
  }

  void _change(int delta) => setState(() => _monthOffset += delta);

  @override
  Widget build(BuildContext context) {
    final ap      = context.watch<AppProvider>();
    final month   = _month;
    final isCurrentMonth = _monthOffset == 0;
    final mTxs    = ap.txForMonth(month.year, month.month);
    final income  = ap.totalIncome(mTxs);
    final expense = ap.totalExpense(mTxs);
    final totInc  = ap.totalIncome(ap.transactions);
    final totExp  = ap.totalExpense(ap.transactions);
    final balance = totInc - totExp;
    final savePct = income > 0 ? ((income - expense) / income * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu(),
        )),
        title: Image.asset('assets/images/logo.png', height: 32),
        actions: [
          IconButton(
            icon: Icon(ap.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: WaColors.gold),
            onPressed: ap.toggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Greeting ───────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مرحباً، ${ap.userName.split(' ').first} 👋',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_dateLabel(),
                style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
            ]),
          ).animate().fadeIn(duration: 400.ms),

          // ── Month Navigator ─────────────────────
          Container(
            margin      : const EdgeInsets.only(bottom: 14),
            padding     : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration  : BoxDecoration(
              color       : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border      : Border.all(color: WaColors.border),
            ),
            child: Row(children: [
              // السهم الأيمن = الشهر السابق (RTL)
              IconButton(
                onPressed: () => _change(-1),
                icon     : const Icon(Icons.chevron_left_rounded),
                color    : WaColors.textSecondary,
                iconSize : 22,
                padding  : EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(child: GestureDetector(
                onTap: isCurrentMonth ? null : () => setState(() => _monthOffset = 0),
                child: Column(children: [
                  Text(
                    '${_monthName(month.month)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w700,
                      color     : isCurrentMonth ? WaColors.gold : null,
                    ),
                  ),
                  if (!isCurrentMonth)
                    Text('اضغط للعودة للشهر الحالي',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
                ]),
              )),
              // السهم الأيسر = الشهر التالي (RTL)
              IconButton(
                onPressed: isCurrentMonth ? null : () => _change(1),
                icon     : const Icon(Icons.chevron_right_rounded),
                color    : isCurrentMonth
                    ? WaColors.border
                    : WaColors.textSecondary,
                iconSize : 22,
                padding  : EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms),

          // ── Stats ──────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics   : const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _StatCard('الرصيد الكلي',  ap.fmt(balance), WaColors.gold,    Icons.account_balance_wallet_outlined),
              _StatCard('مداخيل الشهر',  ap.fmt(income),  WaColors.success,  Icons.trending_up_rounded),
              _StatCard('مصاريف الشهر',  ap.fmt(expense), WaColors.danger,   Icons.trending_down_rounded),
              _StatCard('معدل الادخار',
                  income > 0 ? '$savePct%' : '—', WaColors.info,
                  Icons.track_changes_rounded),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

          const SizedBox(height: 14),

          // ── Donut ──────────────────────────────
          if (expense > 0)
            WaCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('توزيع المصاريف',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('الشهر الحالي',
                  style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
                const SizedBox(height: 14),
                _DonutChart(txs: mTxs, ap: ap),
              ]),
            ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 12),

          // ── Bar Chart ──────────────────────────
          WaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المصاريف والمداخيل',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('آخر 6 أشهر',
                style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
              const SizedBox(height: 14),
              SizedBox(height: 155, child: _BarChart(ap: ap)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legend(WaColors.danger,  'مصاريف'),
                const SizedBox(width: 20),
                _legend(WaColors.success, 'مداخيل'),
              ]),
            ]),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 12),

          // ── Recent ─────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('آخر المعاملات',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${ap.transactions.length} معاملة',
              style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
          ]),
          const SizedBox(height: 8),

          ap.transactions.isEmpty
              ? _emptyState()
              : WaCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics   : const NeverScrollableScrollPhysics(),
                    itemCount : ap.transactions.take(8).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => TxListItem(tx: ap.transactions[i]),
                  ),
                ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _dateLabel() {
    final n = DateTime.now();
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const days   = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
    return '${days[n.weekday % 7]}، ${n.day} ${months[n.month-1]} ${n.year}';
  }

  String _monthName(int m) => const [
    'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ][m - 1];

  Widget _legend(Color color, String label) => Row(children: [
    Container(width:10, height:10,
      decoration: BoxDecoration(color:color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: WaColors.textSecondary)),
  ]);

  Widget _emptyState() => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('💸', style: TextStyle(fontSize: 40)),
        SizedBox(height: 8),
        Text('لا توجد معاملات بعد\nاضغط ＋ لإضافة أول معاملة',
          textAlign: TextAlign.center,
          style: TextStyle(color: WaColors.textMuted, fontSize: 13)),
      ]),
    ),
  );
}

// ── Stat Card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment : MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ]),
        ],
      ),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final AppProvider ap;
  const _BarChart({required this.ap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d   = DateTime(now.year, now.month - 5 + i);
      final txs = ap.txForMonth(d.year, d.month);
      return (
        label  : kMonthsAr[d.month - 1].substring(0, 3),
        expense: ap.totalExpense(txs),
        income : ap.totalIncome(txs),
      );
    });
    final maxY = months.expand((m) => [m.expense, m.income])
        .fold<double>(1, (a, v) => v > a ? v : a);

    return BarChart(BarChartData(
      maxY      : maxY * 1.18,
      gridData  : FlGridData(show: true, drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: WaColors.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          getTitlesWidget: (v, _) {
            final i = v.round();
            if (i < 0 || i >= 6) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 3),
              child: Text(months[i].label,
                style: const TextStyle(fontSize: 9, color: WaColors.textMuted)));
          },
        )),
        // ── محور Y — قيم الخطوط الأفقية ──────
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles   : true,
          reservedSize : 46,
          interval     : maxY / 4,
          getTitlesWidget: (v, _) {
            if (v == 0) return const SizedBox();
            final label = v >= 1000000
                ? '${(v / 1000000).toStringAsFixed(1)}M'
                : v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}K'
                    : v.toInt().toString();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(label,
                style: const TextStyle(fontSize: 9, color: WaColors.textMuted),
                textAlign: TextAlign.right),
            );
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: months[i].expense,
            color: WaColors.danger.withValues(alpha: 0.85),
            width: 8, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: months[i].income,
            color: WaColors.success.withValues(alpha: 0.85),
            width: 8, borderRadius: BorderRadius.circular(4)),
      ])),
    ));
  }
}

// ── Donut Chart ───────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final List<TxModel> txs;
  final AppProvider   ap;
  const _DonutChart({required this.txs, required this.ap});

  @override
  Widget build(BuildContext context) {
    final bycat  = ap.expenseByCategory(txs);
    final total  = bycat.values.fold<double>(0, (a, v) => a + v);
    if (total == 0) return const SizedBox();
    final sorted = (bycat.entries.toList()..sort((a,b) => b.value.compareTo(a.value))).take(5).toList();

    return Row(children: [
      SizedBox(
        width: 120, height: 120,
        child: PieChart(PieChartData(
          sectionsSpace    : 2,
          centerSpaceRadius: 32,
          sections: sorted.map((e) {
            final pct = e.value / total * 100;
            return PieChartSectionData(
              color: WaColors.catColor(e.key), value: e.value,
              title: pct >= 10 ? '${pct.round()}%' : '',
              titleStyle: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              radius: 38,
            );
          }).toList(),
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: sorted.map((e) {
            final cat   = findCategory(e.key, 'expense');
            final color = WaColors.catColor(e.key);
            final pct   = (e.value / total * 100).round();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width:9, height:9,
                  decoration: BoxDecoration(color:color, shape:BoxShape.circle)),
                const SizedBox(width: 5),
                Expanded(child: Text(cat?.label ?? e.key,
                  style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                Text('$pct%', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600, color: color)),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}
