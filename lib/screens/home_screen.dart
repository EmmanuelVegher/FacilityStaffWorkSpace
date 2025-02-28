import 'package:flutter/material.dart';


import 'analytics_screen.dart';
import 'attendance_report.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance App'),
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
                  MaterialPageRoute(builder: (context) => AttendanceReportScreen()),
                );
              },
              child: Text('View Analytics Report'),
            ),
          ]
        ),

      ),
    );
  }
}