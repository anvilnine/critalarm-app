import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the Welcome onboarding screen state and server URL
/// validation.
class OnboardingWelcomeCubit extends Cubit<OnboardingWelcomeState> {
  OnboardingWelcomeCubit(this._getServerInfo)
    : super(const OnboardingWelcomeState());

  final GetServerInfoUsecase _getServerInfo;

  void serverUrlChanged(String url) {
    emit(
      state.copyWith(
        serverUrl: url,
        clearError: true,
        canNavigate: false,
      ),
    );
  }

  Future<void> validateAndContinue() async {
    final trimmed = state.serverUrl.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.onboarding_welcome_server_url_error_empty
              .tr(),
          canNavigate: false,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: LocaleKeys.onboarding_welcome_server_url_error_invalid
              .tr(),
          canNavigate: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isValidating: true, clearError: true));

    final result = await _getServerInfo(const NoParams());
    result.fold(
      (info) {
        emit(
          state.copyWith(
            isValidating: false,
            canNavigate: true,
            clearError: true,
          ),
        );
      },
      (failure) {
        emit(
          state.copyWith(
            isValidating: false,
            errorMessage: failure.message,
            canNavigate: false,
          ),
        );
      },
    );
  }

  void navigationHandled() {
    emit(state.copyWith(canNavigate: false));
  }
}
