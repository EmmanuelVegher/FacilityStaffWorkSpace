import 'package:flutter/material.dart';


import 'attendance_report.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance App'),
      ),
      body: Center(
        child: Column(
          children:[
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => AnalyticsScreen()),
            //     );
            //   },
            //   child: Text('View Analytics'),
            // ),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AttendanceReportScreen()),
                );
              },
              child: const Text('View Analytics Report'),
            ),
          ]
        ),

      ),
    );
  }
}