import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/categories.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';
import '../data/repositories/firestore_repo.dart';
import '../data/services/auth_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/widget_service.dart';

class AppProvider extends ChangeNotifier {
  final FirestoreRepo _repo;
  final AuthService   _auth;
  AppProvider(this._repo, this._auth);

  UserProfile?      _profile;
  List<TxModel>     _transactions = [];
  List<RecurModel>  _recurring    = [];
  bool              _isDark       = true;
  bool              _loading      = false;

  // ✅ مشكلة التكرار: منع تشغيل _applyRecurring أثناء تنفيذه
  bool _applyingRecur = false;
  // ✅ تشغيل مرة واحدة فقط عند أول تحميل
  bool _recurApplied  = false;

  StreamSubscription? _txSub, _recurSub;
  Function(String, bool)? onAlert;

  // ── Getters ────────────────────────────────────
  UserProfile?       get profile   => _profile;
  bool               get isDark    => _isDark;
  bool               get isLoading => _loading;
  String             get currency  => _profile?.currency ?? 'SAR';
  String             get userName  => _profile?.name ?? '';
  Map<String,double> get budgets   => _profile?.budgets ?? {};
  List<RecurModel>   get recurring => _recurring;

  // ✅ مشكلة 2: ترتيب تنازلي — أحدث أولاً
  List<TxModel> get transactions {
    final sorted = List<TxModel>.from(_transactions);
    sorted.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  Future<void> loadTheme() async {
    final p = await SharedPreferences.getInstance();
    _isDark = p.getBool('isDark') ?? true;
    notifyListeners();
  }

  Future<void> loadUser(String uid) async {
    _loading = true; notifyListeners();

    _profile = await _repo.getProfile(uid);
    if (_profile == null) {
      final u = _auth.currentUser!;
      _profile = UserProfile(
        uid: uid,
        name: u.displayName ?? u.email?.split('@').first ?? 'مستخدم',
        currency: 'SAR',
        createdAt: DateTime.now().toIso8601String(),
        budgets: {},
      );
      await _repo.saveProfile(uid, _profile!.toMap());
    }

    _txSub?.cancel();
    _txSub = _repo.watchTx(uid).listen((list) {
      _transactions = list;
      notifyListeners();
      _updateWidget();
      // ✅ مشكلة التكرار: تحقق من المتكررات مرة واحدة فقط عند أول تحميل
      if (!_recurApplied && _recurring.isNotEmpty) {
        _recurApplied = true;
        Future.delayed(const Duration(milliseconds: 500), _applyRecurring);
      }
      _checkBudgetAlerts();
    });

    _recurSub?.cancel();
    _recurSub = _repo.watchRecur(uid).listen((list) {
      _recurring = list;
      notifyListeners();
      // ✅ تطبيق المتكررات مرة واحدة فقط عند أول تحميل
      if (!_recurApplied && _transactions.isNotEmpty) {
        _recurApplied = true;
        Future.delayed(const Duration(milliseconds: 500), _applyRecurring);
      }
    });

    _loading = false; notifyListeners();
  }

  Future<void> clearUser() async {
    await _txSub?.cancel();
    await _recurSub?.cancel();
    _txSub = null; _recurSub = null;
    _profile = null; _transactions = []; _recurring = [];
    _recurApplied = false; _applyingRecur = false;
    notifyListeners();
  }

  // ── CRUD ─────────────────────────────────────
  // ✅ مشكلة 3: لا timeout — Firestore يحفظ offline فوراً بدون انتظار
  // المشكلة الحقيقية: كانت المعاملة تُرسل لـ Firestore ثم يحدث timeout
  // لكن Firestore يعيد محاولة الرفع → يظهر "حفظ محلياً" حتى مع الاتصال
  Future<void> addTx(TxModel tx) async {
    final uid = _profile?.uid; if (uid == null) return;
    // ignore: unawaited_futures
    _repo.addTx(uid, tx);
    _updateWidget();
  }

  Future<void> updateTx(String id, TxModel tx) async {
    final uid = _profile?.uid; if (uid == null) return;
    // ignore: unawaited_futures
    _repo.updateTx(uid, id, tx.copyWith(updatedAt: DateTime.now()).toMap());
    _updateWidget();
  }

  Future<void> deleteTx(String id) async {
    final uid = _profile?.uid; if (uid == null) return;
    // ignore: unawaited_futures
    _repo.deleteTx(uid, id);
    _updateWidget();
  }

  void _updateWidget() {
    final now  = DateTime.now();
    final mTxs = txForMonth(now.year, now.month);
    WidgetService.update(
      income  : totalIncome(mTxs),
      expense : totalExpense(mTxs),
      currency: currency,
      month   : _monthName(now.month),
    );
  }

  String _monthName(int m) => const [
    '', 'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
  ][m];

  Future<void> addRecur(RecurModel r) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.addRecur(uid, r);
  }

  Future<void> deleteRecur(String id) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.deleteRecur(uid, id);
  }

  // ── Last Used ────────────────────────────────
  // ✅ مشكلة 6: حفظ آخر تصنيف مستخدم
  Future<Map<String,String?>> getLastUsed() async {
    final p = await SharedPreferences.getInstance();
    return {
      'type'       : p.getString('lu_type'),
      'expense_cat': p.getString('lu_expense_cat'),
      'expense_sub': p.getString('lu_expense_sub'),
      'income_cat' : p.getString('lu_income_cat'),
      'income_sub' : p.getString('lu_income_sub'),
    };
  }

  Future<void> saveLastUsed(String type, String cat, String? sub) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lu_type', type);
    await p.setString('lu_${type}_cat', cat);
    if (sub != null) {
      await p.setString('lu_${type}_sub', sub);
    } else {
      await p.remove('lu_${type}_sub');
    }
  }

  // ── Recurring ───────────────────────────────
  // ✅ مشكلة التكرار: mutex كامل + تحقق صارم
  Future<void> _applyRecurring() async {
    if (_applyingRecur) return;  // ← منع التكرار المتزامن
    _applyingRecur = true;
    try {
      final uid = _profile?.uid;
      if (uid == null || _recurring.isEmpty) return;
      final today = _todayStr();
      int applied = 0;
      for (final r in List<RecurModel>.from(_recurring)) {
        if (!_shouldRun(r, today)) continue;
        try {
          await _repo.addTx(uid, TxModel(
            id: '', type: r.type, cat: r.cat, sub: '',
            amount: r.amount, note: r.name, date: today,
            createdAt: DateTime.now(), updatedAt: null,
          ));
          // ✅ حدّث lastRun فوراً لمنع أي إعادة تشغيل
          await _repo.updateRecurLastRun(uid, r.id, today);
          // ✅ حدّث النموذج المحلي أيضاً
          final idx = _recurring.indexWhere((x) => x.id == r.id);
          if (idx >= 0) {
            _recurring[idx] = _recurring[idx].copyWith(lastRun: today);
          }
          applied++;
        } catch (_) {}
      }
      if (applied > 0) onAlert?.call('🔄 تم تطبيق $applied معاملة متكررة', false);
    } finally {
      _applyingRecur = false;
    }
  }

  bool _shouldRun(RecurModel r, String today) {
    // ✅ lastRun == today → لا تشغيل
    if (r.lastRun == today) return false;
    // ✅ لم يحِن تاريخ البدء
    if (today.compareTo(r.startDate) < 0) return false;
    // إن لم تُشغَّل قط → شغّلها
    if (r.lastRun.isEmpty) return true;
    final last = DateTime.tryParse(r.lastRun);
    final now  = DateTime.tryParse(today);
    if (last == null || now == null) return false;
    switch (r.freq) {
      case 'monthly': return now.month != last.month || now.year != last.year;
      case 'weekly' : return now.difference(last).inDays >= 7;
      case 'yearly' : return now.year != last.year;
      default       : return false;
    }
  }

  // ── Budget Alerts ────────────────────────────
  void _checkBudgetAlerts() {
    final b = _profile?.budgets ?? {};
    if (b.isEmpty) return;
    final now  = DateTime.now();
    final mTxs = txForMonth(now.year, now.month)
        .where((t) => t.isExpense).toList();
    final bycat = <String, double>{};
    for (final t in mTxs) bycat[t.cat] = (bycat[t.cat] ?? 0) + t.amount;
    b.forEach((cat, limit) {
      if (limit <= 0) return;
      final spent = bycat[cat] ?? 0;
      final pct   = spent / limit;
      final catLabel = kExpenseCategories
          .firstWhere((c) => c.id == cat,
              orElse: () => WaCategory(id: cat, label: cat, emoji: '📊', subs: []))
          .label;

      if (pct >= 1.0) {
        onAlert?.call('🚨 تجاوزت ميزانية $catLabel!', true);
        NotificationService.instance.showBudgetAlert(
          categoryLabel: catLabel,
          spent: spent, limit: limit,
          currency: currency,
          isOver: true,
        );
      } else if (pct >= 0.9) {
        onAlert?.call('⚠️ 90% من ميزانية $catLabel', false);
        NotificationService.instance.showBudgetAlert(
          categoryLabel: catLabel,
          spent: spent, limit: limit,
          currency: currency,
          isOver: false,
        );
      }
    });
  }

  // ── Profile ──────────────────────────────────
  Future<void> updateCurrency(String cur) async {
    final uid = _profile?.uid; if (uid == null) return;
    _profile = _profile!.copyWith(currency: cur);
    await _repo.saveProfile(uid, {'currency': cur});
    notifyListeners();
  }

  Future<void> saveBudgets(Map<String, double> b) async {
    final uid = _profile?.uid; if (uid == null) return;
    _profile = _profile!.copyWith(budgets: b);
    await _repo.updateBudgets(uid, b);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final p = await SharedPreferences.getInstance();
    await p.setBool('isDark', _isDark);
    notifyListeners();
  }

  // ── Analytics ────────────────────────────────
  List<TxModel> txForMonth(int y, int m) => transactions.where((t) {
    final d = DateTime.tryParse(t.date);
    return d != null && d.year == y && d.month == m;
  }).toList();

  double totalIncome(List<TxModel> txs) =>
      txs.where((t) => t.isIncome).fold(0, (a, t) => a + t.amount);
  double totalExpense(List<TxModel> txs) =>
      txs.where((t) => t.isExpense).fold(0, (a, t) => a + t.amount);

  Map<String, double> expenseByCategory(List<TxModel> txs) {
    final m = <String, double>{};
    for (final t in txs.where((t) => t.isExpense))
      m[t.cat] = (m[t.cat] ?? 0) + t.amount;
    return m;
  }

  Map<String, double> incomeByCategory(List<TxModel> txs) {
    final m = <String, double>{};
    for (final t in txs.where((t) => t.isIncome))
      m[t.cat] = (m[t.cat] ?? 0) + t.amount;
    return m;
  }

  // ── Export ───────────────────────────────────
  Future<void> exportCSV() async {
    if (_transactions.isEmpty) return;
    final buf = StringBuffer();
    buf.writeln('sep=;');
    buf.writeln('التاريخ;النوع;التصنيف;التصنيف الفرعي;المبلغ;العملة;ملاحظة');
    for (final tx in transactions) {
      buf.writeln([tx.date, tx.isIncome ? 'دخل' : 'مصروف', tx.cat,
        tx.sub, tx.amount.toStringAsFixed(2), currency,
        tx.note.replaceAll(';', '،')].join(';'));
    }
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/wafra_export.csv');
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...buf.toString().codeUnits]);
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
        subject: 'وفرة — تصدير البيانات');
  }

  // ── Formatting ───────────────────────────────
  String fmt(double amount) {
    final nf = NumberFormat('#,##0.##', 'en_US');
    return '${nf.format(amount.abs())} $currency';
  }

  String fmtShort(double amount) {
    final n = amount.abs();
    String s;
    if (n >= 1000000)   s = '${(n/1000000).toStringAsFixed(1)}M';
    else if (n >= 1000) s = '${(n/1000).toStringAsFixed(1)}K';
    else                s = NumberFormat('#,##0.##', 'en_US').format(n);
    return '$s $currency';
  }

  String fmtDate(String date) {
    final d = DateTime.tryParse(date); if (d == null) return date;
    const m = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  }

  String fmtDateShort(String date) {
    final d = DateTime.tryParse(date); if (d == null) return date;
    const m = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]}';
  }

  String _todayStr() => DateTime.now().toIso8601String().split('T').first;
}
