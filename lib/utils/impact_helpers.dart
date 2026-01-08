// lib/utils/impact_helpers.dart

class ImpactHelpers {
  /// Converts saved money into relatable items for students
  static String getMoneyEquivalent(double amount) {
    if (amount <= 0) return 'Start saving!';
    
    if (amount < 5) {
      final count = (amount / 1.5).toStringAsFixed(1);
      return '≈ $count Sodas 🥤';
    } else if (amount < 20) {
      final count = (amount / 6.0).toStringAsFixed(1);
      return '≈ $count Döners 🥙';
    } else if (amount < 60) {
      final count = (amount / 15.0).toStringAsFixed(1);
      return '≈ $count mth Netflix 📺';
    } else if (amount < 150) {
      final count = (amount / 60.0).toStringAsFixed(1);
      return '≈ $count Video Games 🎮';
    } else {
      final count = (amount / 120.0).toStringAsFixed(1);
      return '≈ $count pairs of Sneakers 👟';
    }
  }

  /// Converts CO2 kg into relatable actions
  static String getCo2Equivalent(double kg) {
    if (kg <= 0) return 'No impact yet';

    // 1 smartphone charge ≈ 0.005 kg CO2 (very rough estimate for visualization)
    if (kg < 1) {
      final charges = (kg / 0.005).floor();
      return '≈ $charges Phone charges 📱';
    } 
    // 1 km by car ≈ 0.12 kg CO2
    else if (kg < 10) {
      final km = (kg / 0.12).toStringAsFixed(1);
      return '≈ Driving $km km 🚗';
    } 
    // 1 Tree absorbs ~20kg CO2 per year
    else {
      final trees = (kg / 20).toStringAsFixed(2);
      return '≈ Planting $trees Trees 🌳';
    }
  }

  /// Gamification: Gives a title based on savings
  static String getSavingsTitle(double amount) {
    if (amount < 10) return 'Smart Saver';
    if (amount < 50) return 'Fridge Master';
    if (amount < 100) return 'Budget Ninja 🥷';
    if (amount < 300) return 'Dorm Tycoon 💰';
    return 'Sustainability Legend 👑';
  }

  /// Projections: "At this rate..."
  static String getProjectedSavings(double currentAmount, String rangeMode) {
    double yearly = 0;
    if (rangeMode == 'week') {
      yearly = currentAmount * 52;
    } else if (rangeMode == 'month') {
      yearly = currentAmount * 12;
    } else {
      yearly = currentAmount;
    }
    
    return 'On track to save €${yearly.toStringAsFixed(0)} / year';
  }
}