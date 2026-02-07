import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/quantity_units.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/pantry_item.dart';
import '../domain/detected_item.dart';

class VerifyScanPage extends ConsumerStatefulWidget {
  const VerifyScanPage({
    super.key,
    required this.initialItems,
    required this.warnings,
  });

  final List<DetectedPantryItem> initialItems;
  final List<String> warnings;

  @override
  ConsumerState<VerifyScanPage> createState() => _VerifyScanPageState();
}

class _VerifyScanPageState extends ConsumerState<VerifyScanPage> {
  late final List<_EditableDetectedItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems
        .map(_EditableDetectedItem.fromDetected)
        .toList(growable: true);
    if (_items.isEmpty) {
      _items.add(_EditableDetectedItem.empty());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Scan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final warning in widget.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(warning),
            ),
          ..._buildItemCards(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _items.add(_EditableDetectedItem.empty())),
            icon: const Icon(Icons.add),
            label: const Text('Add Row'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save To Pantry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItemCards() {
    final widgets = <Widget>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      widgets.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Item ${i + 1}'),
                    const Spacer(),
                    IconButton(
                      onPressed: _items.length == 1
                          ? null
                          : () => setState(() => _items.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: item.name,
                  decoration: const InputDecoration(labelText: 'Ingredient Name'),
                  onChanged: (v) => item.name = v,
                ),
                TextFormField(
                  initialValue: item.category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: (v) => item.category = v,
                ),
                TextFormField(
                  initialValue: formatDate(item.expiryDate),
                  decoration: const InputDecoration(labelText: 'Expiry (yyyy-MM-dd)'),
                  onChanged: (v) => item.expiryDate = parseIsoDate(v),
                ),
                TextFormField(
                  initialValue: item.quantityValue?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity Value'),
                  onChanged: (v) => item.quantityValue = double.tryParse(v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: quantityUnits.contains(item.quantityUnit)
                      ? item.quantityUnit
                      : 'other',
                  items: quantityUnits
                      .map(
                        (unit) => DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => item.quantityUnit = value,
                  decoration: const InputDecoration(labelText: 'Quantity Unit'),
                ),
                TextFormField(
                  initialValue: item.quantityNote,
                  decoration: const InputDecoration(labelText: 'Quantity Note'),
                  onChanged: (v) => item.quantityNote = v,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Future<void> _save() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) {
      return;
    }

    final validItems = _items.where((item) {
      return item.name.trim().isNotEmpty && item.expiryDate != null;
    }).toList(growable: false);

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one valid item.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final items = validItems
          .map(
            (item) => PantryItem(
              id: '',
              name: item.name.trim(),
              category: item.category.trim().isEmpty ? 'Other' : item.category.trim(),
              expiryDate: item.expiryDate!,
              quantityValue: item.quantityValue,
              quantityUnit: item.quantityUnit,
              quantityNote: item.quantityNote?.trim().isEmpty ?? true
                  ? null
                  : item.quantityNote?.trim(),
              addedAt: now,
              updatedAt: now,
              source: PantryItemSource.scan,
              scanConfidence: item.confidence,
              isArchived: false,
            ),
          )
          .toList(growable: false);

      await ref.read(pantryRepositoryProvider).addItems(uid, items);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _EditableDetectedItem {
  _EditableDetectedItem({
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.confidence,
    this.quantityValue,
    this.quantityUnit,
    this.quantityNote,
  });

  factory _EditableDetectedItem.fromDetected(DetectedPantryItem item) {
    return _EditableDetectedItem(
      name: item.name,
      category: item.category,
      expiryDate: item.expiryDate,
      confidence: item.confidence,
      quantityValue: item.quantityValue,
      quantityUnit: item.quantityUnit,
      quantityNote: item.quantityNote,
    );
  }

  factory _EditableDetectedItem.empty() {
    return _EditableDetectedItem(
      name: '',
      category: 'Other',
      expiryDate: null,
      confidence: 0,
    );
  }

  String name;
  String category;
  DateTime? expiryDate;
  double confidence;
  double? quantityValue;
  String? quantityUnit;
  String? quantityNote;
}
