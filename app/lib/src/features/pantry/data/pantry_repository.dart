import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/pantry_item.dart';

class PantryRepository {
  PantryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _pantryCollection(String uid) {
    return _db.collection('users').doc(uid).collection('pantry');
  }

  Stream<List<PantryItem>> watchPantry(String uid) {
    return _pantryCollection(uid)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PantryItem.fromSnapshot)
              .toList(growable: false),
        );
  }

  Future<void> addItem(String uid, PantryItem item) async {
    await _pantryCollection(uid).add(item.toFirestore());
  }

  Future<void> addItems(String uid, List<PantryItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      final ref = _pantryCollection(uid).doc();
      batch.set(ref, item.toFirestore());
    }
    await batch.commit();
  }

  Future<void> updateItem(String uid, PantryItem item) async {
    await _pantryCollection(uid).doc(item.id).update(item.toFirestore());
  }

  Future<void> archiveItem(String uid, PantryItem item) async {
    await _pantryCollection(uid).doc(item.id).update(<String, dynamic>{
      'isArchived': true,
      'updatedAt': Timestamp.now(),
    });
  }
}

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository(FirebaseFirestore.instance);
});

final pantryItemsProvider = StreamProvider.autoDispose<List<PantryItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  final uid = user?.uid;
  if (uid == null) {
    return const Stream<List<PantryItem>>.empty();
  }
  return ref.watch(pantryRepositoryProvider).watchPantry(uid);
});
