import 'package:attendanceappmailtool/screens/home_screen.dart';
import 'package:attendanceappmailtool/screens/login_screen.dart';
import 'package:attendanceappmailtool/screens/staff_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'package:js/js.dart';

// Declare the JS function from face_recognition.js
@JS('loadModels')
external Future<void> loadModels();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load face-api.js models via Dart-JS interop from face_recognition.js
  await loadModels();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Facility Staff Workspace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/dashboard', page: () => const UserDashboardApp()),
      ],
    );
  }
}
