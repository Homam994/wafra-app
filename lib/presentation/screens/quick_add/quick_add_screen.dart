import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/firestore_repo.dart';
import '../../../providers/app_provider.dart';
import '../../../generated/l10n/app_localizations.dart';

class QuickAddScreen extends StatefulWidget {
  final String type;
  final bool standalone;
  const QuickAddScreen({super.key, required this.type, this.standalone = false});
  @override State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  late TxType _type;
  String? _mainCat;
  bool    _saving  = false;
  bool    _success = false;

  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'income' ? TxType.income : TxType.expense;
    // Auto-focus amount field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.standalone) SystemNavigator.pop();
    else if (mounted) Navigator.of(context).pop();
  }

  List<WaCategory> get _cats =>
      _type == TxType.expense ? kExpenseCategories : kIncomeCategories;

  Future<void> _save() async {
    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    final amt  = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amt == null || amt <= 0) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAr ? 'أدخل مبلغاً صحيحاً' : 'Enter a valid amount')));
      return;
    }
    if (_mainCat == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAr ? 'اختر التصنيف أولاً' : 'Choose a category first')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = context.read<AppProvider>().profile?.uid
          ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) throw Exception(isAr ? 'لم يتم تسجيل الدخول' : 'Not signed in');
      final tx = TxModel(
        id: '', type: _type, cat: _mainCat!, sub: '',
        amount: amt, note: _noteCtrl.text.trim(),
        date: DateTime.now().toIso8601String().split('T').first,
        createdAt: DateTime.now(),
      );
      // timeout ثانيتان — Firestore offline يحفظ محلياً فوراً لكن لا يُرجع نتيجة
      // نعتبر أي حالة (نجاح أو timeout) نجاحاً لأن الـ offline persistence تضمن الحفظ
      await FirestoreRepo(FirebaseFirestore.instance)
          .addTx(uid, tx)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {}, // offline: محفوظ محلياً — اعتبره نجاحاً
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() { _saving = false; _success = true; });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _close();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ap        = context.watch<AppProvider>();
    final isAr      = ap.locale.languageCode == 'ar';
    final isExpense = _type == TxType.expense;
    final accent    = isExpense ? WaColors.danger : WaColors.success;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final currency  = ap.currency;
    final lang      = ap.locale.languageCode;

    return Scaffold(
      backgroundColor: isDark ? WaColors.obsidian : const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: isDark ? Colors.white70 : Colors.black54),
          onPressed: _close,
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isExpense
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
              color: accent, size: 18),
          const SizedBox(width: 6),
          Text(
            isExpense
                ? (isAr ? 'مصروف سريع' : 'Quick Expense')
                : (isAr ? 'دخل سريع'    : 'Quick Income'),
            style: TextStyle(fontSize: 16, color: accent,
                fontWeight: FontWeight.w700),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _type    = isExpense ? TxType.income : TxType.expense;
              _mainCat = null;
            }),
            child: Text(
              isExpense
                  ? (isAr ? '← دخل'     : '← Income')
                  : (isAr ? '← مصروف'   : '← Expense'),
              style: const TextStyle(fontSize: 13,
                  color: WaColors.textMuted)),
          ),
        ],
      ),
      body: _success
          ? _buildSuccess(accent, isAr)
          : _buildForm(accent, isDark, currency, isAr, lang),
    );
  }

  // ── Success screen ─────────────────────────────────────────
  Widget _buildSuccess(Color accent, bool isAr) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: accent, size: 80)
          .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),
      Text(isAr ? 'تم الحفظ ✓' : 'Saved ✓',
          style: TextStyle(fontSize: 22, color: accent,
              fontWeight: FontWeight.w700))
          .animate(delay: 200.ms).fadeIn(),
    ]),
  );

  // ── Main form ──────────────────────────────────────────────
  Widget _buildForm(Color accent, bool isDark, String currency,
      bool isAr, String lang) {
    final fieldBg    = isDark ? WaColors.obsidian2 : Colors.white;
    final textColor  = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final mutedColor = isDark ? WaColors.textMuted : const Color(0xFF666666);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Amount ────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text(currency,
                style: TextStyle(fontSize: 18, color: mutedColor)),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller  : _amountCtrl,
              focusNode   : _amountFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign   : TextAlign.center,
              style       : TextStyle(fontSize: 38,
                  fontWeight: FontWeight.w700, color: accent),
              decoration  : InputDecoration(
                border   : InputBorder.none,
                hintText : '0',
                hintStyle: TextStyle(
                    color: accent.withValues(alpha: 0.3), fontSize: 38),
              ),
            )),
          ]),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // ── Category ──────────────────────────────────
        Text(isAr ? 'التصنيف' : 'Category',
            style: TextStyle(fontSize: 12,
                color: mutedColor, letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _cats.map((cat) {
            final sel = _mainCat == cat.id;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _mainCat = sel ? null : cat.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? accent : fieldBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: sel ? accent : WaColors.border.withValues(alpha: 0.6),
                    width: 1.5),
                  boxShadow: sel ? [BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(cat.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 5),
                  Text(cat.localizedLabel(lang),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : textColor)),
                ]),
              ),
            );
          }).toList(),
        ).animate(delay: 80.ms).fadeIn(),

        const SizedBox(height: 20),

        // ── Note ──────────────────────────────────────
        TextField(
          controller: _noteCtrl,
          maxLines  : 2,
          style     : TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText : isAr
                ? 'ملاحظة (اختياري)...'
                : 'Note (optional)...',
            hintStyle    : TextStyle(
                color: mutedColor.withValues(alpha: 0.6)),
            filled       : true,
            fillColor    : fieldBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: WaColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: WaColors.border.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2)),
          ),
        ).animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 28),

        // ── Save ──────────────────────────────────────
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: accent.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: _saving
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isAr ? 'حفظ' : 'Save',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
          ),
        ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.2),

      ]),
    );
  }
}
