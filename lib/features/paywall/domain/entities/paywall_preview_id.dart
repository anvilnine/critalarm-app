/// One id per benefit, naming the small preview a layout draws beside it.
///
/// The widget that draws a preview lives in the layout kit. The id lives
/// here so a benefit can name its preview without the domain reaching into
/// presentation.
enum PaywallPreviewId {
  topics,
  pushes,
  history,
  widgets,
  appIcons,
  weeklyCheck,
  fireDrills,
  wakeUpChallenges,
  customAlarmScreens,
  morningSummary,
}
