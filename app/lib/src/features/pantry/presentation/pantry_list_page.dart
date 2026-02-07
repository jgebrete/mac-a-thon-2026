import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/pantry_repository.dart';
import '../data/pantry_sorter.dart';
import '../domain/pantry_item.dart';

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

    return Column(
      children: <Widget>[
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
                return const Center(child: Text('No pantry items yet.'));
              }

              final sorted = sortPantryItems(items, _sort);
              return ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  return ListTile(
                    key: ValueKey(item.id),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.category} • Exp ${formatDate(item.expiryDate)} • ${item.quantityValue ?? '-'} ${item.quantityUnit ?? ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditDialog(context, item);
                        } else if (value == 'delete') {
                          _archiveItem(item);
                        }
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                        PopupMenuItem<String>(value: 'delete', child: Text('Remove')),
                      ],
                    ),
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

  Future<void> _archiveItem(PantryItem item) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }
    await ref.read(pantryRepositoryProvider).archiveItem(uid, item);
  }

  Future<void> _openEditDialog(BuildContext context, PantryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final categoryController = TextEditingController(text: item.category);
    final expiryController = TextEditingController(text: formatDate(item.expiryDate));
    final quantityValueController = TextEditingController(
      text: item.quantityValue?.toString() ?? '',
    );
    final quantityUnitController = TextEditingController(text: item.quantityUnit ?? '');
    final quantityNoteController = TextEditingController(text: item.quantityNote ?? '');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<PantryItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Pantry Item'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ingredient Name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  TextFormField(
                    controller: expiryController,
                    decoration: const InputDecoration(labelText: 'Expiry (yyyy-MM-dd)'),
                    validator: (value) => parseIsoDate(value ?? '') == null
                        ? 'Use yyyy-MM-dd'
                        : null,
                  ),
                  TextFormField(
                    controller: quantityValueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity Value'),
                  ),
                  TextFormField(
                    controller: quantityUnitController,
                    decoration: const InputDecoration(labelText: 'Quantity Unit'),
                  ),
                  TextFormField(
                    controller: quantityNoteController,
                    decoration: const InputDecoration(labelText: 'Quantity Note'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  item.copyWith(
                    name: nameController.text.trim(),
                    category: categoryController.text.trim().isEmpty
                        ? 'Other'
                        : categoryController.text.trim(),
                    expiryDate: parseIsoDate(expiryController.text.trim())!,
                    quantityValue: double.tryParse(quantityValueController.text.trim()),
                    quantityUnit: quantityUnitController.text.trim().isEmpty
                        ? null
                        : quantityUnitController.text.trim(),
                    quantityNote: quantityNoteController.text.trim().isEmpty
                        ? null
                        : quantityNoteController.text.trim(),
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }

    await ref.read(pantryRepositoryProvider).updateItem(uid, result);
  }
}


