import '../domain/pantry_item.dart';

List<PantryItem> sortPantryItems(List<PantryItem> items, PantrySort sort) {
  final sorted = List<PantryItem>.from(items);

  switch (sort) {
    case PantrySort.expiryAsc:
      sorted.sort(_compareExpiryAsc);
    case PantrySort.expiryDesc:
      sorted.sort((a, b) => _compareExpiryAsc(b, a));
    case PantrySort.nameAsc:
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case PantrySort.nameDesc:
      sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case PantrySort.recentlyAdded:
      sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  return sorted;
}

int _compareExpiryAsc(PantryItem a, PantryItem b) {
  final aBucket = _expiryBucket(a);
  final bBucket = _expiryBucket(b);
  if (aBucket != bBucket) {
    return aBucket.compareTo(bBucket);
  }

  if (aBucket == 0 || aBucket == 2) {
    final aDate = a.expiryDate!;
    final bDate = b.expiryDate!;
    return aDate.compareTo(bDate);
  }

  if (aBucket == 1) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  return a.addedAt.compareTo(b.addedAt);
}

int _expiryBucket(PantryItem item) {
  final now = DateTime.now();
  final date = item.expiryDate;
  if (date != null && !date.isAfter(DateTime(now.year, now.month, now.day))) {
    return 0;
  }
  if (item.isPerishableNoExpiry) {
    return 1;
  }
  if (date != null) {
    return 2;
  }
  return 3;
}
