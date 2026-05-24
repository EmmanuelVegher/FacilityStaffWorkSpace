
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:refreshable_widget/refreshable_widget.dart';

import 'package:google_fonts/google_fonts.dart';

import '../screens/account_management/my_state_screen.dart';
import '../screens/admin/pending_schedules_page.dart';
import '../screens/attendance_analysis_page/attendance_analysis_page.dart';
import '../screens/attendance_analysis_page/low_attendance_staff_page.dart';
import '../screens/call_tracker/state_reports_page_web.dart';
import '../screens/dashboard/state_ofice_dashboard.dart';
import '../screens/eac_tracker/state_eac_report_tab.dart';
import '../screens/forgot_password2.dart';
import '../screens/leave_request/state_leave_request_page.dart';
import '../screens/login_screen.dart';
import '../screens/pending_approvals.dart';
import '../screens/profile_page2.dart';
import '../screens/psychological_survey_analysis_page/PsychologicalSurveyAnalysisPage.dart';
import '../screens/performance_impact_dashboad/state_performance_impact_dashboard.dart';
import '../screens/supervisor/supervisor_task_summary_page.dart';
import '../screens/timesheet/timesheet_management_dashboard.dart';
import '../screens/upload_signature2.dart';
import '../screens/viral_load_tracker/state_vl_report_tab_2.dart';
import '../screens/admin/audit_logs_state_page.dart';
import '../screens/admin/staff_status_report_state_page.dart';
import '../screens/admin/srt_management_state_page.dart';
import 'app_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Access control: only Program Management can access Account Management entries
Future<bool> _hasProgramManagementAccess() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
    final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
    return dept == 'program management';
  } catch (_) {
    return false;
  }
}

// Access control for Pending Payment Schedules
Future<bool> _hasPendingPaymentAccess() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
    final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
    const allowed = {
      'program management',
      'compliance',
      'state management',
      'internal audit',
      'finance',
    };
    return allowed.contains(dept);
  } catch (_) {
    return false;
  }
}

Widget drawer2(
    BuildContext context,

    ) {


  //final DataBaseService _dataBaseService = DataBaseService();
  double drawerIconSize = 24;
  double drawerFontSize = 17;
  //final _taskController = Get.put(TaskController());
  const Color maroonPrimary = Color(0xFF5C1A2E);
  const Color goldAccent = Color(0xFFD4A03C);

  return Drawer(
    child: Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                1.0
              ],


              colors: [
                Colors.white,
                Colors.white,
              ])),
      child: ListView(
        children: [
          // Row(children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: maroonPrimary,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 1.0],
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
                    const SizedBox(width: 12),
                    Container(
                        height: 60,
                        width: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: goldAccent,
                        ),
                        child: RefreshableWidget<List<Uint8List>?>(
                          refreshCall: () async => null,
                          refreshRate: const Duration(seconds: 1),
                          errorWidget: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          loadingWidget: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          builder: (context, value) {
                            if (value == null || value.isEmpty) {
                              return Icon(Icons.person, size: 40, color: Colors.grey.shade300);
                            }
                            return Image.memory(value.first, fit: BoxFit.cover);
                          },
                        )),
                  ],
                )),
          ),

          // ],
          // ),

          ListTile(
              leading: Icon(
                Icons.screen_lock_landscape_rounded,
                size: drawerIconSize,
                color: maroonPrimary,
              ),
              title: Text(
                'DashBoard',
                style: GoogleFonts.poppins(
                    fontSize: drawerFontSize,
                    color: Get.isDarkMode ? Colors.white : Colors.black87),
              ),
              onTap: () async {
                //  onTap();
                // await _dataBaseService.loadDB();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardScreen(

                      )),
                );
              }),//AttendanceAnalysisPage


          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.timer,
                size: drawerIconSize, color: maroonPrimary),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Attendance Analysis',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: drawerFontSize,
                        color: Get.isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text(
                    'Upd',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceAnalysisPage()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.person_off_outlined,
                size: drawerIconSize, color: maroonPrimary),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Low Attendance Staff',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 17, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: const Text(
                    'New',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LowAttendanceStaffPage()),
              );
            },
          ),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.analytics,
                size: drawerIconSize, color: maroonPrimary),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Performance Impact',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: drawerFontSize,
                        color: Get.isDarkMode ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                // --- NEW: "NEW" FLAG FOR 30 DAYS ---
                if (DateTime.now().isBefore(DateTime(2025, 10, 31)))
                  Chip(
                    label: const Text(
                      'NEW',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatePerformanceImpactDashboardPage()),
              );
            },
          ),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          ListTile(
            leading: Icon(
              Icons.pending_actions, // Changed Icon
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Pending Leave Requests',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StateLeaveRequestManagementPage()),
              );
            },
          ),



          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(
              Icons.schedule, // Changed Icon
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Pending Timesheets',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PendingApprovalsPage()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.task,
                size: drawerIconSize, color: maroonPrimary),
            title: Text(
              'Task Management Summary',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SupervisorTaskSummaryPage()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),

          // ListTile(
          //   leading: Icon(
          //     Icons.task,
          //     size: drawerIconSize,
          //     color: Colors.blue,
          //   ),
          //   title: Text(
          //     'Create Activity',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const CreateActivityPage()),
          //
          //     );
          //   },
          // ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),

          ListTile(
            leading: Icon(
              Icons.phone,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Call Tracking Report',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ReportsPageWeb2()),

              );
            },
          ),



          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          ListTile(
            leading: Icon(
              Icons.art_track,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'EAC Tracking Report',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StateEacReportsPageWeb()),

              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          ListTile(
            leading: Icon(
              Icons.biotech_outlined,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Viral Load Tracking Report',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StateVlTrackingPageWeb()),

              );
            },
          ),//

          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          ListTile(
            leading: Icon(
              Icons.lock_clock,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'View Submitted Timesheets',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TimesheetReviewPage()),

              );
            },
          ),
   const Divider(
            color: Colors.grey,
            height: 1,
          ),

          // Pending Payment Schedules visible only to specific departments
          FutureBuilder<bool>(
            future: _hasPendingPaymentAccess(),
            builder: (context, snapshot) {
              final allowed = snapshot.data == true;
              if (!allowed) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.playlist_add_check_circle_outlined, color: maroonPrimary),
                title: Text('Pending Payment Schedules', style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Colors.black87)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PendingSchedulesPage(),
                    ),
                  );
                },
              );
            },
          ),




          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          ListTile(
            leading: Icon(
              Icons.psychology,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Survey Analysis',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PsychologicalSurveyAnalysisPage()),

              );
            },
          ),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),

          // NEW: State-specific reports for drawer2
          ListTile(
            leading: const Icon(Icons.group, color: maroonPrimary),
            title: Text(
              'Staff Status Report',
              style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffStatusReportStatePage()),
              );
            },
          ),
          const Divider(color: Colors.grey, height: 1),
          ListTile(
            leading: const Icon(Icons.history, color: maroonPrimary),
            title: Text(
              'Audit Logs',
              style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuditLogsStatePage()),
              );
            },
          ),
          const Divider(color: Colors.grey, height: 1),
          ListTile(
            leading: const Icon(Icons.location_city, color: maroonPrimary),
            title: Text('SRT Management', style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Colors.black87)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SRTManagementStatePage()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          // Account Management is only visible to Program Management department
          FutureBuilder<bool>(
            future: _hasProgramManagementAccess(),
            builder: (context, snapshot) {
              final allowed = snapshot.data == true;
              if (!allowed) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.manage_accounts, color: maroonPrimary),
                title: Text(
                  'Account Management',
                  style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Colors.black87),
                ),
                onTap: () {
                  Navigator.of(context).pop(); // Close the drawer
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const MyStateScreen(),
                  ));
                },
              );
            },
          ),




          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(
              Icons.password_rounded,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Forgot Password',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordPage2()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(
              Icons.draw,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Upload Signature',
              style: GoogleFonts.poppins(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UploadSignaturePage2(

                    )),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(
              Icons.person,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Profile Page',
              style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Colors.black87),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage2()),
              );
            },
          ),



          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(
              Icons.logout_rounded,
              size: drawerIconSize,
              color: maroonPrimary,
            ),
            title: Text(
              'Logout',
              style: GoogleFonts.poppins(fontSize: drawerFontSize, color: Colors.black87),
            ),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
    ),
  );
}



Future<Future> _displayDialog(BuildContext context) async {
  return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Do you want to Log-Out?'),
          content: const Text("Kindly Choose your Log-Out Option"
            //controller: _textFieldController,
            //decoration: InputDecoration(hintText: "TextField in Dialog"),
          ),
          actions: <Widget>[
            AppButton(
                text: "Exit",
                onPressed: () {
                  Navigator.of(context).pop();
                  SystemNavigator.pop();
                }),
            AppButton(
                text: "Switch Account",
                onPressed: () {
                  Navigator.of(context).pop();
                  _displayDialogForDiffAcount(context);
                  //Navigator.of(context).pop();
                })
          ],
        );
      });
}

Future<Future> _displayDialogForDiffAcount(BuildContext context) async {
  return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Have you synced all attendance?'),
          content: const Text("Kindly Sync all data before switching account"
            //controller: _textFieldController,
            //decoration: InputDecoration(hintText: "TextField in Dialog"),
          ),
          actions: <Widget>[
            AppButton(
                text: "Yes",
                onPressed: () {
                  _switchAccountValidation(context);

                  Navigator.of(context).pop();
                }),
            AppButton(
                text: "No",
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => AttendanceHomeScreen(
                  //               service: IsarService(),
                  //             )));
                  Fluttertoast.showToast(
                      msg: "Sync data before switching account",
                      toastLength: Toast.LENGTH_LONG,
                      backgroundColor: Colors.black54,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      textColor: Colors.white,
                      fontSize: 16.0);
                })
          ],
        );
      });
}

void _switchAccountValidation(BuildContext context) async {
  //final attendanceNotSynced = await IsarService().getAttendanceForUnSynced();
  // SharedPreferences preferences = await SharedPreferences.getInstance();

  // if (attendanceNotSynced.isEmpty) {
  //   // Navigator.of(context).pushReplacement(
  //   //   MaterialPageRoute(builder: (context) {
  //   //     return LoginPage(
  //   //       service: IsarService(),
  //   //     );
  //   //   }),
  //   // );
  //
  //   Navigator.of(context).pushAndRemoveUntil(
  //     MaterialPageRoute(builder: (context) => LoginPage(service: IsarService())),
  //         (Route<dynamic> route) => false, // This condition pops all routes
  //   );
  //   Fluttertoast.showToast(
  //       msg: "Login to switch account",
  //       toastLength: Toast.LENGTH_LONG,
  //       backgroundColor: Colors.black54,
  //       gravity: ToastGravity.BOTTOM,
  //       timeInSecForIosWeb: 1,
  //       textColor: Colors.white,
  //       fontSize: 16.0);
  // } else {
  //   Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //           builder: (context) => AttendanceHomeScreen(
  //                 service: IsarService(),
  //               )));
  //   Fluttertoast.showToast(
  //       msg: "Sync data before switching account",
  //       toastLength: Toast.LENGTH_LONG,
  //       backgroundColor: Colors.black54,
  //       gravity: ToastGravity.BOTTOM,
  //       timeInSecForIosWeb: 1,
  //       textColor: Colors.white,
  //       fontSize: 16.0);
  // }
}

PersistentBottomSheetController _showBottomSheet2(BuildContext context) {
  return showBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 4),
          height: MediaQuery.of(context).size.height * 0.32,
          width: MediaQuery.of(context).size.width * 1,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                height: 6,
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.deepOrange,
                ),
              ),
              const Spacer(),
              _bottomSheetButton(
                label: "Local Backup",
                onTap: () async {
                  // final feedback =
                  //     await widget.service.getSpecificFeedback(id);
                  // Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //         builder: (context) => ModifySheetsPage(feedback:feedback,)));
                  //_updateFeedback(context, id);
                  //_taskController.markTaskCompleted(task.id!);
                  //Navigator.of(context).pop();
                },
                clr: Colors.red,
                context: context,
              ),
              _bottomSheetButton(
                label: "Restore from Local DB",
                onTap: () async {
                  // await widget.service.deleteFeedback(id);
                  // Navigator.of(context).pop();
                },
                clr: Colors.orange,
                context: context,
              ),
              const SizedBox(
                height: 20,
              ),
              _bottomSheetButton(
                label: "Restore from Server",
                onTap: () {
                  //Navigator.of(context).pop();
                },
                clr: Colors.red,
                isClose: true,
                context: context,
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      });
}

GestureDetector _bottomSheetButton(
    {required String label,
      required Function()? onTap,
      required Color clr,
      bool isClose = false,
      required BuildContext context}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 55,
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: BoxDecoration(
        color: isClose == true ? Colors.red : Colors.blue,
        border: Border.all(
          width: 2,
          color: Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(20),
        //color: Colors.transparent,
      ),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, color: Colors.white, fontFamily: "NexaBold")),
      ),
    ),
  );
}
