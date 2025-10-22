
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:refreshable_widget/refreshable_widget.dart';

import '../features/payroll/ui/payroll_review_page.dart';
import '../features/payroll/ui/salary_management_page.dart';
import '../forgot_password3.dart';
import '../screens/account_management/account_management_hub_screen.dart';
import '../screens/activity_monitoring/create_activity_page.dart';
import '../screens/admin/bank_management_page.dart';
import '../screens/admin/salary_scale_page.dart';
import '../screens/admin/audit_logs_page.dart';
import '../screens/admin/staff_status_report_page.dart';
import '../screens/admin/srt_management_page.dart';
import '../screens/attendance_analysis_page/hq_attendance_analysis_page.dart';
import '../screens/call_tracker/hq_call_tracking_reports.dart';
import '../screens/dashboard/hq_dashboard_screen.dart';
import '../screens/eac_tracker/hq_eac_report.dart';
import '../screens/leave_request/hq_leave_request_management_page.dart';
import '../screens/login_screen.dart';
import '../screens/performance_impact_dashboad/attendance_adoption_report_page.dart';
import '../screens/profile_page3.dart';
import '../screens/psychological_survey_analysis_page/hq_survey_analysis_page.dart';
import '../screens/timesheet/hq_timesheet_review_page.dart';
import '../screens/upload_signature3.dart';
import '../screens/viral_load_tracker/hq_vl_report_page.dart';
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

/// Access control for Payroll & Payments section
Future<bool> _hasPayrollAccess() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
    final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
    const allowed = {
      'program management',
      'compliance',
      'internal audit',
      'finance',
    };
    return allowed.contains(dept);
  } catch (_) {
    return false;
  }
}

Widget drawer3(
    BuildContext context,

    ) {


  //final DataBaseService _dataBaseService = DataBaseService();
  double drawerIconSize = 24;
  double drawerFontSize = 17;
  //final _taskController = Get.put(TaskController());

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
              color: Get.isDarkMode ? Colors.white : Colors.white,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 1.0],
                colors: [Colors.red, Colors.black],
              ),
            ),
            child: Container(
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    const Text(
                      "Dashboard",
                      style: TextStyle(
                          fontSize: 25,
                          color: Colors.white,
                          fontFamily: "NexaBold"),
                    ),
                    const SizedBox(
                      width: 30,
                    ),
                    Container(
                        margin: const EdgeInsets.only(
                          top: 20,
                          bottom: 24,
                        ),
                        height: 100,
                        width: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.redAccent,
                        ),
                        child: RefreshableWidget<List<Uint8List>?>(
                          refreshCall: () async {
                            return null;

                            // return await _readImagesFromDatabase();
                          },
                          refreshRate: const Duration(seconds: 1),
                          errorWidget: Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          loadingWidget: Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          builder: ((context, value) {
                            return ListView.builder(
                              itemCount: value!.length,
                              itemBuilder: (context, index) =>
                                  Image.memory(value.first),
                            );
                          }),
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
                color: Colors.red,
              ),
              title: Text(
                'DashBoard',
                style: TextStyle(
                    fontSize: drawerFontSize,
                    color: Get.isDarkMode ? Colors.white : Colors.brown),
              ),
              onTap: () async {
                //  onTap();
                // await _dataBaseService.loadDB();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HQDashboardScreen(

                      )),
                );
              }),//AttendanceAnalysisPage


          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.timer,
                size: drawerIconSize, color: Colors.orangeAccent),
            title: Text(
              'Central Attendance Analysis',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HQAttendanceAnalysisPage()),
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),

          ListTile(
            leading: Icon(
              Icons.analytics,
              size: drawerIconSize,
              color: Colors.blue,
            ),
            title: Text(
              'Performance Impact',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StateLevelEngagementReportPage()),


              );
            },
          ),


          // const Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          // ListTile(
          //   leading: Icon(Icons.pending,
          //       size: drawerIconSize, color: Colors.red),
          //   title: Text(
          //     'Pending Approval',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const PendingApprovalsPage()),
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
              color: Colors.blue,
            ),
            title: Text(
              'Central Call Tracking Report',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HQCallTrackerReportsPage()),

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
              color: Colors.blue,
            ),
            title: Text(
              'Central EAC Tracking Report',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const HqEacReportsPageWeb()),

              );
            },
          ),//TimesheetManagementDashboard

          const Divider(
            color: Colors.grey,
            height: 1,
          ),



          ListTile(
            leading: Icon(
              Icons.biotech_outlined,
              size: drawerIconSize,
              color: Colors.blue,
            ),
            title: Text(
              'Central Viral Load Tracking Report',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VlTrackingPageWeb()),

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
              color: Colors.blue,
            ),
            title: Text(
              'View Timesheets',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TimesheetReviewPageHq()),

              );
            },
          ),

          // const Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          //
          //
          //
          // ListTile(
          //   leading: Icon(
          //     Icons.payment,
          //     size: drawerIconSize,
          //     color: Colors.orange,
          //   ),
          //   title: Text(
          //     'Payment Module',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const PaymentModulePage()),
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
              Icons.holiday_village,
              size: drawerIconSize,
              color: Colors.blue,
            ),
            title: Text(
              'View Leave Requests',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LeaveRequestManagementPage()),

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
              return ExpansionTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text("Account management"),
                children: [
                  ListTile(
                    leading: const Icon(Icons.manage_accounts),
                    title: Text(
                      'Manage Account',
                      style: TextStyle(
                          fontSize: drawerFontSize,
                          color: Get.isDarkMode ? Colors.white : Colors.brown),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // Close the drawer
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const AccountManagementHubScreen(),
                      ));
                    },
                  ),
                  const Divider(
                    color: Colors.grey,
                    height: 1,
                  ),

                  ListTile(
                    leading: const Icon(Icons.account_balance, color: Colors.indigo),
                    title: const Text('Manage Banks'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BankManagementPage()),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey, height: 1),

                  // Audit Logs
                  ListTile(
                    leading: const Icon(Icons.history, color: Colors.brown),
                    title: Row(
                      children: [
                        const Text('Audit Logs'),
                        const SizedBox(width: 8),
                        // --- NEW: "NEW" FLAG FOR 30 DAYS ---
                        if (DateTime.now().isBefore(DateTime(2025, 12, 31)))
                          Chip(
                            label: const Text(
                              'NEW',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            backgroundColor: Colors.brown,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuditLogsPage()),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey, height: 1),

                  // Staff Status Report
                  ListTile(
                    leading: const Icon(Icons.group, color: Colors.teal),
                    title: Row(
                      children: [
                        const Text('Staff Status Report'),
                        const SizedBox(width: 8),
                        // --- NEW: "NEW" FLAG FOR 30 DAYS ---
                        if (DateTime.now().isBefore(DateTime(2025, 12, 31)))
                          Chip(
                            label: const Text(
                              'NEW',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffStatusReportPage()),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey, height: 1),

                  // SRT Management
                  ListTile(
                    leading: const Icon(Icons.location_city, color: Colors.purple),
                    title: const Text('SRT Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SRTManagementPage()),
                      );
                    },
                  ),
                  const Divider(color: Colors.grey, height: 1),
                ],
              );
            },
          ),

          const Divider(
            color: Colors.grey,
            height: 1,
          ),



          ListTile(
            leading: Icon(
              Icons.task,
              size: drawerIconSize,
              color: Colors.blue,
            ),
            title: Text(
              'Create Task Management Indicators',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateActivityPage()),

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
              color: Colors.blue,
            ),
            title: Text(
              'Survey Analysis',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StateSurveyAnalysisPage()),

              );
            },
          ),



          const Divider(
            color: Colors.grey,
            height: 1,
          ),


          //  if (isAdmin)
// Find this section in your drawer3.dart file and add the new ListTile

          FutureBuilder<bool>(
            future: _hasPayrollAccess(),
            builder: (context, snapshot) {
              final allowed = snapshot.data == true;
              if (!allowed) return const SizedBox.shrink();
              return ExpansionTile(
                leading: const Icon(Icons.monetization_on),
                title: const Text("Payroll & Payments"),
                children: [
                  // --- ADD THIS LISTTILE ---
                  ListTile(
                    leading: const Icon(Icons.price_change, color: Colors.teal), // Added icon and color
                    title: const Text('Manage Salary Scales'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SalaryScalePage()));
                    },
                  ),
                  // --- END OF ADDITION ---

                  ListTile(
                    leading: const Icon(Icons.price_change), // This was your old "Manage Salaries"
                    title: const Text('Manage Salaries'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SalaryManagementPage()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.payments),
                    title: const Text('Payroll Workflow'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PayrollReviewPage()));
                    },
                  ),
                ],
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
              color: Colors.purple,
            ),
            title: Text(
              'Forgot Password',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordPage3()),
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
              color: Colors.blue,
            ),
            title: Text(
              'Upload Signature',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UploadSignaturePage3(

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
              color: Colors.red,
            ),
            title: Text(
              'Profile Page',
              style: TextStyle(fontSize: drawerFontSize, color: Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage3()),
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
              color: Colors.red,
            ),
            title: Text(
              'Logout',
              style: TextStyle(fontSize: drawerFontSize, color: Colors.brown),
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
