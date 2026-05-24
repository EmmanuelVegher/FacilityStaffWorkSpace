import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/attendance_analysis_page/facility_supervisor_analysis_page.dart';
import '../screens/dashboard/facility_supervisor_dashboard.dart';
import '../screens/forgot_password4.dart';
import '../screens/login_screen.dart';
import '../screens/pending_approval_facility_supervisor.dart';
import '../screens/profile4.dart';
import '../screens/psychological_survey_analysis_page/facility_supervisor_survey_page.dart';
import '../screens/supervisor_qr_generator_page.dart';
import '../screens/upload_signature4.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_button.dart';

Widget drawer4(BuildContext context) {
  double drawerIconSize = 24;
  double drawerFontSize = 17;

  // Define Maroon and Gold colors to match drawer.dart
  const Color maroonPrimary = Color(0xFF5C1A2E);

  return Drawer(
    child: Container(
      color: Colors.white,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [maroonPrimary, Color(0xFF2E0215)],
              ),
            ),
            child: Container(
              alignment: Alignment.bottomLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Dashboard",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 25,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: drawerIconSize,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          _buildDrawerItem(
            context: context,
            icon: Icons.dashboard_outlined,
            title: 'Dashboard Main',
            color: const Color(0xFFD4A03C), // Gold
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            isBold: true,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FacilitySupervisorDashboard()));
            },
          ),
          
          const Divider(height: 1),

          _buildDrawerItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Profile',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage4()));
            },
          ),

          _buildDrawerItem(
            context: context,
            icon: Icons.analytics_outlined,
            title: 'Attendance Analysis',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FacilitySupervisorAttendanceAnalysisPage()));
            },
          ),

          _buildDrawerItem(
            context: context,
            icon: Icons.assignment_turned_in_outlined,
            title: 'Pending Approvals',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingFacilitySupervisorApprovalsPage()));
            },
          ),
          
          _buildDrawerItem(
            context: context,
            icon: Icons.qr_code_2_outlined,
            title: 'Generate Supervisor QR',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SupervisorQRGeneratorPage()));
            },
          ),

          _buildDrawerItem(
            context: context,
            icon: Icons.poll_outlined,
            title: 'Survey Analysis',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const FacilitySupervisorPsychologicalSurveyAnalysisPage()));
            },
          ),

          _buildDrawerItem(
            context: context,
            icon: Icons.draw_outlined,
            title: 'Upload Signature',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadSignaturePage4()));
            },
          ),

          _buildDrawerItem(
            context: context,
            icon: Icons.lock_reset_outlined,
            title: 'Forgot Password',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage4()));
            },
          ),

          const Divider(height: 1),

          _buildDrawerItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            fontSize: drawerFontSize,
            iconSize: drawerIconSize,
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildDrawerItem({
  required BuildContext context,
  required IconData icon,
  required String title,
  required double fontSize,
  required double iconSize,
  required VoidCallback onTap,
  Color color = Colors.black87,
  bool isBold = false,
}) {
  return ListTile(
    leading: Icon(icon, size: iconSize, color: color),
    title: Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    onTap: onTap,
  );
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to logout?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Logout", style: TextStyle(color: Color(0xFF5C1A2E), fontWeight: FontWeight.bold)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      );
    },
  );
}
