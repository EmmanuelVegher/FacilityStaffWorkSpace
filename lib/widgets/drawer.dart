
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:refreshable_widget/refreshable_widget.dart';

import '../screens/activity_monitoring/activity_monitoring_page.dart';
import '../screens/facial_recognition/Facial_recognition_page.dart';
import '../screens/forgot_password_page.dart';
import '../screens/leave_request/leave_request.dart';
import '../screens/login_screen.dart';
import '../screens/profile_page.dart';
import '../screens/staff_dashboard.dart';
import '../screens/timesheet/timesheet.dart';
import '../screens/timesheet/upload_signature.dart';
import 'app_button.dart';



Widget drawer(
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
                      builder: (context) => const UserDashboardApp(

                          )),
                );
              }),
          const Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading:
                Icon(Icons.work, size: drawerIconSize, color: Colors.orange),
            title: Text(
              'Attendance',
              style: TextStyle(fontSize: drawerFontSize, color: Colors.brown),
            ),
            onTap: () {
              // _taskController.getTasks();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FacialRecognitionPage()),
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
            leading: Icon(Icons.holiday_village_sharp,
                size: drawerIconSize, color: Colors.red),
            title: Text(
              'Leave Request',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaveRequestsPage1()),
              );
            },
          ),

          // const Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          // ListTile(
          //   leading: Icon(Icons.task,
          //       size: drawerIconSize, color: Colors.brown),
          //   title: Text(
          //     'State Office Dashboard',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const DashboardScreen()),
          //     );
          //   },
          // ),

          // const Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          //
          // ListTile(
          //   leading: Icon(
          //     Icons.local_post_office,
          //     size: drawerIconSize,
          //     color: Colors.blue,
          //   ),
          //   title: Text(
          //     'Team Survey',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const PsychologicalMetricsPage(
          //
          //           )),
          //     );
          //   },
          // ),
          //
          // const Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          //
          // ListTile(
          //   leading: Icon(
          //     Icons.local_post_office,
          //     size: drawerIconSize,
          //     color: Colors.blue,
          //   ),
          //   title: Text(
          //     'Best Team player',
          //     style: TextStyle(
          //         fontSize: drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => const BestPlayerChartPage(
          //
          //           )),
          //     );
          //   },
          // ),

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
              'Task Management',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DailyActivityMonitoringPage()),

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
              Icons.access_time,
              size: drawerIconSize,
              color: Colors.blue,
            ),
            title: Text(
              'TimeSheet',
              style: TextStyle(
                  fontSize: drawerFontSize,
                  color: Get.isDarkMode ? Colors.white : Colors.brown),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TimesheetScreen()),
              );
            },
          ),

          // Divider(
          //   color: Colors.grey,
          //   height: 1,
          // ),
          // ListTile(
          //   leading: Icon(
          //     Icons.access_time,
          //     size: _drawerIconSize,
          //     color: Colors.blue,
          //   ),
          //   title: Text(
          //     'Pending TimeSheet',
          //     style: TextStyle(
          //         fontSize: _drawerFontSize,
          //         color: Get.isDarkMode ? Colors.white : Colors.brown),
          //   ),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) => PendingTimesheetsScreen()),
          //     );
          //   },
          // ),

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
                MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
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
                    builder: (context) => const UploadSignaturePage(

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
                MaterialPageRoute(builder: (context) => const ProfilePage()),
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



_displayDialog(BuildContext context) async {
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

_displayDialogForDiffAcount(BuildContext context) async {
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

_showBottomSheet2(BuildContext context) {
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

_bottomSheetButton(
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
