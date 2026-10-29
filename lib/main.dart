import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/session_provider.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'views/home_view.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirestoreService();
  final auth = AuthService(firestore: firestore);

  runApp(
    MultiProvider(
      providers: [
        Provider<FirestoreService>.value(value: firestore),
        Provider<AuthService>.value(value: auth),
        Provider<StorageService>(create: (_) => StorageService()),
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
