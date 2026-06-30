import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../home/home_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap   = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedAnalytics),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu(),
        )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailyAvgSection(ap: ap).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          _SalaryDistSection(ap: ap).animate(delay: 60.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          _MonthCompareSection(ap: ap).animate(delay: 120.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          _ProjectionSection(ap: ap).animate(delay: 180.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          _BestWorstSection(ap: ap).animate(delay: 240.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          _WeekdaySection(ap: ap).animate(delay: 300.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── 1. Daily Average ─────────────────────────────────────────
class _DailyAvgSection extends StatelessWidget {
  final AppProvider ap;
  const _DailyAvgSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final isAr = ap.locale.languageCode == 'ar';
    final data  = ap.dailyAvgComparison();
    final diff  = data.thisWeek - data.lastWeek;
    final isMore = diff > 0;
    final pct   = data.lastWeek > 0 ? (diff.abs() / data.lastWeek * 100).round() : 0;

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '📅 متوسط الإنفاق اليومي' : '📅 Daily Spending Average',
        isAr ? 'هذا الأسبوع مقارنةً بالماضي' : 'This week vs last week',
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricBox(
          label: isAr ? 'هذا الأسبوع' : 'This Week',
          value: ap.fmt(data.thisWeek), color: WaColors.gold)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(
          label: isAr ? 'الأسبوع الماضي' : 'Last Week',
          value: ap.fmt(data.lastWeek), color: WaColors.textMuted)),
      ]),
      if (data.lastWeek > 0) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(isMore ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: isMore ? WaColors.danger : WaColors.success, size: 16),
          const SizedBox(width: 4),
          Expanded(child: Text(
            isMore
                ? (isAr ? 'إنفاقك اليومي أعلى بنسبة $pct% عن الأسبوع الماضي'
                         : 'Daily spending is $pct% higher than last week')
                : (isAr ? 'إنفاقك اليومي أقل بنسبة $pct% عن الأسبوع الماضي'
                         : 'Daily spending is $pct% lower than last week'),
            style: TextStyle(fontSize: 12,
                color: isMore ? WaColors.danger : WaColors.success),
          )),
        ]),
      ],
    ]));
  }
}

// ── 2. Salary Distribution ───────────────────────────────────
class _SalaryDistSection extends StatelessWidget {
  final AppProvider ap;
  const _SalaryDistSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final isAr = ap.locale.languageCode == 'ar';
    final data = ap.salaryDistribution();

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '💰 أين يذهب راتبك؟' : '💰 Where Does Your Money Go?',
        isAr ? 'نسبة كل تصنيف من دخل هذا الشهر' : 'Each category\'s share of this month\'s income',
      ),
      const SizedBox(height: 14),
      if (data.isEmpty)
        _EmptyHint(isAr ? 'لا توجد بيانات كافية هذا الشهر' : 'Not enough data this month')
      else
        ...data.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13))),
              Text(ap.fmt(item.amount),
                  style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
              const SizedBox(width: 8),
              Text('${item.pct.round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: item.pct > 30 ? WaColors.danger : WaColors.gold)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.pct / 100).clamp(0, 1), minHeight: 6,
                backgroundColor: WaColors.border,
                valueColor: AlwaysStoppedAnimation(
                    item.pct > 30 ? WaColors.danger : WaColors.gold),
              ),
            ),
          ]),
        )),
    ]));
  }
}

// ── 3. Month Comparison ──────────────────────────────────────
class _MonthCompareSection extends StatelessWidget {
  final AppProvider ap;
  const _MonthCompareSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final isAr    = ap.locale.languageCode == 'ar';
    final data    = ap.monthVsLastMonth();
    final now     = DateTime.now();
    final months  = AppLocalizations.of(context).months;
    final curName  = months[now.month - 1];
    final prevName = months[DateTime(now.year, now.month - 1).month - 1];

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '📊 مقارنة الأشهر' : '📊 Month Comparison',
        isAr ? '$curName مقارنةً بـ $prevName' : '$curName vs $prevName',
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricBox(label: curName, value: ap.fmt(data.current),
            color: data.isMore ? WaColors.danger : WaColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(label: prevName, value: ap.fmt(data.previous),
            color: WaColors.textMuted)),
      ]),
      if (data.previous > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (data.isMore ? WaColors.danger : WaColors.success).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: (data.isMore ? WaColors.danger : WaColors.success).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(data.isMore ? Icons.trending_up : Icons.trending_down,
                color: data.isMore ? WaColors.danger : WaColors.success, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(
              data.isMore
                  ? (isAr ? 'أنفقت أكثر بنسبة ${data.changePct.round()}% عن الشهر الماضي'
                           : 'You spent ${data.changePct.round()}% more than last month')
                  : (isAr ? 'أنفقت أقل بنسبة ${data.changePct.round()}% عن الشهر الماضي 🎉'
                           : 'You spent ${data.changePct.round()}% less than last month 🎉'),
              style: TextStyle(fontSize: 13,
                  color: data.isMore ? WaColors.danger : WaColors.success,
                  fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ],
    ]));
  }
}

// ── 4. Projection ────────────────────────────────────────────
class _ProjectionSection extends StatelessWidget {
  final AppProvider ap;
  const _ProjectionSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = ap.locale.languageCode == 'ar';
    final data = ap.monthProjection();
    final pct  = data.projected > 0
        ? (data.sofar / data.projected).clamp(0.0, 1.0) : 0.0;

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '🔮 توقع نهاية الشهر' : '🔮 Month-End Projection',
        isAr ? 'بناءً على معدل إنفاقك · تبقى ${data.daysLeft} يوم'
             : 'Based on your spending rate · ${data.daysLeft} days left',
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricBox(
          label: isAr ? 'أنفقت حتى الآن' : 'Spent So Far',
          value: ap.fmt(data.sofar), color: WaColors.gold)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(
          label: isAr ? 'المتوقع بالنهاية' : 'Projected Total',
          value: ap.fmt(data.projected), color: WaColors.info)),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l10n.monthProgress,
            style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
        Text('${(pct * 100).round()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 8, backgroundColor: WaColors.border,
          valueColor: AlwaysStoppedAnimation(pct > 0.8 ? WaColors.danger : WaColors.gold),
        ),
      ),
    ]));
  }
}

// ── 5. Best & Worst Month ────────────────────────────────────
class _BestWorstSection extends StatelessWidget {
  final AppProvider ap;
  const _BestWorstSection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final isAr = ap.locale.languageCode == 'ar';
    final data = ap.bestAndWorstMonth();

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '🏆 أفضل وأسوأ شهر' : '🏆 Best & Worst Month',
        isAr ? 'خلال آخر 12 شهراً' : 'Over the last 12 months',
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricBox(
          label: isAr ? '🟢 أقل إنفاقاً\n${data.bestMonth}' : '🟢 Least Spent\n${data.bestMonth}',
          value: ap.fmt(data.bestAmt), color: WaColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _MetricBox(
          label: isAr ? '🔴 أكثر إنفاقاً\n${data.worstMonth}' : '🔴 Most Spent\n${data.worstMonth}',
          value: ap.fmt(data.worstAmt), color: WaColors.danger)),
      ]),
      if (data.bestAmt > 0 && data.worstAmt > 0) ...[
        const SizedBox(height: 10),
        Text(
          isAr
              ? 'الفرق: ${ap.fmt(data.worstAmt - data.bestAmt)} بين أعلى وأدنى شهر'
              : 'Difference: ${ap.fmt(data.worstAmt - data.bestAmt)} between highest and lowest',
          style: TextStyle(fontSize: 12, color: WaColors.textMuted),
        ),
      ],
    ]));
  }
}

// ── 6. Spending by Weekday ───────────────────────────────────
class _WeekdaySection extends StatelessWidget {
  final AppProvider ap;
  const _WeekdaySection({required this.ap});

  @override
  Widget build(BuildContext context) {
    final isAr  = ap.locale.languageCode == 'ar';
    final data  = ap.spendingByWeekday();
    final maxVal = data.map((d) => d.total).fold<double>(1, (a, v) => v > a ? v : a);
    final topDay = data.reduce((a, b) => a.total > b.total ? a : b);

    return WaCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
        isAr ? '📆 إنفاقك حسب اليوم' : '📆 Spending by Day of Week',
        isAr ? 'أكثر يوم: ${topDay.day} — ${ap.fmt(topDay.total)}'
             : 'Highest: ${topDay.day} — ${ap.fmt(topDay.total)}',
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 140,
        child: BarChart(BarChartData(
          maxY: maxVal * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= data.length) return const SizedBox();
                final short = data[i].day.length > 3
                    ? data[i].day.substring(0, 3) : data[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(short, style: TextStyle(
                    fontSize: 9,
                    color: data[i].total == topDay.total ? WaColors.gold : WaColors.textMuted,
                    fontWeight: data[i].total == topDay.total ? FontWeight.w700 : FontWeight.normal,
                  )),
                );
              },
            )),
            leftTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles   : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(data.length, (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: data[i].total,
              color: data[i].total == topDay.total
                  ? WaColors.gold : WaColors.gold.withValues(alpha: 0.35),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ])),
        )),
      ),
    ]));
  }
}

// ── Shared Helpers ────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      Text(subtitle, style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
    ],
  );
}

class _MetricBox extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _MetricBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: WaColors.textMuted, height: 1.4)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _EmptyHint extends StatelessWidget {
  final String msg;
  const _EmptyHint(this.msg);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg, style: TextStyle(fontSize: 13, color: WaColors.textMuted)),
  );
}
