import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { income, expense }
enum RecurFreq { monthly, weekly, yearly }

// ── Transaction ──────────────────────────────────────────────
class TxModel {
  final String id, cat, sub, note, date;
  final TxType type;
  final double amount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TxModel({
    required this.id, required this.type, required this.cat,
    required this.sub, required this.amount, required this.note,
    required this.date, required this.createdAt, this.updatedAt,
  });

  bool get isIncome  => type == TxType.income;
  bool get isExpense => type == TxType.expense;

  factory TxModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TxModel(
      id       : doc.id,
      type     : d['type'] == 'income' ? TxType.income : TxType.expense,
      cat      : d['cat']    ?? '',
      sub      : d['sub']    ?? '',
      amount   : (d['amount'] ?? 0).toDouble(),
      note     : d['note']   ?? '',
      date     : d['date']   ?? '',
      createdAt: _ts(d['createdAt']),
      updatedAt: d['updatedAt'] != null ? _ts(d['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'type'     : type == TxType.income ? 'income' : 'expense',
    'cat'      : cat,   'sub': sub,   'amount': amount,
    'note'     : note,  'date': date,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  TxModel copyWith({String? id, TxType? type, String? cat, String? sub,
      double? amount, String? note, String? date, DateTime? updatedAt}) =>
    TxModel(id: id??this.id, type: type??this.type, cat: cat??this.cat,
      sub: sub??this.sub, amount: amount??this.amount, note: note??this.note,
      date: date??this.date, createdAt: createdAt, updatedAt: updatedAt??this.updatedAt);

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String)    return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ── Recurring ────────────────────────────────────────────────
class RecurModel {
  final String id, name, cat, startDate, lastRun;
  final TxType type;
  final double amount;
  final RecurFreq freq;
  final DateTime createdAt;

  const RecurModel({
    required this.id, required this.type, required this.name,
    required this.cat, required this.amount, required this.freq,
    required this.startDate, required this.lastRun, required this.createdAt,
  });

  String get freqLabel => const {'monthly':'شهري','weekly':'أسبوعي','yearly':'سنوي'}[freq.name] ?? '';

  factory RecurModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    RecurFreq f;
    switch(d['freq']) {
      case 'weekly': f = RecurFreq.weekly; break;
      case 'yearly': f = RecurFreq.yearly; break;
      default: f = RecurFreq.monthly;
    }
    return RecurModel(
      id       : doc.id,
      type     : d['type'] == 'income' ? TxType.income : TxType.expense,
      name     : d['name']      ?? '',
      cat      : d['cat']       ?? '',
      amount   : (d['amount']   ?? 0).toDouble(),
      freq     : f,
      startDate: d['startDate'] ?? '',
      lastRun  : d['lastRun']   ?? '',
      createdAt: TxModel._ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'type'     : type == TxType.income ? 'income' : 'expense',
    'name'     : name, 'cat': cat, 'amount': amount, 'freq': freq.name,
    'startDate': startDate, 'lastRun': lastRun,
    'createdAt': createdAt.toIso8601String(),
  };

  RecurModel copyWith({
    String?   id,        String?    name,
    String?   cat,       String?    startDate,
    String?   lastRun,   TxType?    type,
    double?   amount,    RecurFreq? freq,
    DateTime? createdAt,
  }) => RecurModel(
    id       : id        ?? this.id,
    name     : name      ?? this.name,
    cat      : cat       ?? this.cat,
    startDate: startDate ?? this.startDate,
    lastRun  : lastRun   ?? this.lastRun,
    type     : type      ?? this.type,
    amount   : amount    ?? this.amount,
    freq     : freq      ?? this.freq,
    createdAt: createdAt ?? this.createdAt,
  );
}

// ── Bill (فاتورة / اشتراك) ────────────────────────────────────
enum BillFreq { once, weekly, monthly, yearly }

class BillModel {
  final String id, name, cat, note;
  final double amount;
  final BillFreq freq;
  final String dueDate;      // تاريخ الاستحقاق القادم (yyyy-MM-dd)
  final bool isPaid;
  final DateTime createdAt;

  const BillModel({
    required this.id, required this.name, required this.cat,
    required this.note, required this.amount, required this.freq,
    required this.dueDate, required this.isPaid, required this.createdAt,
  });

  String get freqLabel => const {
    'once'   : 'مرة واحدة',
    'weekly' : 'أسبوعي',
    'monthly': 'شهري',
    'yearly' : 'سنوي',
  }[freq.name] ?? '';

  // كم يوم تبقى حتى الاستحقاق
  int get daysUntilDue {
    final due = DateTime.tryParse(dueDate);
    if (due == null) return 0;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isOverdue  => daysUntilDue < 0;
  bool get isDueToday => daysUntilDue == 0;
  bool get isDueSoon  => daysUntilDue > 0 && daysUntilDue <= 3;

  // تاريخ الاستحقاق التالي بعد الدفع
  String get nextDueDate {
    final due = DateTime.tryParse(dueDate);
    if (due == null) return dueDate;
    switch (freq) {
      case BillFreq.once   : return dueDate;
      case BillFreq.weekly : return due.add(const Duration(days: 7)).toIso8601String().split('T').first;
      case BillFreq.monthly: return DateTime(due.year, due.month + 1, due.day).toIso8601String().split('T').first;
      case BillFreq.yearly : return DateTime(due.year + 1, due.month, due.day).toIso8601String().split('T').first;
    }
  }

  factory BillModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    BillFreq f;
    switch (d['freq']) {
      case 'weekly' : f = BillFreq.weekly;  break;
      case 'yearly' : f = BillFreq.yearly;  break;
      case 'once'   : f = BillFreq.once;    break;
      default       : f = BillFreq.monthly;
    }
    return BillModel(
      id       : doc.id,
      name     : d['name']    ?? '',
      cat      : d['cat']     ?? 'bills',
      note     : d['note']    ?? '',
      amount   : (d['amount'] ?? 0).toDouble(),
      freq     : f,
      dueDate  : d['dueDate'] ?? '',
      isPaid   : d['isPaid']  ?? false,
      createdAt: TxModel._ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name'     : name, 'cat': cat, 'note': note,
    'amount'   : amount, 'freq': freq.name,
    'dueDate'  : dueDate, 'isPaid': isPaid,
    'createdAt': createdAt.toIso8601String(),
  };

  BillModel copyWith({
    String? id, String? name, String? cat, String? note,
    double? amount, BillFreq? freq, String? dueDate, bool? isPaid,
  }) => BillModel(
    id: id ?? this.id, name: name ?? this.name, cat: cat ?? this.cat,
    note: note ?? this.note, amount: amount ?? this.amount,
    freq: freq ?? this.freq, dueDate: dueDate ?? this.dueDate,
    isPaid: isPaid ?? this.isPaid, createdAt: createdAt,
  );
}
class UserProfile {
  final String uid, name, currency, createdAt;
  final Map<String, double> budgets;

  const UserProfile({
    required this.uid, required this.name, required this.currency,
    required this.createdAt, required this.budgets,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> d) => UserProfile(
    uid      : uid,
    name     : d['name']     ?? '',
    currency : d['currency'] ?? 'SAR',
    createdAt: d['createdAt'] ?? '',
    budgets  : (d['budgets'] as Map<String,dynamic>? ?? {})
        .map((k,v) => MapEntry(k, (v??0).toDouble())),
  );

  Map<String, dynamic> toMap() => {
    'name': name, 'currency': currency,
    'createdAt': createdAt, 'budgets': budgets,
  };

  UserProfile copyWith({String? name, String? currency, Map<String,double>? budgets}) =>
    UserProfile(uid: uid, name: name??this.name, currency: currency??this.currency,
      createdAt: createdAt, budgets: budgets??this.budgets);
}
