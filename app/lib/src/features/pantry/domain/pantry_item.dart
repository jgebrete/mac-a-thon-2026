import 'package:cloud_firestore/cloud_firestore.dart';

enum PantryItemSource { scan, manual }

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
  });

  final String id;
  final String name;
  final String category;
  final DateTime expiryDate;
  final DateTime addedAt;
  final DateTime updatedAt;
  final PantryItemSource source;
  final bool isArchived;
  final double? quantityValue;
  final String? quantityUnit;
  final String? quantityNote;
  final double? scanConfidence;

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
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'quantityValue': quantityValue,
      'quantityUnit': quantityUnit,
      'quantityNote': quantityNote,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'source': source.name,
      'scanConfidence': scanConfidence,
      'isArchived': isArchived,
    };
  }

  static PantryItem fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PantryItem(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Unknown Item',
      category: (data['category'] as String?)?.trim() ?? 'Other',
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    );
  }
}

enum PantrySort { expiryAsc, expiryDesc, nameAsc, nameDesc, recentlyAdded }
