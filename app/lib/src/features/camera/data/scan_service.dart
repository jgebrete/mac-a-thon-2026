import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/detected_item.dart';

class ScanService {
  ScanService(this._functions);

  final FirebaseFunctions _functions;

  Future<ScanResponse> extractItemsFromImage({
    required List<int> bytes,
    required String mimeType,
  }) async {
    final callable = _functions.httpsCallable('extractPantryItemsFromImage');
    final result = await callable.call(<String, dynamic>{
      'imageBase64': base64Encode(bytes),
      'mimeType': mimeType,
    });

    final data = Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
    final rawItems = (data['items'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList(growable: false);

    return ScanResponse(
      warnings: (data['warnings'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      items: rawItems.map(DetectedPantryItem.fromJson).toList(growable: false),
    );
  }
}

final scanServiceProvider = Provider<ScanService>((ref) {
  return ScanService(FirebaseFunctions.instance);
});

class ScanResponse {
  ScanResponse({required this.items, required this.warnings});

  final List<DetectedPantryItem> items;
  final List<String> warnings;
}
