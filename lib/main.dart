import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

import 'modules/main/screens/main_screen.dart';
import 'modules/main/screens/login_page.dart';
import 'modules/main/screens/verify_email_page.dart';
import 'modules/main/services/user_profile_service.dart';
import 'modules/main/screens/editar_perfil_page.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/notifications/notification_service.dart';
import 'modules/main/screens/jornada_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Mostra erro na tela ao invés de preto silencioso
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("🔥 FlutterError: ${details.exceptionAsString()}");
  };

  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ App Check SEM travar o app (não use getToken(true) bloqueando aqui)
  try {
    await FirebaseAppCheck.instance
        .activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    )
        .timeout(const Duration(seconds: 3));
    debugPrint("✅ App Check activate OK");
  } catch (e) {
    // não trava o app se falhar/token rate-limited
    debugPrint("⚠️ App Check activate falhou/timeout: $e");
  }

  // ✅ Notificações também sem travar caso algo falhe
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("⚠️ NotificationService init falhou: $e");
  }

  runApp(const MyApp());

  // ✅ (opcional) tentar pegar token DEPOIS que o app já abriu (em background)
  Future.microtask(() async {
    try {
      final t = await FirebaseAppCheck.instance
          .getToken(false)
          .timeout(const Duration(seconds: 3));
      debugPrint("✅ AppCheck token (bg): $t");
    } catch (e) {
      debugPrint("⚠️ AppCheck token (bg) falhou: $e");
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color kWine = Color.fromRGBO(78, 4, 5, 1);
  static const Color kWhite = Colors.white;
  static const Color kBlack = Colors.black;

  Future<Map<String, String>> _carregarDadosPerfil() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {
        'nome': 'Novo Membro',
        'nickname': 'novo_membro',
        'bio': 'Bem-vindo ao Atos 29!',
      };
    }

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final nome =
    (data['nome'] ?? user.displayName ?? 'Novo Membro').toString().trim();
    final nickname = (data['nickname'] ?? 'novo_membro').toString().trim();
    final bio =
    (data['bio'] ?? 'Bem-vindo ao Atos 29!').toString().trim();

    return {
      'nome': nome.isEmpty ? 'Novo Membro' : nome,
      'nickname': nickname.isEmpty ? 'novo_membro' : nickname,
      'bio': bio.isEmpty ? 'Bem-vindo ao Atos 29!' : bio,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atos 29',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: kWine,
          onPrimary: kWhite,
          secondary: kWine,
          onSecondary: kWhite,
          error: kBlack,
          onError: kWhite,
          background: kWhite,
          onBackground: kBlack,
          surface: kWhite,
          onSurface: kBlack,
        ),
        scaffoldBackgroundColor: kWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: kWine,
          foregroundColor: kWhite,
          elevation: 0,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kWine,
        ),
      ),

      home: const StartupSplashGate(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainScreen(nickname: "Membro Atos 29"),
        '/editProfile': (context) {
          return FutureBuilder<Map<String, String>>(
            future: _carregarDadosPerfil(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snap.data ??
                  {
                    'nome': 'Novo Membro',
                    'nickname': 'novo_membro',
                    'bio': 'Bem-vindo ao Atos 29!',
                  };

              return EditarPerfilPage(
                nomeAtual: data['nome'] ?? 'Novo Membro',
                nicknameAtual: data['nickname'] ?? 'novo_membro',
                bioAtual: data['bio'] ?? 'Bem-vindo ao Atos 29!',
              );
            },
          );
        },
      },
    );
  }
}

class StartupSplashGate extends StatefulWidget {
  const StartupSplashGate({super.key});

  @override
  State<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<StartupSplashGate> {
  late final Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = Future<void>.delayed(const Duration(milliseconds: 900));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AtosSplashPage();
        }
        return const AuthFlowGate();
      },
    );
  }
}

class AuthFlowGate extends StatefulWidget {
  const AuthFlowGate({super.key});

  @override
  State<AuthFlowGate> createState() => _AuthFlowGateState();
}

class _AuthFlowGateState extends State<AuthFlowGate> {
  Future<void>? _reloadFuture;
  String? _reloadUid;

  Future<void> _ensureReload(User user) {
    if (_reloadFuture == null || _reloadUid != user.uid) {
      _reloadUid = user.uid;
      _reloadFuture = user.reload();
    }
    return _reloadFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AtosSplashPage();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Erro no auth: ${snapshot.error}")),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<void>(
          future: _ensureReload(user),
          builder: (context, reloadSnap) {
            if (reloadSnap.connectionState == ConnectionState.waiting) {
              return const AtosSplashPage();
            }

            final refreshed = FirebaseAuth.instance.currentUser;
            if (refreshed == null) return const LoginPage();

            if (!refreshed.emailVerified) {
              return VerifyEmailPage(
                email: refreshed.email ?? "",
                nickname: refreshed.displayName ?? "Novo Membro",
                editProfileRouteName: '/editProfile',
                onCreateProfile:
                    ({required User user, required String nickname}) async {
                  await UserProfileService.ensureProfileCreated(
                    user: user,
                    nickname: nickname,
                  );
                },
              );
            }

            return FutureBuilder<void>(
              future: UserProfileService.ensureProfileCreated(
                user: refreshed,
                nickname: refreshed.displayName ?? "Novo Membro",
              ),
              builder: (context, profSnap) {
                if (profSnap.connectionState == ConnectionState.waiting) {
                  return const AtosSplashPage();
                }
                return const HomeGate();
              },
            );
          },
        );
      },
    );
  }
}

class HomeGate extends StatefulWidget {
  const HomeGate({super.key});
  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  bool _didSetup = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSetup) return;
    _didSetup = true;

    NotificationService.instance.syncTokenToUserDoc();
    NotificationService.instance.listenTokenRefresh();
    NotificationService.instance.syncTopicSubscriptions();
    NotificationService.instance.setupOnNotificationTap(_handleTap);
  }

  void _handleTap(Map<String, dynamic> data) {
    debugPrint("NOTIF TAP DATA: $data");

    final screen = (data['screen'] ?? '').toString().trim();

    if (screen == 'post') {
      final postId = (data['postId'] ?? '').toString().trim();
      if (postId.isEmpty) return;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const MainScreen(nickname: "Membro Atos 29"),
        ),
      );

      return;
    }

    if (screen == 'jornada') {
      final focus = (data['focus'] ?? '').toString().trim();

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => JornadaPage(
            initialFocusDailyMission: focus == 'daily_mission',
          ),
        ),
      );
      return;
    }

    debugPrint("NOTIF: screen não reconhecida: $screen");
  }


  @override
  Widget build(BuildContext context) {
    return const MainScreen(nickname: "Membro Atos 29");
  }
}

class AtosSplashPage extends StatelessWidget {
  const AtosSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromRGBO(78, 4, 5, 1),
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/logo_atos29_branco.png'),
            width: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
