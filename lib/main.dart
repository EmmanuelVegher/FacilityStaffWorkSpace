import 'package:service_delivery_workspace/screens/delete_account/delete_account.dart';
import 'package:service_delivery_workspace/screens/delete_account/delete_data.dart';
import 'package:service_delivery_workspace/screens/login_screen.dart';
// <<<--- ADD THIS
// <<<--- ADD THIS
// <<<--- ADD THIS
// <<<--- ADD THIS
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:js/js.dart';
// <<<--- ADD THIS

import 'firebase_options.dart';

// Declare the JS function from face_recognition.js
@JS('loadModels')
external Future<void> loadModels();

// <<<--- ADD THIS ENTIRE FUNCTION ---<<<
/// This function handles getting the FCM token for both Mobile and Web
/// and saving it to Firestore.
// Future<void> updateAndSaveFcmToken() async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) {
//     log("Cannot save FCM token. User is not logged in.");
//     return;
//   }
//
//   try {
//     String? fcmToken;
//
//     // For WEB, you MUST provide the VAPID key.
//     log("Platform is Web. Getting FCM token with VAPID key...");
//     fcmToken = await FirebaseMessaging.instance.getToken(
//       // IMPORTANT: Paste your VAPID key from the Firebase Console here
//       vapidKey: "BDtoMWZWcGyQ6deMJxkqGnVI1m8YR9rwOn6PDRNvEjFhWjldnk73XQ96wtkNbtjdZIkmgBEYnzw6MrVC43G9tFU",
//     );
//
//     if (fcmToken != null) {
//       log("Web FCM Token found: $fcmToken");
//
//       // Save the token to the user's document in the 'Staff' collection
//       final userDocRef =
//       FirebaseFirestore.instance.collection('Staff').doc(user.uid);
//       await userDocRef.set(
//         {'fcmToken': fcmToken},
//         SetOptions(merge: true), // Use merge to avoid overwriting other data
//       );
//
//       log("✅ FCM Token saved to Firestore successfully!");
//     } else {
//       log("⚠️ Could not get FCM token for web. It was null.");
//     }
//   } catch (e, s) {
//     log("❌ Error saving FCM token", error: e, stackTrace: s);
//   }
// }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // // <<<--- ADD THIS ---<<<
  // // Request notification permissions for the web app
  // if (kIsWeb) {
  //   await FirebaseMessaging.instance.requestPermission();
  // }

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
        child:
        // Lottie.asset(
        //   'assets/lottie/loading5.json',
        //   width: 200,
        //   height: 200,
        //   fit: BoxFit.contain,
        // ),
        Text(
          "Loading...",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}