import SwiftUI
import WidgetKit

/// The widget extension. Two Live Activities and three widgets live here.
///
/// `IncidentActivityWidget` is ours: the acknowledge card the relay starts
/// with `apns-push-type: liveactivity`, or the app starts locally.
///
/// `AlarmActivityWidget` is AlarmKit's. It is the alarm's own card, and it
/// only exists to give the ringing alarm the same face and colours as the rest
/// of the app. The system starts and ends it; we never do.
///
/// `TopicsWidget`, `TopicWidget` and `OpenCountWidget` are the home and lock
/// screen widgets. They draw the widget snapshot the app keeps in the app
/// group (`WidgetSnapshotStore`).
@main
struct CritAlarmActivityBundle: WidgetBundle {
    var body: some Widget {
        IncidentActivityWidget()
        TopicsWidget()
        TopicWidget()
        OpenCountWidget()
        if #available(iOS 26.0, *) {
            AlarmActivityWidget()
        }
    }
}
