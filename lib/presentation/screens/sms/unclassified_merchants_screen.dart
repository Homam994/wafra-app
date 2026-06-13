// ════════════════════════════════════════════════════════════
//  UnclassifiedMerchantsScreen — تصنيف التجار الجدد دفعةً واحدة
// ════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/sms_models.dart';
import '../../../providers/sms_provider.dart';
import '../../widgets/common/wa_card.dart';

class UnclassifiedMerchantsScreen extends StatelessWidget {
  const UnclassifiedMerchantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sms = context.watch<SmsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تجار بدون تصنيف'),
        actions: [
          if (sms.unclassified.isNotEmpty)
            TextButton(
              onPressed: () => _dismissAll(context, sms),
              child: const Text('تجاهل الكل',
                style: TextStyle(color: WaColors.textMuted, fontSize: 13)),
            ),
        ],
      ),
      body: sms.unclassified.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // إرشاد
                Container(
                  padding: const EdgeInsets.all(12),
                  margin : const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color : WaColors.gold.withValues(alpha: 0.08),
                    border: Border.all(color: WaColors.gold.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Text('💡', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'صنّف كل تاجر مرة واحدة — سيُطبَّق تلقائياً على كل معاملاته القادمة',
                      style: TextStyle(fontSize: 12, color: WaColors.gold, height: 1.5),
                    )),
                  ]),
                ),

                // قائمة التجار
                ...sms.unclassified.asMap().entries.map((e) =>
                  _MerchantCard(
                    merchant: e.value,
                    onClassify: (catId) =>
                        sms.classifyMerchant(e.value.name, catId),
                    onDismiss: () => sms.dismissMerchant(e.value.name),
                  ).animate().fadeIn(
                    delay   : Duration(milliseconds: e.key * 60),
                    duration: 300.ms,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
      Text('🎉', style: TextStyle(fontSize: 52)),
      SizedBox(height: 12),
      Text('كل التجار مُصنَّفون!',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('لا يوجد تجار ينتظرون التصنيف',
        style: TextStyle(fontSize: 13, color: WaColors.textMuted)),
    ]),
  );

  Future<void> _dismissAll(BuildContext context, SmsProvider sms) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : const Text('تجاهل الكل'),
        content: const Text('سيتم حذف جميع التجار من القائمة بدون تصنيف'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: const Text('تجاهل الكل')),
        ],
      ),
    );
    if (ok == true) {
      for (final m in List.from(sms.unclassified)) {
        await sms.dismissMerchant(m.name);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════
//  بطاقة تاجر واحد مع اختيار التصنيف
// ══════════════════════════════════════════════════════════
class _MerchantCard extends StatefulWidget {
  final UnclassifiedMerchant merchant;
  final ValueChanged<String>  onClassify;
  final VoidCallback          onDismiss;

  const _MerchantCard({
    required this.merchant,
    required this.onClassify,
    required this.onDismiss,
  });

  @override
  State<_MerchantCard> createState() => _MerchantCardState();
}

class _MerchantCardState extends State<_MerchantCard> {
  String? _selectedCat;
  bool    _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.merchant.txType == 'expense';
    final cats      = isExpense ? kExpenseCategories : kIncomeCategories;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WaCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (isExpense ? WaColors.danger : WaColors.success)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(
                isExpense ? '🏪' : '💼',
                style: const TextStyle(fontSize: 20),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.merchant.name,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    isExpense ? '📤 مصروف' : '📥 دخل',
                    style: TextStyle(
                      fontSize: 11,
                      color: isExpense ? WaColors.danger : WaColors.success,
                    ),
                  ),
                  const Text(' · ',
                    style: TextStyle(color: WaColors.textMuted, fontSize: 11)),
                  Text(
                    '${widget.merchant.count} معاملة',
                    style: const TextStyle(
                      fontSize: 11, color: WaColors.textMuted),
                  ),
                  const Text(' · ',
                    style: TextStyle(color: WaColors.textMuted, fontSize: 11)),
                  Text(
                    '${widget.merchant.lastAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11, color: WaColors.textMuted),
                  ),
                ]),
              ],
            )),
            // زر تجاهل
            IconButton(
              icon   : const Icon(Icons.close, size: 18),
              color  : WaColors.textMuted,
              onPressed: widget.onDismiss,
              tooltip: 'تجاهل',
            ),
          ]),

          const SizedBox(height: 12),

          // ── اختيار التصنيف ────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color : _selectedCat != null
                    ? WaColors.gold.withValues(alpha: 0.1)
                    : WaColors.obsidian3,
                border: Border.all(
                  color: _selectedCat != null
                      ? WaColors.gold.withValues(alpha: 0.4)
                      : WaColors.border,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                if (_selectedCat != null) ...[
                  Text(
                    cats.firstWhere(
                      (c) => c.id == _selectedCat,
                      orElse: () => cats.first,
                    ).emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cats.firstWhere(
                      (c) => c.id == _selectedCat,
                      orElse: () => cats.first,
                    ).label,
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: WaColors.gold),
                  ),
                ] else
                  const Text('اختر التصنيف...',
                    style: TextStyle(
                      fontSize: 13, color: WaColors.textMuted)),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: WaColors.textMuted, size: 20,
                ),
              ]),
            ),
          ),

          // ── شبكة التصنيفات (عند التوسع) ──────────────
          if (_expanded) ...[
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount  : 4,
              crossAxisSpacing: 6,
              mainAxisSpacing : 6,
              shrinkWrap      : true,
              physics         : const NeverScrollableScrollPhysics(),
              children        : cats.map((cat) {
                final isSel = _selectedCat == cat.id;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCat = cat.id;
                    _expanded    = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color : isSel
                          ? WaColors.gold.withValues(alpha: 0.15)
                          : WaColors.obsidian3,
                      border: Border.all(
                        color: isSel
                            ? WaColors.gold.withValues(alpha: 0.6)
                            : WaColors.border,
                        width: isSel ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.emoji,
                          style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 3),
                        Text(cat.label,
                          style: TextStyle(
                            fontSize  : 9,
                            color     : isSel
                                ? WaColors.gold
                                : WaColors.textMuted,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          maxLines : 2,
                          overflow : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // ── زر الحفظ ─────────────────────────────────
          if (_selectedCat != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onClassify(_selectedCat!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WaColors.gold,
                  foregroundColor: WaColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('💾 حفظ التصنيف',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      )),
    );
  }
}
