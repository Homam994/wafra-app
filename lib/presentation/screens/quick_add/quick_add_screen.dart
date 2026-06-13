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

class QuickAddScreen extends StatefulWidget {
  final String type;
  /// standalone=true عند الفتح من اختصار — يُغلق التطبيق عند الإنهاء
  /// standalone=false عند الفتح من داخل التطبيق — يعود للشاشة السابقة
  final bool standalone;
  const QuickAddScreen({super.key, required this.type, this.standalone = false});
  @override State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  late TxType _type;
  String?  _mainCat;
  bool     _saving  = false;
  bool     _success = false;

  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'income' ? TxType.income : TxType.expense;
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _amountFocus.requestFocus());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.standalone) {
      SystemNavigator.pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  List<WaCategory> get _cats =>
      _type == TxType.expense ? kExpenseCategories : kIncomeCategories;

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amt == null || amt <= 0) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    if (_mainCat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر التصنيف أولاً')));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = context.read<AppProvider>().profile?.uid
          ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) throw Exception('لم يتم تسجيل الدخول');

      final tx = TxModel(
        id: '', type: _type, cat: _mainCat!, sub: '',
        amount: amt, note: _noteCtrl.text.trim(),
        date: DateTime.now().toIso8601String().split('T').first,
        createdAt: DateTime.now(),
      );

      await FirestoreRepo(FirebaseFirestore.instance).addTx(uid, tx);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() { _saving = false; _success = true; });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) _close();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == TxType.expense;
    final accent    = isExpense ? WaColors.danger : WaColors.success;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final currency  = context.watch<AppProvider>().currency;

    return Scaffold(
      backgroundColor: isDark ? WaColors.obsidian : WaColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _close(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward,
              color: accent, size: 18),
          const SizedBox(width: 6),
          Text(isExpense ? 'مصروف سريع' : 'دخل سريع',
              style: TextStyle(fontSize: 16, color: accent,
                  fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _type = isExpense ? TxType.income : TxType.expense;
              _mainCat = null;
            }),
            child: Text(isExpense ? 'دخل ←' : 'مصروف ←',
                style: const TextStyle(fontSize: 13,
                    color: WaColors.textMuted)),
          ),
        ],
      ),
      body: _success ? _buildSuccess(accent) : _buildForm(accent, isDark, currency),
    );
  }

  Widget _buildSuccess(Color accent) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: accent, size: 80)
          .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
      const SizedBox(height: 16),
      Text('تم الحفظ ✓', style: TextStyle(
          fontSize: 22, color: accent, fontWeight: FontWeight.w700))
          .animate(delay: 200.ms).fadeIn(),
    ]),
  );

  Widget _buildForm(Color accent, bool isDark, String currency) =>
    SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── حقل المبلغ ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? WaColors.obsidian2 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Text(currency, style: const TextStyle(
                fontSize: 18, color: WaColors.textMuted)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller  : _amountCtrl,
                focusNode   : _amountFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign   : TextAlign.center,
                style       : TextStyle(fontSize: 38,
                    fontWeight: FontWeight.w700, color: accent),
                decoration  : const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(
                      color: WaColors.textMuted, fontSize: 38),
                ),
              ),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // ── التصنيفات ────────────────────────────────
        const Text('التصنيف', style: TextStyle(
            fontSize: 12, color: WaColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _cats.map((cat) {
            final sel = _mainCat == cat.id;
            return GestureDetector(
              onTap: () => setState(() =>
                  _mainCat = sel ? null : cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? accent
                      : (isDark ? WaColors.obsidian2 : Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: sel ? accent : WaColors.border, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(cat.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(cat.label, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : WaColors.textPrimary)),
                ]),
              ),
            );
          }).toList(),
        ).animate(delay: 100.ms).fadeIn(),

        const SizedBox(height: 20),

        // ── ملاحظة ───────────────────────────────────
        TextField(
          controller: _noteCtrl,
          maxLines  : 2,
          decoration: InputDecoration(
            hintText: 'ملاحظة (اختياري)...',
            filled  : true,
            fillColor: isDark ? WaColors.obsidian2 : Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: WaColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: WaColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2)),
          ),
        ).animate(delay: 150.ms).fadeIn(),

        const SizedBox(height: 28),

        // ── زر الحفظ ─────────────────────────────────
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('حفظ', style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),

      ]),
    );
}
