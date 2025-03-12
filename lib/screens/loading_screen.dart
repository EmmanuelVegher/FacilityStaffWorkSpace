import 'package:attendanceappmailtool/screens/staff_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'dashboard/state_ofice_dashboard.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnRole();
  }

  Future<void> _navigateBasedOnRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot staffDoc =
      await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();

      if (staffDoc.exists) {
        String role = staffDoc['role'] ?? 'User';
        await Future.delayed(const Duration(seconds: 5)); // Simulating loading

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
              role == 'User' ? const UserDashboardPage() : const DashboardScreen(),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("Authenticating...", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
