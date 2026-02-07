import '../domain/pantry_item.dart';

List<PantryItem> sortPantryItems(List<PantryItem> items, PantrySort sort) {
  final sorted = List<PantryItem>.from(items);

  switch (sort) {
    case PantrySort.expiryAsc:
      sorted.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    case PantrySort.expiryDesc:
      sorted.sort((a, b) => b.expiryDate.compareTo(a.expiryDate));
    case PantrySort.nameAsc:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PantrySort.nameDesc:
      sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case PantrySort.recentlyAdded:
      sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  return sorted;
}
