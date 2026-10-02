import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/account_model.dart';

/// Contrato del Repositorio de Cuentas (Domain Layer)
abstract class IAccountRepository {
  /// Escucha en tiempo real todas las cuentas del usuario en /users/{userId}/accounts
  Stream<List<AccountModel>> watchUserAccounts(String userId);

  /// Crea una nueva cuenta bancaria, efectivo o tarjeta de crédito
  Future<void> createAccount(AccountModel account);

  /// Actualiza los datos o saldo de una cuenta existente
  Future<void> updateAccount(AccountModel account);

  /// Elimina una cuenta del usuario
  Future<void> deleteAccount({required String userId, required String accountId});
}

/// Implementación en Cloud Firestore: AccountRepository
class AccountRepository implements IAccountRepository {
  final FirebaseFirestore _firestore;

  const AccountRepository(this._firestore);

  CollectionReference<AccountModel> _accountsRef(String userId) {
    return _firestore
        .collection(FirestorePaths.accounts(userId))
        .withConverter<AccountModel>(
          fromFirestore: AccountModel.fromFirestore,
          toFirestore: (AccountModel acc, _) => acc.toFirestore(),
        );
  }

  @override
  Stream<List<AccountModel>> watchUserAccounts(String userId) {
    if (userId.isEmpty) return const Stream.empty();

    // Importante: incluye .where('userId', isEqualTo: userId) para cumplir
    // con la regla Query Enforcer de firestore.rules (resource.data.userId == request.auth.uid)
    return _accountsRef(userId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((querySnapshot) =>
            querySnapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Future<void> createAccount(AccountModel account) async {
    final docRef = _firestore.doc(
      FirestorePaths.accountDoc(account.userId, account.id),
    );
    await docRef.set(account.toFirestore(isNew: true));
  }

  @override
  Future<void> updateAccount(AccountModel account) async {
    final docRef = _firestore.doc(
      FirestorePaths.accountDoc(account.userId, account.id),
    );
    await docRef.update(account.toFirestore(isNew: false));
  }

  @override
  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {
    final docRef = _firestore.doc(FirestorePaths.accountDoc(userId, accountId));
    await docRef.delete();
  }
}
