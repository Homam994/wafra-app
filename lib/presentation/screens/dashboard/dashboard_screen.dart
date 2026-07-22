import '../home/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/services/nav_stack_service.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/sms_provider.dart';
import '../../../data/models/models.dart';
import '../../widgets/common/wa_card.dart';
import '../../widgets/transaction/tx_list_item.dart';
import '../sms/unclassified_merchants_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _monthOffset = 0;

  DateTime get _month {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset);
  }

  void _change(int delta) => setState(() => _monthOffset += delta);

  @override
  Widget build(BuildContext context) {
    final ap             = context.watch<AppProvider>();
    final sms            = context.watch<SmsProvider>();
    final l10n           = AppLocalizations.of(context);
    final month          = _month;
    final isCurrentMonth = _monthOffset == 0;
    final mTxs           = ap.txForMonth(month.year, month.month);
    final income         = ap.totalIncome(mTxs);
    final expense        = ap.totalExpense(mTxs);
    final totInc         = ap.totalIncome(ap.transactions);
    final totExp         = ap.totalExpense(ap.transactions);
    final balance        = totInc - totExp;
    final savePct        = income > 0 ? ((income - expense) / income * 100).round() : 0;
    final isAr           = ap.locale.languageCode == 'ar';

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
              Text(l10n.greeting(ap.userName.split(' ').first),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_dateLabel(l10n, isAr),
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
                    '${_monthName(l10n, month.month)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w700,
                      color     : isCurrentMonth ? WaColors.gold : null,
                    ),
                  ),
                  if (!isCurrentMonth)
                    Text(l10n.returnToCurrentMonth,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: WaColors.textMuted)),
                ]),
              )),
              IconButton(
                onPressed: isCurrentMonth ? null : () => _change(1),
                icon     : const Icon(Icons.chevron_right_rounded),
                color    : isCurrentMonth ? WaColors.border : WaColors.textSecondary,
                iconSize : 22,
                padding  : EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms),

          // ── Stats: Balance | Savings | Expenses | Income ──
          GridView.count(
            shrinkWrap: true,
            physics   : const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _StatCard(isAr ? 'الرصيد الكلي' : 'Total Balance',
                  '${balance < 0 ? '-' : ''}${ap.fmt(balance)}',
                  balance < 0 ? WaColors.danger : WaColors.gold,
                  Icons.account_balance_wallet_outlined),
              _StatCard(isAr ? 'معدل الادخار'  : 'Savings Rate',
                  income > 0 ? '$savePct%' : '—', WaColors.info, Icons.track_changes_rounded),
              _StatCard(isAr ? 'مصاريف الشهر' : 'Month Expenses', ap.fmt(expense), WaColors.danger,  Icons.trending_down_rounded),
              _StatCard(isAr ? 'مداخيل الشهر' : 'Month Income',   ap.fmt(income),  WaColors.success, Icons.trending_up_rounded),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

          // ── اختصار: تجار بدون تصنيف ──────────────────
          if (sms.unclassified.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                NavStackService.push('sms_unclassified');
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const UnclassifiedMerchantsScreen()))
                  .then((_) => NavStackService.pop());
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color : WaColors.gold.withValues(alpha: 0.08),
                  border: Border.all(color: WaColors.gold.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: WaColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('🏪', style: TextStyle(fontSize: 17))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? '${sms.unclassified.length} تاجر بحاجة لتصنيف'
                             : '${sms.unclassified.length} merchants need classification',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        isAr ? 'اضغط لتصنيفهم الآن' : 'Tap to classify now',
                        style: TextStyle(fontSize: 11, color: WaColors.textMuted),
                      ),
                    ],
                  )),
                  Icon(
                    isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: WaColors.gold,
                  ),
                ]),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],

          const SizedBox(height: 14),

          // ── Donut ──────────────────────────────
          if (expense > 0)
            WaCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.expenseDistribution,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(l10n.currentMonth,
                  style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
                const SizedBox(height: 14),
                _DonutChart(txs: mTxs, ap: ap),
              ]),
            ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 12),

          // ── Expense Trend Line ─────────────────
          if (mTxs.isNotEmpty)
            WaCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? 'اتجاه المصاريف' : 'Expense Trend',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${_monthName(l10n, month.month)} ${month.year}',
                  style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
                const SizedBox(height: 14),
                SizedBox(height: 130, child: _TrendChart(txs: mTxs, ap: ap, month: month)),
              ]),
            ).animate(delay: 120.ms).fadeIn(),

          const SizedBox(height: 12),

          // ── Bar Chart ──────────────────────────
          WaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.expensesAndIncome,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(l10n.last6Months,
                style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
              const SizedBox(height: 14),
              SizedBox(height: 155, child: _BarChart(ap: ap, l10n: l10n)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legend(WaColors.danger,  l10n.expenses),
                const SizedBox(width: 20),
                _legend(WaColors.success, l10n.incomes),
              ]),
            ]),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 12),

          // ── Recent ─────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(l10n.latestTransactions,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(l10n.transactionCount(ap.transactions.length),
              style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
          ]),
          const SizedBox(height: 8),

          ap.transactions.isEmpty
              ? _emptyState(l10n)
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

  String _dateLabel(AppLocalizations l10n, bool isAr) {
    final n = DateTime.now();
    final months = l10n.months;
    final days   = l10n.days;
    return '${days[n.weekday % 7]}، ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  String _monthName(AppLocalizations l10n, int m) => l10n.months[m - 1];

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: WaColors.textSecondary)),
  ]);

  Widget _emptyState(AppLocalizations l10n) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('💸', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(l10n.noTransactions,
          textAlign: TextAlign.center,
          style: const TextStyle(color: WaColors.textMuted, fontSize: 13)),
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
  final AppLocalizations l10n;
  const _BarChart({required this.ap, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthNames = l10n.months;
    final months = List.generate(6, (i) {
      final d   = DateTime(now.year, now.month - 5 + i);
      final txs = ap.txForMonth(d.year, d.month);
      return (
        label  : monthNames[d.month - 1].substring(0, 3),
        expense: ap.totalExpense(txs),
        income : ap.totalIncome(txs),
      );
    });
    final maxY = months.expand((m) => [m.expense, m.income])
        .fold<double>(1, (a, v) => v > a ? v : a);

    // Format value for tooltip: 2 decimal places, abbreviate if large
    String fmtVal(double v) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
      if (v >= 1000)    return '${(v / 1000).toStringAsFixed(2)}K';
      return v.toStringAsFixed(2);
    }

    const barW = 14.0;
    const barRadius = BorderRadius.only(
      topLeft : Radius.circular(5),
      topRight: Radius.circular(5),
    );

    return BarChart(BarChartData(
      maxY      : maxY * 1.22,
      gridData  : FlGridData(show: true, drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: WaColors.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => WaColors.obsidian2,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          getTooltipItem: (group, _, rod, rodIndex) {
            final isExpense = rodIndex == 0;
            final color = isExpense ? WaColors.danger : WaColors.success;
            final label = isExpense
                ? (ap.locale.languageCode == 'ar' ? 'مصاريف' : 'Expenses')
                : (ap.locale.languageCode == 'ar' ? 'مداخيل' : 'Income');
            return BarTooltipItem(
              '$label\n',
              TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: fmtVal(rod.toY),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          getTitlesWidget: (v, _) {
            final i = v.round();
            if (i < 0 || i >= 6) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(months[i].label,
                style: const TextStyle(fontSize: 9, color: WaColors.textMuted)));
          },
        )),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles   : true,
          reservedSize : 46,
          interval     : maxY / 4,
          getTitlesWidget: (v, _) {
            if (v == 0) return const SizedBox();
            final lbl = v >= 1000000
                ? '${(v / 1000000).toStringAsFixed(1)}M'
                : v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}K'
                    : v.toInt().toString();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(lbl,
                style: const TextStyle(fontSize: 9, color: WaColors.textMuted),
                textAlign: TextAlign.right),
            );
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: List.generate(6, (i) => BarChartGroupData(
        x: i,
        groupVertically: false,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY         : months[i].expense,
            color       : WaColors.danger.withValues(alpha: 0.85),
            width       : barW,
            borderRadius: barRadius,
            backDrawRodData: BackgroundBarChartRodData(
              show : true,
              toY  : maxY * 1.22,
              color: WaColors.danger.withValues(alpha: 0.06),
            ),
          ),
          BarChartRodData(
            toY         : months[i].income,
            color       : WaColors.success.withValues(alpha: 0.85),
            width       : barW,
            borderRadius: barRadius,
            backDrawRodData: BackgroundBarChartRodData(
              show : true,
              toY  : maxY * 1.22,
              color: WaColors.success.withValues(alpha: 0.06),
            ),
          ),
        ],
      )),
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
    final lang   = ap.locale.languageCode;
    final bycat  = ap.expenseByCategory(txs);
    final total  = bycat.values.fold<double>(0, (a, v) => a + v);
    if (total == 0) return const SizedBox();
    final sorted = (bycat.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

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
                Container(width: 9, height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Expanded(child: Text(cat?.localizedLabel(lang) ?? e.key,
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

// ── Trend Line Chart ──────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  final List<TxModel> txs;
  final AppProvider   ap;
  final DateTime      month;
  const _TrendChart({required this.txs, required this.ap, required this.month});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final today       = DateTime.now();
    final lastDay     = (month.year == today.year && month.month == today.month)
        ? today.day : daysInMonth;

    // Accumulate daily expenses
    final daily = List<double>.filled(daysInMonth + 1, 0);
    for (final tx in txs.where((t) => t.isExpense)) {
      final d = DateTime.tryParse(tx.date);
      if (d != null && d.day >= 1 && d.day <= daysInMonth) {
        daily[d.day] += tx.amount;
      }
    }

    // Build cumulative spending per day (only up to today)
    double cumulative = 0;
    final spots = <FlSpot>[];
    for (int day = 1; day <= lastDay; day++) {
      cumulative += daily[day];
      spots.add(FlSpot(day.toDouble(), cumulative));
    }

    if (spots.isEmpty) return const SizedBox();

    final maxY = spots.map((s) => s.y).fold<double>(1, (a, v) => v > a ? v : a);

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: daysInMonth.toDouble(),
        minY: 0,
        maxY: maxY * 1.25,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: WaColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => WaColors.obsidian2,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (spots) => spots.map((s) {
              final isAr = ap.locale.languageCode == 'ar';
              final dayLabel = isAr ? 'يوم ${s.x.round()}' : 'Day ${s.x.round()}';
              final val = s.y >= 1000000
                  ? '${(s.y / 1000000).toStringAsFixed(2)}M'
                  : s.y >= 1000
                      ? '${(s.y / 1000).toStringAsFixed(2)}K'
                      : s.y.toStringAsFixed(2);
              return LineTooltipItem(
                '$dayLabel\n',
                const TextStyle(
                    color: WaColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(
                    text: val,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              );
            }).toList(),
          ),
          getTouchedSpotIndicator: (data, indices) => indices.map((i) =>
            TouchedSpotIndicatorData(
              FlLine(color: WaColors.danger.withValues(alpha: 0.5), strokeWidth: 1.5,
                  dashArray: [4, 4]),
              FlDotData(getDotPainter: (_, __, ___, ____) =>
                FlDotCirclePainter(radius: 5, color: WaColors.danger,
                    strokeWidth: 2, strokeColor: Colors.white)),
            )).toList(),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: maxY / 3,
            getTitlesWidget: (v, _) {
              if (v == 0) return const SizedBox();
              final lbl = v >= 1000000
                  ? '${(v / 1000000).toStringAsFixed(1)}M'
                  : v >= 1000
                      ? '${(v / 1000).toStringAsFixed(0)}K'
                      : v.toInt().toString();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(lbl,
                  style: const TextStyle(fontSize: 9, color: WaColors.textMuted),
                  textAlign: TextAlign.right),
              );
            },
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 18,
            interval: (daysInMonth / 4).roundToDouble(),
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: const TextStyle(fontSize: 9, color: WaColors.textMuted),
            ),
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: WaColors.danger,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end  : Alignment.bottomCenter,
                colors: [
                  WaColors.danger.withValues(alpha: 0.25),
                  WaColors.danger.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
