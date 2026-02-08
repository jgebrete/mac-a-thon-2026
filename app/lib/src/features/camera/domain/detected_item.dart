import '../../../core/utils/date_utils.dart';
import '../../pantry/domain/pantry_item.dart';

class DetectedPantryItem {
  DetectedPantryItem({
    required this.name,
    required this.category,
    required this.detectedExpiryDate,
    required this.inferredExpiryDate,
    required this.confidence,
    this.expiryReason,
    this.quantityValue,
    this.quantityUnit,
    this.quantityNote,
  });

  final String name;
  final String category;
  final DateTime? detectedExpiryDate;
  final DateTime? inferredExpiryDate;
  final double confidence;
  final String? expiryReason;
  final double? quantityValue;
  final String? quantityUnit;
  final String? quantityNote;

  factory DetectedPantryItem.fromJson(Map<String, dynamic> json) {
    final detected = _sanitizeModelDate(parseIsoDate((json['expiryDateISO'] as String?) ?? ''));
    final inferred =
        _sanitizeModelDate(parseIsoDate((json['expiryInferenceISO'] as String?) ?? ''));
    return DetectedPantryItem(
      name: (json['name'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? 'Other',
      detectedExpiryDate: detected,
      inferredExpiryDate: inferred,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      expiryReason: (json['expiryReason'] as String?)?.trim(),
      quantityValue: (json['quantityValue'] as num?)?.toDouble(),
      quantityUnit: (json['quantityUnit'] as String?)?.trim(),
      quantityNote: (json['quantityNote'] as String?)?.trim(),
    );
  }

  static DateTime? _sanitizeModelDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    if (value.year < 2000) {
      return null;
    }
    return value;
  }

  PantryItem toPantryItem() {
    final now = DateTime.now();
    return PantryItem(
      id: '',
      name: name,
      category: category,
      expiryDate: detectedExpiryDate ?? inferredExpiryDate,
      quantityValue: quantityValue,
      quantityUnit: quantityUnit,
      quantityNote: quantityNote,
      addedAt: now,
      updatedAt: now,
      source: PantryItemSource.scan,
      scanConfidence: confidence,
      isArchived: false,
      expirySource: detectedExpiryDate != null
          ? ExpirySource.detected
          : inferredExpiryDate != null
              ? ExpirySource.inferred
              : ExpirySource.manual,
      expiryConfidence: confidence,
      expiryInferenceNoticeShown: inferredExpiryDate != null,
      isPerishableNoExpiry: false,
    );
  }
}
