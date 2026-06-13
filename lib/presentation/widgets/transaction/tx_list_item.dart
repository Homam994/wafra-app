import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import 'add_transaction_sheet.dart';

class TxListItem extends StatelessWidget {
  final TxModel tx;
  final bool    showActions;
  const TxListItem({super.key, required this.tx, this.showActions = true});

  @override
  Widget build(BuildContext context) {
    final ap    = context.watch<AppProvider>();
    final cat   = findCategory(tx.cat, tx.isIncome ? 'income' : 'expense');
    final color = WaColors.catColor(tx.cat);

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
                tx.sub.isNotEmpty ? tx.sub : (cat?.label ?? tx.cat),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${cat?.label ?? tx.cat}'
                '${tx.note.isNotEmpty ? " · ${tx.note}" : ""}'
                ' · ${_fmtDate(tx.date)}',
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
              tooltip: 'حذف',
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
            title  : const Text('حذف المعاملة'),
            content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: WaColors.danger),
                child: const Text('حذف'),
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
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title  : const Text('حذف المعاملة'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: const Text('حذف'),
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

  String _fmtDate(String date) {
    final d = DateTime.tryParse(date); if (d == null) return date;
    const m = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]}';
  }
}
