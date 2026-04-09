import 'dart:async';
import 'package:chat_messenger_app/data/repositories/auth_repository.dart';
import 'package:chat_messenger_app/logic/cubits/auth/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _authStateSubscription;

  AuthCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState()) {
    _init();
  }

  void _init() {
    emit(state.copyWith(status: AuthStatus.initial));

    _authStateSubscription = _authRepository.authStateChanges.listen((
      user,
    ) async {
      if (user != null) {
        try {
          final userData = await _authRepository.getUserData(user.uid);
          emit(AuthState(status: AuthStatus.authenticated, user: userData));
        } catch (e) {
          emit(AuthState(status: AuthStatus.error, error: e.toString()));
        }
      } else {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(state.copyWith(status: AuthStatus.loading));
      await _authRepository.signIn(email: email, password: password);
      // DO NOT emit authenticated here — authStateChanges will handle it
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      emit(state.copyWith(status: AuthStatus.loading));
      await _authRepository.signUp(
        fullName: fullName,
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      // DO NOT emit authenticated here either
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
      await _clearSessionData();
      // DO NOT cancel the subscription — let authStateChanges emit unauthenticated
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> _clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // optional cleanup
  }

  Future<void> checkAuthStatus() async {
    final firebaseUser = _authRepository.currentUser;
    if (firebaseUser != null) {
      try {
        final userData = await _authRepository.getUserData(firebaseUser.uid);
        emit(AuthState(status: AuthStatus.authenticated, user: userData));
      } catch (e) {
        emit(AuthState(status: AuthStatus.error, error: e.toString()));
      }
    } else {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }


  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}
