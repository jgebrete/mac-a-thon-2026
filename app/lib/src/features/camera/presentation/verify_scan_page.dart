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
          if (widget.warnings.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.warnings
                      .map((warning) => Text('• $warning'))
                      .toList(growable: false),
                ),
              ),
            ),
          ..._buildItemCards(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _items.add(_EditableDetectedItem.empty())),
            icon: const Icon(Icons.add),
            label: const Text('Add Row'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Scan'),
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
      final missingDetectedExpiry = item.detectedExpiryDate == null;

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
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: item.isPerishableNoExpiry
                            ? null
                            : () => _pickDateForItem(item),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          item.selectedExpiryDate == null
                              ? 'Pick expiry date'
                              : formatDate(item.selectedExpiryDate),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: item.isPerishableNoExpiry,
                  onChanged: (value) {
                    setState(() {
                      item.isPerishableNoExpiry = value;
                      if (value) {
                        item.selectedExpiryDate = null;
                        item.expirySource = ExpirySource.manual;
                      }
                    });
                  },
                  title: const Text('Perishable with no known expiry date'),
                  subtitle: const Text('Prioritize usage soon without exact expiry date'),
                ),
                if (missingDetectedExpiry) ...<Widget>[
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Expiry date not detected. Please verify manually.',
                          ),
                          if (item.expiryReason != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(item.expiryReason!),
                            ),
                          if (item.inferredExpiryDate != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              'Suggested: ${formatDate(item.inferredExpiryDate)}',
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  item.isPerishableNoExpiry = false;
                                  item.selectedExpiryDate = item.inferredExpiryDate;
                                  item.expirySource = ExpirySource.inferred;
                                  item.expiryInferenceNoticeShown = true;
                                });
                              },
                              icon: const Icon(Icons.warning_amber_rounded),
                              label: const Text('Use suggested (approximate)'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
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

    final invalid = _items.where((item) {
      return item.name.trim().isNotEmpty &&
          item.selectedExpiryDate == null &&
          !item.isPerishableNoExpiry;
    }).isNotEmpty;
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick expiry date or mark item as perishable no-expiry.'),
        ),
      );
      return;
    }

    final validItems = _items.where((item) {
      if (item.name.trim().isEmpty) {
        return false;
      }
      return item.selectedExpiryDate != null || item.isPerishableNoExpiry;
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
              expiryDate: item.selectedExpiryDate,
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
              expirySource: item.expirySource,
              expiryConfidence: item.confidence,
              expiryInferenceNoticeShown: item.expiryInferenceNoticeShown,
              isPerishableNoExpiry: item.isPerishableNoExpiry,
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

  Future<void> _pickDateForItem(_EditableDetectedItem item) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampPickerDate(item.selectedExpiryDate ?? now, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      item.isPerishableNoExpiry = false;
      item.selectedExpiryDate = dateOnly(picked);
      if (item.detectedExpiryDate != null) {
        item.expirySource = ExpirySource.detected;
      } else if (item.expirySource != ExpirySource.inferred) {
        item.expirySource = ExpirySource.manual;
      }
    });
  }

  DateTime _clampPickerDate(DateTime value, DateTime firstDate, DateTime lastDate) {
    if (value.isBefore(firstDate)) {
      return firstDate;
    }
    if (value.isAfter(lastDate)) {
      return lastDate;
    }
    return value;
  }
}

class _EditableDetectedItem {
  _EditableDetectedItem({
    required this.name,
    required this.category,
    required this.detectedExpiryDate,
    required this.inferredExpiryDate,
    required this.selectedExpiryDate,
    required this.confidence,
    required this.expirySource,
    required this.expiryInferenceNoticeShown,
    required this.isPerishableNoExpiry,
    this.expiryReason,
    this.quantityValue,
    this.quantityUnit,
    this.quantityNote,
  });

  factory _EditableDetectedItem.fromDetected(DetectedPantryItem item) {
    final hasDetected = item.detectedExpiryDate != null;
    return _EditableDetectedItem(
      name: item.name,
      category: item.category,
      detectedExpiryDate: item.detectedExpiryDate,
      inferredExpiryDate: item.inferredExpiryDate,
      selectedExpiryDate: item.detectedExpiryDate,
      confidence: item.confidence,
      expirySource: hasDetected ? ExpirySource.detected : ExpirySource.manual,
      expiryInferenceNoticeShown: false,
      isPerishableNoExpiry: false,
      expiryReason: item.expiryReason,
      quantityValue: item.quantityValue,
      quantityUnit: item.quantityUnit,
      quantityNote: item.quantityNote,
    );
  }

  factory _EditableDetectedItem.empty() {
    return _EditableDetectedItem(
      name: '',
      category: 'Other',
      detectedExpiryDate: null,
      inferredExpiryDate: null,
      selectedExpiryDate: null,
      confidence: 0,
      expirySource: ExpirySource.manual,
      expiryInferenceNoticeShown: false,
      isPerishableNoExpiry: false,
    );
  }

  String name;
  String category;
  DateTime? detectedExpiryDate;
  DateTime? inferredExpiryDate;
  DateTime? selectedExpiryDate;
  double confidence;
  ExpirySource expirySource;
  bool expiryInferenceNoticeShown;
  bool isPerishableNoExpiry;
  String? expiryReason;
  double? quantityValue;
  String? quantityUnit;
  String? quantityNote;
}
