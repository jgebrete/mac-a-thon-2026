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
    await archiveItemWithReason(
      uid,
      item,
      PantryArchivedReason.thrown,
    );
  }

  Future<void> archiveItemWithReason(
    String uid,
    PantryItem item,
    PantryArchivedReason reason, {
    String? recipeAttemptId,
  }) async {
    await _pantryCollection(uid).doc(item.id).update(<String, dynamic>{
      'isArchived': true,
      'archivedReason': reason.name,
      'lastRecipeAttemptId': recipeAttemptId,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> archiveItemsForRecipe(
    String uid,
    List<PantryItem> items, {
    required String recipeAttemptId,
  }) async {
    final batch = _db.batch();
    for (final item in items) {
      final ref = _pantryCollection(uid).doc(item.id);
      batch.update(ref, <String, dynamic>{
        'isArchived': true,
        'archivedReason': PantryArchivedReason.consumedRecipe.name,
        'lastRecipeAttemptId': recipeAttemptId,
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> applyRecipeConsumption(
    String uid,
    String recipeAttemptId,
    List<PantryConsumptionUpdate> updates,
  ) async {
    final batch = _db.batch();
    for (final update in updates) {
      final ref = _pantryCollection(uid).doc(update.itemId);
      if (update.archive) {
        batch.update(ref, <String, dynamic>{
          'isArchived': true,
          'archivedReason': PantryArchivedReason.consumedRecipe.name,
          'lastRecipeAttemptId': recipeAttemptId,
          'updatedAt': Timestamp.now(),
        });
      } else {
        batch.update(ref, <String, dynamic>{
          'quantityValue': update.newQuantityValue,
          'lastRecipeAttemptId': recipeAttemptId,
          'updatedAt': Timestamp.now(),
        });
      }
    }
    await batch.commit();
  }
}

class PantryConsumptionUpdate {
  const PantryConsumptionUpdate({
    required this.itemId,
    required this.archive,
    this.newQuantityValue,
  });

  final String itemId;
  final bool archive;
  final double? newQuantityValue;
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
