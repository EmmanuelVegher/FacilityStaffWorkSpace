// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;
// // If you are using GetX for navigation
// import '../Pages/auth_check.dart'; // Replace with your actual navigation target
// import '../main.dart';
// import 'isar_service.dart'; // Replace with your actual service
//
// // Function for Handling background notification taps
// @pragma('vm:entry-point')
// void notificationTapBackground(NotificationResponse notificationResponse) {
//   // Print details about the tapped notification for debugging.
//   print('notification(${notificationResponse.id}) action tapped: '
//       '${notificationResponse.actionId} with '
//       'payload: ${notificationResponse.payload}');
//
//   // Check if the notification tap included user input.
//   if (notificationResponse.input?.isNotEmpty ?? false) {
//     print(
//         'notification action tapped with input: ${notificationResponse.input}');
//   }
// }
//
// class NotifyHelper {
//   // Create an instance of the notification plugin. This is a singleton
//   // object, meaning you'll use this same instance throughout your app.
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   // Flag to ensure timezone initialization happens only once.
//   static bool _isTimeZoneInitialized = false;
//
//   // Initializes the notification plugin and configures settings.
//   Future<void> initializeNotification() async {
//     // Initialize timezones only once.
//     if (!_isTimeZoneInitialized) {
//       _configureLocalTimezone();
//       _isTimeZoneInitialized = true;
//     }
//
//     // Android-specific initialization settings.
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('notification_icon'); // Replace 'notification_icon' with your app's notification icon name from the 'android' folder in your project.
//
//     // iOS-specific initialization settings.
//     const DarwinInitializationSettings initializationSettingsDarwin =
//     DarwinInitializationSettings(
//       requestSoundPermission: false,
//       requestBadgePermission: false,
//       requestAlertPermission: false,
//     );
//
//     // Combine platform-specific settings.
//     const InitializationSettings initializationSettings =
//     InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsDarwin, // Use Darwin for both iOS and macOS
//     );
//
//     // Initialize the notification plugin with settings and callbacks.
//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       // Handle notification tap actions when the app is in the foreground.
//       onDidReceiveNotificationResponse:
//           (NotificationResponse notificationResponse) {
//         // Determine the type of notification response.
//         switch (notificationResponse.notificationResponseType) {
//           case NotificationResponseType.selectedNotification:
//           // Navigate to a specific page when the notification is tapped.
//             navigatorKey.currentState?.push(
//               MaterialPageRoute(
//                 builder: (context) => AuthCheck(
//                   service: IsarService(),
//                 ),
//               ),
//             );
//             //_scheduleClockOutReminders(); // Re-schedule the notification if needed.
//             break;
//           case NotificationResponseType.selectedNotificationAction:
//           // Handle actions associated with specific action IDs.
//             break;
//         }
//       },
//       // Handle notification taps when the app is in the background.
//       onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
//     );
//   }
//
//   // Future<void> _configureLocalTimezone() async {
//   //   tz.initializeTimeZones();
//   //   tz.setLocalLocation(tz.getLocation('Africa/Lagos')); // Use setLocalLocation
//   // }
//
//   // Schedules a notification based on the Task object
//   // Future<void> scheduledNotification(int hour, int minute, Task task) async {
//   //   await _configureLocalTimezone(); // Ensure timezone is configured
//   //
//   //   try {
//   //     var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
//   //         'your channel id', 'your channel name',
//   //         channelDescription: 'your channel description',
//   //         importance: Importance.max, priority: Priority.high, ticker: 'ticker');
//   //     var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
//   //
//   //     NotificationDetails platformChannelSpecifics = NotificationDetails(
//   //         android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
//   //
//   //
//   //     tz.TZDateTime scheduledDate = _calculateScheduledTime(hour, minute, task.repeat);
//   //
//   //     await flutterLocalNotificationsPlugin.zonedSchedule(
//   //       task.id!.toInt(),
//   //       task.title,
//   //       task.note,
//   //       scheduledDate,
//   //       platformChannelSpecifics,
//   //       androidAllowWhileIdle: true,
//   //       uiLocalNotificationDateInterpretation:
//   //       UILocalNotificationDateInterpretation.absoluteTime,
//   //       matchDateTimeComponents: DateTimeComponents.time, // Match only time components for daily repeats
//   //       payload: "${task.title}|${task.note}|", // Use task details as payload
//   //     );
//   //   } catch (e) {
//   //     print('Error scheduling notification: $e');
//   //   }
//   //
//   //
//   //
//   //
//   // }
//
//   tz.TZDateTime _calculateScheduledTime(int hour, int minute, String repeat) {
//     final now = DateTime.now();
//     tz.Location nigeriaTimeZone = tz.getLocation('Africa/Lagos');
//
//     var scheduledDate = tz.TZDateTime(nigeriaTimeZone, now.year, now.month, now.day, hour, minute);
//
//     // Adjust scheduled date for future notifications
//     if (scheduledDate.isBefore(tz.TZDateTime.now(nigeriaTimeZone))) {
//       if (repeat == 'Daily') {
//         scheduledDate = scheduledDate.add(const Duration(days: 1));
//       } else { // For other repeat types (e.g., Weekly, Monthly), add appropriate duration
//         // Example for weekly:
//         // scheduledDate = scheduledDate.add(const Duration(days: 7));
//       }
//     }
//
//     return scheduledDate;
//   }
//
//   // // Schedule daily notifications for clock-out reminders (example).
//   // Future<void> _scheduleClockOutReminders() async {
//   //   tz.initializeTimeZones();
//   //   tz.Location nigeriaTimeZone = tz.getLocation('Africa/Lagos');
//   //
//   //   DateTime now = DateTime.now();
//   //   DateTime fivePM = DateTime(now.year, now.month, now.day, 17, 0, 0);
//   //
//   //   if (fivePM.isBefore(now)) {
//   //     fivePM = DateTime(now.year, now.month, now.day + 1, 17, 0, 0);
//   //   }
//   //
//   //   tz.TZDateTime scheduledDate =
//   //   tz.TZDateTime.from(fivePM, nigeriaTimeZone);
//   //
//   //   await flutterLocalNotificationsPlugin.zonedSchedule(
//   //     0, // Unique notification ID
//   //     'Clock Out Reminder',
//   //     'Don\'t forget to clock out for the day!',
//   //     scheduledDate,
//   //     const NotificationDetails(
//   //       android: AndroidNotificationDetails(
//   //         'high_importance_channel',
//   //         'Clock Out Reminder',
//   //         importance: Importance.high,
//   //         playSound: true,
//   //       ),
//   //       iOS: DarwinNotificationDetails(
//   //         sound: 'default.wav',
//   //         presentSound: true,
//   //       ),
//   //     ),
//   //     androidAllowWhileIdle: true,
//   //     uiLocalNotificationDateInterpretation:
//   //     UILocalNotificationDateInterpretation.absoluteTime,
//   //     matchDateTimeComponents: DateTimeComponents.time,
//   //     payload: "Clock-Out Reminder|+ Kindly remember to clock-out|",
//   //   );
//   // }
//   //
//   // // Schedules a daily notification for a specific time.
//   // Future<void> scheduleDailyNotifications(
//   //     int id, String title, String body, int hour, int minute) async {
//   //   tz.initializeTimeZones();
//   //   tz.Location nigeriaTimeZone = tz.getLocation('Africa/Lagos');
//   //
//   //   final now = DateTime.now();
//   //   var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
//   //
//   //   // Debugging: Print the initially calculated scheduled time
//   //   print("Initial Scheduled Time: $scheduledTime");
//   //
//   //   // If scheduled time has already passed, schedule for tomorrow.
//   //   if (scheduledTime.isBefore(now)) {
//   //     scheduledTime = scheduledTime.add(const Duration(days: 1));
//   //     print("Scheduling for Tomorrow: $scheduledTime"); // Debugging
//   //   }
//   //
//   //   tz.TZDateTime scheduledDate =
//   //   tz.TZDateTime.from(scheduledTime, nigeriaTimeZone);
//   //
//   //   // Debugging: Print the final scheduled date and time
//   //   print("Final Scheduled Date: $scheduledDate");
//   //
//   //   await flutterLocalNotificationsPlugin.zonedSchedule(
//   //     id,
//   //     title,
//   //     body,
//   //     scheduledDate,
//   //     const NotificationDetails(
//   //       android: AndroidNotificationDetails(
//   //         'your_channel_id',
//   //         'your_channel_name',
//   //         importance: Importance.high,
//   //         playSound: true,
//   //       ),
//   //       iOS: DarwinNotificationDetails(
//   //         sound: 'default.wav',
//   //         presentSound: true,
//   //       ),
//   //     ),
//   //     androidAllowWhileIdle: true,
//   //     uiLocalNotificationDateInterpretation:
//   //     UILocalNotificationDateInterpretation.absoluteTime,
//   //     matchDateTimeComponents: DateTimeComponents.time,
//   //     payload: '$title|+${body ?? ''}',
//   //   );
//   // }
//
//   // Configures the local timezone to 'Africa/Lagos'.
//   Future<void> _configureLocalTimezone() async {
//     tz.initializeTimeZones();
//     // You can directly set the timezone to 'Africa/Lagos' here.
//     // No need to use 'FlutterNativeTimezone' if you have a fixed timezone.
//     print("tz.initializeTimeZonesBeforeChange()======${tz.Location}");
//     tz.Location nigeriaTimeZone = tz.getLocation('Africa/Lagos');
//
//     print("tz.initializeTimeZonesAfterChange()======$nigeriaTimeZone");
//   }
//
//   // Displays a notification immediately.
//   displayNotification({required String title, required String body}) async {
//     print("doing test");
//     var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
//         'high_importance_channel', 'Clock Out Reminder',
//         importance: Importance.max,
//         priority: Priority.high,
//         playSound: true);
//     var iOSPlatformChannelSpecifics =
//     const DarwinNotificationDetails(sound: 'default.wav');
//     var platformChannelSpecifics = NotificationDetails(
//         android: androidPlatformChannelSpecifics,
//         iOS: iOSPlatformChannelSpecifics);
//     await flutterLocalNotificationsPlugin.show(
//       0, // Notification ID
//       title, // Notification title
//       body, // Notification body
//       platformChannelSpecifics, // Platform-specific notification details
//       payload: title, // Optional payload
//     );
//   }
//
//   // Requests notification permissions for iOS.
//   void requestIOSPermissions() {
//     flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         IOSFlutterLocalNotificationsPlugin>()
//         ?.requestPermissions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//   }
//
//   // Handles notification taps when the app is in the foreground.
//   Future selectNotification(String? payload) async {
//     // Check if a payload was included with the notification.
//     if (payload != null) {
//       print('notification payload: $payload');
//     } else {
//       print("Notification Done");
//     }
//
//     // Example: Handle navigation based on the payload.
//     if (payload == "Theme Changed") {
//       print("Nothing to Navigate to");
//     } else {
//       // Get.to(()=>NotifiedPage(label:payload),);
//     }
//   }
// }
