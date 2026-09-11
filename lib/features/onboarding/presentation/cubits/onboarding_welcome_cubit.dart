import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_state.dart';
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
          errorMessage: 'Server URL cannot be empty',
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
          errorMessage: 'Enter a valid URL (e.g. https://api.critalarm.app)',
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
