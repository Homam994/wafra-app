import '../home/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../../widgets/transaction/tx_list_item.dart';
import '../../widgets/transaction/add_transaction_sheet.dart';
import '../../../generated/l10n/app_localizations.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap   = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);
    final txs  = ap.transactions.where((t) => t.isExpense).toList();
    final bycat= ap.expenseByCategory(txs);
    final total= ap.totalExpense(txs);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => MenuOpener.of(context)?.onMenu(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: WaColors.gold),
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddTransactionSheet(forceType: TxType.expense),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics   : const NeverScrollableScrollPhysics(),
            crossAxisCount  : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing : 10,
            childAspectRatio: 2.2,
            children: kExpenseCategories.map((cat) {
              final amt = bycat[cat.id] ?? 0;
              return _CatCard(cat: cat, amount: amt, currency: ap.currency, total: total)
                  .animate().fadeIn(duration: 300.ms);
            }).toList(),
          ),
          const SizedBox(height: 16),
          WaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.expenseHistory,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('${txs.length} معاملة',
                      style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                if (txs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('📊', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(l10n.noExpenses,
                          style: const TextStyle(color: WaColors.textMuted, fontSize: 13)),
                    ])),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics   : const NeverScrollableScrollPhysics(),
                    itemCount : txs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => TxListItem(tx: txs[i]),
                  ),
              ],
            ),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  final WaCategory cat;
  final double amount, total;
  final String currency;
  const _CatCard({required this.cat, required this.amount, required this.total, required this.currency});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment : MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(child: Text(cat.label,
              style: TextStyle(fontSize: 12, color: WaColors.textSecondary),
              overflow: TextOverflow.ellipsis)),
          ]),
          Text('${amount.toStringAsFixed(0)} $currency',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: WaColors.danger, fontFeatures: const [FontFeature.tabularFigures()])),
          if (total > 0)
            LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0), minHeight: 3,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? WaColors.obsidian3 : const Color(0xFFEDE9E0),
              valueColor: AlwaysStoppedAnimation(cat.color),
            ),
        ],
      ),
    );
  }
}
