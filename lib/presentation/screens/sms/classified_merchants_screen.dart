import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../providers/sms_provider.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';

/// شاشة عرض التجار الذين سبق تصنيفهم، مع إمكانية تغيير
/// تصنيفهم (الأساسي والفرعي) أو إزالة التصنيف بالكامل.
class ClassifiedMerchantsScreen extends StatelessWidget {
  const ClassifiedMerchantsScreen({super.key});

  static WaCategory? _findCat(String id) {
    for (final c in [...kExpenseCategories, ...kIncomeCategories]) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sms  = context.watch<SmsProvider>();
    final isAr = context.watch<AppProvider>().locale.languageCode == 'ar';
    final lang = isAr ? 'ar' : 'en';

    final entries = sms.merchants.all.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'التجار المصنَّفون' : 'Classified Merchants')),
      body: entries.isEmpty
        ? _EmptyState(isAr: isAr)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final name  = entries[i].key;
              final parts = entries[i].value.split('::');
              final catId = parts.first;
              final sub   = parts.length > 1 ? parts[1] : '';
              final cat   = _findCat(catId);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WaCard(child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: (cat?.color ?? WaColors.gold).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(cat?.emoji ?? '🏪',
                      style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        sub.isNotEmpty
                          ? '${cat?.localizedLabel(lang) ?? catId} · $sub'
                          : (cat?.localizedLabel(lang) ?? catId),
                        style: const TextStyle(fontSize: 12, color: WaColors.textMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: WaColors.gold),
                    tooltip: isAr ? 'تعديل التصنيف' : 'Edit category',
                    onPressed: () => _openPicker(context, sms, name, catId, sub, isAr, lang),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: WaColors.danger),
                    tooltip: isAr ? 'إزالة التصنيف' : 'Remove classification',
                    onPressed: () => _confirmRemove(context, sms, name, isAr),
                  ),
                ])),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 40), duration: 250.ms);
            },
          ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, SmsProvider sms, String name, bool isAr) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(isAr ? 'إزالة التصنيف' : 'Remove classification'),
      content: Text(isAr
        ? 'سيعود "$name" إلى قائمة التجار بدون تصنيف عند وصول رسالة جديدة منه.'
        : '"$name" will return to the unclassified list on its next message.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(isAr ? 'إلغاء' : 'Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: WaColors.danger),
          child: Text(isAr ? 'إزالة' : 'Remove')),
      ],
    ));
    if (ok == true) await sms.removeMerchantCategory(name);
  }

  void _openPicker(BuildContext context, SmsProvider sms, String name,
      String currentCat, String currentSub, bool isAr, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        merchantName: name,
        initialCat: currentCat,
        initialSub: currentSub,
        isAr: isAr,
        lang: lang,
        onConfirm: (cat, sub) => sms.classifyMerchant(name, cat, sub),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  const _EmptyState({required this.isAr});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏪', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(isAr ? 'لا يوجد تجار مصنَّفون بعد' : 'No classified merchants yet',
          style: const TextStyle(fontSize: 14, color: WaColors.textMuted),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── ورقة اختيار التصنيف (أساسي + فرعي) ─────────────────────
class _CategoryPickerSheet extends StatefulWidget {
  final String merchantName, initialCat, initialSub, lang;
  final bool isAr;
  final void Function(String cat, String sub) onConfirm;

  const _CategoryPickerSheet({
    required this.merchantName,
    required this.initialCat,
    required this.initialSub,
    required this.isAr,
    required this.lang,
    required this.onConfirm,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late bool   _isExpense;
  late String _selectedCat;
  String?     _selectedSub;

  @override
  void initState() {
    super.initState();
    _isExpense   = kExpenseCategories.any((c) => c.id == widget.initialCat) ||
                   !kIncomeCategories.any((c) => c.id == widget.initialCat);
    _selectedCat = widget.initialCat;
    _selectedSub = widget.initialSub.isNotEmpty ? widget.initialSub : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final sheetBg = isDark ? WaColors.obsidian2 : WaColors.creamWhite;
    final cats = _isExpense ? kExpenseCategories : kIncomeCategories;
    final selCat = cats.firstWhere((c) => c.id == _selectedCat, orElse: () => cats.first);

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: WaColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(widget.merchantName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // ── مصروف / دخل ──
          Row(children: [
            Expanded(child: _typeTab(widget.isAr ? 'مصروف' : 'Expense', true, fieldBg)),
            const SizedBox(width: 8),
            Expanded(child: _typeTab(widget.isAr ? 'دخل' : 'Income', false, fieldBg)),
          ]),
          const SizedBox(height: 14),

          // ── التصنيف الأساسي ──
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: cats.map((cat) {
              final isSel = cat.id == _selectedCat;
              return GestureDetector(
                onTap: () => setState(() { _selectedCat = cat.id; _selectedSub = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    color : isSel ? cat.color.withValues(alpha: 0.15) : fieldBg,
                    border: Border.all(color: isSel ? cat.color : WaColors.border,
                      width: isSel ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(cat.localizedLabel(widget.lang),
                      style: TextStyle(fontSize: 9,
                        color: isSel ? cat.color : WaColors.textMuted,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }).toList(),
          ),

          // ── التصنيف الفرعي ──
          if (selCat.subs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(widget.isAr ? 'تصنيف فرعي (اختياري)' : 'Subcategory (optional)',
              style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: WaColors.textMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: selCat.subs.map((sub) {
              final label = sub.localizedLabel(widget.lang);
              final isSel = _selectedSub == sub.label; // نخزّن دائماً بالتسمية العربية كمفتاح ثابت
              return GestureDetector(
                onTap: () => setState(() => _selectedSub = isSel ? null : sub.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? selCat.color.withValues(alpha: 0.14) : fieldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSel ? selCat.color : WaColors.border,
                      width: isSel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(sub.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 12,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                      color: isSel ? selCat.color : WaColors.textSecondary)),
                  ]),
                ),
              );
            }).toList()),
          ],

          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              widget.onConfirm(_selectedCat, _selectedSub ?? '');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WaColors.gold, foregroundColor: WaColors.obsidian,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(widget.isAr ? 'حفظ' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  Widget _typeTab(String label, bool expense, Color fieldBg) {
    final isSel = _isExpense == expense;
    return GestureDetector(
      onTap: () => setState(() {
        _isExpense   = expense;
        final list   = _isExpense ? kExpenseCategories : kIncomeCategories;
        _selectedCat = list.first.id;
        _selectedSub = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? WaColors.gold.withValues(alpha: 0.15) : fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? WaColors.gold : WaColors.border),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
            color: isSel ? WaColors.gold : WaColors.textSecondary)),
      ),
    );
  }
}
