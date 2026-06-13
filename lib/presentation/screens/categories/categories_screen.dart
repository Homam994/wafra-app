import '../home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap     = context.watch<AppProvider>();
    final txs    = ap.transactions.where((t) => t.isExpense).toList();
    final total  = ap.totalExpense(txs);
    final bycat  = ap.expenseByCategory(txs);
    final sorted = bycat.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليل التصنيفات'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => MenuOpener.of(context)?.onMenu(),
          ),
        ),
      ),
      body: sorted.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('📊', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('لا توجد بيانات بعد',
                  style: TextStyle(color: WaColors.textMuted, fontSize: 14)),
            ]))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المصاريف حسب التصنيف',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${txs.length} معاملة · ${ap.fmt(total)} إجمالاً',
                        style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                      const SizedBox(height: 16),
                      ...sorted.asMap().entries.map((e) =>
                        _CatRow(
                          catId : e.value.key,
                          amount: e.value.value,
                          total : total,
                          txs   : txs,
                          ap    : ap,
                        ).animate(delay: (e.key * 50).ms).fadeIn(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

class _CatRow extends StatefulWidget {
  final String catId;
  final double amount, total;
  final List txs;
  final AppProvider ap;
  const _CatRow({required this.catId, required this.amount, required this.total,
      required this.txs, required this.ap});

  @override
  State<_CatRow> createState() => _CatRowState();
}

class _CatRowState extends State<_CatRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cat   = findCategory(widget.catId, 'expense');
    final color = WaColors.catColor(widget.catId);
    final pct   = widget.total > 0 ? widget.amount / widget.total : 0.0;

    // Subcategory breakdown
    final subs = <String, double>{};
    for (final tx in widget.txs.where((t) => t.cat == widget.catId)) {
      final key = tx.sub.isNotEmpty ? tx.sub : 'أخرى';
      subs[key] = (subs[key] ?? 0) + tx.amount;
    }
    final subsSorted = subs.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(cat?.emoji ?? '•', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat?.label ?? widget.catId,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Row(children: [
                            Text(widget.ap.fmt(widget.amount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18, color: WaColors.textMuted),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0), minHeight: 5,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? WaColors.obsidian3 : const Color(0xFFEDE9E0),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Expanded subcats
          if (_expanded && subsSorted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 34, top: 8),
              child: Column(
                children: subsSorted.map((e) {
                  final subPct = widget.amount > 0 ? e.value / widget.amount : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.key,
                            style: TextStyle(fontSize: 12, color: WaColors.textSecondary)),
                        ),
                        Text(widget.ap.fmt(e.value),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${(subPct * 100).round()}%',
                          style: TextStyle(fontSize: 11, color: WaColors.textMuted)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn(duration: 200.ms),

          const Divider(height: 20),
        ],
      ),
    );
  }
}
