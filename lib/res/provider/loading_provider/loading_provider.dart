import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define a class to hold loading states
class LoadingState {
  final bool isLoading;
  final bool isLoading2;

  LoadingState({this.isLoading = false, this.isLoading2 = false});

  LoadingState copyWith({bool? isLoading, bool? isLoading2}) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      isLoading2: isLoading2 ?? this.isLoading2,
    );
  }
}

// StateNotifier to manage LoadingState
class LoadingNotifier extends StateNotifier<LoadingState> {
  LoadingNotifier() : super(LoadingState());

  void toggleLoading() {
    state = state.copyWith(isLoading: !state.isLoading);
  }

  void toggleLoading2() {
    state = state.copyWith(isLoading2: !state.isLoading2);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setLoading2(bool value) {
    state = state.copyWith(isLoading2: value);
  }
}

// Riverpod provider
final loadingProvider = StateNotifierProvider<LoadingNotifier, LoadingState>((ref) {
  return LoadingNotifier();
});
