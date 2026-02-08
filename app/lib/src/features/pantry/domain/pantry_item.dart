import 'package:cloud_firestore/cloud_firestore.dart';

enum PantryItemSource { scan, manual }
enum PantryArchivedReason { thrown, consumedRecipe }
enum ExpirySource { detected, inferred, manual }

class PantryItem {
  PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.addedAt,
    required this.updatedAt,
    required this.source,
    required this.isArchived,
    this.quantityValue,
    this.quantityUnit,
    this.quantityNote,
    this.scanConfidence,
    this.archivedReason,
    this.lastRecipeAttemptId,
    this.expirySource = ExpirySource.manual,
    this.expiryConfidence,
    this.expiryInferenceNoticeShown = false,
    this.isPerishableNoExpiry = false,
  });

  final String id;
  final String name;
  final String category;
  final DateTime? expiryDate;
  final DateTime addedAt;
  final DateTime updatedAt;
  final PantryItemSource source;
  final bool isArchived;
  final double? quantityValue;
  final String? quantityUnit;
  final String? quantityNote;
  final double? scanConfidence;
  final PantryArchivedReason? archivedReason;
  final String? lastRecipeAttemptId;
  final ExpirySource expirySource;
  final double? expiryConfidence;
  final bool expiryInferenceNoticeShown;
  final bool isPerishableNoExpiry;

  PantryItem copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? expiryDate,
    DateTime? addedAt,
    DateTime? updatedAt,
    PantryItemSource? source,
    bool? isArchived,
    double? quantityValue,
    String? quantityUnit,
    String? quantityNote,
    double? scanConfidence,
    PantryArchivedReason? archivedReason,
    String? lastRecipeAttemptId,
    ExpirySource? expirySource,
    double? expiryConfidence,
    bool? expiryInferenceNoticeShown,
    bool? isPerishableNoExpiry,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      isArchived: isArchived ?? this.isArchived,
      quantityValue: quantityValue ?? this.quantityValue,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      quantityNote: quantityNote ?? this.quantityNote,
      scanConfidence: scanConfidence ?? this.scanConfidence,
      archivedReason: archivedReason ?? this.archivedReason,
      lastRecipeAttemptId: lastRecipeAttemptId ?? this.lastRecipeAttemptId,
      expirySource: expirySource ?? this.expirySource,
      expiryConfidence: expiryConfidence ?? this.expiryConfidence,
      expiryInferenceNoticeShown:
          expiryInferenceNoticeShown ?? this.expiryInferenceNoticeShown,
      isPerishableNoExpiry: isPerishableNoExpiry ?? this.isPerishableNoExpiry,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'quantityValue': quantityValue,
      'quantityUnit': quantityUnit,
      'quantityNote': quantityNote,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'source': source.name,
      'scanConfidence': scanConfidence,
      'isArchived': isArchived,
      'archivedReason': archivedReason?.name,
      'lastRecipeAttemptId': lastRecipeAttemptId,
      'expirySource': expirySource.name,
      'expiryConfidence': expiryConfidence,
      'expiryInferenceNoticeShown': expiryInferenceNoticeShown,
      'isPerishableNoExpiry': isPerishableNoExpiry,
    };
  }

  static PantryItem fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PantryItem(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Unknown Item',
      category: (data['category'] as String?)?.trim() ?? 'Other',
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      quantityValue: (data['quantityValue'] as num?)?.toDouble(),
      quantityUnit: (data['quantityUnit'] as String?)?.trim(),
      quantityNote: (data['quantityNote'] as String?)?.trim(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: (data['source'] as String?) == PantryItemSource.scan.name
          ? PantryItemSource.scan
          : PantryItemSource.manual,
      scanConfidence: (data['scanConfidence'] as num?)?.toDouble(),
      isArchived: data['isArchived'] as bool? ?? false,
      archivedReason: _archivedReasonFromString(data['archivedReason'] as String?),
      lastRecipeAttemptId: data['lastRecipeAttemptId'] as String?,
      expirySource: _expirySourceFromString(data['expirySource'] as String?),
      expiryConfidence: (data['expiryConfidence'] as num?)?.toDouble(),
      expiryInferenceNoticeShown:
          data['expiryInferenceNoticeShown'] as bool? ?? false,
      isPerishableNoExpiry: data['isPerishableNoExpiry'] as bool? ?? false,
    );
  }

  static PantryArchivedReason? _archivedReasonFromString(String? value) {
    if (value == PantryArchivedReason.thrown.name) {
      return PantryArchivedReason.thrown;
    }
    if (value == PantryArchivedReason.consumedRecipe.name) {
      return PantryArchivedReason.consumedRecipe;
    }
    return null;
  }

  static ExpirySource _expirySourceFromString(String? value) {
    switch (value) {
      case 'detected':
        return ExpirySource.detected;
      case 'inferred':
        return ExpirySource.inferred;
      case 'manual':
      default:
        return ExpirySource.manual;
    }
  }
}

enum PantrySort { expiryAsc, expiryDesc, nameAsc, nameDesc, recentlyAdded }
