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

// ── User Profile ─────────────────────────────────────────────
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
