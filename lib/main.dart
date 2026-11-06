import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/gemini_service.dart';
import 'services/local_db.dart';
import 'services/storage_service.dart';
import 'views/home_view.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: en release se usa Play Integrity. En debug solo se activa con
  // `--dart-define=APP_CHECK_DEBUG=true` y con el token de depuración ya
  // registrado en la consola; si no, firebase_ai falla al pedir el token
  // (403 App attestation failed). AI Logic está en "solo supervisión" hasta
  // que Firebase lo exija (21/01/2027).
  // En web hace falta una clave de reCAPTCHA, aún no configurada.
  const appCheckDebug = bool.fromEnvironment('APP_CHECK_DEBUG');
  if (!kIsWeb && (kReleaseMode || appCheckDebug)) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestProvider()
          : const AppleDebugProvider(),
    );
  }

  final firestore = FirestoreService();
  final auth = AuthService(firestore: firestore);

  runApp(
    MultiProvider(
      providers: [
        Provider<FirestoreService>.value(value: firestore),
        Provider<AuthService>.value(value: auth),
        Provider<StorageService>(create: (_) => StorageService()),
        Provider<GeminiService>(create: (_) => GeminiService()),
        Provider<LocalDb>.value(value: LocalDb.instancia),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(auth: auth, firestore: firestore),
        ),
      ],
      child: const ResCatApp(),
    ),
  );
}

class ResCatApp extends StatelessWidget {
  const ResCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResCAT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomeView(),
    );
  }
}
