import 'package:flutter/material.dart';

import '../../../core/constants/quantity_units.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/pantry_item.dart';

class ManualAddSheet extends StatefulWidget {
  const ManualAddSheet({super.key, this.initial});

  final PantryItem? initial;

  @override
  State<ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<ManualAddSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityValueController;
  late final TextEditingController _quantityNoteController;

  String? _quantityUnit;
  DateTime? _selectedExpiryDate;
  bool _isPerishableNoExpiry = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _categoryController = TextEditingController(text: widget.initial?.category ?? 'Other');
    _quantityValueController = TextEditingController(
      text: widget.initial?.quantityValue?.toString() ?? '',
    );
    _quantityNoteController = TextEditingController(text: widget.initial?.quantityNote ?? '');
    _quantityUnit = widget.initial?.quantityUnit ?? 'pcs';
    _selectedExpiryDate = _sanitizeInitialDate(widget.initial?.expiryDate);
    _isPerishableNoExpiry = widget.initial?.isPerishableNoExpiry ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityValueController.dispose();
    _quantityNoteController.dispose();
    super.dispose();
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.initial == null ? 'Add Ingredient Manually' : 'Edit Ingredient',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ingredient Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Expiry Date',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPerishableNoExpiry,
                onChanged: (value) {
                  setState(() {
                    _isPerishableNoExpiry = value;
                    if (value) {
                      _selectedExpiryDate = null;
                    }
                  });
                },
                title: const Text('Perishable with no known expiry date'),
                subtitle: const Text('Use soon priority without exact date'),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPerishableNoExpiry ? null : _pickExpiryDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _selectedExpiryDate == null
                            ? 'Pick date'
                            : formatDate(_selectedExpiryDate),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _quantityValueController,
                      decoration: const InputDecoration(labelText: 'Qty Value'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: quantityUnits.contains(_quantityUnit)
                          ? _quantityUnit
                          : 'pcs',
                      items: quantityUnits
                          .map((u) => DropdownMenuItem<String>(value: u, child: Text(u)))
                          .toList(growable: false),
                      onChanged: (v) => _quantityUnit = v,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _quantityNoteController,
                decoration: const InputDecoration(labelText: 'Quantity Note'),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_isPerishableNoExpiry && _selectedExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick an expiry date or enable perishable no-expiry.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final item = PantryItem(
      id: widget.initial?.id ?? '',
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'Other'
          : _categoryController.text.trim(),
      expiryDate: _selectedExpiryDate,
      quantityValue: double.tryParse(_quantityValueController.text.trim()),
      quantityUnit: _quantityUnit,
      quantityNote: _quantityNoteController.text.trim().isEmpty
          ? null
          : _quantityNoteController.text.trim(),
      addedAt: widget.initial?.addedAt ?? now,
      updatedAt: now,
      source: widget.initial?.source ?? PantryItemSource.manual,
      scanConfidence: widget.initial?.scanConfidence,
      isArchived: false,
      archivedReason: widget.initial?.archivedReason,
      lastRecipeAttemptId: widget.initial?.lastRecipeAttemptId,
      expirySource: widget.initial?.expirySource ?? ExpirySource.manual,
      expiryConfidence: widget.initial?.expiryConfidence,
      expiryInferenceNoticeShown: widget.initial?.expiryInferenceNoticeShown ?? false,
      isPerishableNoExpiry: _isPerishableNoExpiry,
    );

    Navigator.of(context).pop(item);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 10);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampPickerDate(_selectedExpiryDate ?? now, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedExpiryDate = dateOnly(picked);
    });
  }

  DateTime? _sanitizeInitialDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    if (value.year < 2000) {
      return null;
    }
    return value;
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
