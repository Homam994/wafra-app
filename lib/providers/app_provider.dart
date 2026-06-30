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
  List<BillModel>   _bills        = [];
  bool              _isDark       = true;
  bool              _loading      = false;
  Locale            _locale       = const Locale('ar', 'SA');

  // ✅ مشكلة التكرار: منع تشغيل _applyRecurring أثناء تنفيذه
  bool _applyingRecur = false;
  // ✅ تشغيل مرة واحدة فقط عند أول تحميل
  bool _recurApplied  = false;

  StreamSubscription? _txSub, _recurSub, _billsSub;
  Function(String, bool)? onAlert;

  // ── Getters ────────────────────────────────────
  UserProfile?       get profile   => _profile;
  bool               get isDark    => _isDark;
  bool               get isLoading => _loading;
  Locale             get locale    => _locale;
  bool               get isArabic  => _locale.languageCode == 'ar';
  String             get currency  => _profile?.currency ?? 'SAR';
  String             get userName  => _profile?.name ?? '';
  Map<String,double> get budgets   => _profile?.budgets ?? {};
  List<RecurModel>   get recurring => _recurring;
  List<BillModel>    get bills     => _bills;

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
    final lang = p.getString('language') ?? 'ar';
    _locale = lang == 'en' ? const Locale('en', 'US') : const Locale('ar', 'SA');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final p = await SharedPreferences.getInstance();
    await p.setString('language', locale.languageCode);
    notifyListeners();
    _updateWidget(); // Refresh widget language
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
      _checkUnusualSpendingAlert();
      _checkWeeklySummary();
    });

    _recurSub?.cancel();
    _recurSub = _repo.watchRecur(uid).listen((list) {
      _recurring = list;
      notifyListeners();
      if (!_recurApplied && _transactions.isNotEmpty) {
        _recurApplied = true;
        Future.delayed(const Duration(milliseconds: 500), _applyRecurring);
      }
    });

    _billsSub?.cancel();
    _billsSub = _repo.watchBills(uid).listen((list) {
      _bills = list;
      notifyListeners();
      _checkBillsDueAlerts();
    });

    _loading = false; notifyListeners();
  }

  Future<void> clearUser() async {
    await _txSub?.cancel();
    await _recurSub?.cancel();
    await _billsSub?.cancel();
    _txSub = null; _recurSub = null; _billsSub = null;
    _profile = null; _transactions = []; _recurring = []; _bills = [];
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

  String _monthName(int m) {
    if (_locale.languageCode == 'en') {
      return const ['', 'January','February','March','April','May','June',
        'July','August','September','October','November','December'][m];
    }
    return const ['', 'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'][m];
  }

  Future<void> addRecur(RecurModel r) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.addRecur(uid, r);
  }

  Future<void> deleteRecur(String id) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.deleteRecur(uid, id);
  }

  // ── Bills CRUD ───────────────────────────────
  Future<void> addBill(BillModel b) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.addBill(uid, b);
  }

  Future<void> deleteBill(String id) async {
    final uid = _profile?.uid; if (uid == null) return;
    await _repo.deleteBill(uid, id);
  }

  // دفع الفاتورة → تسجيل معاملة + تحديث تاريخ الاستحقاق التالي
  Future<void> payBill(BillModel b) async {
    final uid = _profile?.uid; if (uid == null) return;
    // سجّل معاملة مصروف
    final tx = TxModel(
      id: '', type: TxType.expense, cat: b.cat, sub: '',
      amount: b.amount, note: 'فاتورة: ${b.name}',
      date: DateTime.now().toIso8601String().split('T').first,
      createdAt: DateTime.now(), updatedAt: null,
    );
    await _repo.addTx(uid, tx);
    // حدّث تاريخ الاستحقاق أو احذف إن كانت مرة واحدة
    if (b.freq == BillFreq.once) {
      await _repo.deleteBill(uid, b.id);
    } else {
      await _repo.updateBill(uid, b.id, {
        'dueDate': b.nextDueDate,
        'isPaid' : false,
      });
    }
  }

  // ── Bills Due Alerts ─────────────────────────
  void _checkBillsDueAlerts() {
    for (final b in _bills) {
      if (b.isPaid) continue;
      if (b.isOverdue || b.isDueToday || b.isDueSoon) {
        NotificationService.instance.showBillDue(
          billName  : b.name,
          amount    : b.amount,
          currency  : currency,
          daysLeft  : b.daysUntilDue,
        );
      }
    }
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

  // ── Unusual Spending Alert ────────────────────────────
  void _checkUnusualSpendingAlert() {
    final result = checkUnusualSpending();
    if (result.unusual) {
      NotificationService.instance.showUnusualSpending(
        todayTotal: result.todayTotal,
        dailyAvg  : result.dailyAvg,
        currency  : currency,
      );
    }
  }

  // ── Weekly Summary ─────────────────────────────────────
  void _checkWeeklySummary() {
    final now = DateTime.now();
    if (now.weekday != DateTime.friday) return;
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekTxs = _transactions.where((t) {
      final d = DateTime.tryParse(t.date);
      return d != null && !DateTime(d.year, d.month, d.day).isBefore(
        DateTime(weekStart.year, weekStart.month, weekStart.day));
    }).toList();
    NotificationService.instance.maybeShowWeeklySummary(
      weekExpense: totalExpense(weekTxs),
      weekIncome : totalIncome(weekTxs),
      currency   : currency,
      txCount    : weekTxs.length,
    );
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
              orElse: () => WaCategory(id: cat, label: cat, labelEn: cat, emoji: '📊', subs: []))
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
    _updateWidget(); // Refresh widget theme
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
    final m = _locale.languageCode == 'en'
        ? ['January','February','March','April','May','June','July','August','September','October','November','December']
        : ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  }

  String fmtDateShort(String date) {
    final d = DateTime.tryParse(date); if (d == null) return date;
    final m = _locale.languageCode == 'en'
        ? ['January','February','March','April','May','June','July','August','September','October','November','December']
        : ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${m[d.month-1]}';
  }

  String _todayStr() => DateTime.now().toIso8601String().split('T').first;
}

// ══════════════════════════════════════════════════════════════
//  Analytics — دوال التحليل المتقدم
// ══════════════════════════════════════════════════════════════
extension AppProviderAnalytics on AppProvider {

  // ── ١. متوسط الإنفاق اليومي (هذا الأسبوع vs الأسبوع الماضي) ──
  // يُرجع (هذا الأسبوع, الأسبوع الماضي)
  ({double thisWeek, double lastWeek}) dailyAvgComparison() {
    final now     = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final thisWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd   = thisWeekStart.subtract(const Duration(days: 1));

    double sumThis = 0, sumLast = 0;
    int daysThis = 0, daysLast = 0;

    for (final tx in transactions.where((t) => t.isExpense)) {
      final d = DateTime.tryParse(tx.date);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(thisWeekStart) && !day.isAfter(DateTime(now.year, now.month, now.day))) {
        sumThis += tx.amount;
        daysThis = now.difference(thisWeekStart).inDays + 1;
      } else if (!day.isBefore(lastWeekStart) && !day.isAfter(lastWeekEnd)) {
        sumLast += tx.amount;
        daysLast = 7;
      }
    }
    return (
      thisWeek: daysThis > 0 ? sumThis / daysThis : 0,
      lastWeek: daysLast > 0 ? sumLast / daysLast : 0,
    );
  }

  // ── ٢. أين يذهب راتبك؟ (نسبة كل تصنيف من الدخل الشهري) ──
  List<({String catId, String label, double amount, double pct})>
      salaryDistribution() {
    final now    = DateTime.now();
    final mTxs   = txForMonth(now.year, now.month);
    final income = totalIncome(mTxs);
    if (income == 0) return [];
    final bycat  = expenseByCategory(mTxs);
    final sorted = bycat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) {
      final cat = kExpenseCategories.firstWhere(
        (c) => c.id == e.key,
        orElse: () => WaCategory(id: e.key, label: e.key, labelEn: e.key, emoji: '📊', subs: []),
      );
      return (
        catId : e.key,
        label : '${cat.emoji} ${cat.label}',
        amount: e.value,
        pct   : e.value / income * 100,
      );
    }).toList();
  }

  // ── ٣. أفضل وأسوأ شهر إنفاقاً خلال السنة ──
  ({String bestMonth, double bestAmt, String worstMonth, double worstAmt})
      bestAndWorstMonth() {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final d    = DateTime(now.year, now.month - 11 + i);
      final txs  = txForMonth(d.year, d.month);
      final exp  = totalExpense(txs);
      final mNames = _locale.languageCode == 'en' ? kMonthsEn : kMonthsAr;
      return (month: mNames[d.month - 1], amount: exp);
    }).where((m) => m.amount > 0).toList();

    if (months.isEmpty) return (bestMonth: '—', bestAmt: 0, worstMonth: '—', worstAmt: 0);
    final best  = months.reduce((a, b) => a.amount < b.amount ? a : b);
    final worst = months.reduce((a, b) => a.amount > b.amount ? a : b);
    return (
      bestMonth : best.month,  bestAmt : best.amount,
      worstMonth: worst.month, worstAmt: worst.amount,
    );
  }

  // ── ٤. توقع الإنفاق بنهاية الشهر ──
  ({double projected, double sofar, int daysLeft}) monthProjection() {
    final now      = DateTime.now();
    final mTxs     = txForMonth(now.year, now.month);
    final sofar    = totalExpense(mTxs);
    final daysDone = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - daysDone;
    final projected = daysDone > 0
        ? (sofar / daysDone) * daysInMonth
        : 0.0;
    return (projected: projected, sofar: sofar, daysLeft: daysLeft);
  }

  // ── ٥. مقارنة الشهر الحالي بالسابق ──
  ({double current, double previous, double changePct, bool isMore})
      monthVsLastMonth() {
    final now  = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    final cur  = totalExpense(txForMonth(now.year, now.month));
    final pre  = totalExpense(txForMonth(prev.year, prev.month));
    final pct  = pre > 0 ? (cur - pre) / pre * 100 : 0.0;
    return (current: cur, previous: pre, changePct: pct.abs(), isMore: cur > pre);
  }

  // ── ٦. أكثر يوم في الأسبوع إنفاقاً ──
  List<({String day, double total})> spendingByWeekday() {
    final days = _locale.languageCode == 'en'
        ? ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']
        : ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
    final sums = List<double>.filled(7, 0);
    for (final tx in transactions.where((t) => t.isExpense)) {
      final d = DateTime.tryParse(tx.date);
      if (d == null) continue;
      sums[d.weekday % 7] += tx.amount;
    }
    return List.generate(7, (i) => (day: days[i], total: sums[i]));
  }

  // ── ٧. فحص الإنفاق غير المعتاد اليوم ──
  // يُرجع true إن تجاوز إنفاق اليوم ضعف المتوسط اليومي
  ({bool unusual, double todayTotal, double dailyAvg}) checkUnusualSpending() {
    final now     = DateTime.now();
    final todayStr = now.toIso8601String().split('T').first;
    final todayTxs = transactions
        .where((t) => t.isExpense && t.date == todayStr)
        .toList();
    final todayTotal = todayTxs.fold<double>(0, (a, t) => a + t.amount);

    // متوسط يومي على آخر 30 يوم (بدون اليوم)
    double sum = 0;
    int days = 0;
    for (int i = 1; i <= 30; i++) {
      final d   = now.subtract(Duration(days: i));
      final str = d.toIso8601String().split('T').first;
      final dayExp = transactions
          .where((t) => t.isExpense && t.date == str)
          .fold<double>(0, (a, t) => a + t.amount);
      if (dayExp > 0) { sum += dayExp; days++; }
    }
    final avg = days > 0 ? sum / days : 0.0;
    return (
      unusual     : avg > 0 && todayTotal > avg * 2,
      todayTotal  : todayTotal,
      dailyAvg    : avg,
    );
  }
}
