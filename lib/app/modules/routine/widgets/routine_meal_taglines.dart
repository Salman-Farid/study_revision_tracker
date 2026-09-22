import 'dart:math';

/// Food / brain-fuel tips for meal tiles (Breakfast, Lunch, Snack, Dinner).
/// Never show the same line twice in one day — use [uniqueForDay].
class RoutineMealTaglines {
  RoutineMealTaglines._();

  static const List<String> breakfast = [
    'Have some good breakfast.',
    '🍳 Have at least 1 egg with your breakfast.',
    'Start the day with protein — egg, milk, or beans.',
    'Pair breakfast with fruit for steady morning focus.',
    'Don\'t skip breakfast — your first study block needs fuel.',
    'Whole grains + protein = longer attention span.',
    'Add nuts or seeds to breakfast for healthy fats.',
    'A warm breakfast beats a rushed empty stomach.',
  ];

  static const List<String> lunch = [
    '🥬 Add dal and vegetables to your lunch.',
    'Keep lunch balanced — rice/roti + protein + greens.',
    'Eat lunch away from the screen. Full break, better afternoon.',
    'Include a vegetable curry — your brain likes the micronutrients.',
    'Don\'t study through lunch. Refuel properly.',
    'Add a protein source (egg, fish, chicken, or dal) to lunch.',
    'Light enough to avoid a crash, solid enough to last till snack.',
  ];

  static const List<String> snack = [
    '🍎 Include 1 seasonal fruit in your snack.',
    'A handful of nuts beats chips for study stamina.',
    'Banana + peanut butter = quick clean energy.',
    'Choose fruit or yogurt over sugary snacks.',
    'Dark chocolate square (small) can lift afternoon focus.',
    'Hydrate with the snack — thirst looks like tiredness.',
  ];

  static const List<String> dinner = [
    '🐟 Keep a protein source like fish, egg, or meat in your dinner.',
    'Eat dinner early enough to sleep well after study.',
    'Add greens to dinner for overnight recovery.',
    'Lighter dinner → clearer night revision.',
    'Include eggs or fish if today\'s meals were low on protein.',
    'Finish dinner before the last study block when you can.',
  ];

  /// General brain-food tips (any meal).
  static const List<String> brainBoost = [
    '💧 Drink enough water throughout the day.',
    'Keep some dark chocolate in your diet to support memory and brain health.',
    'Have a handful of nuts to support memory and brain function.',
    'Include eggs in your meals to support memory and learning.',
    'Eat fish regularly for omega-3s that support brain health.',
    'Add leafy greens to your meals to support overall brain function.',
    'Have bananas for nutrients that support normal brain function.',
    'Add chia seeds for plant-based omega-3s that support brain health.',
    'Turmeric and colorful veggies support overall brain health.',
    'Limit heavy fried food before long study sessions.',
  ];

  static final Random _rng = Random();

  static List<String> poolFor(String mealName) {
    final n = mealName.toLowerCase();
    if (n.contains('break')) return breakfast; // breakfast
    if (n.contains('lunch')) return lunch;
    if (n.contains('snack') || n.contains('nasta') || n.contains('নাস্তা')) {
      return snack;
    }
    if (n.contains('dinner') || n.contains('supper')) return dinner;
    return [...breakfast, ...lunch, ...snack, ...dinner, ...brainBoost];
  }

  static List<String> get all => [...breakfast, ...lunch, ...snack, ...dinner, ...brainBoost];

  /// Unique tip for one meal block. Prefers meal-specific copy, then brain tips.
  static String uniqueForDay(String mealName, {Set<String> avoid = const {}}) {
    final mealPool = poolFor(mealName).where((l) => !avoid.contains(l)).toList();
    if (mealPool.isNotEmpty) {
      return mealPool[_rng.nextInt(mealPool.length)];
    }
    final free = brainBoost.where((l) => !avoid.contains(l)).toList();
    final pool = free.isEmpty
        ? all.where((l) => !avoid.contains(l)).toList()
        : free;
    if (pool.isEmpty) return 'Eat well for steady study energy.';
    return pool[_rng.nextInt(pool.length)];
  }

  /// Deterministic fallback when notes were not stamped at save time.
  static String pickFor(String seed, String mealName) {
    final pool = poolFor(mealName);
    if (pool.isEmpty) return 'Eat well for steady study energy.';
    final h = seed.hashCode.abs();
    // Avoid rare overflow when hashCode is min-int (abs stays negative).
    final idx = h % pool.length;
    return pool[idx < 0 ? -idx % pool.length : idx];
  }

  /// Assign distinct lines for several meals in one day (in order).
  static List<String> uniqueBatchForDay(List<String> mealNames) {
    final used = <String>{};
    final out = <String>[];
    for (final name in mealNames) {
      final line = uniqueForDay(name, avoid: used);
      used.add(line);
      out.add(line);
    }
    return out;
  }
}
