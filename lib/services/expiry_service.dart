import '../models/food_item.dart';

class ExpiryService {
  DateTime predictExpiry(String? category, StorageLocation location, DateTime purchased, {DateTime? openDate, DateTime? bestBefore}) {
    int days = 7;
    if (location == StorageLocation.freezer) {
      days = 90;
    } else if (location == StorageLocation.pantry) {
      days = 14;
    } else if (location == StorageLocation.fridge) {
      days = 5;
    }

    if (bestBefore != null) {
      final ruleDate = purchased.add(Duration(days: days));
      if (ruleDate.isAfter(bestBefore)) return bestBefore;
      return ruleDate;
    }
    if (openDate != null) {
      days = (days * 0.7).round();
      return openDate.add(Duration(days: days));
    }
    return purchased.add(Duration(days: days));
  }
}