import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/sms_provider.dart';
import '../../../data/services/biometric_service.dart';
import '../auth/lock_screen.dart';
import '../quick_add/quick_add_screen.dart';
import '../sms/sms_templates_screen.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/transactions_screen.dart';
import '../income/income_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/reports_screen.dart';
import '../analytics/analytics_screen.dart';
import '../bills/bills_screen.dart';
import '../budget/budget_screen.dart';
import '../recurring/recurring_screen.dart';
import '../categories/categories_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/transaction/add_transaction_sheet.dart';
import '../../../generated/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int  _pageIdx  = 0;
  bool _isOnline = true;
  bool _syncing  = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLocked      = false;
  bool _lockBgEnabled = false;

  late final AppLifecycleListener _lifecycleListener;

  static const _pages = <Widget>[
    DashboardScreen(), TransactionsScreen(), IncomeScreen(),
    ExpensesScreen(), BudgetScreen(), RecurringScreen(),
    ReportsScreen(), CategoriesScreen(), SettingsScreen(),
    AnalyticsScreen(),
    BillsScreen(),
  ];
  static const _navOrder = [0, 1, 4, 6];

  @override
  void initState() {
    super.initState();
    _initNetwork();
    _loadLockBgSetting();

    // Register handler for when app is already running
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        context.read<SmsProvider>().onAppResumed();
        if (_lockBgEnabled && _isLocked) _showLockOverlay();
      },
      onHide: () {
        if (_lockBgEnabled) setState(() => _isLocked = true);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final smsP = context.read<SmsProvider>();
      final ap   = context.read<AppProvider>();

      smsP.onAlert = (msg, isErr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            backgroundColor: isErr ? WaColors.danger : WaColors.warning,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
      };

      void tryInitSms() {
        final uid = ap.profile?.uid ?? '';
        if (uid.isNotEmpty && !smsP.isLoading) smsP.init(uid);
      }
      tryInitSms();
      ap.addListener(tryInitSms);

      ap.onAlert = (msg, isErr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            backgroundColor: isErr ? WaColors.danger : WaColors.warning,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56 + 8,
              left: 12, right: 12,
              bottom: MediaQuery.of(context).size.height - 200,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
      };
    });
  }

  @override
  void dispose() { _lifecycleListener.dispose(); super.dispose(); }

  Future<void> _loadLockBgSetting() async {
    final p   = await SharedPreferences.getInstance();
    final bio = context.read<BiometricService>();
    final method = await bio.getMethod();
    if (mounted) {
      setState(() {
        _lockBgEnabled = (method == LockMethod.enabled) && (p.getBool('lockBg') ?? false);
      });
    }
  }

  void _showLockOverlay() {
    if (!mounted) return;
    setState(() => _isLocked = false);
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LockScreen(destination: HomeScreen()),
        transitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

  void _initNetwork() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      final online = r.any((x) => x != ConnectivityResult.none);
      if (online && !_isOnline) {
        setState(() { _isOnline = true; _syncing = true; });
        Future.delayed(3.seconds, () {
          if (mounted) setState(() => _syncing = false);
        });
      } else if (!online && _isOnline) {
        setState(() => _isOnline = false);
      }
    });
    Connectivity().checkConnectivity().then((r) {
      if (r.any((x) => x == ConnectivityResult.none) && mounted)
        setState(() => _isOnline = false);
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    return Scaffold(
      key   : _scaffoldKey,
      drawer: _buildDrawer(),
      body  : Stack(children: [
        _PageHost(
          pageIdx   : _pageIdx,
          pages     : _pages,
          onMenu    : _openDrawer,
          onSwipeNav: _swipeTo,
        ),
        _NetworkBadge(isOnline: _isOnline, syncing: _syncing),
      ]),
      bottomNavigationBar: _buildBottomNav(surf),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }






  void _swipeTo(int delta) {
    final pos  = _navOrder.indexOf(_pageIdx);
    if (pos < 0) return;
    final next = pos + delta;
    if (next < 0 || next >= _navOrder.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pageIdx = _navOrder[next]);
  }

  Widget _buildDrawer() {
    final ap      = context.watch<AppProvider>();
    final l10n    = AppLocalizations.of(context);
    final isAr    = ap.locale.languageCode == 'ar';
    final initial = ap.userName.isNotEmpty ? ap.userName[0].toUpperCase() : '؟';
    final surf    = Theme.of(context).colorScheme.surface;

    return Drawer(
      width: 275,
      backgroundColor: surf,
      child: SafeArea(child: Column(children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WaColors.border))),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: WaColors.gold,
              child: Text(initial, style: const TextStyle(
                  color: WaColors.obsidian, fontWeight: FontWeight.w700, fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ap.userName, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(ap.currency,
                  style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
            ])),
          ]),
        ),
        // ── Items ──
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          _dSec(isAr ? 'الرئيسية'    : 'Home'),
          _dItem(Icons.grid_view_rounded,      isAr ? 'لوحة التحكم'          : 'Dashboard',          0),
          _dSec(isAr ? 'المعاملات'   : 'Transactions'),
          _dItem(Icons.receipt_long_outlined,  isAr ? 'جميع المعاملات'       : 'All Transactions',   1),
          _dItem(Icons.trending_up_rounded,    isAr ? 'المداخيل'             : 'Income',             2),
          _dItem(Icons.trending_down_rounded,  isAr ? 'المصاريف'             : 'Expenses',           3),
          _dSec(isAr ? 'التخطيط'     : 'Planning'),
          _dItem(Icons.donut_large_outlined,   isAr ? 'الميزانية الشهرية'    : 'Monthly Budget',     4),
          _dItem(Icons.repeat_rounded,         isAr ? 'المتكررة التلقائية'   : 'Auto Recurring',     5),
          _dSec(isAr ? 'التحليل'     : 'Analysis'),
          _dItem(Icons.bar_chart_rounded,      isAr ? 'التقارير الشهرية'     : 'Monthly Reports',    6),
          _dItem(Icons.pie_chart,              isAr ? 'تحليل التصنيفات'      : 'Category Analysis',  7),
          _dItem(Icons.insights_rounded,       isAr ? 'إحصائيات متقدمة'      : 'Advanced Analytics', 9),
          _dSec(isAr ? 'المدفوعات'   : 'Payments'),
          _dItem(Icons.receipt_long_outlined,  isAr ? 'الفواتير والاشتراكات' : 'Bills & Subscriptions', 10),
          _dSec(isAr ? 'الأدوات الذكية' : 'Smart Tools'),
          _dItemNav(Icons.sms_outlined,
            isAr ? 'ربط رسائل البنوك' : 'Bank SMS Link',
            () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SmsTemplatesScreen()));
            }),
          _dSec(isAr ? 'الحساب' : 'Account'),
          _dItem(Icons.settings_outlined, l10n.settings, 8),
        ])),
        // ── Footer ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: WaColors.border))),
          child: Row(children: [
            IconButton(
              icon: Icon(ap.isDark
                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: WaColors.gold),
              onPressed: ap.toggleTheme),
            const Spacer(),
            TextButton.icon(
              onPressed: _logout,
              icon : const Icon(Icons.logout, color: WaColors.danger, size: 18),
              label: Text(l10n.logout,
                  style: const TextStyle(color: WaColors.danger, fontSize: 13))),
          ]),
        ),
      ])),
    );
  }

  Widget _dItemNav(IconData icon, String label, VoidCallback onTap) =>
    ListTile(
      dense  : true,
      leading: Icon(icon, size: 20, color: WaColors.gold),
      title  : Text(label, style: const TextStyle(fontSize: 13)),
      onTap  : onTap,
    );

  Widget _dSec(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(t, style: const TextStyle(
        fontSize: 10, letterSpacing: 2, color: WaColors.textMuted)),
  );

  Widget _dItem(IconData icon, String label, int idx) {
    final active = _pageIdx == idx;
    return ListTile(
      dense   : true,
      leading : Icon(icon, size: 20,
          color: active ? WaColors.gold : WaColors.textSecondary),
      title   : Text(label, style: TextStyle(fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color     : active ? WaColors.gold : null)),
      selected          : active,
      selectedTileColor : WaColors.gold.withValues(alpha: 0.07),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(8))),
      onTap: () { setState(() => _pageIdx = idx); Navigator.pop(context); },
    );
  }

  Widget _buildBottomNav(Color surf) {
    final isAr  = context.read<AppProvider>().locale.languageCode == 'ar';
    final navIdx = _navOrder.contains(_pageIdx) ? _navOrder.indexOf(_pageIdx) : -1;
    final items = [
      (Icons.grid_view_rounded,     Icons.grid_view,    isAr ? 'الرئيسية'   : 'Home'),
      (Icons.receipt_long_outlined, Icons.receipt_long, isAr ? 'المعاملات'  : 'Transactions'),
      (Icons.donut_large_outlined,  Icons.donut_large,  isAr ? 'الميزانية'  : 'Budget'),
      (Icons.bar_chart_outlined,    Icons.bar_chart,    isAr ? 'التقارير'   : 'Reports'),
    ];
    return Container(
      decoration: BoxDecoration(color: surf,
          border: const Border(top: BorderSide(color: WaColors.border))),
      child: BottomAppBar(
        color: Colors.transparent, elevation: 0,
        notchMargin: 6, shape: const CircularNotchedRectangle(),
        child: Row(children: [
          ...List.generate(2, (i) => _bItem(items[i], i, navIdx)),
          const SizedBox(width: 64),
          ...List.generate(2, (i) => _bItem(items[i + 2], i + 2, navIdx)),
        ]),
      ),
    );
  }

  Widget _bItem(dynamic item, int idx, int navIdx) {
    final active = navIdx == idx;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _pageIdx = _navOrder[idx]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(active ? item.$2 : item.$1, size: 22,
            color: active ? WaColors.gold : WaColors.textMuted),
        const SizedBox(height: 2),
        Text(item.$3, style: TextStyle(fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? WaColors.gold : WaColors.textMuted)),
      ]),
    ));
  }

  Widget _buildFAB() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [WaColors.gold, WaColors.goldDim]),
      boxShadow: [BoxShadow(color: WaColors.gold.withValues(alpha: 0.4),
          blurRadius: 16, offset: const Offset(0, 4))]),
    child: Material(color: Colors.transparent, shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(),
        onTap: () => showModalBottomSheet(context: context,
            isScrollControlled: true, backgroundColor: Colors.transparent,
            builder: (_) => const AddTransactionSheet()),
        child: const Icon(Icons.add, color: WaColors.obsidian, size: 28))),
  );

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    Navigator.pop(context);
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: WaColors.danger),
              child: Text(l10n.logout)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SmsProvider>().clear();
    await context.read<AppProvider>().clearUser();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}

// ══════════════════════════════════════════════
class _PageHost extends StatelessWidget {
  final int pageIdx;
  final List<Widget> pages;
  final VoidCallback onMenu;
  final ValueChanged<int> onSwipeNav;
  const _PageHost({required this.pageIdx, required this.pages,
      required this.onMenu, required this.onSwipeNav});

  @override
  Widget build(BuildContext context) {
    double sx = 0; int st = 0;
    return GestureDetector(
      onHorizontalDragStart: (d) {
        sx = d.globalPosition.dx;
        st = DateTime.now().millisecondsSinceEpoch;
      },
      onHorizontalDragEnd: (d) {
        final dx = d.velocity.pixelsPerSecond.dx;
        final dt = DateTime.now().millisecondsSinceEpoch - st;
        if (dt > 400 || dx.abs() < 300) return;
        onSwipeNav(dx > 0 ? -1 : 1);
      },
      child: MenuOpener(onMenu: onMenu,
        child: IndexedStack(index: pageIdx, children: pages)),
    );
  }
}

class MenuOpener extends InheritedWidget {
  final VoidCallback onMenu;
  const MenuOpener({required this.onMenu, required super.child, super.key});
  static MenuOpener? of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<MenuOpener>();
  @override bool updateShouldNotify(MenuOpener old) => false;
}

// ══════════════════════════════════════════════
class _NetworkBadge extends StatefulWidget {
  final bool isOnline, syncing;
  const _NetworkBadge({required this.isOnline, required this.syncing});
  @override State<_NetworkBadge> createState() => _NetworkBadgeState();
}

class _NetworkBadgeState extends State<_NetworkBadge> {
  bool   _visible = false;
  Timer? _hideTimer;

  @override
  void didUpdateWidget(_NetworkBadge old) {
    super.didUpdateWidget(old);
    final shouldShow = !widget.isOnline || widget.syncing;
    if (shouldShow && !_visible) {
      setState(() => _visible = true);
      _scheduleHide();
    } else if (!shouldShow && _visible) {
      _scheduleHide(delay: const Duration(seconds: 2));
    }
  }

  void _scheduleHide({Duration delay = const Duration(seconds: 4)}) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override void dispose() { _hideTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_visible && widget.isOnline && !widget.syncing) return const SizedBox.shrink();
    final isAr     = context.read<AppProvider>().locale.languageCode == 'ar';
    final isOffline = !widget.isOnline;
    final label = isOffline
        ? (isAr ? '📡 بدون إنترنت — محفوظ محلياً' : '📡 Offline — saved locally')
        : widget.syncing
            ? (isAr ? '🔄 جارٍ المزامنة...' : '🔄 Syncing...')
            : (isAr ? '✅ تمت المزامنة' : '✅ Synced');
    final color = isOffline ? WaColors.danger
                : widget.syncing ? WaColors.gold
                : WaColors.success;

    return Positioned(
      top: MediaQuery.of(context).padding.top, left: 0, right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: color,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10))),
            child: Text(label, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOffline ? Colors.white : WaColors.obsidian)),
          ).animate().slideY(begin: -1.0, duration: 400.ms, curve: Curves.easeOut),
        ),
      ),
    );
  }
}
