import 'package:attendanceappmailtool/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'package:js/js.dart';
import 'dart:async'; // Import dart:async for Future.delayed

// Declare the JS function from face_recognition.js
@JS('loadModels')
external Future<void> loadModels();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await loadModels(); // Load models first

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Workspace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Use SplashScreen as home
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        // GetPage(name: '/home', page: () => const HomeScreen()),
        // GetPage(name: '/dashboard', page: () => const UserDashboardApp()),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Firebase.initializeApp( // Initialize Firebase again here for extra safety in SplashScreen
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await loadModels(); // Load face-api models

    // Delay navigation slightly to ensure everything is initialized
    await Future.delayed(const Duration(milliseconds: 100)); // Adjust delay if needed

    Get.offNamed('/login'); // Navigate to login after initialization
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading indicator
      ),
    );
  }
}