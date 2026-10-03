import 'package:service_delivery_workspace/screens/login_screen.dart';
import 'package:service_delivery_workspace/screens/staff_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard/facility_supervisor_dashboard.dart';
import 'dashboard/hq_dashboard_screen.dart';
import 'dashboard/state_ofice_dashboard.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _navigateBasedOnRole();
  }

  Future<void> _navigateBasedOnRole() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      }

      final DocumentSnapshot staffDoc = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(user.uid)
          .get();

      if (!staffDoc.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Staff record not found for this account. Please contact the administrator.";
          });
        }
        return;
      }

      final data = staffDoc.data() as Map<String, dynamic>?;
      final String role = data != null && data.containsKey('role') && data['role'] != null
          ? data['role'].toString().trim()
          : 'User';

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Widget targetDashboard;
        if (role == 'State Office Staff') {
          targetDashboard = const DashboardScreen();
        } else if (role == 'Facility Supervisor') {
          targetDashboard = const FacilitySupervisorDashboard();
        } else if (role == 'HQ Staff' || role == 'HQ') {
          targetDashboard = const HQDashboardScreen();
        } else {
          // Default: 'User', 'Facility Staff', etc.
          targetDashboard = const UserDashboardPage();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetDashboard),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load profile: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryMaroon = Color(0xFF5C1A2E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(color: primaryMaroon),
                const SizedBox(height: 20),
                Text(
                  "Authenticating...",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: primaryMaroon,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Authentication Error",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryMaroon,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _navigateBasedOnRole,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Retry",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryMaroon,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Back to Login",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
