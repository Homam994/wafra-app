import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirestoreRepo {
  final FirebaseFirestore _db;
  FirestoreRepo(this._db);

  CollectionReference<Map<String,dynamic>> _tx(String uid)    => _db.collection('users').doc(uid).collection('transactions');
  CollectionReference<Map<String,dynamic>> _recur(String uid) => _db.collection('users').doc(uid).collection('recurring');
  CollectionReference<Map<String,dynamic>> _bills(String uid) => _db.collection('users').doc(uid).collection('bills');
  DocumentReference<Map<String,dynamic>>   _user(String uid)  => _db.collection('users').doc(uid);

  // Profile
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final s = await _user(uid).get();
      return s.exists ? UserProfile.fromMap(uid, s.data()!) : null;
    } catch (_) { return null; }
  }
  Future<void> saveProfile(String uid, Map<String,dynamic> d) =>
      _user(uid).set(d, SetOptions(merge: true));
  Future<void> updateBudgets(String uid, Map<String,double> b) =>
      _user(uid).update({'budgets': b});

  // Transactions — real-time stream (offline-first)
  Stream<List<TxModel>> watchTx(String uid) =>
      _tx(uid).orderBy('date', descending: true).snapshots()
          .map((s) => s.docs.map(TxModel.fromDoc).toList());

  Future<void> addTx(String uid, TxModel tx) => _tx(uid).add(tx.toMap());
  Future<void> updateTx(String uid, String id, Map<String,dynamic> d) =>
      _tx(uid).doc(id).set(d, SetOptions(merge: true));
  Future<void> deleteTx(String uid, String id) => _tx(uid).doc(id).delete();

  // Recurring
  Stream<List<RecurModel>> watchRecur(String uid) =>
      _recur(uid).snapshots().map((s) => s.docs.map(RecurModel.fromDoc).toList());
  Future<void> addRecur(String uid, RecurModel r)  => _recur(uid).add(r.toMap());
  Future<void> deleteRecur(String uid, String id)  => _recur(uid).doc(id).delete();
  Future<void> updateRecurLastRun(String uid, String id, String date) =>
      _recur(uid).doc(id).update({'lastRun': date});

  // Bills
  Stream<List<BillModel>> watchBills(String uid) =>
      _bills(uid).snapshots().map((s) {
        final list = s.docs.map(BillModel.fromDoc).toList();
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return list;
      });
  Future<void> addBill(String uid, BillModel b)    => _bills(uid).add(b.toMap());
  Future<void> updateBill(String uid, String id, Map<String,dynamic> d) =>
      _bills(uid).doc(id).set(d, SetOptions(merge: true));
  Future<void> deleteBill(String uid, String id)   => _bills(uid).doc(id).delete();
}
