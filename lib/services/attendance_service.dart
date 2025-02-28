// // // attendance_service.dart
// // import 'dart:io';
// // import 'dart:isolate';
// // import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// // import 'package:workmanager/workmanager.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// // import 'package:connectivity_plus/connectivity_plus.dart';
// // import 'location_tracking_service.dart';
// // import 'notification_services.dart';
// // // ... your other imports
// //
// // const String clockInTask = "clockInTask";
// // const String clockOutTask = "clockOutTask";
// // const int clockCheckInterval = 60; // Seconds (1 minute)
// //
// // class AttendanceService {
// //   static Future<void> initializeWorkManager() async {
// //     Workmanager().initialize(
// //       callbackDispatcher,
// //       isInDebugMode: true,
// //     );
// //   }
// //
// //   static Future<void> initializeBackgroundTasks() async {
// //     // 1. Schedule frequent clock checks (Android)
// //     if (Platform.isAndroid) {
// //       await AndroidAlarmManager.periodic(
// //         const Duration(seconds: clockCheckInterval),
// //         0, // Unique ID for this alarm
// //         _checkTimeAndNotify,
// //         wakeup: true, // Wake up device if needed
// //         rescheduleOnReboot: true, // Reschedule after reboot
// //       );
// //     } else if (Platform.isIOS) {
// //       // Implement Background Fetch for iOS (see Apple documentation)
// //     }
// //
// //     // 2. Schedule 12 PM location tracking using WorkManager
// //     await LocationTrackingService.initializeLocationTracking();
// //   }
// //
// //   // Function to be executed by AlarmManager
// //   static void _checkTimeAndNotify() async {
// //     final now = DateTime.now();
// //
// //     // Trigger clock-in notification
// //     if (now.hour == 8 && now.minute == 0) {
// //       await showNotification(
// //           title: "Clock In Reminder", body: "Don't forget to clock in!");
// //     }
// //
// //     // Trigger clock-out notification
// //     if (now.hour == 17 && now.minute == 0) {
// //       await showNotification(
// //           title: "Clock Out Reminder", body: "Don't forget to clock out!");
// //     }
// //   }
// // }
// //
// //   void scheduleClockNotifications() {
// //     _scheduleNotification(clockInTask, 5, 10, "Clock In Reminder", "Don't forget to clock in!");
// //     _scheduleNotification(clockOutTask, 17, 0, "Clock Out Reminder", "Don't forget to clock out!");
// //   }
// //
// //   Future<void> _scheduleNotification(
// //       String taskName, int hour, int minute, String title, String body) async {
// //     await Workmanager().registerPeriodicTask(
// //       taskName,
// //       taskName,
// //       frequency: const Duration(hours: 1), // Run every hour
// //       initialDelay: _calculateDelayUntilTime(hour, minute),
// //       existingWorkPolicy: ExistingWorkPolicy.replace, // Replace previous task
// //       constraints: Constraints(
// //         networkType: NetworkType.not_required,
// //       ),
// //     );
// //   }
// //
// //   Duration _calculateDelayUntilTime(int hour, int minute) {
// //     final now = DateTime.now();
// //     final targetTime = DateTime(now.year, now.month, now.day, hour, minute);
// //     print("targetTime=====${targetTime}");
// //     if (targetTime.isBefore(now)) {
// //       // If the target time has already passed today, schedule for tomorrow
// //       return targetTime.add(const Duration(days: 1)).difference(now);
// //     } else {
// //       return targetTime.difference(now);
// //     }
// //   }
// //
// //   void cancelClockNotifications() {
// //     Workmanager().cancelByUniqueName(clockInTask);
// //     Workmanager().cancelByUniqueName(clockOutTask);
// //   }
// //
// //   Future<void> showNotification(
// //       {required String title, required String body}) async {
// //     // ... your notification logic (using flutter_local_notifications)
// //     // ... make sure to initialize FlutterLocalNotificationsPlugin
// //     // ... and define notification details before calling this method
// //     NotifyHelper().displayNotification(title: title, body: body);
// //   }
// //
// //
// //
// //   // This is the callback function that WorkManager will execute in the background
// //   void callbackDispatcher() {
// //     Workmanager().executeTask((task, inputData) async {
// //       switch (task) {
// //         case clockInTask:
// //           await showNotification(
// //               title: "Clock In Reminder", body: "It's 8 AM,Don't forget to clock in!");
// //           break;
// //         case clockOutTask:
// //           await showNotification(
// //               title: "Clock Out Reminder",
// //               body: "It's 5 PM,Don't forget to clock out!");
// //           break;
// //         case 'trackLocation':
// //           await LocationTrackingService.trackLocation();;
// //           break;
// //         default:
// //           print("This task is not recognized: $task");
// //       }
// //       return Future.value(true);
// //     });
// //   }
// // }
//
// import 'dart:io';
// import 'dart:isolate';
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// import 'package:workmanager/workmanager.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
//
// import 'location_tracking_service.dart';
// import 'notification_services.dart';
// // ... other imports
//
// const int clockCheckInterval = 60; // Seconds (1 minute)
// const String clockInTask = "clockInTask";
// const String clockOutTask = "clockOutTask";
//
// class AttendanceService {
//   // ... (initializeWorkManager remains the same)
//     static Future<void> initializeWorkManager() async {
//     Workmanager().initialize(
//       callbackDispatcher,
//       isInDebugMode: true,
//     );
//   }
//
//   static  void callbackDispatcher() {
//     Workmanager().executeTask((task, inputData) async {
//       switch (task) {
//         case clockInTask:
//           await NotifyHelper().displayNotification(
//               title: "Clock In Reminder", body: "It's 8 AM,Don't forget to clock in!");
//           break;
//         case clockOutTask:
//           await NotifyHelper().displayNotification(
//               title: "Clock Out Reminder",
//               body: "It's 5 PM,Don't forget to clock out!");
//           break;
//         case 'trackLocation':
//           await LocationTrackingService.trackLocation();;
//           break;
//         default:
//           print("This task is not recognized: $task");
//       }
//       return Future.value(true);
//     });
//   }
//
//   static Future<void> initializeBackgroundTasks() async {
//
//     // Add a delay before setting the alarm
//     await Future.delayed(const Duration(seconds: 5));
//     // 1. Schedule frequent clock checks (Android)
//     if (Platform.isAndroid) {
//       await AndroidAlarmManager.periodic(
//         const Duration(seconds: clockCheckInterval),
//         0, // Unique ID for this alarm
//         _checkTimeAndNotify,
//         wakeup: true, // Wake up device if needed
//         rescheduleOnReboot: true, // Reschedule after reboot
//       );
//     } else if (Platform.isIOS) {
//       // Implement Background Fetch for iOS (see Apple documentation)
//     }
//
//     // 2. Schedule 12 PM location tracking using WorkManager
//     await LocationTrackingService.initializeLocationTracking();
//   }
//
//   static void scheduleClockNotifications() {
//     _scheduleNotification(clockInTask, 8, 0, "Clock In Reminder", "Don't forget to clock in!");
//     _scheduleNotification(clockOutTask, 17, 0, "Clock Out Reminder", "Don't forget to clock out!");
//   }
//
//   static Future<void> _scheduleNotification(
//       String taskName, int hour, int minute, String title, String body) async {
//     await Workmanager().registerPeriodicTask(
//       taskName,
//       taskName,
//       frequency: const Duration(hours: 24), // Run daily
//       initialDelay: _calculateDelayUntilTime(hour, minute),
//       existingWorkPolicy: ExistingWorkPolicy.replace, // Replace previous task
//       constraints: Constraints(
//         networkType: NetworkType.not_required, // Remove network constraint
//       ),
//     );
//   }
//   // ... (Other methods: _calculateDelayUntilTime, cancelClockNotifications, synchronizeData)
//
//
//
//   static Duration _calculateDelayUntilTime(int hour, int minute) {
//     final now = DateTime.now();
//     final targetTime = DateTime(now.year, now.month, now.day, hour, minute);
//     print("targetTime=====${targetTime}");
//     if (targetTime.isBefore(now)) {
//       // If the target time has already passed today, schedule for tomorrow
//       return targetTime.add(const Duration(days: 1)).difference(now);
//     } else {
//       return targetTime.difference(now);
//     }
//   }
//
//   static void cancelClockNotifications() {
//     Workmanager().cancelByUniqueName(clockInTask);
//     Workmanager().cancelByUniqueName(clockOutTask);
//   }
//
//   Future<void> showNotification(
//       {required String title, required String body}) async {
//     // ... your notification logic (using flutter_local_notifications)
//     // ... make sure to initialize FlutterLocalNotificationsPlugin
//     // ... and define notification details before calling this method
//     NotifyHelper().displayNotification(title: title, body: body);
//   }
//
//
//   // Function to be executed by AlarmManager
//   static void _checkTimeAndNotify() async {
//     final now = DateTime.now();
//     print("_checkTimeAndNotify Time ==== ${_checkTimeAndNotify}");
//
//     // Trigger clock-in notification
//     if (now.hour == 5 && now.minute == 50) {
//       await NotifyHelper().displayNotification(
//           title: "Clock In Reminder", body: "Don't forget to clock in!");
//     }
//
//     // Trigger clock-out notification
//     if (now.hour == 17 && now.minute == 0) {
//       await NotifyHelper().displayNotification(
//           title: "Clock Out Reminder", body: "Don't forget to clock out!");
//     }
//   }
// }