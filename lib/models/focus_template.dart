/// A predefined focus session template shown in the "For you" carousel.
class FocusTemplate {
  final String title;
  final Duration duration;
  final String blockedAppsLabel;
  final FocusTemplateArt art;

  const FocusTemplate({
    required this.title,
    required this.duration,
    required this.blockedAppsLabel,
    required this.art,
  });

  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

/// Enum mapping each template to its bespoke procedural painter.
enum FocusTemplateArt {
  deepStudy,
  commute,
  workout,
  reading,
  weekendZen,
}

const kFocusTemplates = <FocusTemplate>[
  FocusTemplate(
    title: 'Deep study',
    duration: Duration(hours: 1, minutes: 30),
    blockedAppsLabel: 'Social, Games, Video',
    art: FocusTemplateArt.deepStudy,
  ),
  FocusTemplate(
    title: 'Commute',
    duration: Duration(minutes: 30),
    blockedAppsLabel: 'Social, Video',
    art: FocusTemplateArt.commute,
  ),
  FocusTemplate(
    title: 'Workout',
    duration: Duration(hours: 1),
    blockedAppsLabel: 'Social, Games',
    art: FocusTemplateArt.workout,
  ),
  FocusTemplate(
    title: 'Reading',
    duration: Duration(minutes: 30),
    blockedAppsLabel: 'Social, Video, Games',
    art: FocusTemplateArt.reading,
  ),
  FocusTemplate(
    title: 'Weekend zen',
    duration: Duration(hours: 1),
    blockedAppsLabel: 'Social, Video, News',
    art: FocusTemplateArt.weekendZen,
  ),
];
