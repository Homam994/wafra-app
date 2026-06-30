// ignore_for_file: unused_import, avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

/// Lookup function to find the right delegate.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = locale;

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('ar', 'SA'),
    Locale('en', 'US'),
  ];

  // ── General ──────────────────────────────────────────────
  String get appName;
  String get appTagline;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get add;
  String get close;
  String get confirm;
  String get retry;
  String get back;
  String get yes;
  String get no;
  String get loading;
  String get noData;
  String get search;
  String get filter;
  String get all;
  String get total;
  String get currency;
  String currentCurrency(String currency);
  String get transactions;
  String transactionCount(int count);
  String get noTransactions;
  String get noResults;
  String get amount;
  String get note;
  String get date;
  String get category;
  String get subCategory;
  String get type;
  String get income;
  String get expense;

  // ── Dashboard ─────────────────────────────────────────────
  String greeting(String name);
  String get returnToCurrentMonth;
  String get expenseDistribution;
  String get currentMonth;
  String get expensesAndIncome;
  String get last6Months;
  String get latestTransactions;

  // ── Transactions ──────────────────────────────────────────
  String get allTransactions;
  String get deleteTransaction;
  String get deleteTransactionConfirm;

  // ── Bills ─────────────────────────────────────────────────
  String get billsAndSubscriptions;
  String get deleteBill;
  String deleteBillConfirm(String name);
  String get payBill;
  String get confirmPayment;
  String get noBills;
  String get noBillsSubtitle;
  String get addBill;
  String get dueThisMonth;
  String get overdue;
  String get dueToday;
  String get dueSoon;
  String get upcoming;
  String get billName;
  String get billAmount;
  String get dueDay;
  String get frequency;
  String get monthly;
  String get weekly;
  String get yearly;
  String get daily;
  String get quarterly;

  // ── Budget ────────────────────────────────────────────────
  String get monthlyBudget;
  String get budgetSaved;
  String get saveChanges;
  String get totalThisMonth;
  String get spent;
  String spentOf(String spent, String total);
  String percentOfBudget(int pct);
  String get noBudgetSet;
  String get budgetLimit;
  String spentAmount(String amount);
  String limitAmount(String amount, String currency);
  String spentNoLimit(String amount, String currency);

  // ── Analytics ─────────────────────────────────────────────
  String get advancedAnalytics;
  String get monthProgress;

  // ── Categories ────────────────────────────────────────────
  String get categoryAnalysis;
  String get totalExpensesByCategory;
  String categoryTxSummary(int count, String total);

  // ── Recurring ─────────────────────────────────────────────
  String get autoRecurring;
  String get noRecurring;
  String get addFirstRecurring;
  String get recurringTx;
  String startingFrom(String date);
  String lastApplied(String date);
  String startDate(String date);

  // ── Reports ───────────────────────────────────────────────
  String get monthlyReports;
  String get expenseBreakdown;
  String get incomeBreakdown;
  String monthTransactions(int count);
  String get noTransactionsThisMonth;

  // ── Income / Expenses ─────────────────────────────────────
  String get incomes;
  String get incomeHistory;
  String get noIncomes;
  String get expenses;
  String get expenseHistory;
  String get noExpenses;

  // ── Settings ──────────────────────────────────────────────
  String get settings;
  String get securityAndPrivacy;
  String get biometricLock;
  String get biometricSub;
  String get lockOnBackground;
  String get lockOnBackgroundSub;
  String get resetLockMethod;
  String currentMethod(String method);
  String get lockNotEnabled;
  String get lockNotEnabledBody;
  String get lockEnabled;
  String get lockDisabled;
  String get lockResetDone;
  String get lockSaveFailed;
  String get bioNotEnrolled;
  String get bioNotAvailable;
  String get bioPasscodeNotSet;
  String get bioLockedOut;
  String get bioPermanentlyLockedOut;
  String get bioCancelled;
  String bioFailed(String code);
  String get notifications;
  String get budgetNotifications;
  String get budgetNotificationsSub;
  String get testNotification;
  String get testNotificationSub;
  String get notifEnabled;
  String get notifDisabled;
  String get notifDisabledWarning;
  String get testNotifSent;
  String get displayAndTheme;
  String get darkMode;
  String get darkModeSub;
  String get language;
  String get languageArabic;
  String get languageEnglish;
  String get data;
  String get syncData;
  String get syncDataSub;
  String get exportCSV;
  String get exportCSVSub;
  String get aboutApp;
  String get version;
  String get appFullName;
  String get database;
  String get logout;
  String get logoutConfirmTitle;
  String get logoutConfirmBody;
  String get lockMethodEnabled;
  String get lockMethodDisabled;

  // ── Auth ──────────────────────────────────────────────────
  String get forgotPassword;
  String get resetPassword;
  String get resetPasswordSub;
  String get backToLogin;

  // ── Category labels ───────────────────────────────────────
  String get catFood;
  String get catTransport;
  String get catHealth;
  String get catBills;
  String get catEntertainment;
  String get catShopping;
  String get catEducation;
  String get catFamily;
  String get catSalary;
  String get catBusiness;
  String get catInvestment;
  String get catRental;
  String get catOtherIncome;

  // ── Subcategory labels ────────────────────────────────────
  String get subRestaurants;
  String get subGrocery;
  String get subCafes;
  String get subBakeries;
  String get subDelivery;
  String get subOther;
  String get subFuel;
  String get subTaxi;
  String get subMaintenance;
  String get subInsurance;
  String get subPublicTransport;
  String get subTravel;
  String get subMedicines;
  String get subDoctor;
  String get subGym;
  String get subPharmacy;
  String get subPersonalCare;
  String get subDental;
  String get subRent;
  String get subUtilities;
  String get subInternet;
  String get subPhone;
  String get subHomeMaintenance;
  String get subHomeInsurance;
  String get subCinema;
  String get subSubscriptions;
  String get subGames;
  String get subTourism;
  String get subBooks;
  String get subSport;
  String get subClothes;
  String get subShoes;
  String get subElectronics;
  String get subHomeTools;
  String get subGifts;
  String get subCourses;
  String get subSchool;
  String get subTextbooks;
  String get subSoftware;
  String get subStationery;
  String get subExams;
  String get subChildAllowance;
  String get subOccasions;
  String get subChildcare;
  String get subParentCare;
  String get subFamilyGifts;
  String get subHousehold;
  String get subMonthlySalary;
  String get subBonus;
  String get subOvertime;
  String get subFreelance;
  String get subCommission;
  String get subAllowance;
  String get subBusinessProfit;
  String get subSales;
  String get subServices;
  String get subConsulting;
  String get subGoods;
  String get subFranchise;
  String get subStocks;
  String get subRealEstate;
  String get subBankInterest;
  String get subCrypto;
  String get subGold;
  String get subFunds;
  String get subApartmentRent;
  String get subShopRent;
  String get subCarRent;
  String get subWarehouseRent;
  String get subDigitalRent;
  String get subGift;
  String get subInheritance;
  String get subAssetSale;
  String get subRefund;
  String get subDonationReceived;

  // ── Month names ───────────────────────────────────────────
  String get monthJan;
  String get monthFeb;
  String get monthMar;
  String get monthApr;
  String get monthMay;
  String get monthJun;
  String get monthJul;
  String get monthAug;
  String get monthSep;
  String get monthOct;
  String get monthNov;
  String get monthDec;

  List<String> get months => [
    monthJan, monthFeb, monthMar, monthApr, monthMay, monthJun,
    monthJul, monthAug, monthSep, monthOct, monthNov, monthDec,
  ];

  // ── Day names ─────────────────────────────────────────────
  String get daySun;
  String get dayMon;
  String get dayTue;
  String get dayWed;
  String get dayThu;
  String get dayFri;
  String get daySat;

  List<String> get days => [daySun, dayMon, dayTue, dayWed, dayThu, dayFri, daySat];
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'en':
        return AppLocalizationsEn();
      case 'ar':
      default:
        return AppLocalizationsAr();
    }
  }

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
