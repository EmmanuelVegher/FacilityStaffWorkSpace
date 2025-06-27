import 'package:attendanceappmailtool/screens/delete_account/delete_account.dart';
import 'package:attendanceappmailtool/screens/delete_account/delete_data.dart';
import 'package:attendanceappmailtool/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:js/js.dart';
import 'package:lottie/lottie.dart';
import 'firebase_options.dart';

// Declare the JS function from face_recognition.js
@JS('loadModels')
external Future<void> loadModels();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await loadModels(); // Load models once here

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'CARITAS Nigeria Service Delivery Workspace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/delete-data', page: () => const DeleteDataPage()),
        GetPage(name: '/delete-account', page: () => const DeleteAccountPage()),
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
    _goToLogin();
  }

  Future<void> _goToLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    Get.offNamed('/login'); // Navigate to login screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/lottie/loading.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
