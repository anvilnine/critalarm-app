import 'package:flutter/widgets.dart';

/// Lets a screen hear when it becomes the top of the stack again.
///
/// The app only ever loaded on a cold start, so creating a topic left the list
/// saying "No topics yet" and coming back from a topic showed the state from
/// before. A screen that cares subscribes to this and reloads in `didPopNext`.
final appRouteObserver = RouteObserver<ModalRoute<void>>();
