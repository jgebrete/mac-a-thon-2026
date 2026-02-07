import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/pantry_item.dart';
import '../data/recipes_service.dart';
import '../domain/recipe_suggestion.dart';

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
            label: const Text('Generate Recipe From Pantry'),
          ),
          if (_loading) ...<Widget>[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          recipe.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Uses: ${recipe.usesExpiring.join(', ')}'),
                        const SizedBox(height: 8),
                        const Text('Ingredients'),
                        ...recipe.ingredients.map(Text.new),
                        const SizedBox(height: 8),
                        const Text('Steps'),
                        ...recipe.steps.asMap().entries.map(
                          (entry) => Text('${entry.key + 1}. ${entry.value}'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
}
