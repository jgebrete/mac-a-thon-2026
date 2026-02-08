import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../../recipes/domain/recipe_attempt.dart';
import '../../recipes/repositories/recipe_attempt_repository.dart';
import '../../settings/domain/user_settings.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../data/freshness_style.dart';
import '../data/pantry_repository.dart';
import '../data/pantry_sorter.dart';
import '../domain/pantry_item.dart';
import 'manual_add_sheet.dart';

class PantryListPage extends ConsumerStatefulWidget {
  const PantryListPage({super.key});

  @override
  ConsumerState<PantryListPage> createState() => _PantryPageState();
}

class _PantryPageState extends ConsumerState<PantryListPage> {
  PantrySort _sort = PantrySort.expiryAsc;

  @override
  Widget build(BuildContext context) {
    final pantryAsync = ref.watch(pantryItemsProvider);
    final tryingAttemptAsync = ref.watch(latestTryingAttemptProvider);
    final settings = ref.watch(userSettingsProvider).valueOrNull ?? UserSettings.defaults;

    return Column(
      children: <Widget>[
        if ((tryingAttemptAsync.valueOrNull) case final RecipeAttempt attempt?)
          _RecipePendingBanner(
            attempt: attempt,
            onComplete: () => _startRecipeCompletion(attempt),
            onCancel: () => _cancelAttempt(attempt),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: DropdownButtonFormField<PantrySort>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Sort By'),
            items: PantrySort.values
                .map(
                  (sort) => DropdownMenuItem<PantrySort>(
                    value: sort,
                    child: Text(_labelForSort(sort)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _sort = value);
            },
          ),
        ),
        Expanded(
          child: pantryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Error: $error')),
            data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('No pantry items yet. Use + to add.'));
              }

              final sorted = sortPantryItems(items, _sort);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  final days = item.expiryDate != null ? daysUntil(item.expiryDate!) : null;
                  final style = freshnessStyleForDays(
                    days,
                    settings,
                    Theme.of(context).brightness,
                    isPerishableNoExpiry: item.isPerishableNoExpiry,
                  );
                  return _PantryCard(
                    key: ValueKey(item.id),
                    item: item,
                    daysUntilExpiry: days,
                    style: style,
                    onEdit: () => _openEditBottomSheet(item),
                    onThrow: (days != null && days <= 0) || item.isPerishableNoExpiry
                        ? () => _throwItem(item)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _labelForSort(PantrySort sort) {
    switch (sort) {
      case PantrySort.expiryAsc:
        return 'Expiry (Soonest First)';
      case PantrySort.expiryDesc:
        return 'Expiry (Latest First)';
      case PantrySort.nameAsc:
        return 'Name (A-Z)';
      case PantrySort.nameDesc:
        return 'Name (Z-A)';
      case PantrySort.recentlyAdded:
        return 'Recently Added';
    }
  }

  Future<void> _openEditBottomSheet(PantryItem item) async {
    final updated = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ManualAddSheet(initial: item),
    );
    if (updated == null) {
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }
    await ref.read(pantryRepositoryProvider).updateItem(uid, updated);
  }

  Future<void> _throwItem(PantryItem item) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }

    final shouldThrow = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Throw ingredient?'),
        content: Text('Archive ${item.name} as thrown away?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Throw'),
          ),
        ],
      ),
    );

    if (shouldThrow != true) {
      return;
    }

    await ref.read(pantryRepositoryProvider).archiveItemWithReason(
          uid,
          item,
          PantryArchivedReason.thrown,
        );
  }

  Future<void> _cancelAttempt(RecipeAttempt attempt) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }
    await ref.read(recipeAttemptRepositoryProvider).cancelAttempt(uid, attempt.id);
  }

  Future<void> _startRecipeCompletion(RecipeAttempt attempt) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final pantryItems = ref.read(pantryItemsProvider).value ?? const <PantryItem>[];
    if (uid == null || pantryItems.isEmpty) {
      return;
    }

    final normalized = pantryItems.map((i) => MapEntry(_normalize(i.name), i)).toList();
    final matched = <PantryItem>[];

    for (final ingredient in attempt.usedIngredientNames) {
      final key = _normalize(ingredient);
      final match = normalized
          .where((entry) => entry.key == key)
          .map((entry) => entry.value)
          .where((item) => !matched.any((m) => m.id == item.id))
          .firstWhereOrNull((_) => true);
      if (match != null) {
        matched.add(match);
      }
    }

    final consumption = await showModalBottomSheet<List<_ConsumptionInput>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompleteRecipeSheet(initialMatched: matched),
    );

    if (consumption == null || consumption.isEmpty) {
      return;
    }

    final updates = <PantryConsumptionUpdate>[];
    final entries = <RecipeConsumptionEntry>[];

    for (final entry in consumption) {
      if (entry.archive) {
        updates.add(PantryConsumptionUpdate(itemId: entry.item.id, archive: true));
        entries.add(
          RecipeConsumptionEntry(
            pantryItemId: entry.item.id,
            consumedValue: entry.item.quantityValue ?? 0,
            consumedUnit: entry.item.quantityUnit,
          ),
        );
        continue;
      }

      if (entry.consumedValue == null || entry.consumedValue! <= 0) {
        continue;
      }

      final current = entry.item.quantityValue;
      if (current == null) {
        continue;
      }

      final remaining = current - entry.consumedValue!;
      if (remaining <= 0) {
        updates.add(PantryConsumptionUpdate(itemId: entry.item.id, archive: true));
      } else {
        updates.add(
          PantryConsumptionUpdate(
            itemId: entry.item.id,
            archive: false,
            newQuantityValue: remaining,
          ),
        );
      }

      entries.add(
        RecipeConsumptionEntry(
          pantryItemId: entry.item.id,
          consumedValue: entry.consumedValue!,
          consumedUnit: entry.item.quantityUnit,
        ),
      );
    }

    if (updates.isEmpty) {
      return;
    }

    await ref.read(pantryRepositoryProvider).applyRecipeConsumption(
          uid,
          attempt.id,
          updates,
        );

    await ref.read(recipeAttemptRepositoryProvider).completeAttempt(
          uid,
          attempt.id,
          updates.map((item) => item.itemId).toList(growable: false),
          entries,
        );
  }

  String _normalize(String input) {
    return input.toLowerCase().trim();
  }
}

class _PantryCard extends StatelessWidget {
  const _PantryCard({
    super.key,
    required this.item,
    required this.daysUntilExpiry,
    required this.style,
    required this.onEdit,
    required this.onThrow,
  });

  final PantryItem item;
  final int? daysUntilExpiry;
  final FreshnessStyle style;
  final VoidCallback onEdit;
  final VoidCallback? onThrow;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.isPerishableNoExpiry
        ? 'No fixed expiry date • Use soon'
        : daysUntilExpiry == null
            ? 'Expiry unknown'
            : daysUntilExpiry! <= 0
                ? 'Expired'
                : 'Expires in $daysUntilExpiry day(s)';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (item.expirySource == ExpirySource.inferred)
                  Tooltip(
                    message: 'Expiry is inferred. Please verify safety manually.',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (item.isPerishableNoExpiry)
                  Tooltip(
                    message: 'Perishable item without known date. Check quality before use.',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.access_time_filled_rounded,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.badge,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      style.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item.category} • $subtitle'),
            const SizedBox(height: 2),
            Text(
              'Qty: ${item.quantityValue ?? '-'} ${item.quantityUnit ?? ''} ${item.quantityNote ?? ''}',
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                if (onThrow != null)
                  FilledButton.icon(
                    onPressed: onThrow,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Throw'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipePendingBanner extends StatelessWidget {
  const _RecipePendingBanner({
    required this.attempt,
    required this.onComplete,
    required this.onCancel,
  });

  final RecipeAttempt attempt;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Recipe in progress: ${attempt.recipeTitle}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Did you go through with this recipe?'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: onComplete,
                    child: const Text('Complete Recipe'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteRecipeSheet extends StatefulWidget {
  const _CompleteRecipeSheet({required this.initialMatched});

  final List<PantryItem> initialMatched;

  @override
  State<_CompleteRecipeSheet> createState() => _CompleteRecipeSheetState();
}

class _CompleteRecipeSheetState extends State<_CompleteRecipeSheet> {
  late final List<_ConsumptionInput> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialMatched
        .map((item) => _ConsumptionInput(item: item))
        .toList(growable: true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Confirm Used Ingredients', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const Text('Enter consumed amount. Use "Remove all" if item is fully used.'),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              const Text('No exact pantry matches found for this recipe.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: _items
                      .map(
                        (entry) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(entry.item.name),
                                Text(
                                  'Current: ${entry.item.quantityValue ?? '-'} ${entry.item.quantityUnit ?? ''}',
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  enabled: !entry.archive,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Consumed amount',
                                  ),
                                  onChanged: (v) {
                                    entry.consumedValue = double.tryParse(v);
                                  },
                                ),
                                CheckboxListTile(
                                  value: entry.archive,
                                  onChanged: (v) => setState(() => entry.archive = v ?? false),
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Remove all remaining quantity'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Apply Consumption'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    for (final entry in _items) {
      if (entry.archive) {
        continue;
      }
      if (entry.consumedValue == null || entry.consumedValue! <= 0) {
        continue;
      }
      final current = entry.item.quantityValue;
      if (current != null && entry.consumedValue! > current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Consumed amount exceeds ${entry.item.name} quantity.')),
        );
        return;
      }
    }

    Navigator.of(context).pop(_items);
  }
}

class _ConsumptionInput {
  _ConsumptionInput({required this.item});

  final PantryItem item;
  double? consumedValue;
  bool archive = false;
}
