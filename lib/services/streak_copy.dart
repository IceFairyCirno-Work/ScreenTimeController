class StreakCopy {
  final String title;
  final String body;

  const StreakCopy({required this.title, required this.body});

  /// Capstone milestones always override the daily rotation pool.
  static StreakCopy forStreak(int streakCount) {
    if (streakCount <= 0) return zero;

    final capstone = capstones[streakCount];
    if (capstone != null) return capstone;

    return dailyMessages[streakCount % dailyMessages.length];
  }

  static const StreakCopy zero = StreakCopy(
    title: 'Start your streak',
    body: 'Turn on a rule today. One active day is all it takes to begin.',
  );

  static const Map<int, StreakCopy> capstones = {
    1: StreakCopy(
      title: 'First step taken',
      body:
          "You started. That's the hardest part. Your future self is already thanking you.",
    ),
    3: StreakCopy(
      title: 'Three days strong',
      body:
          'Three days of showing up. Small wins stack — keep the rules on.',
    ),
    7: StreakCopy(
      title: 'One week in',
      body:
          'A full week of staying in control. This is how habits are built.',
    ),
    14: StreakCopy(
      title: 'Two weeks locked in',
      body:
          "Fourteen days of consistency. You're not just trying — you're doing it.",
    ),
    30: StreakCopy(
      title: 'A month of focus',
      body:
          "Thirty days. That's not luck — that's discipline showing up daily.",
    ),
    60: StreakCopy(
      title: 'Sixty days deep',
      body:
          "Two months of protecting your time. You've made this part of who you are.",
    ),
    100: StreakCopy(
      title: 'Century streak',
      body: 'One hundred days. Most people never get here. You did.',
    ),
    365: StreakCopy(
      title: 'One year of focus',
      body:
          "Three hundred and sixty-five days of protecting your time. That's not a streak — that's a lifestyle.",
    ),
  };

  static const List<StreakCopy> dailyMessages = [
    StreakCopy(
      title: 'Keep it going',
      body: "Another day, another win. Your rules are doing the work.",
    ),
    StreakCopy(
      title: 'Still on track',
      body: 'You showed up again. Consistency beats motivation every time.',
    ),
    StreakCopy(
      title: 'Building momentum',
      body: "Day by day, the streak adds up. Don't break the chain.",
    ),
    StreakCopy(
      title: 'Staying intentional',
      body: "You're choosing focus over distraction. That choice matters.",
    ),
    StreakCopy(
      title: 'Holding the line',
      body: 'Your rules are active and so is your progress. Keep going.',
    ),
    StreakCopy(
      title: 'Quiet consistency',
      body:
          'No fanfare needed — just another day of staying in control.',
    ),
    StreakCopy(
      title: 'Almost there',
      body:
          "You're building something real. Tomorrow is another chance to extend it.",
    ),
  ];
}
