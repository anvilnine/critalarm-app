package app.critalarm

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: flutter_local_notifications
// needs a FragmentActivity to show its permission and exact-alarm dialogs, and
// A2's full-screen alarm intent lands on this class.
class MainActivity : FlutterFragmentActivity()
