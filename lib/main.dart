import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:chat_messenger_app/data/services/service_locator.dart';
import 'package:chat_messenger_app/logic/cubits/auth/auth_cubit.dart';
import 'package:chat_messenger_app/logic/cubits/auth/auth_state.dart';
import 'package:chat_messenger_app/logic/observer/app_life_cycle_observer.dart';
import 'package:chat_messenger_app/router/app_router.dart';
import 'package:chat_messenger_app/presentation/screens/splash_screen.dart';
import 'config/theme/app_theme.dart';
import 'data/repositories/chat_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  // Use the same AuthCubit instance everywhere:
  final authCubit = getIt<AuthCubit>();
  authCubit.checkAuthStatus();

  runApp(MyApp(authCubit: authCubit));
}

class MyApp extends StatefulWidget {
  final AuthCubit authCubit;
  const MyApp({super.key, required this.authCubit});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLifeCycleObserver _appLifeCycleObserver;

  @override
  void initState() {
    super.initState();

    widget.authCubit.stream.listen((state) {
      if (state.status == AuthStatus.authenticated && state.user != null) {
        _appLifeCycleObserver = AppLifeCycleObserver(
          userId: state.user!.uid,
          chatRepository: getIt<ChatRepository>(),
        );
        WidgetsBinding.instance.addObserver(_appLifeCycleObserver);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: BlocProvider<AuthCubit>.value(
        value: widget.authCubit,
        child: MaterialApp(
          title: 'Giggl',
          navigatorKey: getIt<AppRouter>().navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
