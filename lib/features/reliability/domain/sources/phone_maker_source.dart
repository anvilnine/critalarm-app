import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:flutter/foundation.dart';

/// Whether the phone's maker puts unused apps to sleep, and whether the user
/// has gone through the steps for it.
///
/// - Not on this phone: an iPhone, the web, and a maker with no guide
///   (`makerFamilyFor` is null).
/// - Needs a look: a maker with a guide, until the user says they did the
///   steps. A phone update voids that word, because updates often put the
///   settings back.
/// - Fine: the user said so, on this OS version.
///
/// The app cannot read any of these settings: Samsung's Never sleeping
/// apps, Xiaomi's Autostart, Oppo's background activity and Huawei's App
/// launch have no public read. So "fine" here is the user's word, and the
/// check never turns fine by itself. The stock battery exemption is a
/// separate check (`PermissionsSource`), and it is not used as proof here:
/// the skins keep their own switches on top of it.
///
/// Reasons: `maker_unchecked`, `maker_os_changed`. The fix opens the guide,
/// through [guideRouteName].
final class PhoneMakerSource implements ReliabilityCheckSource {
  PhoneMakerSource({
    required this.capabilities,
    required this.makerReader,
    required this.os,
    required this.store,
    required this.guideRouteName,
  });

  final PlatformCapabilities capabilities;
  final DeviceMakerReader makerReader;
  final OsVersionReader os;
  final MakerGuideStore store;

  /// The route name of the guide page, handed in by `lib/app/di.dart`.
  final String guideRouteName;

  @override
  Future<List<ReliabilityCheck>> read() async {
    const gone = ReliabilityCheck.notOnThisPhone(
      ReliabilityCheckIds.phoneMaker,
    );
    final isAndroid =
        !capabilities.isWeb && capabilities.platform == TargetPlatform.android;
    if (!isAndroid) return [gone];
    if (makerFamilyFor(await makerReader.read()) == null) return [gone];
    return [
      phoneMakerCheckFor(
        record: store.read(),
        osMajor: await os.major(),
        guideRouteName: guideRouteName,
      ),
    ];
  }

  /// The state rule. Pure.
  static ReliabilityCheck phoneMakerCheckFor({
    required MakerGuideRecord record,
    required int? osMajor,
    required String guideRouteName,
  }) {
    const id = ReliabilityCheckIds.phoneMaker;
    final fix = OpenRouteFix(guideRouteName);
    if (!record.isDone) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        reason: 'maker_unchecked',
        fix: fix,
      );
    }
    if (record.osMajor != osMajor) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        reason: 'maker_os_changed',
        fix: fix,
      );
    }
    return const ReliabilityCheck(id: id, state: ReliabilityState.fine);
  }
}
