import 'dart:math';

/// Pool of motivational break lines for daily-routine break tiles.
/// Never repeat the same line twice in one routine — use [uniqueBatch].
class RoutineBreakTaglines {
  RoutineBreakTaglines._();

  static const List<String> all = [
    'Stretch your body. Don\'t worry — You\'re going to make it!',
    'Hydrate and recharge. It\'s a little tough today, next day, next week — then it\'s easy.',
    'Take a deep breath. Just stay focused. Don\'t waste your time on your phone. Stop watching reels & social media.',
    'Do some exercise or walk out. Study smartly — recall and spaced repetition. You don\'t have huge time, so use it properly.',
    'Stand up, roll your shoulders. One focused hour beats four distracted ones.',
    'Sip water, look away from the screen. Your brain consolidates while you rest.',
    'Phone down, mind up. Ten quiet minutes now = clearer recall later.',
    'Walk a few steps. Movement wakes the memory you just built.',
    'You showed up today — that already separates you from yesterday.',
    'Tough now, normal later. Keep the streak; don\'t negotiate with the plan.',
    'Close your eyes for a moment. Breathe in 4, out 6. Then back to the desk.',
    'No reels, no scrolling. This break is for you — not the algorithm.',
    'Shake it out. Spaced revision works if you return, not if you quit.',
    'You don\'t need more hours — you need honest focus in the hours you have.',
    'Stretch your neck and spine. A tired body steals attention from study.',
    'Next block is waiting. Finish this break clean, start the next one sharp.',
    'It\'s okay to find it hard. Difficulty means you\'re at the edge of learning.',
    'Hydrate. Your focus drops before you feel thirsty.',
    'Short walk, fresh air. Come back and attack the next topic.',
    'Recall what you just read — without notes. That\'s the real test.',
    'Don\'t compare your chapter 1 to someone else\'s chapter 20.',
    'Phone in another room for the next study block. Thank yourself later.',
    'Breathe. Reset. You\'re building a career one 50-minute block at a time.',
    'Stretch, smile, continue. Consistency beats intensity on exam weeks.',
    'This break ends in minutes — protect it. No doom-scrolling.',
    'You are not behind forever — you are behind today, and today can change.',
    'Light movement, deep breath. Memory loves a calm nervous system.',
    'Study smart: active recall + spaced repetition > re-reading forever.',
  ];

  static final Random _rng = Random();

  /// Shuffled unique lines for one routine build (cycles if n > pool size).
  static List<String> uniqueBatch(int n) {
    if (n <= 0) return const [];
    final idx = List<int>.generate(all.length, (i) => i)..shuffle(_rng);
    final out = <String>[];
    var i = 0;
    while (out.length < n) {
      out.add(all[idx[i % idx.length]]);
      i++;
      if (i % all.length == 0) idx.shuffle(_rng);
    }
    return out;
  }

  /// Next unused line relative to [avoid] (already used strings this day).
  static String unique({Set<String> avoid = const {}}) {
    final free = all.where((l) => !avoid.contains(l)).toList();
    final pool = free.isEmpty ? all : free;
    return pool[_rng.nextInt(pool.length)];
  }

  /// Stable pick for a seed — last resort when notes were not stamped.
  static String pickFor(String seed) =>
      all[seed.hashCode.abs() % all.length];

  /// Prefer distinct times → distinct indices when notes are missing.
  static String pickUniqueForDay(String dayKey, int breakIndex, Set<String> used) {
    final start = (dayKey.hashCode.abs() + breakIndex * 17) % all.length;
    for (var k = 0; k < all.length; k++) {
      final line = all[(start + k) % all.length];
      if (!used.contains(line)) {
        used.add(line);
        return line;
      }
    }
    return all[start];
  }
}
