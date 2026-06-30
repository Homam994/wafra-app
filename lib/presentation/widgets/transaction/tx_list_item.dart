import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import 'add_transaction_sheet.dart';
import '../../../generated/l10n/app_localizations.dart';

class TxListItem extends StatelessWidget {
  final TxModel tx;
  final bool    showActions;
  const TxListItem({super.key, required this.tx, this.showActions = true});

  @override
  Widget build(BuildContext context) {
    final lang  = context.read<AppProvider>().locale.languageCode;
    final ap    = context.watch<AppProvider>();
    final cat   = findCategory(tx.cat, tx.isIncome ? 'income' : 'expense');
    final color = WaColors.catColor(tx.cat);
    // Translate sub-category: stored in Arabic, find matching WaSubCategory
    final subLabel = tx.sub.isNotEmpty
        ? (cat?.subs.cast<WaSubCategory?>().firstWhere(
              (s) => s?.label == tx.sub, orElse: () => null)
            ?.localizedLabel(lang) ?? tx.sub)
        : '';

    // الصف الأساسي
    Widget row = InkWell(
      onTap: showActions ? () => _openEdit(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          // أيقونة
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(cat?.emoji ?? '💸',
                style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // معلومات
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subLabel.isNotEmpty ? subLabel : (cat?.localizedLabel(lang) ?? tx.cat),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${cat?.localizedLabel(lang) ?? tx.cat}'
                '${tx.note.isNotEmpty ? " · ${tx.note}" : ""}'
                ' · ${_fmtDate(tx.date, lang)}',
                style: const TextStyle(fontSize: 11, color: WaColors.textMuted),
                overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: 8),
          // المبلغ
          Text(
            '${tx.isIncome ? "+" : "-"}${ap.fmt(tx.amount)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: tx.isIncome ? WaColors.success : WaColors.danger),
          ),
          // ── زر الحذف ──────────────────────────
          if (showActions) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: WaColors.textMuted,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: context.read<AppProvider>().locale.languageCode == 'ar' ? 'حذف' : 'Delete',
              onPressed: () => _confirmDelete(context, ap),
            ),
          ],
        ]),
      ),
    );

    if (!showActions) return row;

    // Swipe لليسار للحذف السريع
    return Dismissible(
      key       : Key(tx.id),
      direction : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding  : const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: WaColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.delete_outline, color: WaColors.danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title  : Text(AppLocalizations.of(context).deleteTransaction),
            content: Text(AppLocalizations.of(context).deleteTransactionConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context).cancel)),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: WaColors.danger),
                child: Text(AppLocalizations.of(context).delete),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => ap.deleteTx(tx.id),
      child: row,
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, AppProvider ap) async {
    final l10n = AppLocalizations.of(ctx);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title  : Text(l10n.deleteTransaction),
        content: Text(l10n.deleteTransactionConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) ap.deleteTx(tx.id);
  }

  void _openEdit(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: AddTransactionSheet(editing: tx),
    ),
  );

  String _fmtDate(String date, String lang) {
    final d = DateTime.tryParse(date); if (d == null) return date;
    final m = lang == 'en'
        ? ['January','February','March','April','May','June',
           'July','August','September','October','November','December']
        : ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
           'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]}';
  }
}
