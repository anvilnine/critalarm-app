import 'package:critalarm/features/reliability/domain/maker/guides/huawei_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/guides/oppo_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/guides/samsung_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/guides/xiaomi_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_family.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';

/// The guide for [family]. One file per family under `guides/`.
MakerGuide makerGuideFor(MakerFamily family) => switch (family) {
  MakerFamily.samsung => samsungGuide,
  MakerFamily.xiaomi => xiaomiGuide,
  MakerFamily.oppo => oppoGuide,
  MakerFamily.huawei => huaweiGuide,
};
