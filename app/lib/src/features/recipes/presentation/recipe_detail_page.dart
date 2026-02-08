import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/recipe_suggestion.dart';
import '../repositories/saved_recipe_repository.dart';

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.onTryNow,
  });

  final RecipeSuggestion recipe;
  final Future<void> Function() onTryNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final recipeId = recipeSaveId(recipe);
    final isSavedAsync = uid == null
        ? const AsyncData<bool>(false)
        : ref.watch(isRecipeSavedProvider((uid: uid, recipeId: recipeId)));

    final isSaved = isSavedAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (recipe.rationale.isNotEmpty) ...<Widget>[
            Text(recipe.rationale),
            const SizedBox(height: 14),
          ],
          Text('From Your Pantry', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (recipe.pantryIngredientsUsed.isEmpty)
            const Text('No direct pantry matches identified.')
          else
            ...recipe.pantryIngredientsUsed
                .map((item) => ListTile(leading: const Icon(Icons.check_circle), title: Text(item))),
          const SizedBox(height: 14),
          Text('Need to Acquire', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (recipe.missingIngredients.isEmpty)
            const Text('No additional ingredients needed.')
          else
            ...recipe.missingIngredients
                .map((item) => ListTile(leading: const Icon(Icons.shopping_cart), title: Text(item))),
          const SizedBox(height: 14),
          Text('All Ingredients', style: Theme.of(context).textTheme.titleMedium),
          ...recipe.ingredients.map((item) => Text('- $item')),
          const SizedBox(height: 14),
          Text('Steps', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...recipe.steps.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${entry.key + 1}. ${entry.value}'),
              )),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await onTryNow();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Try Now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uid == null
                    ? null
                    : () async {
                        if (isSaved) {
                          await ref.read(savedRecipeRepositoryProvider).removeRecipe(uid, recipe);
                        } else {
                          await ref.read(savedRecipeRepositoryProvider).saveRecipe(uid, recipe);
                        }

                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSaved
                                  ? 'Removed "${recipe.title}" from saved recipes.'
                                  : 'Saved "${recipe.title}".',
                            ),
                          ),
                        );
                      },
                icon: Icon(isSaved ? Icons.delete_outline : Icons.bookmark_add_outlined),
                label: Text(isSaved ? 'Delete Saved' : 'Save Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
