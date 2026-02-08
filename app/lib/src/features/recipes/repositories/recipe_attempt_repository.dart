import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/recipe_attempt.dart';
import '../domain/recipe_suggestion.dart';

class RecipeAttemptRepository {
  RecipeAttemptRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _attempts(String uid) {
    return _db.collection('users').doc(uid).collection('recipeAttempts');
  }

  Stream<RecipeAttempt?> watchLatestTrying(String uid) {
    return _attempts(uid)
        .where('status', isEqualTo: RecipeAttemptStatus.trying.name)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return RecipeAttempt.fromSnapshot(snapshot.docs.first);
    });
  }

  Future<String> createTryingAttempt(
    String uid,
    RecipeSuggestion recipe,
  ) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'title': recipe.title,
      'ingredients': recipe.ingredients,
      'steps': recipe.steps,
      'rationale': recipe.rationale,
      'usesExpiring': recipe.usesExpiring,
      'pantryIngredientsUsed': recipe.pantryIngredientsUsed,
      'missingIngredients': recipe.missingIngredients,
    };

    final doc = await _attempts(uid).add(<String, dynamic>{
      'status': RecipeAttemptStatus.trying.name,
      'recipeTitle': recipe.title,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'usedIngredientNames': recipe.pantryIngredientsUsed,
      'missingIngredientNames': recipe.missingIngredients,
      'selectedPantryItemIds': const <String>[],
      'consumptionEntries': const <Map<String, dynamic>>[],
      'sourceRecipePayload': payload,
    });

    return doc.id;
  }

  Future<void> cancelAttempt(String uid, String attemptId) async {
    await _attempts(uid).doc(attemptId).set(<String, dynamic>{
      'status': RecipeAttemptStatus.cancelled.name,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> completeAttempt(
    String uid,
    String attemptId,
    List<String> selectedPantryItemIds,
    List<RecipeConsumptionEntry> consumptionEntries,
  ) async {
    await _attempts(uid).doc(attemptId).set(<String, dynamic>{
      'status': RecipeAttemptStatus.completed.name,
      'selectedPantryItemIds': selectedPantryItemIds,
      'consumptionEntries':
          consumptionEntries.map((entry) => entry.toJson()).toList(growable: false),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

final recipeAttemptRepositoryProvider = Provider<RecipeAttemptRepository>((ref) {
  return RecipeAttemptRepository(FirebaseFirestore.instance);
});

final latestTryingAttemptProvider = StreamProvider.autoDispose<RecipeAttempt?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return const Stream<RecipeAttempt?>.empty();
  }
  return ref.watch(recipeAttemptRepositoryProvider).watchLatestTrying(uid);
});
