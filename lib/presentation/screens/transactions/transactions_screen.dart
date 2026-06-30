import '../home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../../widgets/transaction/tx_list_item.dart';
import '../../widgets/transaction/add_transaction_sheet.dart';
import '../../../generated/l10n/app_localizations.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  String _filter = 'all', _search = '', _dateFrom = '', _dateTo = '';

  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  List<TxModel> _filtered(List<TxModel> all) {
    var l = all;
    if (_filter == 'income')  l = l.where((t) => t.isIncome).toList();
    if (_filter == 'expense') l = l.where((t) => t.isExpense).toList();
    if (_dateFrom.isNotEmpty) l = l.where((t) {
      final d = DateTime.tryParse(t.date) ?? DateTime.now();
      final f = DateTime.tryParse(_dateFrom) ?? DateTime.now();
      return !d.isBefore(f);
    }).toList();
    if (_dateTo.isNotEmpty) l = l.where((t) {
      final d = DateTime.tryParse(t.date) ?? DateTime.now();
      final f = DateTime.tryParse(_dateTo) ?? DateTime.now();
      return !d.isAfter(f);
    }).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      l = l.where((t) =>
        t.note.toLowerCase().contains(q) || t.sub.toLowerCase().contains(q) ||
        t.cat.contains(q) || t.amount.toString().contains(q) ||
        t.date.contains(q)).toList();
    }
    return l;
  }

  void _resetPagination() => setState(() => _visibleCount = _pageSize);

  @override
  Widget build(BuildContext context) {
    // ✅ ألوان تتبع الثيم
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);
    final chipBg  = isDark ? WaColors.obsidian3 : const Color(0xFFEDE9E0);

    final ap       = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered(ap.transactions);
    final visible  = filtered.take(_visibleCount).toList();
    final hasMore  = filtered.length > _visibleCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allTransactions),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => MenuOpener.of(context)?.onMenu()),
        actions: [IconButton(
          icon: const Icon(Icons.add, color: WaColors.gold),
          onPressed: () => showModalBottomSheet(context: context,
              isScrollControlled: true, backgroundColor: Colors.transparent,
              builder: (_) => const AddTransactionSheet()),
        )],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(children: [
            // ✅ حقل البحث بخلفية الثيم
            TextField(
              controller: _searchCtrl,
              onChanged : (v) { setState(() => _search = v); _resetPagination(); },
              decoration: InputDecoration(
                hintText  : l10n.search,
                filled    : true,
                fillColor : fieldBg,
                prefixIcon: const Icon(Icons.search,
                    color: WaColors.textMuted, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            // ✅ حقلا التاريخ بخلفية الثيم
            Row(children: [
              _dateField(
                  l10n.date + (ap.locale.languageCode == 'ar' ? ' من' : ' from'),
                  _dateFrom, (v) => setState(() => _dateFrom = v), fieldBg),
              const SizedBox(width: 8),
              _dateField(
                  l10n.date + (ap.locale.languageCode == 'ar' ? ' إلى' : ' to'),
                  _dateTo, (v) => setState(() => _dateTo = v), fieldBg),
              if (_dateFrom.isNotEmpty || _dateTo.isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: WaColors.danger),
                  onPressed: () =>
                      setState(() { _dateFrom = ''; _dateTo = ''; }),
                  style: IconButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _chip(l10n.all,     'all',     chipBg),
              const SizedBox(width: 6),
              _chip(l10n.incomes, 'income',  chipBg),
              const SizedBox(width: 6),
              _chip(l10n.expenses, 'expense', chipBg),
              const Spacer(),
              Text(l10n.transactionCount(filtered.length),
                style: const TextStyle(
                    fontSize: 11, color: WaColors.textMuted)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min, children: [
                  Text('🔍', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text(l10n.noResults,
                      style: TextStyle(
                          color: WaColors.textMuted, fontSize: 14)),
                ]))
              : WaCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    controller     : _scrollCtrl,
                    padding        : const EdgeInsets.symmetric(horizontal: 16),
                    itemCount      : visible.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder    : (_, i) {
                      if (i == visible.length) {
                        // مؤشر تحميل في الأسفل
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WaColors.gold,
                              )),
                          ),
                        );
                      }
                      return TxListItem(tx: visible[i]);
                    },
                  ),
                ).animate().fadeIn(duration: 300.ms),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _chip(String label, String val, Color bg) {
    final active = _filter == val;
    return GestureDetector(
      onTap: () { setState(() => _filter = val); _resetPagination(); },
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? WaColors.gold.withValues(alpha: 0.14) : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? WaColors.goldDim : WaColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? WaColors.goldLight : WaColors.textSecondary)),
      ),
    );
  }

  Widget _dateField(String hint, String val,
      ValueChanged<String> onChange, Color bg) =>
    Expanded(child: GestureDetector(
      onTap: () async {
        final locale = context.read<AppProvider>().locale;
        final p = await showDatePicker(
          context    : context,
          locale     : locale,
          initialDate: val.isNotEmpty
              ? (DateTime.tryParse(val) ?? DateTime.now()) : DateTime.now(),
          firstDate: DateTime(2000), lastDate: DateTime(2100),
        );
        if (p != null) onChange(p.toIso8601String().split('T').first);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg,                              // ✅ ثيم
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WaColors.border)),
        child: Text(val.isNotEmpty ? val : hint,
          style: TextStyle(fontSize: 12,
            color: val.isNotEmpty ? null : WaColors.textMuted)),
      ),
    ));
}
