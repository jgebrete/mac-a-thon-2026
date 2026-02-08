import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/recipe_suggestion.dart';
import '../repositories/saved_recipe_repository.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.onTryNow,
  });

  final RecipeSuggestion recipe;
  final Future<void> Function() onTryNow;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final recipeId = recipeSaveId(widget.recipe);
    final isSavedAsync = uid == null
        ? const AsyncData<bool>(false)
        : ref.watch(isRecipeSavedProvider((uid: uid, recipeId: recipeId)));
    final isSaved = isSavedAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe'),
        actions: <Widget>[
          if (isSaved)
            PopupMenuButton<_RecipeDetailAction>(
              onSelected: (action) async {
                if (action == _RecipeDetailAction.deleteSaved) {
                  await _confirmAndDeleteSaved(uid);
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<_RecipeDetailAction>>[
                PopupMenuItem<_RecipeDetailAction>(
                  value: _RecipeDetailAction.deleteSaved,
                  child: Text('Delete saved recipe'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            widget.recipe.title,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (widget.recipe.rationale.isNotEmpty) ...<Widget>[
            Text(widget.recipe.rationale),
            const SizedBox(height: 14),
          ],
          Text('From Your Pantry', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.recipe.pantryIngredientsUsed.isEmpty)
            const Text('No direct pantry matches identified.')
          else
            ...widget.recipe.pantryIngredientsUsed.map(
              (item) => ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(item),
              ),
            ),
          const SizedBox(height: 14),
          Text('Need to Acquire', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (widget.recipe.missingIngredients.isEmpty)
            const Text('No additional ingredients needed.')
          else
            ...widget.recipe.missingIngredients.map(
              (item) => ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: Text(item),
              ),
            ),
          const SizedBox(height: 14),
          Text('All Ingredients', style: Theme.of(context).textTheme.titleMedium),
          ...widget.recipe.ingredients.map((item) => Text('- $item')),
          const SizedBox(height: 14),
          Text('Steps', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...widget.recipe.steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${entry.key + 1}. ${entry.value}'),
                ),
              ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onTryNow();
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                          }
                        }
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Try Now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isSaved
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.bookmark_added),
                      label: const Text('Saved'),
                    )
                  : OutlinedButton.icon(
                      onPressed: uid == null || _busy
                          ? null
                          : () => _saveRecipe(uid),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Recipe'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteSaved(String? uid) async {
    if (uid == null || _busy) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete saved recipe?'),
        content: const Text('This removes it from your saved list only.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(savedRecipeRepositoryProvider).removeRecipe(uid, widget.recipe);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${widget.recipe.title}" from saved recipes.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveRecipe(String uid) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(savedRecipeRepositoryProvider).saveRecipe(uid, widget.recipe);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${widget.recipe.title}".'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

enum _RecipeDetailAction {
  deleteSaved,
}
