import 'package:app/src/features/pantry/data/pantry_sorter.dart';
import 'package:app/src/features/pantry/domain/pantry_item.dart';
import 'package:flutter_test/flutter_test.dart';

PantryItem _item({
  required String id,
  required String name,
  required String expiry,
  required String addedAt,
}) {
  return PantryItem(
    id: id,
    name: name,
    category: 'Other',
    expiryDate: DateTime.parse(expiry),
    addedAt: DateTime.parse(addedAt),
    updatedAt: DateTime.parse(addedAt),
    source: PantryItemSource.manual,
    isArchived: false,
  );
}

void main() {
  final items = <PantryItem>[
    _item(id: '1', name: 'Milk', expiry: '2026-02-20', addedAt: '2026-02-10'),
    _item(id: '2', name: 'Apple', expiry: '2026-02-12', addedAt: '2026-02-12'),
    _item(id: '3', name: 'Bread', expiry: '2026-02-15', addedAt: '2026-02-11'),
  ];

  test('sortPantryItems expiryAsc sorts nearest expiry first', () {
    final sorted = sortPantryItems(items, PantrySort.expiryAsc);
    expect(sorted.map((e) => e.name).toList(), ['Apple', 'Bread', 'Milk']);
  });

  test('sortPantryItems nameAsc sorts alphabetically', () {
    final sorted = sortPantryItems(items, PantrySort.nameAsc);
    expect(sorted.map((e) => e.name).toList(), ['Apple', 'Bread', 'Milk']);
  });
}
