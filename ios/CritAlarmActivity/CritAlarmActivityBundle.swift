import SwiftUI
import WidgetKit

/// The widget extension. Two Live Activities live here.
///
/// `IncidentActivityWidget` is ours: the acknowledge card the relay starts
/// with `apns-push-type: liveactivity`, or the app starts locally.
///
/// `AlarmActivityWidget` is AlarmKit's. It is the alarm's own card, and it
/// only exists to give the ringing alarm the same face and colours as the rest
/// of the app. The system starts and ends it; we never do.
@main
struct CritAlarmActivityBundle: WidgetBundle {
    var body: some Widget {
        IncidentActivityWidget()
        if #available(iOS 26.0, *) {
            AlarmActivityWidget()
        }
    }
}
