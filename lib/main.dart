import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tulabe/controllers/auth_controller.dart';
import 'package:tulabe/controllers/push_controller.dart';
import 'package:tulabe/splash_screen.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  await PushController.instance.init();

  // Restore a persisted session (token + user) before the first frame.
  await AuthController.instance.ensureLoaded();

  // Set transparent system navigation & status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0E12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TulabeApp());
}

class TulabeApp extends StatelessWidget {
  const TulabeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Enforce light (white) status-bar icons on every screen and orientation.
    // On Android `statusBarIconBrightness` drives icon color; `statusBarBrightness`
    // is the iOS counterpart. Wrapping the app in an AnnotatedRegion keeps the
    // overlay style applied even when screens draw behind the transparent bar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: const Color(0xFF0D0E12),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'Tulabe',
        debugShowCheckedModeBanner: false,
        navigatorKey: PushController.navigatorKey,
        scaffoldMessengerKey: PushController.scaffoldMessengerKey,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0118),
          fontFamily: 'PlusJakartaSans',
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
