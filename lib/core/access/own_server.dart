import 'package:critalarm/core/api/api_session.dart';

/// Whether [mode] is a server of the user's own: `selfhosted` and nothing
/// else.
///
/// The one rule for anything about plans. Crit Alarm Cloud (`hosted`) has
/// plans. So does a server that reports `relay`: it is the relay itself,
/// with accounts, tiers and caps. A mode that is not known yet is treated
/// the same. All three follow what is held.
///
/// `FeatureAccess.isOwnServer` is this, for the mode it keeps. Code that
/// already has a mode in hand, such as a rule that read it for another
/// reason, asks here. Nothing outside this folder compares a server mode
/// to decide something about plans.
bool isOwnServerMode(ServerMode? mode) => mode == ServerMode.selfhosted;
