import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/fun_loading_panel.dart';
import '../../auth/providers/auth_providers.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/pantry_item.dart';
import '../data/recipes_service.dart';
import '../domain/recipe_attempt.dart';
import '../domain/recipe_suggestion.dart';
import '../presentation/recipe_detail_page.dart';
import '../repositories/recipe_attempt_repository.dart';
import '../repositories/saved_recipe_repository.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  bool _loading = false;
  String? _error;
  List<RecipeSuggestion> _recipes = const <RecipeSuggestion>[];

  @override
  Widget build(BuildContext context) {
    final pantryItems = ref.watch(pantryItemsProvider).value ?? const <PantryItem>[];
    final activeAttempt = ref.watch(latestTryingAttemptProvider).valueOrNull;
    final savedRecipesAsync = ref.watch(savedRecipesProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: pantryItems.isEmpty || _loading
                ? null
                : () => _generateRecipes(pantryItems),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Recipes'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const FunLoadingPanel(
              title: 'Cooking up ideas...',
              messages: <String>[
                'Checking what is about to expire...',
                'Balancing pantry and missing ingredients...',
                'Finalizing tasty options...',
              ],
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: <Widget>[
                Text('Saved Recipes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...savedRecipesAsync.when(
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, stackTrace) => <Widget>[
                    Text('Failed to load saved recipes: $error'),
                  ],
                  data: (savedRecipes) {
                    if (savedRecipes.isEmpty) {
                      return const <Widget>[
                        Text('No saved recipes yet. Open a recipe and tap Save.'),
                      ];
                    }
                    return savedRecipes
                        .map(
                          (recipe) => _RecipeCard(
                            recipe: recipe,
                            saved: true,
                            onView: () => _openDetail(recipe),
                            onTry: () => _tryRecipe(recipe, activeAttempt),
                            onDelete: () => _removeSavedRecipe(recipe),
                          ),
                        )
                        .toList(growable: false);
                  },
                ),
                const SizedBox(height: 16),
                Text('Generated Now', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_recipes.isEmpty && !_loading)
                  const Text('Generate recipes to see suggestions here.'),
                ..._recipes.map(
                  (recipe) => _RecipeCard(
                    recipe: recipe,
                    onView: () => _openDetail(recipe),
                    onTry: () => _tryRecipe(recipe, activeAttempt),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(RecipeSuggestion recipe) async {
    final activeAttempt = ref.read(latestTryingAttemptProvider).valueOrNull;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailPage(
          recipe: recipe,
          onTryNow: () => _tryRecipe(recipe, activeAttempt),
        ),
      ),
    );
  }

  Future<void> _generateRecipes(List<PantryItem> pantryItems) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recipes = await ref.read(recipesServiceProvider).generateRecipes(
            pantryItems,
          );
      setState(() {
        _recipes = recipes;
      });
    } catch (error) {
      setState(() {
        _error = 'Failed to generate recipe: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _removeSavedRecipe(RecipeSuggestion recipe) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }
    await ref.read(savedRecipeRepositoryProvider).removeRecipe(uid, recipe);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "${recipe.title}" from saved recipes.')),
    );
  }

  Future<void> _tryRecipe(
    RecipeSuggestion recipe,
    RecipeAttempt? activeAttempt,
  ) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }

    if (activeAttempt != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace active recipe?'),
          content: const Text(
            'You already have a recipe in progress. Replace it with this one?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true) {
        return;
      }
      await ref
          .read(recipeAttemptRepositoryProvider)
          .cancelAttempt(uid, activeAttempt.id);
    }

    await ref.read(recipeAttemptRepositoryProvider).createTryingAttempt(uid, recipe);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked "${recipe.title}" as in progress.')),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onView,
    required this.onTry,
    this.onDelete,
    this.saved = false,
  });

  final RecipeSuggestion recipe;
  final VoidCallback onView;
  final VoidCallback onTry;
  final VoidCallback? onDelete;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (saved)
                  Chip(
                    label: const Text('Saved'),
                    avatar: const Icon(Icons.bookmark, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pantry: ${recipe.pantryIngredientsUsed.join(', ')}'),
            const SizedBox(height: 4),
            Text('Need: ${recipe.missingIngredients.join(', ')}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(onPressed: onView, child: const Text('View')),
                FilledButton(onPressed: onTry, child: const Text('Try')),                
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
