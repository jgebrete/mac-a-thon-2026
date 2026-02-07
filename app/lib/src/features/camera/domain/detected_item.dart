import '../../../core/utils/date_utils.dart';
import '../../pantry/domain/pantry_item.dart';

class DetectedPantryItem {
  DetectedPantryItem({
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.confidence,
    this.quantityValue,
    this.quantityUnit,
    this.quantityNote,
  });

  final String name;
  final String category;
  final DateTime? expiryDate;
  final double confidence;
  final double? quantityValue;
  final String? quantityUnit;
  final String? quantityNote;

  factory DetectedPantryItem.fromJson(Map<String, dynamic> json) {
    return DetectedPantryItem(
      name: (json['name'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? 'Other',
      expiryDate: parseIsoDate((json['expiryDateISO'] as String?) ?? ''),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      quantityValue: (json['quantityValue'] as num?)?.toDouble(),
      quantityUnit: (json['quantityUnit'] as String?)?.trim(),
      quantityNote: (json['quantityNote'] as String?)?.trim(),
    );
  }

  PantryItem toPantryItem() {
    final now = DateTime.now();
    return PantryItem(
      id: '',
      name: name,
      category: category,
      expiryDate: expiryDate ?? now,
      quantityValue: quantityValue,
      quantityUnit: quantityUnit,
      quantityNote: quantityNote,
      addedAt: now,
      updatedAt: now,
      source: PantryItemSource.scan,
      scanConfidence: confidence,
      isArchived: false,
    );
  }
}
