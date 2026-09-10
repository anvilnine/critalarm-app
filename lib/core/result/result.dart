import 'package:critalarm/core/failures/failure.dart';
import 'package:result_dart/result_dart.dart' hide Failure;

export 'package:result_dart/result_dart.dart' hide Failure;

/// Cross-layer return type: every domain/data boundary returns this.
/// No exceptions may cross a layer boundary.
typedef AppResult<T extends Object> = ResultDart<T, Failure>;
