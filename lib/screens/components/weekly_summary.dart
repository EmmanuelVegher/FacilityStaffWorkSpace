// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'dart:ui';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// import '../api/attendance_api.dart';
// import '../models/attendance_record.dart';
// import '../utils/constants.dart';
// import '../utils/date_helper.dart';
// import 'package:path/path.dart' as path;
// import 'package:image/image.dart' as img; // Import the image package
//
// class AttendanceReportScreen extends StatefulWidget {
//   @override
//   _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
// }
//
// class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
//   // Filter values
//   String? _selectedState;
//   String? _selectedLocationName;
//   String? _selectedFullName;
//   // Lists to hold unique values for filters
//   List<String> _states = [];
//   List<String> _locationNames = [];
//   List<String> _fullNames = [];
//
//
//   DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
//   DateTime _endDate = DateTime.now();
//   String? formattedMonth;
//   String _reportMessage = '';
//   final AttendanceAPI _attendanceAPI = AttendanceAPI();
//   List<AttendanceRecord> _attendanceData = [];
//   List<LocationRecord> _locationData = [];
//
//   bool _isLoading = true;
//   String? _errorMessage;
//   // Global Keys for charts
//   final GlobalKey<SfCartesianChartState> _clockInOutTrendsChartKey = GlobalKey();
//   final GlobalKey<SfCartesianChartState> _durationWorkedDistributionChartKey = GlobalKey();
//   final GlobalKey<SfCircularChartState> _attendanceByLocationChartKey = GlobalKey();
//   final GlobalKey<SfCartesianChartState> _earlyLateClockInsChartKey = GlobalKey();
//   // Controllers for input fields
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _designationController = TextEditingController();
//   final TextEditingController _fullNameController = TextEditingController();
//
//   late GlobalKey<SfCartesianChartState> _cartesianClockInChartKey;
//
//   final GlobalKey<SfCartesianChartState> _clockInOutTrendsChartKey2 = GlobalKey();
//
//   @override
//   void initState() {
//     super.initState();
//     _cartesianClockInChartKey = GlobalKey();
//     //_fetchAttendanceData();
//     _fetchUniqueFilterValues();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Attendance Report'),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildFilterDropdown<String>(
//                 'State',
//                 _states,
//                 _selectedState,
//                     (value) => setState(() {
//                   _selectedState = value;
//                   // You might want to update location names based on the selected state
//                   _fetchUniqueLocationNamesForState(value);
//                 }),
//               ),
//               _buildFilterDropdown<String>(
//                 'Location Name',
//                 _locationNames,
//                 _selectedLocationName,
//                     (value) => setState(() => _selectedLocationName = value),
//               ),
//               _buildFilterDropdown<String>(
//                 'Full Name',
//                 _fullNames,
//                 _selectedFullName,
//                     (value) => setState(() => _selectedFullName = value),
//               ),
//               // ... [Your Existing Report Generation Section] ...
//
//               // Input fields for email and designation
//               TextField(
//                 controller: _emailController,
//                 decoration: InputDecoration(labelText: 'Your Email'),
//               ),
//               TextField(
//                 controller: _designationController,
//                 decoration: InputDecoration(labelText: 'Your Designation'),
//               ),
//               _buildDatePicker('Start Date', _startDate, (date) {
//                 setState(() {
//                   _startDate = date;
//                 });
//               }),
//               _buildDatePicker('End Date', _endDate, (date) {
//                 setState(() {
//                   _endDate = date;
//                   formattedMonth = DateFormat('MMMM yyyy').format(_endDate); // Get month and year
//                 });
//               }),
//               ElevatedButton(
//                 onPressed: _generateReport,
//                 child: Text('Generate Report'),
//               ),
//               SizedBox(height: 20),
//               Text(_reportMessage),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _fetchAttendanceData,
//                 child: Text('Generate Analytics'),
//               ),
//               _isLoading
//                   ? Center(child: CircularProgressIndicator())
//                   : _errorMessage != null
//                   ? Center(child: Text(_errorMessage!))
//                   : _buildAnalyticsDashboard(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Widget to build filter dropdowns
//   Widget _buildFilterDropdown<T>(
//       String label,
//       List<T> items,
//       T? selectedValue,
//       ValueChanged<T?> onChanged,
//       ) {
//     return DropdownButtonFormField<T>(
//       value: selectedValue,
//       onChanged: onChanged,
//       decoration: InputDecoration(labelText: label),
//       items: items
//           .map((item) => DropdownMenuItem<T>(
//         value: item,
//         child: Text(item.toString()),
//       ))
//           .toList(),
//     );
//   }
//
//   // Function to fetch unique values for filters
//   Future<void> _fetchUniqueFilterValues() async {
//     try {
//       final firestore = FirebaseFirestore.instance;
//       final staffSnapshot = await firestore.collection('Staff').get();
//
//       setState(() {
//         _states = staffSnapshot.docs
//             .map((doc) => doc.data()['state'] as String? ?? '')
//             .toSet()
//             .toList();
//         _locationNames = staffSnapshot.docs
//             .map((doc) => doc.data()['location'] as String? ?? '')
//             .toSet()
//             .toList();
//         _fullNames = staffSnapshot.docs
//             .map((doc) =>
//         '${doc.data()['firstName']} ${doc.data()['lastName']}' as String? ??
//             '')
//             .toSet()
//             .toList();
//       });
//     } catch (e) {
//       print('Error fetching unique filter values: $e');
//     }
//   }
//
//   // Function to fetch location names based on the selected state
//   Future<void> _fetchUniqueLocationNamesForState(String? state) async {
//     if (state == null) return;
//
//     try {
//       final firestore = FirebaseFirestore.instance;
//       final locationSnapshot = await firestore
//           .collection('Location')
//           .doc(state)
//           .collection(state)
//           .get();
//
//       setState(() {
//         _locationNames = locationSnapshot.docs
//             .map((doc) => doc.data()['LocationName'] as String? ?? '')
//             .toSet()
//             .toList();
//       });
//     } catch (e) {
//       print('Error fetching location names for state $state: $e');
//     }
//   }
//
//
//   Widget _buildDatePicker(
//       String label, DateTime initialDate, Function(DateTime) onDateSelected) {
//     return Row(
//       children: [
//         Text('$label: '),
//         TextButton(
//           onPressed: () async {
//             final selectedDate = await showDatePicker(
//               context: context,
//               initialDate: initialDate,
//               firstDate: DateTime(2020),
//               lastDate: DateTime.now(),
//             );
//             if (selectedDate != null) {
//               onDateSelected(selectedDate);
//             }
//           },
//           child: Text(DateFormat('dd-MM-yyyy').format(initialDate)),
//         ),
//       ],
//     );
//   }
//
//   Future<void> _generateReport() async {
//     setState(() {
//       _reportMessage = 'Generating report...';
//     });
//
//     try {
//       final startDate = _startDate;
//       final endDate = _endDate;
//
//       final recipientEmail = _emailController.text.trim();
//       final designation = _designationController.text.trim();
//
//       if (recipientEmail.isEmpty) {
//         throw Exception('Please enter your email address.');
//       }
//
//       // Fetch all records within the date range and corresponding staff data
//       final attendanceRecords = await getRecordsForDateRangeForChart(startDate, endDate);
//       final staffSnapshot = await FirebaseFirestore.instance.collection('Staff').get();
//
//       // Filter the data
//       final filteredRecords = <AttendanceRecord>[];
//       for (var record in attendanceRecords) {
//         final staffDoc = staffSnapshot.docs.firstWhere(
//                 (doc) => doc.id == record.userId);
//
//         if (staffDoc != null) {
//           final staffData = staffDoc.data();
//
//           // Apply state filter
//           if (_selectedState != null && staffData['state'] != _selectedState) {
//             continue; // Skip to the next record
//           }
//
//           // Apply location name filter
//           if (_selectedLocationName != null && staffData['location'] != _selectedLocationName) {
//             continue;
//           }
//
//           // Apply full name filter
//           if (_selectedFullName != null) {
//             final fullNameParts = _selectedFullName!.split(' ');
//             final firstName = fullNameParts[0];
//             final lastName = fullNameParts.length > 1 ? fullNameParts[1] : '';
//
//             if (staffData['firstName'] != firstName ||
//                 staffData['lastName'] != lastName) {
//               continue;
//             }
//           }
//
//           // If the record passes all filters, add it to filteredRecords
//           filteredRecords.add(record);
//         }
//       }
//
//
//       // Assuming your API has a method to fetch and send the report
//       await _sendAttendanceReport(
//         recipientEmail,
//         designation,
//         filteredRecords,
//         startDate,
//         endDate,
//       );
//
//       setState(() {
//         _reportMessage = 'Report generation completed. Email sent!';
//       });
//     } catch (error) {
//       print('Error generating report: $error');
//       setState(() {
//         _reportMessage = 'Error generating report: $error';
//       });
//     }
//   }
//
//   // Future<void> _generateReport() async {
//   //   setState(() {
//   //     _reportMessage = 'Generating report...';
//   //
//   //   });
//   //
//   //   try {
//   //     final startDate = _startDate;
//   //     final endDate = _endDate;
//   //
//   //     // Assuming your API has a method to fetch and send the report
//   //     await getRecordsForDateRange(startDate, endDate);
//   //
//   //     setState(() {
//   //       _reportMessage = 'Report generation completed. Emails sent!';
//   //     });
//   //   } catch (error) {
//   //     print('Error generating report: $error');
//   //     setState(() {
//   //       _reportMessage = 'Error generating report: $error';
//   //     });
//   //   }
//   //
//   // }
//
//   // // Function to fetch and filter attendance records
//   // Future<List<AttendanceRecord>> _getFilteredAttendanceRecords(
//   //     DateTime startDate,
//   //     DateTime endDate,
//   //     String? state,
//   //     String? locationName,
//   //     String? fullName,
//   //     ) async {
//   //   // 1. Fetch all records within the date range
//   //   final allRecords = await getRecordsForDateRangeForChart(startDate, endDate);
//   //
//   //   // 2. Apply filters
//   //   return allRecords.where((record) {
//   //     final staffData = record.staffData; // Assuming you have access to staff data in AttendanceRecord
//   //
//   //     // Apply state filter
//   //     if (state != null && staffData?['state'] != state) {
//   //       return false;
//   //     }
//   //
//   //     // Apply location name filter
//   //     if (locationName != null && staffData?['location'] != locationName) {
//   //       return false;
//   //     }
//   //
//   //     // Apply full name filter
//   //     if (fullName != null) {
//   //       final fullNameParts = fullName.split(' ');
//   //       final firstName = fullNameParts[0];
//   //       final lastName = fullNameParts.length > 1 ? fullNameParts[1] : '';
//   //
//   //       if (staffData?['firstName'] != firstName ||
//   //           staffData?['lastName'] != lastName) {
//   //         return false;
//   //       }
//   //     }
//   //
//   //     return true;
//   //   }).toList();
//   // }
//
//   // Function to send the attendance report
//   Future<void> _sendAttendanceReport(
//       String recipientEmail,
//       String designation,
//       List<AttendanceRecord> records,
//       DateTime startDate,
//       DateTime endDate,
//       ) async {
//     // ... Your logic to process and send the email report ...
//   }
//
//
//   Future<void> _fetchAttendanceData() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       _attendanceData =
//       await getRecordsForDateRangeForChart(_startDate, _endDate);
//       _locationData = _getLocationData(_attendanceData);
//       print("_attendanceData ==== $_attendanceData");
//       print("_locationData ==== $_locationData");
//     } catch (error) {
//       _errorMessage = 'Error fetching data: ${error.toString()}';
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<List<AttendanceRecord>> getRecordsForDateRangeForChart2(DateTime startDate, DateTime endDate) async {
//     final records = <AttendanceRecord>[];
//     final firestore = FirebaseFirestore.instance;
//
//     try{
//
//
//       final staffSnapshot = await firestore.collection('Staff').get();
//
//
//
//       // Now process the attendance records for each staff member
//       for (var staffDoc in staffSnapshot.docs) {
//         final userId = staffDoc.id;
//         final staffData = staffDoc.data();
//         final primaryFacility = staffData['location'] ?? '';
//
//
//
//         for (var date = startDate;
//         date.isBefore(endDate.add(const Duration(days: 1)));
//         date = date.add(const Duration(days: 1))) {
//           final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//           print("formattedDate ====$formattedDate");
//           final recordSnapshot = await firestore
//               .collection('Staff')
//               .doc(userId)
//               .collection('Record')
//               .doc(formattedDate)
//               .get();
//
//           if (recordSnapshot.exists) {
//             records.add(AttendanceRecord.fromFirestore(recordSnapshot));
//           }
//         }
//
//
//
//
//
//       }
//
//
//
//       print('Successfully processed records and sent emails.');
//
//     }catch(e){
//       print('Error fetching data: $e');
//       rethrow;
//     }
//
//     return records;
//   }
//
//
//   // Function to extract location data from attendance records
//   List<LocationRecord> _getLocationData(List<AttendanceRecord> attendanceData) {
//     Map<String, int> locationCounts = {};
//     for (var record in attendanceData) {
//       final location = record.clockInLocation;
//       if (location != null) {
//         locationCounts.update(location, (value) => value + 1, ifAbsent: () => 1);
//       }
//     }
//     return locationCounts.entries
//         .map((entry) => LocationRecord(location: entry.key, attendanceCount: entry.value))
//         .toList();
//   }
//
//   List<List<HeatmapData>> _getHeatmapData() {
//     Map<int, Map<int, dynamic>> weeklyData = {};
//
//     for (var record in _attendanceData) {
//       int weekNumber = ((record.date.difference(DateTime(record.date.year, 1, 1)).inDays + 1) / 7).ceil();
//       int dayOfWeek = record.date.weekday;
//
//       weeklyData.putIfAbsent(weekNumber, () => {});
//       weeklyData[weekNumber]![dayOfWeek] = record;
//     }
//
//     List<List<HeatmapData>> heatmapData = [];
//     for (int week = 1; week <= 4; week++) {
//       List<HeatmapData> weekData = [];
//       for (int day = 0; day < 7; day++) {
//         var record = weeklyData[week]?[day];
//         weekData.add(HeatmapData(
//           dayOfWeek: day,
//           weekNumber: week,
//           attendanceScore: record != null ?  double.tryParse(record.attendanceScore!) ?? 0.0 : 0.0,
//         ));
//       }
//       heatmapData.add(weekData);
//     }
//
//     return heatmapData;
//   }
//
//   Widget _buildAnalyticsDashboard() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             _buildSummaryCard(),
//
//             SizedBox(height: 20),
//
//             //  _buildClockInOutTrendsChart(),
//             SizedBox(height: 20),
//             // _buildDurationWorkedDistributionChart(),
//             SizedBox(height: 20),
//             // _buildAttendanceByLocationChart(),
//             SizedBox(height: 20),
//             //_buildEarlyLateClockInsChart(),
//             SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () {
//                 _renderChartAsImage(_clockInOutTrendsChartKey); // Pass the chart key you want to export
//               },
//               child: Text('Export Clock-In/Out Trends Chart'),
//             ),
//             SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () {
//                 _renderChartAsImage(_durationWorkedDistributionChartKey);
//               },
//               child: Text('Export Duration Worked Distribution Chart'),
//             ),
//             SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () {
//                 _renderChartAsImage(_attendanceByLocationChartKey);
//               },
//               child: Text('Export Attendance by Location Chart'),
//             ),
//             SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () {
//                 _renderChartAsImage(_earlyLateClockInsChartKey);
//               },
//               child: Text('Export Early/Late Clock-Ins Chart'),
//             ),
//
//
//
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryCard() {
//     return Card(
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Weekly Summary',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 10),
//             // Example Summary Data (Replace with your logic)
//             Text('Total Hours Worked: ${_calculateTotalHoursWorked()}'),
//             Text('Average Clock-In Time: ${_calculateAverageClockInTime()}'),
//             // Add more summary data as needed...
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Example summary calculation functions (Replace with your logic)
//   String _calculateTotalHoursWorked() {
//     // Calculate total hours worked from _attendanceData
//     // Example implementation (replace with your actual calculation)
//     double totalHours = 0;
//     for (var record in _attendanceData) {
//       totalHours += DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
//     }
//     return totalHours.toStringAsFixed(2);
//   }
//
//
//   String _calculateAverageClockInTime() {
//     // Define the time format (assuming HH:mm)
//     final timeFormat = DateFormat('HH:mm');
//
//     // Calculate average clock-in time from _attendanceData
//     if (_attendanceData.isEmpty) {
//       return 'N/A';
//     }
//
//     double totalMinutes = 0;
//     for (var record in _attendanceData) {
//       // Parse the clockInTime string to DateTime
//       DateTime clockInTime = timeFormat.parse(record.clockInTime);
//
//       // Add the time in minutes
//       totalMinutes += clockInTime.hour * 60 + clockInTime.minute;
//     }
//
//     int averageMinutes = totalMinutes ~/ _attendanceData.length;
//     int averageHour = averageMinutes ~/ 60;
//     int averageMinute = averageMinutes % 60;
//
//     // Return the formatted average time as HH:mm
//     return '$averageHour:${averageMinute.toString().padLeft(2, '0')}';
//   }
//
//
//
//   // Widget _buildClockInOutTrendsChart() {
//   //   // Define the time format (assuming it's in hh:mm a format)
//   //   final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//   //
//   //   return Card(
//   //     elevation: 3,
//   //     child: Container(
//   //       height: 300,
//   //       padding: EdgeInsets.all(16.0),
//   //       child: SfCartesianChart(
//   //         key: _clockInOutTrendsChartKey,
//   //         title: ChartTitle(text: 'Clock-In and Clock-Out Trends'),
//   //         primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//   //         tooltipBehavior: TooltipBehavior(
//   //           enable: true,
//   //           format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
//   //         ),
//   //         series: <CartesianSeries<AttendanceRecord, String>>[
//   //           LineSeries<AttendanceRecord, String>(
//   //             dataSource: _attendanceData,
//   //             xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//   //             yValueMapper: (data, _) {
//   //               // Parse clockInTime string to DateTime
//   //               DateTime clockIn = timeFormat.parse(data.clockInTime);
//   //               // Return rounded value for plotting
//   //               return double.parse((clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
//   //             },
//   //             name: 'Clock-In',
//   //             color: Colors.green,
//   //             dataLabelSettings: DataLabelSettings(
//   //               isVisible: true,
//   //               // Display the rounded value with one decimal place in labels
//   //               labelAlignment: ChartDataLabelAlignment.middle,
//   //               // Use a custom label formatter for data labels
//   //               // labelMapper: (data, _) {
//   //               //   DateTime clockIn = timeFormat.parse(data.clockInTime);
//   //               //   return (clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1);
//   //               // },
//   //             ),
//   //           ),
//   //           LineSeries<AttendanceRecord, String>(
//   //             dataSource: _attendanceData,
//   //             xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//   //             yValueMapper: (data, _) {
//   //               // Parse clockOutTime string to DateTime
//   //               DateTime clockOut = timeFormat.parse(data.clockOutTime);
//   //               // Return rounded value for plotting
//   //               return double.parse((clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
//   //             },
//   //             name: 'Clock-Out',
//   //             color: Colors.red,
//   //             dataLabelSettings: DataLabelSettings(
//   //               isVisible: true,
//   //               // Display the rounded value with one decimal place in labels
//   //               labelAlignment: ChartDataLabelAlignment.middle,
//   //               // Use a custom label formatter for data labels
//   //               // labelMapper: (data, _) {
//   //               //   DateTime clockOut = timeFormat.parse(data.clockOutTime);
//   //               //   return (clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1);
//   //               // },
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
//   //
//   //
//   //
//   // Widget _buildDurationWorkedDistributionChart() {
//   //   return Card(
//   //     elevation: 3,
//   //     child: Container(
//   //       height: 300,
//   //       padding: EdgeInsets.all(16.0),
//   //       child: SfCartesianChart(
//   //         key: _durationWorkedDistributionChartKey,
//   //         title: ChartTitle(text: 'Work Duration Distribution'),
//   //         primaryXAxis: NumericAxis(
//   //             labelStyle: TextStyle(fontSize: 10),
//   //             title: AxisTitle(text: 'Work Duration (hours)') // Add X-axis title
//   //         ),
//   //         tooltipBehavior: TooltipBehavior(enable: true),
//   //         series: <HistogramSeries<AttendanceRecord, double>>[
//   //           HistogramSeries<AttendanceRecord, double>(
//   //             dataSource: _attendanceData,
//   //             yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime,data.clockOutTime),// Calculate duration in hours
//   //             binInterval: 1,
//   //             color: Colors.purple,
//   //             // Add data label settings here
//   //             dataLabelSettings: DataLabelSettings(
//   //               isVisible: true,
//   //               // Customize appearance (optional):
//   //               // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//   //               // labelAlignment: ChartDataLabelAlignment.top,
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
//   //
//   // Widget _buildAttendanceByLocationChart() {
//   //   return Card(
//   //     elevation: 3,
//   //     child: Container(
//   //       height: 300,
//   //       padding: EdgeInsets.all(16.0),
//   //       child: SfCircularChart(
//   //         key: _attendanceByLocationChartKey,
//   //         title: ChartTitle(text: 'Attendance by Location'),
//   //         legend: Legend(isVisible: true),
//   //         series: <CircularSeries>[
//   //           PieSeries<LocationRecord, String>(
//   //             dataSource: _locationData,
//   //             xValueMapper: (LocationRecord data, _) => data.location,
//   //             yValueMapper: (LocationRecord data, _) => data.attendanceCount,
//   //             dataLabelSettings: DataLabelSettings(isVisible: true),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
//   //
//   //
//   // Widget _buildEarlyLateClockInsChart() {
//   //   // Calculate early/late minutes for each record
//   //   List<Map<String, dynamic>> chartData = _attendanceData.map((record) {
//   //     int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
//   //     return {
//   //       'date': DateFormat('dd-MMM').format(record.date),
//   //       'earlyLateMinutes': earlyLateMinutes,
//   //     };
//   //   }).toList();
//   //
//   //   return Card(
//   //     elevation: 3,
//   //     child: Container(
//   //       height: 300,
//   //       padding: EdgeInsets.all(16.0),
//   //       child: SfCartesianChart(
//   //         key: _earlyLateClockInsChartKey,
//   //         title: ChartTitle(text: 'Early Clock-Ins and Late Clock-Ins In Minutes (If positive(green), it means the user clocked in late.If negative(Red), the user clocked in early.If it’s zero, the user clocked in on time.'),
//   //         primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//   //         primaryYAxis: NumericAxis(
//   //           // Center the Y-axis around zero
//   //           minimum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b) < 0
//   //               ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b).toDouble()
//   //               : null,
//   //           maximum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b) > 0
//   //               ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b).toDouble()
//   //               : null,
//   //         ),
//   //         tooltipBehavior: TooltipBehavior(enable: true),
//   //         series: <CartesianSeries<Map<String, dynamic>, String>>[
//   //           ColumnSeries<Map<String, dynamic>, String>(
//   //             dataSource: chartData,
//   //             xValueMapper: (data, _) => data['date'] as String,
//   //             yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
//   //             name: 'Clock-In/Out',
//   //             pointColorMapper: (data, _) =>
//   //             (data['earlyLateMinutes'] as int) >= 0 ? Colors.green : Colors.red, // Green for positive, red for negative
//   //             dataLabelSettings: DataLabelSettings(
//   //               isVisible: true, // Make data labels visible
//   //               // You can further customize the appearance of data labels
//   //               // using properties like:
//   //               // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//   //               // labelAlignment: ChartDataLabelAlignment.top,
//   //             ),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
//
//
//
//   Future<void> _renderChartAsImage(GlobalKey chartKey) async {
//     try {
//       // Get the chart state using the GlobalKey
//       if (chartKey.currentState is SfCartesianChartState) {
//         // For Cartesian charts (SfCartesianChart)
//         final SfCartesianChartState chartState = chartKey.currentState! as SfCartesianChartState;
//         final ui.Image? chartImage = await chartState.toImage(pixelRatio: 3.0);
//         if (chartImage != null) {
//           final ByteData? bytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
//           if (bytes != null) {
//             final Uint8List imageBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
//             // You can now use 'imageBytes' to display or share the image.
//             // For example, you can navigate to a new screen and show the image:
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => Scaffold(
//                   appBar: AppBar(title: Text('Chart Image')),
//                   body: Center(
//                     child: Image.memory(imageBytes),
//                   ),
//                 ),
//               ),
//             );
//           } else {
//             print('Error: Failed to convert image to bytes.');
//           }
//         } else {
//           print('Error: Chart image is null.');
//         }
//
//         // ... (Rest of your image export logic) ...
//
//       } else if (chartKey.currentState is SfCircularChartState) {
//         // For circular charts (SfCircularChart)
//         final SfCircularChartState chartState = chartKey.currentState! as SfCircularChartState;
//         final ui.Image? chartImage = await chartState.toImage(pixelRatio: 3.0);
//
//         // ... (Rest of your image export logic) ...
//         if (chartImage != null) {
//           final ByteData? bytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
//           if (bytes != null) {
//             final Uint8List imageBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
//             // You can now use 'imageBytes' to display or share the image.
//             // For example, you can navigate to a new screen and show the image:
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => Scaffold(
//                   appBar: AppBar(title: Text('Chart Image')),
//                   body: Center(
//                     child: Image.memory(imageBytes),
//                   ),
//                 ),
//               ),
//             );
//           } else {
//             print('Error: Failed to convert image to bytes.');
//           }
//         } else {
//           print('Error: Chart image is null.');
//         }
//
//       } else {
//         print('Error: Unsupported chart type.');
//       }
//
//     } catch (e) {
//       print('Error rendering chart as image: $e');
//     }
//   }
//
//   // Future<String?> _createChartImage(List<AttendanceRecord> attendanceData) async {
//   //   print("attendanceData==$attendanceData");
//   //   final Completer<String?> completer = Completer<String?>();
//   //   final chartKey = GlobalKey();
//   //
//   //   // Build the chart within a StatefulBuilder to rebuild it after it's in the tree
//   //   await showDialog(
//   //     context: context, // Use the provided context
//   //     builder: (BuildContext dialogContext) => StatefulBuilder(
//   //       builder: (context, setState) {
//   //         return Dialog(
//   //           insetPadding: EdgeInsets.zero, // Make the dialog fill the screen
//   //           backgroundColor: Colors.transparent, // Hide the dialog background
//   //           child: RepaintBoundary(
//   //             key: chartKey,
//   //             child: _buildClockInOutTrendsChartForEmail(attendanceData),
//   //           ),
//   //         );
//   //       },
//   //     ),
//   //   );
//   //
//   //   // Schedule image capture after the dialog is shown
//   //   WidgetsBinding.instance.addPostFrameCallback((_) async {
//   //     try {
//   //       RenderRepaintBoundary boundary =
//   //       chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//   //       ui.Image image = await boundary.toImage(pixelRatio: 0.8);
//   //       ByteData? byteData =
//   //       await image.toByteData(format: ui.ImageByteFormat.png);
//   //
//   //       if (byteData != null) {
//   //         // Convert to PNG bytes
//   //         final List<int> pngBytes = byteData.buffer.asUint8List();
//   //
//   //         // Decode PNG image to the image package format
//   //         img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//   //
//   //         // Encode the resized image to PNG format
//   //         List<int> compressedPng = img.encodePng(originalImage);
//   //
//   //         // Convert to Base64 string
//   //         completer.complete(base64Encode(compressedPng));
//   //
//   //         // Close the dialog after image capture using the provided `context`
//   //         Navigator.of(context).pop();  // Use context here
//   //       } else {
//   //         completer.complete(null);
//   //         // Close the dialog after image capture failure using the provided `context`
//   //         Navigator.of(context).pop();  // Use context here
//   //       }
//   //     } catch (e) {
//   //       print('Error creating chart image: $e');
//   //       completer.complete(null);
//   //       // Close the dialog after error using the provided `context`
//   //       Navigator.of(context).pop();  // Use context here
//   //     }
//   //   });
//   //
//   //   return completer.future;
//   // }
//
//
//
//   // Future<String?> _createChartImage(List<AttendanceRecord> attendanceData) async {
//   //   print("attendanceData==$attendanceData");
//   //   final Completer<String?> completer = Completer<String?>();
//   //   final chartKey = GlobalKey();
//   //
//   //   // Create a controller to check when the chart is ready
//   //   final chartReadyCompleter = Completer<void>();
//   //
//   //   // Build the chart within a StatefulBuilder to notify when it's built
//   //   final chartWidget = StatefulBuilder(
//   //     builder: (context, setState) {
//   //       // Notify when the chart is built (first frame)
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         if (!chartReadyCompleter.isCompleted) {
//   //           chartReadyCompleter.complete();
//   //         }
//   //       });
//   //       return RepaintBoundary(
//   //         key: chartKey,
//   //         child: _buildClockInOutTrendsChartForEmail(attendanceData),
//   //       );
//   //     },
//   //   );
//   //
//   //   // Create an overlay entry to show the chart off-screen
//   //   final overlayEntry = OverlayEntry(
//   //     builder: (context) => chartWidget,
//   //   );
//   //
//   //   // Insert the overlay entry to render the chart off-screen
//   //   Overlay.of(context).insert(overlayEntry);
//   //
//   //   // Wait for the chart to signal that it's ready
//   //   await chartReadyCompleter.future;
//   //
//   //   // Now capture the image, giving the chart enough time to render
//   //   await Future.delayed(Duration(milliseconds: 2000));
//   //
//   //   try {
//   //     RenderRepaintBoundary boundary =
//   //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//   //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//   //     ByteData? byteData =
//   //     await image.toByteData(format: ui.ImageByteFormat.png);
//   //
//   //     if (byteData != null) {
//   //       final List<int> pngBytes = byteData.buffer.asUint8List();
//   //
//   //       // 2. Resize the image using the image package
//   //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//   //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//   //
//   //       // Encode the resized image
//   //       List<int> compressedPng = img.encodePng(originalImage);
//   //
//   //       completer.complete(base64Encode(compressedPng));
//   //     } else {
//   //       completer.complete(null);
//   //     }
//   //   } catch (e) {
//   //     print('Error creating chart image: $e');
//   //     completer.complete(null);
//   //   } finally {
//   //     // Remove the overlay entry to avoid memory leaks
//   //     overlayEntry.remove();
//   //   }
//   //
//   //   return completer.future;
//   // }
//   //
//   // Future<String?> _createChartImage1(List<AttendanceRecord> attendanceData) async {
//   //   print("attendanceData==$attendanceData");
//   //   final Completer<String?> completer = Completer<String?>();
//   //   final chartKey = GlobalKey();
//   //
//   //   // Create a controller to check when the chart is ready
//   //   final chartReadyCompleter = Completer<void>();
//   //
//   //   // Build the chart within a StatefulBuilder to notify when it's built
//   //   final chartWidget = StatefulBuilder(
//   //     builder: (context, setState) {
//   //       // Notify when the chart is built (first frame)
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         if (!chartReadyCompleter.isCompleted) {
//   //           chartReadyCompleter.complete();
//   //         }
//   //       });
//   //       return RepaintBoundary(
//   //         key: chartKey,
//   //         child: _buildDurationWorkedDistributionChartForEmail(attendanceData),
//   //       );
//   //     },
//   //   );
//   //
//   //   // Create an overlay entry to show the chart off-screen
//   //   final overlayEntry = OverlayEntry(
//   //     builder: (context) => chartWidget,
//   //   );
//   //
//   //   // Insert the overlay entry to render the chart off-screen
//   //   Overlay.of(context).insert(overlayEntry);
//   //
//   //   // Wait for the chart to signal that it's ready
//   //   await chartReadyCompleter.future;
//   //
//   //   // Now capture the image, giving the chart enough time to render
//   //   await Future.delayed(Duration(milliseconds: 2000));
//   //
//   //   try {
//   //     RenderRepaintBoundary boundary =
//   //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//   //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//   //     ByteData? byteData =
//   //     await image.toByteData(format: ui.ImageByteFormat.png);
//   //
//   //     if (byteData != null) {
//   //       final List<int> pngBytes = byteData.buffer.asUint8List();
//   //
//   //       // 2. Resize the image using the image package
//   //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//   //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//   //
//   //       // Encode the resized image
//   //       List<int> compressedPng = img.encodePng(originalImage);
//   //
//   //       completer.complete(base64Encode(compressedPng));
//   //     } else {
//   //       completer.complete(null);
//   //     }
//   //   } catch (e) {
//   //     print('Error creating chart image: $e');
//   //     completer.complete(null);
//   //   } finally {
//   //     // Remove the overlay entry to avoid memory leaks
//   //     overlayEntry.remove();
//   //   }
//   //
//   //   return completer.future;
//   // }
//   // Future<String?> _createChartImage2(List<AttendanceRecord> attendanceData) async {
//   //   print("attendanceData==$attendanceData");
//   //   final Completer<String?> completer = Completer<String?>();
//   //   final chartKey = GlobalKey();
//   //
//   //   // Create a controller to check when the chart is ready
//   //   final chartReadyCompleter = Completer<void>();
//   //
//   //   // Build the chart within a StatefulBuilder to notify when it's built
//   //   final chartWidget = StatefulBuilder(
//   //     builder: (context, setState) {
//   //       // Notify when the chart is built (first frame)
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         if (!chartReadyCompleter.isCompleted) {
//   //           chartReadyCompleter.complete();
//   //         }
//   //       });
//   //       return RepaintBoundary(
//   //         key: chartKey,
//   //         child: _buildAttendanceByLocationChartForEmail(attendanceData),
//   //       );
//   //     },
//   //   );
//   //
//   //   // Create an overlay entry to show the chart off-screen
//   //   final overlayEntry = OverlayEntry(
//   //     builder: (context) => chartWidget,
//   //   );
//   //
//   //   // Insert the overlay entry to render the chart off-screen
//   //   Overlay.of(context).insert(overlayEntry);
//   //
//   //   // Wait for the chart to signal that it's ready
//   //   await chartReadyCompleter.future;
//   //
//   //   // Now capture the image, giving the chart enough time to render
//   //   await Future.delayed(Duration(milliseconds: 2000));
//   //
//   //   try {
//   //     RenderRepaintBoundary boundary =
//   //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//   //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//   //     ByteData? byteData =
//   //     await image.toByteData(format: ui.ImageByteFormat.png);
//   //
//   //     if (byteData != null) {
//   //       final List<int> pngBytes = byteData.buffer.asUint8List();
//   //
//   //       // 2. Resize the image using the image package
//   //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//   //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//   //
//   //       // Encode the resized image
//   //       List<int> compressedPng = img.encodePng(originalImage);
//   //
//   //       completer.complete(base64Encode(compressedPng));
//   //     } else {
//   //       completer.complete(null);
//   //     }
//   //   } catch (e) {
//   //     print('Error creating chart image: $e');
//   //     completer.complete(null);
//   //   } finally {
//   //     // Remove the overlay entry to avoid memory leaks
//   //     overlayEntry.remove();
//   //   }
//   //
//   //   return completer.future;
//   // }
//   // Future<String?> _createChartImage3(List<AttendanceRecord> attendanceData) async {
//   //   print("attendanceData==$attendanceData");
//   //   final Completer<String?> completer = Completer<String?>();
//   //   final chartKey = GlobalKey();
//   //
//   //   // Create a controller to check when the chart is ready
//   //   final chartReadyCompleter = Completer<void>();
//   //
//   //   // Build the chart within a StatefulBuilder to notify when it's built
//   //   final chartWidget = StatefulBuilder(
//   //     builder: (context, setState) {
//   //       // Notify when the chart is built (first frame)
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         if (!chartReadyCompleter.isCompleted) {
//   //           chartReadyCompleter.complete();
//   //         }
//   //       });
//   //       return RepaintBoundary(
//   //         key: chartKey,
//   //         child: _buildEarlyLateClockInsChartForEmail(attendanceData),
//   //       );
//   //     },
//   //   );
//   //
//   //   // Create an overlay entry to show the chart off-screen
//   //   final overlayEntry = OverlayEntry(
//   //     builder: (context) => chartWidget,
//   //   );
//   //
//   //   // Insert the overlay entry to render the chart off-screen
//   //   Overlay.of(context).insert(overlayEntry);
//   //
//   //   // Wait for the chart to signal that it's ready
//   //   await chartReadyCompleter.future;
//   //
//   //   // Now capture the image, giving the chart enough time to render
//   //   await Future.delayed(Duration(milliseconds: 2000));
//   //
//   //   try {
//   //     RenderRepaintBoundary boundary =
//   //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//   //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//   //     ByteData? byteData =
//   //     await image.toByteData(format: ui.ImageByteFormat.png);
//   //
//   //     if (byteData != null) {
//   //       final List<int> pngBytes = byteData.buffer.asUint8List();
//   //
//   //       // 2. Resize the image using the image package
//   //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//   //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//   //
//   //       // Encode the resized image
//   //       List<int> compressedPng = img.encodePng(originalImage);
//   //
//   //       completer.complete(base64Encode(compressedPng));
//   //     } else {
//   //       completer.complete(null);
//   //     }
//   //   } catch (e) {
//   //     print('Error creating chart image: $e');
//   //     completer.complete(null);
//   //   } finally {
//   //     // Remove the overlay entry to avoid memory leaks
//   //     overlayEntry.remove();
//   //   }
//   //
//   //   return completer.future;
//   // }
//
//
//   Widget _buildClockInOutTrendsChartForEmail(List<AttendanceRecord> attendanceData) {
//     // Define the time format (assuming it's in hh:mm a format)
//     final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Clock-In and Clock-Out Trends (When People Clock In (Green) and Clock Out (Red))',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), ),
//           primaryXAxis: CategoryAxis(
//               labelStyle: TextStyle(fontSize: 20),
//               title: AxisTitle(text: 'Days of the Week',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),) // Add X-axis title
//           ),
//           primaryYAxis: NumericAxis(
//               labelStyle: TextStyle(fontSize: 20), // Style for Y-axis labels
//               title: AxisTitle(text: 'Time of the Day',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//
//           ),
//           tooltipBehavior: TooltipBehavior(
//             enable: true,
//             format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
//           ),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             LineSeries<AttendanceRecord, String>(
//               dataSource: attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) {
//                 // Parse clockInTime string to DateTime
//                 DateTime clockIn = timeFormat.parse(data.clockInTime);
//                 // Return rounded value for plotting
//                 return double.parse((clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
//               },
//               name: 'Clock-In',
//               color: Colors.green,
//               dataLabelSettings: DataLabelSettings(
//                   isVisible: true,
//                   labelAlignment: ChartDataLabelAlignment.middle,
//                   textStyle: TextStyle(fontSize: 20, color: Colors.black),
//                   builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//                     return Text(
//                       timeFormat.format(timeFormat.parse(data.clockInTime)),
//                       style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//                     );
//                   }
//
//               ),
//             ),
//             LineSeries<AttendanceRecord, String>(
//               dataSource: attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) {
//                 // Parse clockOutTime string to DateTime
//                 DateTime clockOut = timeFormat.parse(data.clockOutTime);
//                 // Return rounded value for plotting
//                 return double.parse((clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
//               },
//               name: 'Clock-Out',
//               color: Colors.red,
//               dataLabelSettings: DataLabelSettings(
//                   isVisible: true,
//                   labelAlignment: ChartDataLabelAlignment.middle,
//                   textStyle: TextStyle(fontSize: 20, color: Colors.black),
//                   builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//                     return Text(
//                       timeFormat.format(timeFormat.parse(data.clockOutTime)),
//                       style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//                     );
//                   }
//
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDurationWorkedDistributionChartForEmail(List<AttendanceRecord> attendanceData) {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           // key: _durationWorkedDistributionChartKey,
//           title: ChartTitle(text: 'Distribution of Hours Worked (How Many Hours You Worked (For example, if you see a "2" on top of a bar between 8 and 9, it means you worked between 8 and 9 hours two times.)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//           primaryXAxis: NumericAxis(
//               labelStyle: TextStyle(fontSize: 20),
//               title: AxisTitle(text: 'Duration of Hours Worked (Grouped By Hours)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),) // Add X-axis title
//           ),
//           primaryYAxis: NumericAxis(
//               labelStyle: TextStyle(fontSize: 20), // Style for Y-axis labels
//               title: AxisTitle(text: 'Frequency',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//
//           ),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <HistogramSeries<AttendanceRecord, double>>[
//             HistogramSeries<AttendanceRecord, double>(
//               dataSource: attendanceData,
//               yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime,data.clockOutTime),// Calculate duration in hours
//               binInterval: 1,
//               color: Colors.purple,
//               // Add data label settings here
//               dataLabelSettings: DataLabelSettings(
//                 isVisible: true,
//                 // Customize appearance (optional):
//                 textStyle: TextStyle(fontSize: 20, color: Colors.black,fontWeight: FontWeight.bold),
//                 // labelAlignment: ChartDataLabelAlignment.top,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAttendanceByLocationChartForEmail(List<AttendanceRecord> attendanceData){
//     List<LocationRecord> _locationData1 = _getLocationData(attendanceData);
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCircularChart(
//           //key: _attendanceByLocationChartKey,
//           title: ChartTitle(text: 'Where you Clocked In (Attendance by Location)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//
//           legend: Legend(isVisible: true,textStyle: TextStyle(fontSize: 20),), // Style for legend text),
//           series: <CircularSeries>[
//             PieSeries<LocationRecord, String>(
//               dataSource: _locationData1,
//               xValueMapper: (LocationRecord data, _) => data.location,
//               yValueMapper: (LocationRecord data, _) => data.attendanceCount,
//               dataLabelSettings: DataLabelSettings(
//                 isVisible: true,
//                 // labelAlignment: ChartDataLabelAlignment.middle,
//                 textStyle: TextStyle(fontSize: 18, color: Colors.black,fontWeight: FontWeight.bold),
//
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildEarlyLateClockInsChartForEmail(List<AttendanceRecord> attendanceData) {
//
//     // Define the time format for clock-in time
//     final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//     // Calculate early/late minutes for each record
//     List<Map<String, dynamic>> chartData = attendanceData.map((record) {
//       int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
//       return {
//         'date': DateFormat('dd-MMM').format(record.date),
//         'earlyLateMinutes': earlyLateMinutes,
//         'clockInTime': timeFormat.format(timeFormat.parse(record.clockInTime)),
//       };
//     }).toList();
//
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           // key: _earlyLateClockInsChartKey,
//           title: ChartTitle(text: 'Did You Clock In Early or Late? (Green = Early, Red = Late, 0 = On Time)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 20),
//               title: AxisTitle(text: 'Days Of the Week',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//           ),
//           primaryYAxis: NumericAxis(
//             title: AxisTitle(text: 'Number of minutes before ,on or after 8:00 AM',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//             // Center the Y-axis around zero
//             labelStyle: TextStyle(fontSize: 20),
//             minimum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b) < 0
//                 ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b).toDouble()
//                 : null,
//             maximum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b) > 0
//                 ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b).toDouble()
//                 : null,
//           ),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<Map<String, dynamic>, String>>[
//             ColumnSeries<Map<String, dynamic>, String>(
//               dataSource: chartData,
//               xValueMapper: (data, _) => data['date'] as String,
//               yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
//               name: 'Clock-In/Out',
//               pointColorMapper: (data, _) =>
//               (data['earlyLateMinutes'] as int) >= 0 ? Colors.red : Colors.green, // Green for positive, red for negative
//               dataLabelSettings: DataLabelSettings(
//                 isVisible: true, // Make data labels visible
//                 // You can further customize the appearance of data labels
//                 // using properties like:
//                 // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//                 // labelAlignment: ChartDataLabelAlignment.top,
//                 // Custom data labels showing clock-in time and early/late minutes
//                 builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//                   // Display clock-in time and early/late minutes in brackets
//                   return Text(
//                     '${data['clockInTime']} (${data['earlyLateMinutes']} mins)',
//                     style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//                   );
//                 },
//                 textStyle: TextStyle(fontSize: 20, color: Colors.black,fontWeight: FontWeight.bold), // Adjust label text style
//
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
//     final records = <AttendanceRecord>[];
//     final firestore = FirebaseFirestore.instance;
//
//     try {
//       final staffSnapshot = await firestore.collection('Staff').get();
//
//       for (var staffDoc in staffSnapshot.docs) {
//         final userId = staffDoc.id;
//         //  final staffData = staffDoc.data(); // You don't need this line here anymore
//         //  final primaryFacility = staffData['location'] ?? '';
//
//         for (var date = startDate;
//         date.isBefore(endDate.add(const Duration(days: 1)));
//         date = date.add(const Duration(days: 1))) {
//           final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//           final recordSnapshot = await firestore
//               .collection('Staff')
//               .doc(userId)
//               .collection('Record')
//               .doc(formattedDate)
//               .get();
//
//           if (recordSnapshot.exists) {
//             final attendanceRecord = AttendanceRecord.fromFirestore(recordSnapshot);
//
//             // Fetch staff data and assign it to the AttendanceRecord
//             attendanceRecord.staffData = staffDoc.data() as Map<String, dynamic>?;
//
//             records.add(attendanceRecord);
//           }
//         }
//       }
//
//       print('Successfully fetched attendance records.');
//     } catch (e) {
//       print('Error fetching data: $e');
//       rethrow;
//     }
//
//     return records;
//   }
//
//
//
//
//
// // Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
//   //   final records = <AttendanceRecord>[];
//   //
//   //
//   //   try{
//   //     for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
//   //       final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//   //       print("formattedDate=== $formattedDate");
//   //
//   //       // Fetch the attendance record document for the user and date
//   //       final recordSnapshot = await _firestore
//   //           .collection('Staff')
//   //           .doc("0A0ySoctMZcmJVh5OaJ5uUTcn073")
//   //           .collection('Record')
//   //           .doc(formattedDate)
//   //           .get();
//   //
//   //       if (recordSnapshot.exists) {
//   //         records.add(AttendanceRecord.fromFirestore(recordSnapshot));
//   //       }
//   //     }
//   //   }catch(e){
//   //     print('Error fetching data: $e');
//   //     rethrow;
//   //   }
//   //   print("record====${records}");
//   //   return records;
//   // }
//
//
//
//   Future<String> imageToBase64(String imagePath) async {
//     final ByteData bytes = await rootBundle.load(imagePath);
//     final buffer = bytes.buffer;
//     return base64Encode(Uint8List.view(buffer));
//   }
//
//   Future<void> getRecordsForDateRange(DateTime startDate, DateTime endDate) async {
//     final firestore = FirebaseFirestore.instance;
//
//     try {
//       final staffSnapshot = await firestore.collection('Staff').get();
//       final locationSnapshot = await firestore.collection('Location').get();
//
//       // Assuming 'assets/caritas_logo.png' is the path to your image
//       String base64Image = await imageToBase64('assets/image/caritaslogo1.png');
//
//       // Map to store locations categorized by type (Facility, Hotel, etc.)
//       final locationTypeMap = <String, Map<String, String>>{};
//
//       // Iterate through each state document and its sub-collections
//       for (var stateDoc in locationSnapshot.docs) {
//         final stateName = stateDoc.id;
//         final subCollectionSnapshot = await firestore
//             .collection('Location')
//             .doc(stateName)
//             .collection(stateName) // Sub-collection with the same name as the state
//             .get();
//
//         for (var locationDoc in subCollectionSnapshot.docs) {
//           final locationName = locationDoc.id;
//           final locationData = locationDoc.data();
//           final category = locationData['category'] ?? ''; // Assuming category field exists
//           final locationName2 = locationData['LocationName'] ?? ''; // Assuming category field exists
//
//           if (!locationTypeMap.containsKey(category)) {
//             locationTypeMap[category] = {};
//           }
//           locationTypeMap[category]![locationName2] = 'Within CARITAS ${category}s';
//         }
//       }
//
//       // Now process the attendance records for each staff member
//       for (var staffDoc in staffSnapshot.docs) {
//         final userId = staffDoc.id;
//         final staffData = staffDoc.data();
//         final primaryFacility = staffData['location'] ?? '';
//
//         final userRecords = <AttendanceRecord>[];
//
//         for (var date = startDate;
//         date.isBefore(endDate.add(const Duration(days: 1)));
//         date = date.add(const Duration(days: 1))) {
//           final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//           print("formattedDate == $formattedDate");
//           final recordSnapshot = await firestore
//               .collection('Staff')
//               .doc(userId)
//               .collection('Record')
//               .doc(formattedDate)
//               .get();
//
//           if (recordSnapshot.exists) {
//             userRecords.add(AttendanceRecord.fromFirestore(recordSnapshot));
//           }
//         }
//
//
//
//         // Location Summary Counts
//         int withinPrimaryFacilityCountClockIn = 0;
//         int withinOtherCaritasLocationsCountClockIn = 0;
//         int outsideCaritasLocationsCountClockIn = 0;
//
//         int withinPrimaryFacilityCountClockOut = 0;
//         int withinOtherCaritasLocationsCountClockOut = 0;
//         int outsideCaritasLocationsCountClockOut = 0;
//
//         for (var record in userRecords) {
//           final clockInLocation = record.clockInLocation;
//           final clockOutLocation = record.clockOutLocation;
//
//           // Clock In Location Check
// // Clock In Location Check
//           if (clockInLocation == primaryFacility) {
//             withinPrimaryFacilityCountClockIn++;
//           } else if (isWithinCaritasLocations(clockInLocation, locationTypeMap) && clockInLocation != primaryFacility) {
//             // Exclude primary facility from other CARITAS locations
//             withinOtherCaritasLocationsCountClockIn++;
//           } else {
//             outsideCaritasLocationsCountClockIn++;
//           }
//
//           // Clock Out Location Check
//           if (clockOutLocation == primaryFacility) {
//             withinPrimaryFacilityCountClockOut++;
//           } else if (isWithinCaritasLocations(clockOutLocation, locationTypeMap) && clockOutLocation != primaryFacility) {
//             // Exclude primary facility from other CARITAS locations
//             withinOtherCaritasLocationsCountClockOut++;
//           } else {
//             outsideCaritasLocationsCountClockOut++;
//           }
//         }
//
//
//
//         // Generate chart images (as Uint8List)
//         final chartImage1 = await _createChartImage5(
//             userRecords, _buildClockInOutTrendsChartForEmail);
//         final chartImage2 = await _createChartImage5(
//             userRecords, _buildDurationWorkedDistributionChartForEmail);
//         final chartImage3 = await _createChartImage5(
//             userRecords, _buildAttendanceByLocationChartForEmail);
//         final chartImage4 = await _createChartImage5(
//             userRecords, _buildEarlyLateClockInsChartForEmail);
//
//         // Upload chart images to Firebase Storage and get URLs
//         List<String?> chartImageUrls = await Future.wait([
//           _uploadImageToStorage(chartImage1, 'chart1_$userId.png'),
//           _uploadImageToStorage(chartImage2, 'chart2_$userId.png'),
//           _uploadImageToStorage(chartImage3, 'chart3_$userId.png'),
//           _uploadImageToStorage(chartImage4, 'chart4_$userId.png'),
//         ]);
//
//
//         // Send email if there are any records to send
//         if (userRecords.isNotEmpty) {
//           await _sendEmailWithRecords(
//             staffData,
//             userRecords,
//             DateFormat('dd-MMMM-yyyy').format(startDate),
//             DateFormat('dd-MMMM-yyyy').format(endDate),
//             withinPrimaryFacilityCountClockIn,
//             withinOtherCaritasLocationsCountClockIn,
//             outsideCaritasLocationsCountClockIn,
//             withinPrimaryFacilityCountClockOut,
//             withinOtherCaritasLocationsCountClockOut,
//             outsideCaritasLocationsCountClockOut,
//             base64Image,
//             chartImageUrls,
//
//           );
//         }
//       }
//
//       print('Successfully processed records and sent emails.');
//
//     } catch (e) {
//       print('Error fetching data or sending emails: $e');
//       rethrow;
//     }
//   }
//
//   Future<String?> _uploadImageToStorage2(String? base64ImageData, String imageName) async {
//     if (base64ImageData == null) return null;
//
//     try {
//       final decodedBytes = base64Decode(base64ImageData); // Decode base64 string to bytes
//       final storageRef = FirebaseStorage.instance.ref().child('images/$imageName');
//       final uploadTask = await storageRef.putData(decodedBytes);
//       return await uploadTask.ref.getDownloadURL();
//     } catch (e) {
//       print('Error uploading image: $e');
//       return null;
//     }
//   }
//
//
//
//   // Function to create chart image and return Uint8List
//   Future<Uint8List?> _createChartImage5(List<AttendanceRecord> attendanceData, Function chartBuilder) async {
//     final Completer<Uint8List?> completer = Completer<Uint8List?>();
//     final chartKey = GlobalKey();
//
//     final chartReadyCompleter = Completer<void>();
//
//     final chartWidget = StatefulBuilder(
//       builder: (context, setState) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (!chartReadyCompleter.isCompleted) {
//             chartReadyCompleter.complete();
//           }
//         });
//         return RepaintBoundary(
//           key: chartKey,
//           child: chartBuilder(attendanceData), // Use the provided chart builder
//         );
//       },
//     );
//
//     final overlayEntry = OverlayEntry(
//       builder: (context) => chartWidget,
//     );
//     Overlay.of(context).insert(overlayEntry);
//     await chartReadyCompleter.future;
//     await Future.delayed(Duration(milliseconds: 4000));
//
//     try {
//       RenderRepaintBoundary boundary = chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//       ui.Image image = await boundary.toImage(pixelRatio: 0.8); // Adjust pixelRatio as needed
//       ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//
//       if (byteData != null) {
//         completer.complete(byteData.buffer.asUint8List());
//       } else {
//         completer.complete(null);
//       }
//     } catch (e) {
//       print('Error creating chart image: $e');
//       completer.complete(null);
//     } finally {
//       overlayEntry.remove();
//     }
//
//     return completer.future;
//   }
//
// // Function to upload image to Firebase Storage
//   Future<String?> _uploadImageToStorage(
//       Uint8List? imageData, String imageName) async {
//     if (imageData == null) return null;
//
//     try {
//       final storageRef = FirebaseStorage.instance
//           .ref()
//           .child('chart_images/$imageName'); // Adjust storage path
//       final uploadTask = await storageRef.putData(imageData);
//       return await uploadTask.ref.getDownloadURL();
//     } catch (e) {
//       print('Error uploading image: $e');
//       return null;
//     }
//   }
//
//   bool isWithinCaritasLocations(String location, Map<String, Map<String, String>> locationTypeMap) {
//     for (var category in locationTypeMap.keys) {
//       if (locationTypeMap[category]!.containsKey(location)) {
//         return true;
//       }
//     }
//     return false;
//   }
//
//   Future<void> _sendEmailWithRecords(
//       Map<String, dynamic> staffData,
//       List<AttendanceRecord> records,
//       String startDate,
//       String endDate,
//       int withinPrimaryFacilityCountClockIn,
//       int withinOtherCaritasLocationsCountClockIn,
//       int outsideCaritasLocationsCountClockIn,
//       int withinPrimaryFacilityCountClockOut,
//       int withinOtherCaritasLocationsCountClockOut,
//       int outsideCaritasLocationsCountClockOut,
//       String base64Image, // Add this line
//       List<String?> chartImageUrls
//
//       ) async {
//     final firstName = staffData['firstName'] ?? '';
//     final lastName = staffData['lastName'] ?? '';
//     final email = staffData['emailAddress'] ?? '';
//     final primaryFacility = staffData['location'] ?? '';
//     final supervisorEmail = staffData['supervisorEmail'] ?? '';
//     final logoImageUrl = await _uploadImageToStorage2(base64Image, 'caritaslogo1.png');
//
//     //final subject = 'Monthly Attendance Summary for September 2024: $startDate to $endDate';
//     final subject = 'Weekly Attendance Records for the week: $startDate to $endDate';
//     int earlyClockInsCount = 0;
//     int totalClockIns = records.length;
//
//     final body = """
//   <!DOCTYPE html>
//   <html>
//   <head>
//     <meta charset="UTF-8">
//   </head>
//   <body>
//
//     <p>Dear $firstName $lastName,</p>
//     <br>
//
//     <p>Primary Facility/Office Location: $primaryFacility</p>
//     <br>
//
//     <h2>Weekly Attendance Summary:</h2>
//
//     <h3>1) Attendance Details:</h3>
//
//     <ul>
//       ${records.map((record) {
//       final date = record.date;
//       final clockInTime = record.clockInTime ?? '';
//       final clockOutTime = record.clockOutTime ?? '';
//       final clockInLocation = record.clockInLocation ?? '';
//       final clockOutLocation = record.clockOutLocation ?? '';
//       final comments = record.comments ?? '';
//       final durationWorked = record.durationWorked ?? '';
//
//       // Parse clock-in time from string to DateTime
//       DateTime? clockInDateTime;
//       if (clockInTime != null && clockInTime.isNotEmpty) {
//         try {
//           clockInDateTime = DateFormat("HH:mm").parse(clockInTime);
//         } catch (e) {
//           print("Error parsing clock-in time: $e");
//         }
//       }
//
//       // Check if clock-in time is before 8:00 AM
//       if (clockInDateTime != null && clockInDateTime.hour < 8) {
//         earlyClockInsCount++;
//       }
//
//       return "&nbsp;&nbsp;&nbsp;&nbsp;☐ ${DateFormat('dd-MMMM-yyyy').format(date)} (${DateFormat('EEEE').format(record.date)}): Clocked in at $clockInTime, Clocked out at $clockOutTime, Duration: $durationWorked, Comments: $comments, Clock In Location: $clockInLocation, Clock Out Location: $clockOutLocation";
//     }).join('<br><br>')}
//     </ul>
//     <br>
//         ${chartImageUrls[0] != null ? '<img src="${chartImageUrls[0]}" alt="Clock-In/Out Trends" style="max-width: 600px; height: auto;"><br>' : ''}
//         <br>
//     ${chartImageUrls[1] != null ? '<img src="${chartImageUrls[1]}" alt="Work Duration Distribution" style="max-width: 600px; height: auto;"><br>' : ''}
//     <br>
//
//
//
//     <h3>2) Location Summary:</h3>
//
//     <ul>
//       <li>Early Clock-ins (Number of Clock-Ins done on or before 8:00AM): $earlyClockInsCount/${totalClockIns} day(s) (${(earlyClockInsCount / totalClockIns * 100).toStringAsFixed(2)}%)</li></ul>
//       <br>
//       ${chartImageUrls[3] != null ? '<img src="${chartImageUrls[3]}" alt="Early/Late Clock-Ins" style="max-width: 600px; height: auto;"><br>' : ''}
//       <br><br>
//       <ul><li>Clock-Ins: Within Primary Facility: $withinPrimaryFacilityCountClockIn, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockIn, Outside CARITAS Locations: $outsideCaritasLocationsCountClockIn</li>
//       <li>Clock-Outs: Within Primary Facility: $withinPrimaryFacilityCountClockOut, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockOut, Outside CARITAS Locations: $outsideCaritasLocationsCountClockOut</li></ul>
//       <br>
//       ${chartImageUrls[2] != null ? '<img src="${chartImageUrls[2]}" alt="Attendance By Location" style="max-width: 600px; height: auto;"><br>' : ''}
//
//
//
//
//     <p>For further details, kindly visit the dashboard at: <a href="https://lookerstudio.google.com/reporting/e021c456-efe7-43ae-86c9-ca25ebfbdd2f">https://lookerstudio.google.com/reporting/e021c456-efe7-43ae-86c9-ca25ebfbdd2f</a></p>
//     <br>
//
//     <p>Please note that if you have synced any attendance that is not reflected in this report or on the dashboard, kindly click on the sync icon on each of the Attendance to perform singular synchronization of the missing Attendance. Note that this is only available for Version 1.5 upward.</p>
//     <br>
//
//     <p style="color:black; font-size:15px; font-weight:bold;">Best Regards,</p>
//     <p style="color:black; font-size:16px; font-weight:bold;">VEGHER, Emmanuel.</p>
//     <p style="color:black; font-size:16px; font-weight:bold;">SENIOR Technical Specialist  - Health Informatics.</p>
//     <p style="color:red; font-size:16px; font-weight:bold;">Caritas Nigeria (CCFN)</p>
//
//     <p style="color:black;">Catholic Secretariat of Nigeria Building,<br>
//     Plot 459 Cadastral Zone B2, Durumi 1, Garki, Abuja<br>
//     Mobile: (Office) +234-8103465662, +234-9088988551<br>
//     Email: <a href="mailto:Evegher@ccfng.org">Evegher@ccfng.org</a> | Facebook: <a href="https://www.facebook.com/CaritasNigeria">www.facebook.com/CaritasNigeria</a><br>
//     Website: <a href="https://www.caritasnigeria.org">www.caritasnigeria.org</a> | Linkedin: <a href="https://www.linkedin.com/in/emmanuel-vegher-221718190/">www.linkedin.com/in/emmanuel-vegher-221718190/</a></p>
//
//      <br>
//
//     ${logoImageUrl != null ? '<img src="$logoImageUrl" alt="Caritas Nigeria Logo" style="max-width: 200px; height: auto;">' : ''}
//     <br>
//
//   </body>
//   </html>
// """;
//
//     try {
//       await sendEmail(email, subject, body, cc: supervisorEmail);
//       // await sendEmail(email, subject, body, cc: supervisorEmail, attachments: [
//       //   if (chartImagePath1 != null) File(chartImagePath1),
//       //   if (chartImagePath2 != null) File(chartImagePath2),
//       //   if (chartImagePath3 != null) File(chartImagePath3),
//       //   if (chartImagePath4 != null) File(chartImagePath4),
//       // ]);
//       print('Email sent successfully to $email (CC: $supervisorEmail)');
//     } catch (e) {
//       print('Error sending email: $e');
//     }
//   }
//
//
// // Modified sendEmail function to fit into the code structure
//   Future<void> sendEmail(String recipient, String subject, String body, {String? cc}) async {
//     final url = Uri.parse('$URL/send-email');
//     final response = await http.post(
//       url,import 'dart:async';
//     import 'dart:convert';
//     import 'dart:io';
//     import 'dart:typed_data';
//     import 'dart:ui' as ui;
//     import 'dart:ui';
//     import 'package:firebase_storage/firebase_storage.dart';
//     import 'package:cloud_firestore/cloud_firestore.dart';
//     import 'package:flutter/material.dart';
//     import 'package:flutter/rendering.dart';
//     import 'package:flutter/services.dart';
//     import 'package:http/http.dart' as http;
//     import 'package:intl/intl.dart';
//     import 'package:path_provider/path_provider.dart';
//     import 'package:syncfusion_flutter_charts/charts.dart';
//
//     import '../api/attendance_api.dart';
//     import '../models/attendance_record.dart';
//     import '../utils/constants.dart';
//     import '../utils/date_helper.dart';
//     import 'package:path/path.dart' as path;
//     import 'package:image/image.dart' as img; // Import the image package
//
//     class AttendanceReportScreen extends StatefulWidget {
//     @override
//     _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
//     }
//
//     class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
//     // Filter values
//     String? _selectedState;
//     String? _selectedLocationName;
//     String? _selectedFullName;
//     // Lists to hold unique values for filters
//     List<String> _states = [];
//     List<String> _locationNames = [];
//     List<String> _fullNames = [];
//
//
//     DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
//     DateTime _endDate = DateTime.now();
//     String? formattedMonth;
//     String _reportMessage = '';
//     final AttendanceAPI _attendanceAPI = AttendanceAPI();
//     List<AttendanceRecord> _attendanceData = [];
//     List<LocationRecord> _locationData = [];
//
//     bool _isLoading = true;
//     String? _errorMessage;
//     // Global Keys for charts
//     final GlobalKey<SfCartesianChartState> _clockInOutTrendsChartKey = GlobalKey();
//     final GlobalKey<SfCartesianChartState> _durationWorkedDistributionChartKey = GlobalKey();
//     final GlobalKey<SfCircularChartState> _attendanceByLocationChartKey = GlobalKey();
//     final GlobalKey<SfCartesianChartState> _earlyLateClockInsChartKey = GlobalKey();
//     // Controllers for input fields
//     final TextEditingController _emailController = TextEditingController();
//     final TextEditingController _designationController = TextEditingController();
//     final TextEditingController _fullNameController = TextEditingController();
//
//     late GlobalKey<SfCartesianChartState> _cartesianClockInChartKey;
//
//     final GlobalKey<SfCartesianChartState> _clockInOutTrendsChartKey2 = GlobalKey();
//
//     @override
//     void initState() {
//     super.initState();
//     _cartesianClockInChartKey = GlobalKey();
//     //_fetchAttendanceData();
//     _fetchUniqueFilterValues();
//     }
//
//     @override
//     Widget build(BuildContext context) {
//     return Scaffold(
//     appBar: AppBar(
//     title: Text('Attendance Report'),
//     ),
//     body: SingleChildScrollView(
//     child: Padding(
//     padding: EdgeInsets.all(16.0),
//     child: Column(
//     crossAxisAlignment: CrossAxisAlignment.stretch,
//     children: [
//     _buildFilterDropdown<String>(
//     'State',
//     _states,
//     _selectedState,
//     (value) => setState(() {
//     _selectedState = value;
//     // You might want to update location names based on the selected state
//     _fetchUniqueLocationNamesForState(value);
//     }),
//     ),
//     _buildFilterDropdown<String>(
//     'Location Name',
//     _locationNames,
//     _selectedLocationName,
//     (value) => setState(() => _selectedLocationName = value),
//     ),
//     _buildFilterDropdown<String>(
//     'Full Name',
//     _fullNames,
//     _selectedFullName,
//     (value) => setState(() => _selectedFullName = value),
//     ),
//     // ... [Your Existing Report Generation Section] ...
//
//     // Input fields for email and designation
//     TextField(
//     controller: _emailController,
//     decoration: InputDecoration(labelText: 'Your Email'),
//     ),
//     TextField(
//     controller: _designationController,
//     decoration: InputDecoration(labelText: 'Your Designation'),
//     ),
//     _buildDatePicker('Start Date', _startDate, (date) {
//     setState(() {
//     _startDate = date;
//     });
//     }),
//     _buildDatePicker('End Date', _endDate, (date) {
//     setState(() {
//     _endDate = date;
//     formattedMonth = DateFormat('MMMM yyyy').format(_endDate); // Get month and year
//     });
//     }),
//     ElevatedButton(
//     onPressed: _generateReport,
//     child: Text('Generate Report'),
//     ),
//     SizedBox(height: 20),
//     Text(_reportMessage),
//     SizedBox(height: 20),
//     ElevatedButton(
//     onPressed: _fetchAttendanceData,
//     child: Text('Generate Analytics'),
//     ),
//     _isLoading
//     ? Center(child: CircularProgressIndicator())
//         : _errorMessage != null
//     ? Center(child: Text(_errorMessage!))
//         : _buildAnalyticsDashboard(),
//     ],
//     ),
//     ),
//     ),
//     );
//     }
//
//     // Widget to build filter dropdowns
//     Widget _buildFilterDropdown<T>(
//     String label,
//     List<T> items,
//     T? selectedValue,
//     ValueChanged<T?> onChanged,
//     ) {
//     return DropdownButtonFormField<T>(
//     value: selectedValue,
//     onChanged: onChanged,
//     decoration: InputDecoration(labelText: label),
//     items: items
//         .map((item) => DropdownMenuItem<T>(
//     value: item,
//     child: Text(item.toString()),
//     ))
//         .toList(),
//     );
//     }
//
//     // Function to fetch unique values for filters
//     Future<void> _fetchUniqueFilterValues() async {
//     try {
//     final firestore = FirebaseFirestore.instance;
//     final staffSnapshot = await firestore.collection('Staff').get();
//
//     setState(() {
//     _states = staffSnapshot.docs
//         .map((doc) => doc.data()['state'] as String? ?? '')
//         .toSet()
//         .toList();
//     _locationNames = staffSnapshot.docs
//         .map((doc) => doc.data()['location'] as String? ?? '')
//         .toSet()
//         .toList();
//     _fullNames = staffSnapshot.docs
//         .map((doc) =>
//     '${doc.data()['firstName']} ${doc.data()['lastName']}' as String? ??
//     '')
//         .toSet()
//         .toList();
//     });
//     } catch (e) {
//     print('Error fetching unique filter values: $e');
//     }
//     }
//
//     // Function to fetch location names based on the selected state
//     Future<void> _fetchUniqueLocationNamesForState(String? state) async {
//     if (state == null) return;
//
//     try {
//     final firestore = FirebaseFirestore.instance;
//     final locationSnapshot = await firestore
//         .collection('Location')
//         .doc(state)
//         .collection(state)
//         .get();
//
//     setState(() {
//     _locationNames = locationSnapshot.docs
//         .map((doc) => doc.data()['LocationName'] as String? ?? '')
//         .toSet()
//         .toList();
//     });
//     } catch (e) {
//     print('Error fetching location names for state $state: $e');
//     }
//     }
//
//
//     Widget _buildDatePicker(
//     String label, DateTime initialDate, Function(DateTime) onDateSelected) {
//     return Row(
//     children: [
//     Text('$label: '),
//     TextButton(
//     onPressed: () async {
//     final selectedDate = await showDatePicker(
//     context: context,
//     initialDate: initialDate,
//     firstDate: DateTime(2020),
//     lastDate: DateTime.now(),
//     );
//     if (selectedDate != null) {
//     onDateSelected(selectedDate);
//     }
//     },
//     child: Text(DateFormat('dd-MM-yyyy').format(initialDate)),
//     ),
//     ],
//     );
//     }
//
//     Future<void> _generateReport() async {
//     setState(() {
//     _reportMessage = 'Generating report...';
//     });
//
//     try {
//     final startDate = _startDate;
//     final endDate = _endDate;
//
//     final recipientEmail = _emailController.text.trim();
//     final designation = _designationController.text.trim();
//
//     if (recipientEmail.isEmpty) {
//     throw Exception('Please enter your email address.');
//     }
//
//     // Fetch all records within the date range and corresponding staff data
//     final attendanceRecords = await getRecordsForDateRangeForChart(startDate, endDate);
//     final staffSnapshot = await FirebaseFirestore.instance.collection('Staff').get();
//
//     // Filter the data
//     final filteredRecords = <AttendanceRecord>[];
//     for (var record in attendanceRecords) {
//     final staffDoc = staffSnapshot.docs.firstWhere(
//     (doc) => doc.id == record.userId);
//
//     if (staffDoc != null) {
//     final staffData = staffDoc.data();
//
//     // Apply state filter
//     if (_selectedState != null && staffData['state'] != _selectedState) {
//     continue; // Skip to the next record
//     }
//
//     // Apply location name filter
//     if (_selectedLocationName != null && staffData['location'] != _selectedLocationName) {
//     continue;
//     }
//
//     // Apply full name filter
//     if (_selectedFullName != null) {
//     final fullNameParts = _selectedFullName!.split(' ');
//     final firstName = fullNameParts[0];
//     final lastName = fullNameParts.length > 1 ? fullNameParts[1] : '';
//
//     if (staffData['firstName'] != firstName ||
//     staffData['lastName'] != lastName) {
//     continue;
//     }
//     }
//
//     // If the record passes all filters, add it to filteredRecords
//     filteredRecords.add(record);
//     }
//     }
//
//
//     // Assuming your API has a method to fetch and send the report
//     await _sendAttendanceReport(
//     recipientEmail,
//     designation,
//     filteredRecords,
//     startDate,
//     endDate,
//     );
//
//     setState(() {
//     _reportMessage = 'Report generation completed. Email sent!';
//     });
//     } catch (error) {
//     print('Error generating report: $error');
//     setState(() {
//     _reportMessage = 'Error generating report: $error';
//     });
//     }
//     }
//
//     // Future<void> _generateReport() async {
//     //   setState(() {
//     //     _reportMessage = 'Generating report...';
//     //
//     //   });
//     //
//     //   try {
//     //     final startDate = _startDate;
//     //     final endDate = _endDate;
//     //
//     //     // Assuming your API has a method to fetch and send the report
//     //     await getRecordsForDateRange(startDate, endDate);
//     //
//     //     setState(() {
//     //       _reportMessage = 'Report generation completed. Emails sent!';
//     //     });
//     //   } catch (error) {
//     //     print('Error generating report: $error');
//     //     setState(() {
//     //       _reportMessage = 'Error generating report: $error';
//     //     });
//     //   }
//     //
//     // }
//
//     // // Function to fetch and filter attendance records
//     // Future<List<AttendanceRecord>> _getFilteredAttendanceRecords(
//     //     DateTime startDate,
//     //     DateTime endDate,
//     //     String? state,
//     //     String? locationName,
//     //     String? fullName,
//     //     ) async {
//     //   // 1. Fetch all records within the date range
//     //   final allRecords = await getRecordsForDateRangeForChart(startDate, endDate);
//     //
//     //   // 2. Apply filters
//     //   return allRecords.where((record) {
//     //     final staffData = record.staffData; // Assuming you have access to staff data in AttendanceRecord
//     //
//     //     // Apply state filter
//     //     if (state != null && staffData?['state'] != state) {
//     //       return false;
//     //     }
//     //
//     //     // Apply location name filter
//     //     if (locationName != null && staffData?['location'] != locationName) {
//     //       return false;
//     //     }
//     //
//     //     // Apply full name filter
//     //     if (fullName != null) {
//     //       final fullNameParts = fullName.split(' ');
//     //       final firstName = fullNameParts[0];
//     //       final lastName = fullNameParts.length > 1 ? fullNameParts[1] : '';
//     //
//     //       if (staffData?['firstName'] != firstName ||
//     //           staffData?['lastName'] != lastName) {
//     //         return false;
//     //       }
//     //     }
//     //
//     //     return true;
//     //   }).toList();
//     // }
//
//     // Function to send the attendance report
//     Future<void> _sendAttendanceReport(
//     String recipientEmail,
//     String designation,
//     List<AttendanceRecord> records,
//     DateTime startDate,
//     DateTime endDate,
//     ) async {
//     // ... Your logic to process and send the email report ...
//     }
//
//
//     Future<void> _fetchAttendanceData() async {
//     setState(() {
//     _isLoading = true;
//     _errorMessage = null;
//     });
//
//     try {
//     _attendanceData =
//     await getRecordsForDateRangeForChart(_startDate, _endDate);
//     _locationData = _getLocationData(_attendanceData);
//     print("_attendanceData ==== $_attendanceData");
//     print("_locationData ==== $_locationData");
//     } catch (error) {
//     _errorMessage = 'Error fetching data: ${error.toString()}';
//     } finally {
//     setState(() {
//     _isLoading = false;
//     });
//     }
//     }
//
//     Future<List<AttendanceRecord>> getRecordsForDateRangeForChart2(DateTime startDate, DateTime endDate) async {
//     final records = <AttendanceRecord>[];
//     final firestore = FirebaseFirestore.instance;
//
//     try{
//
//
//     final staffSnapshot = await firestore.collection('Staff').get();
//
//
//
//     // Now process the attendance records for each staff member
//     for (var staffDoc in staffSnapshot.docs) {
//     final userId = staffDoc.id;
//     final staffData = staffDoc.data();
//     final primaryFacility = staffData['location'] ?? '';
//
//
//
//     for (var date = startDate;
//     date.isBefore(endDate.add(const Duration(days: 1)));
//     date = date.add(const Duration(days: 1))) {
//     final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//     print("formattedDate ====$formattedDate");
//     final recordSnapshot = await firestore
//         .collection('Staff')
//         .doc(userId)
//         .collection('Record')
//         .doc(formattedDate)
//         .get();
//
//     if (recordSnapshot.exists) {
//     records.add(AttendanceRecord.fromFirestore(recordSnapshot));
//     }
//     }
//
//
//
//
//
//     }
//
//
//
//     print('Successfully processed records and sent emails.');
//
//     }catch(e){
//     print('Error fetching data: $e');
//     rethrow;
//     }
//
//     return records;
//     }
//
//
//     // Function to extract location data from attendance records
//     List<LocationRecord> _getLocationData(List<AttendanceRecord> attendanceData) {
//     Map<String, int> locationCounts = {};
//     for (var record in attendanceData) {
//     final location = record.clockInLocation;
//     if (location != null) {
//     locationCounts.update(location, (value) => value + 1, ifAbsent: () => 1);
//     }
//     }
//     return locationCounts.entries
//         .map((entry) => LocationRecord(location: entry.key, attendanceCount: entry.value))
//         .toList();
//     }
//
//     List<List<HeatmapData>> _getHeatmapData() {
//     Map<int, Map<int, dynamic>> weeklyData = {};
//
//     for (var record in _attendanceData) {
//     int weekNumber = ((record.date.difference(DateTime(record.date.year, 1, 1)).inDays + 1) / 7).ceil();
//     int dayOfWeek = record.date.weekday;
//
//     weeklyData.putIfAbsent(weekNumber, () => {});
//     weeklyData[weekNumber]![dayOfWeek] = record;
//     }
//
//     List<List<HeatmapData>> heatmapData = [];
//     for (int week = 1; week <= 4; week++) {
//     List<HeatmapData> weekData = [];
//     for (int day = 0; day < 7; day++) {
//     var record = weeklyData[week]?[day];
//     weekData.add(HeatmapData(
//     dayOfWeek: day,
//     weekNumber: week,
//     attendanceScore: record != null ?  double.tryParse(record.attendanceScore!) ?? 0.0 : 0.0,
//     ));
//     }
//     heatmapData.add(weekData);
//     }
//
//     return heatmapData;
//     }
//
//     Widget _buildAnalyticsDashboard() {
//     return SingleChildScrollView(
//     child: Padding(
//     padding: EdgeInsets.all(16.0),
//     child: Column(
//     crossAxisAlignment: CrossAxisAlignment.stretch,
//     children: [
//     _buildSummaryCard(),
//
//     SizedBox(height: 20),
//
//     //  _buildClockInOutTrendsChart(),
//     SizedBox(height: 20),
//     // _buildDurationWorkedDistributionChart(),
//     SizedBox(height: 20),
//     // _buildAttendanceByLocationChart(),
//     SizedBox(height: 20),
//     //_buildEarlyLateClockInsChart(),
//     SizedBox(height: 30),
//     ElevatedButton(
//     onPressed: () {
//     _renderChartAsImage(_clockInOutTrendsChartKey); // Pass the chart key you want to export
//     },
//     child: Text('Export Clock-In/Out Trends Chart'),
//     ),
//     SizedBox(height: 30),
//     ElevatedButton(
//     onPressed: () {
//     _renderChartAsImage(_durationWorkedDistributionChartKey);
//     },
//     child: Text('Export Duration Worked Distribution Chart'),
//     ),
//     SizedBox(height: 30),
//     ElevatedButton(
//     onPressed: () {
//     _renderChartAsImage(_attendanceByLocationChartKey);
//     },
//     child: Text('Export Attendance by Location Chart'),
//     ),
//     SizedBox(height: 30),
//     ElevatedButton(
//     onPressed: () {
//     _renderChartAsImage(_earlyLateClockInsChartKey);
//     },
//     child: Text('Export Early/Late Clock-Ins Chart'),
//     ),
//
//
//
//     ],
//     ),
//     ),
//     );
//     }
//
//     Widget _buildSummaryCard() {
//     return Card(
//     elevation: 3,
//     child: Padding(
//     padding: const EdgeInsets.all(16.0),
//     child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//     Text(
//     'Weekly Summary',
//     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//     ),
//     SizedBox(height: 10),
//     // Example Summary Data (Replace with your logic)
//     Text('Total Hours Worked: ${_calculateTotalHoursWorked()}'),
//     Text('Average Clock-In Time: ${_calculateAverageClockInTime()}'),
//     // Add more summary data as needed...
//     ],
//     ),
//     ),
//     );
//     }
//
//     // Example summary calculation functions (Replace with your logic)
//     String _calculateTotalHoursWorked() {
//     // Calculate total hours worked from _attendanceData
//     // Example implementation (replace with your actual calculation)
//     double totalHours = 0;
//     for (var record in _attendanceData) {
//     totalHours += DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
//     }
//     return totalHours.toStringAsFixed(2);
//     }
//
//
//     String _calculateAverageClockInTime() {
//     // Define the time format (assuming HH:mm)
//     final timeFormat = DateFormat('HH:mm');
//
//     // Calculate average clock-in time from _attendanceData
//     if (_attendanceData.isEmpty) {
//     return 'N/A';
//     }
//
//     double totalMinutes = 0;
//     for (var record in _attendanceData) {
//     // Parse the clockInTime string to DateTime
//     DateTime clockInTime = timeFormat.parse(record.clockInTime);
//
//     // Add the time in minutes
//     totalMinutes += clockInTime.hour * 60 + clockInTime.minute;
//     }
//
//     int averageMinutes = totalMinutes ~/ _attendanceData.length;
//     int averageHour = averageMinutes ~/ 60;
//     int averageMinute = averageMinutes % 60;
//
//     // Return the formatted average time as HH:mm
//     return '$averageHour:${averageMinute.toString().padLeft(2, '0')}';
//     }
//
//
//
//     // Widget _buildClockInOutTrendsChart() {
//     //   // Define the time format (assuming it's in hh:mm a format)
//     //   final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//     //
//     //   return Card(
//     //     elevation: 3,
//     //     child: Container(
//     //       height: 300,
//     //       padding: EdgeInsets.all(16.0),
//     //       child: SfCartesianChart(
//     //         key: _clockInOutTrendsChartKey,
//     //         title: ChartTitle(text: 'Clock-In and Clock-Out Trends'),
//     //         primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//     //         tooltipBehavior: TooltipBehavior(
//     //           enable: true,
//     //           format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
//     //         ),
//     //         series: <CartesianSeries<AttendanceRecord, String>>[
//     //           LineSeries<AttendanceRecord, String>(
//     //             dataSource: _attendanceData,
//     //             xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//     //             yValueMapper: (data, _) {
//     //               // Parse clockInTime string to DateTime
//     //               DateTime clockIn = timeFormat.parse(data.clockInTime);
//     //               // Return rounded value for plotting
//     //               return double.parse((clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
//     //             },
//     //             name: 'Clock-In',
//     //             color: Colors.green,
//     //             dataLabelSettings: DataLabelSettings(
//     //               isVisible: true,
//     //               // Display the rounded value with one decimal place in labels
//     //               labelAlignment: ChartDataLabelAlignment.middle,
//     //               // Use a custom label formatter for data labels
//     //               // labelMapper: (data, _) {
//     //               //   DateTime clockIn = timeFormat.parse(data.clockInTime);
//     //               //   return (clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1);
//     //               // },
//     //             ),
//     //           ),
//     //           LineSeries<AttendanceRecord, String>(
//     //             dataSource: _attendanceData,
//     //             xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//     //             yValueMapper: (data, _) {
//     //               // Parse clockOutTime string to DateTime
//     //               DateTime clockOut = timeFormat.parse(data.clockOutTime);
//     //               // Return rounded value for plotting
//     //               return double.parse((clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
//     //             },
//     //             name: 'Clock-Out',
//     //             color: Colors.red,
//     //             dataLabelSettings: DataLabelSettings(
//     //               isVisible: true,
//     //               // Display the rounded value with one decimal place in labels
//     //               labelAlignment: ChartDataLabelAlignment.middle,
//     //               // Use a custom label formatter for data labels
//     //               // labelMapper: (data, _) {
//     //               //   DateTime clockOut = timeFormat.parse(data.clockOutTime);
//     //               //   return (clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1);
//     //               // },
//     //             ),
//     //           ),
//     //         ],
//     //       ),
//     //     ),
//     //   );
//     // }
//     //
//     //
//     //
//     // Widget _buildDurationWorkedDistributionChart() {
//     //   return Card(
//     //     elevation: 3,
//     //     child: Container(
//     //       height: 300,
//     //       padding: EdgeInsets.all(16.0),
//     //       child: SfCartesianChart(
//     //         key: _durationWorkedDistributionChartKey,
//     //         title: ChartTitle(text: 'Work Duration Distribution'),
//     //         primaryXAxis: NumericAxis(
//     //             labelStyle: TextStyle(fontSize: 10),
//     //             title: AxisTitle(text: 'Work Duration (hours)') // Add X-axis title
//     //         ),
//     //         tooltipBehavior: TooltipBehavior(enable: true),
//     //         series: <HistogramSeries<AttendanceRecord, double>>[
//     //           HistogramSeries<AttendanceRecord, double>(
//     //             dataSource: _attendanceData,
//     //             yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime,data.clockOutTime),// Calculate duration in hours
//     //             binInterval: 1,
//     //             color: Colors.purple,
//     //             // Add data label settings here
//     //             dataLabelSettings: DataLabelSettings(
//     //               isVisible: true,
//     //               // Customize appearance (optional):
//     //               // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//     //               // labelAlignment: ChartDataLabelAlignment.top,
//     //             ),
//     //           ),
//     //         ],
//     //       ),
//     //     ),
//     //   );
//     // }
//     //
//     // Widget _buildAttendanceByLocationChart() {
//     //   return Card(
//     //     elevation: 3,
//     //     child: Container(
//     //       height: 300,
//     //       padding: EdgeInsets.all(16.0),
//     //       child: SfCircularChart(
//     //         key: _attendanceByLocationChartKey,
//     //         title: ChartTitle(text: 'Attendance by Location'),
//     //         legend: Legend(isVisible: true),
//     //         series: <CircularSeries>[
//     //           PieSeries<LocationRecord, String>(
//     //             dataSource: _locationData,
//     //             xValueMapper: (LocationRecord data, _) => data.location,
//     //             yValueMapper: (LocationRecord data, _) => data.attendanceCount,
//     //             dataLabelSettings: DataLabelSettings(isVisible: true),
//     //           ),
//     //         ],
//     //       ),
//     //     ),
//     //   );
//     // }
//     //
//     //
//     // Widget _buildEarlyLateClockInsChart() {
//     //   // Calculate early/late minutes for each record
//     //   List<Map<String, dynamic>> chartData = _attendanceData.map((record) {
//     //     int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
//     //     return {
//     //       'date': DateFormat('dd-MMM').format(record.date),
//     //       'earlyLateMinutes': earlyLateMinutes,
//     //     };
//     //   }).toList();
//     //
//     //   return Card(
//     //     elevation: 3,
//     //     child: Container(
//     //       height: 300,
//     //       padding: EdgeInsets.all(16.0),
//     //       child: SfCartesianChart(
//     //         key: _earlyLateClockInsChartKey,
//     //         title: ChartTitle(text: 'Early Clock-Ins and Late Clock-Ins In Minutes (If positive(green), it means the user clocked in late.If negative(Red), the user clocked in early.If it’s zero, the user clocked in on time.'),
//     //         primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//     //         primaryYAxis: NumericAxis(
//     //           // Center the Y-axis around zero
//     //           minimum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b) < 0
//     //               ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b).toDouble()
//     //               : null,
//     //           maximum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b) > 0
//     //               ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b).toDouble()
//     //               : null,
//     //         ),
//     //         tooltipBehavior: TooltipBehavior(enable: true),
//     //         series: <CartesianSeries<Map<String, dynamic>, String>>[
//     //           ColumnSeries<Map<String, dynamic>, String>(
//     //             dataSource: chartData,
//     //             xValueMapper: (data, _) => data['date'] as String,
//     //             yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
//     //             name: 'Clock-In/Out',
//     //             pointColorMapper: (data, _) =>
//     //             (data['earlyLateMinutes'] as int) >= 0 ? Colors.green : Colors.red, // Green for positive, red for negative
//     //             dataLabelSettings: DataLabelSettings(
//     //               isVisible: true, // Make data labels visible
//     //               // You can further customize the appearance of data labels
//     //               // using properties like:
//     //               // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//     //               // labelAlignment: ChartDataLabelAlignment.top,
//     //             ),
//     //           ),
//     //         ],
//     //       ),
//     //     ),
//     //   );
//     // }
//
//
//
//     Future<void> _renderChartAsImage(GlobalKey chartKey) async {
//     try {
//     // Get the chart state using the GlobalKey
//     if (chartKey.currentState is SfCartesianChartState) {
//     // For Cartesian charts (SfCartesianChart)
//     final SfCartesianChartState chartState = chartKey.currentState! as SfCartesianChartState;
//     final ui.Image? chartImage = await chartState.toImage(pixelRatio: 3.0);
//     if (chartImage != null) {
//     final ByteData? bytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
//     if (bytes != null) {
//     final Uint8List imageBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
//     // You can now use 'imageBytes' to display or share the image.
//     // For example, you can navigate to a new screen and show the image:
//     Navigator.push(
//     context,
//     MaterialPageRoute(
//     builder: (context) => Scaffold(
//     appBar: AppBar(title: Text('Chart Image')),
//     body: Center(
//     child: Image.memory(imageBytes),
//     ),
//     ),
//     ),
//     );
//     } else {
//     print('Error: Failed to convert image to bytes.');
//     }
//     } else {
//     print('Error: Chart image is null.');
//     }
//
//     // ... (Rest of your image export logic) ...
//
//     } else if (chartKey.currentState is SfCircularChartState) {
//     // For circular charts (SfCircularChart)
//     final SfCircularChartState chartState = chartKey.currentState! as SfCircularChartState;
//     final ui.Image? chartImage = await chartState.toImage(pixelRatio: 3.0);
//
//     // ... (Rest of your image export logic) ...
//     if (chartImage != null) {
//     final ByteData? bytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
//     if (bytes != null) {
//     final Uint8List imageBytes = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
//     // You can now use 'imageBytes' to display or share the image.
//     // For example, you can navigate to a new screen and show the image:
//     Navigator.push(
//     context,
//     MaterialPageRoute(
//     builder: (context) => Scaffold(
//     appBar: AppBar(title: Text('Chart Image')),
//     body: Center(
//     child: Image.memory(imageBytes),
//     ),
//     ),
//     ),
//     );
//     } else {
//     print('Error: Failed to convert image to bytes.');
//     }
//     } else {
//     print('Error: Chart image is null.');
//     }
//
//     } else {
//     print('Error: Unsupported chart type.');
//     }
//
//     } catch (e) {
//     print('Error rendering chart as image: $e');
//     }
//     }
//
//     // Future<String?> _createChartImage(List<AttendanceRecord> attendanceData) async {
//     //   print("attendanceData==$attendanceData");
//     //   final Completer<String?> completer = Completer<String?>();
//     //   final chartKey = GlobalKey();
//     //
//     //   // Build the chart within a StatefulBuilder to rebuild it after it's in the tree
//     //   await showDialog(
//     //     context: context, // Use the provided context
//     //     builder: (BuildContext dialogContext) => StatefulBuilder(
//     //       builder: (context, setState) {
//     //         return Dialog(
//     //           insetPadding: EdgeInsets.zero, // Make the dialog fill the screen
//     //           backgroundColor: Colors.transparent, // Hide the dialog background
//     //           child: RepaintBoundary(
//     //             key: chartKey,
//     //             child: _buildClockInOutTrendsChartForEmail(attendanceData),
//     //           ),
//     //         );
//     //       },
//     //     ),
//     //   );
//     //
//     //   // Schedule image capture after the dialog is shown
//     //   WidgetsBinding.instance.addPostFrameCallback((_) async {
//     //     try {
//     //       RenderRepaintBoundary boundary =
//     //       chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     //       ui.Image image = await boundary.toImage(pixelRatio: 0.8);
//     //       ByteData? byteData =
//     //       await image.toByteData(format: ui.ImageByteFormat.png);
//     //
//     //       if (byteData != null) {
//     //         // Convert to PNG bytes
//     //         final List<int> pngBytes = byteData.buffer.asUint8List();
//     //
//     //         // Decode PNG image to the image package format
//     //         img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//     //
//     //         // Encode the resized image to PNG format
//     //         List<int> compressedPng = img.encodePng(originalImage);
//     //
//     //         // Convert to Base64 string
//     //         completer.complete(base64Encode(compressedPng));
//     //
//     //         // Close the dialog after image capture using the provided `context`
//     //         Navigator.of(context).pop();  // Use context here
//     //       } else {
//     //         completer.complete(null);
//     //         // Close the dialog after image capture failure using the provided `context`
//     //         Navigator.of(context).pop();  // Use context here
//     //       }
//     //     } catch (e) {
//     //       print('Error creating chart image: $e');
//     //       completer.complete(null);
//     //       // Close the dialog after error using the provided `context`
//     //       Navigator.of(context).pop();  // Use context here
//     //     }
//     //   });
//     //
//     //   return completer.future;
//     // }
//
//
//
//     // Future<String?> _createChartImage(List<AttendanceRecord> attendanceData) async {
//     //   print("attendanceData==$attendanceData");
//     //   final Completer<String?> completer = Completer<String?>();
//     //   final chartKey = GlobalKey();
//     //
//     //   // Create a controller to check when the chart is ready
//     //   final chartReadyCompleter = Completer<void>();
//     //
//     //   // Build the chart within a StatefulBuilder to notify when it's built
//     //   final chartWidget = StatefulBuilder(
//     //     builder: (context, setState) {
//     //       // Notify when the chart is built (first frame)
//     //       WidgetsBinding.instance.addPostFrameCallback((_) {
//     //         if (!chartReadyCompleter.isCompleted) {
//     //           chartReadyCompleter.complete();
//     //         }
//     //       });
//     //       return RepaintBoundary(
//     //         key: chartKey,
//     //         child: _buildClockInOutTrendsChartForEmail(attendanceData),
//     //       );
//     //     },
//     //   );
//     //
//     //   // Create an overlay entry to show the chart off-screen
//     //   final overlayEntry = OverlayEntry(
//     //     builder: (context) => chartWidget,
//     //   );
//     //
//     //   // Insert the overlay entry to render the chart off-screen
//     //   Overlay.of(context).insert(overlayEntry);
//     //
//     //   // Wait for the chart to signal that it's ready
//     //   await chartReadyCompleter.future;
//     //
//     //   // Now capture the image, giving the chart enough time to render
//     //   await Future.delayed(Duration(milliseconds: 2000));
//     //
//     //   try {
//     //     RenderRepaintBoundary boundary =
//     //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//     //     ByteData? byteData =
//     //     await image.toByteData(format: ui.ImageByteFormat.png);
//     //
//     //     if (byteData != null) {
//     //       final List<int> pngBytes = byteData.buffer.asUint8List();
//     //
//     //       // 2. Resize the image using the image package
//     //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//     //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//     //
//     //       // Encode the resized image
//     //       List<int> compressedPng = img.encodePng(originalImage);
//     //
//     //       completer.complete(base64Encode(compressedPng));
//     //     } else {
//     //       completer.complete(null);
//     //     }
//     //   } catch (e) {
//     //     print('Error creating chart image: $e');
//     //     completer.complete(null);
//     //   } finally {
//     //     // Remove the overlay entry to avoid memory leaks
//     //     overlayEntry.remove();
//     //   }
//     //
//     //   return completer.future;
//     // }
//     //
//     // Future<String?> _createChartImage1(List<AttendanceRecord> attendanceData) async {
//     //   print("attendanceData==$attendanceData");
//     //   final Completer<String?> completer = Completer<String?>();
//     //   final chartKey = GlobalKey();
//     //
//     //   // Create a controller to check when the chart is ready
//     //   final chartReadyCompleter = Completer<void>();
//     //
//     //   // Build the chart within a StatefulBuilder to notify when it's built
//     //   final chartWidget = StatefulBuilder(
//     //     builder: (context, setState) {
//     //       // Notify when the chart is built (first frame)
//     //       WidgetsBinding.instance.addPostFrameCallback((_) {
//     //         if (!chartReadyCompleter.isCompleted) {
//     //           chartReadyCompleter.complete();
//     //         }
//     //       });
//     //       return RepaintBoundary(
//     //         key: chartKey,
//     //         child: _buildDurationWorkedDistributionChartForEmail(attendanceData),
//     //       );
//     //     },
//     //   );
//     //
//     //   // Create an overlay entry to show the chart off-screen
//     //   final overlayEntry = OverlayEntry(
//     //     builder: (context) => chartWidget,
//     //   );
//     //
//     //   // Insert the overlay entry to render the chart off-screen
//     //   Overlay.of(context).insert(overlayEntry);
//     //
//     //   // Wait for the chart to signal that it's ready
//     //   await chartReadyCompleter.future;
//     //
//     //   // Now capture the image, giving the chart enough time to render
//     //   await Future.delayed(Duration(milliseconds: 2000));
//     //
//     //   try {
//     //     RenderRepaintBoundary boundary =
//     //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//     //     ByteData? byteData =
//     //     await image.toByteData(format: ui.ImageByteFormat.png);
//     //
//     //     if (byteData != null) {
//     //       final List<int> pngBytes = byteData.buffer.asUint8List();
//     //
//     //       // 2. Resize the image using the image package
//     //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//     //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//     //
//     //       // Encode the resized image
//     //       List<int> compressedPng = img.encodePng(originalImage);
//     //
//     //       completer.complete(base64Encode(compressedPng));
//     //     } else {
//     //       completer.complete(null);
//     //     }
//     //   } catch (e) {
//     //     print('Error creating chart image: $e');
//     //     completer.complete(null);
//     //   } finally {
//     //     // Remove the overlay entry to avoid memory leaks
//     //     overlayEntry.remove();
//     //   }
//     //
//     //   return completer.future;
//     // }
//     // Future<String?> _createChartImage2(List<AttendanceRecord> attendanceData) async {
//     //   print("attendanceData==$attendanceData");
//     //   final Completer<String?> completer = Completer<String?>();
//     //   final chartKey = GlobalKey();
//     //
//     //   // Create a controller to check when the chart is ready
//     //   final chartReadyCompleter = Completer<void>();
//     //
//     //   // Build the chart within a StatefulBuilder to notify when it's built
//     //   final chartWidget = StatefulBuilder(
//     //     builder: (context, setState) {
//     //       // Notify when the chart is built (first frame)
//     //       WidgetsBinding.instance.addPostFrameCallback((_) {
//     //         if (!chartReadyCompleter.isCompleted) {
//     //           chartReadyCompleter.complete();
//     //         }
//     //       });
//     //       return RepaintBoundary(
//     //         key: chartKey,
//     //         child: _buildAttendanceByLocationChartForEmail(attendanceData),
//     //       );
//     //     },
//     //   );
//     //
//     //   // Create an overlay entry to show the chart off-screen
//     //   final overlayEntry = OverlayEntry(
//     //     builder: (context) => chartWidget,
//     //   );
//     //
//     //   // Insert the overlay entry to render the chart off-screen
//     //   Overlay.of(context).insert(overlayEntry);
//     //
//     //   // Wait for the chart to signal that it's ready
//     //   await chartReadyCompleter.future;
//     //
//     //   // Now capture the image, giving the chart enough time to render
//     //   await Future.delayed(Duration(milliseconds: 2000));
//     //
//     //   try {
//     //     RenderRepaintBoundary boundary =
//     //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//     //     ByteData? byteData =
//     //     await image.toByteData(format: ui.ImageByteFormat.png);
//     //
//     //     if (byteData != null) {
//     //       final List<int> pngBytes = byteData.buffer.asUint8List();
//     //
//     //       // 2. Resize the image using the image package
//     //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//     //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//     //
//     //       // Encode the resized image
//     //       List<int> compressedPng = img.encodePng(originalImage);
//     //
//     //       completer.complete(base64Encode(compressedPng));
//     //     } else {
//     //       completer.complete(null);
//     //     }
//     //   } catch (e) {
//     //     print('Error creating chart image: $e');
//     //     completer.complete(null);
//     //   } finally {
//     //     // Remove the overlay entry to avoid memory leaks
//     //     overlayEntry.remove();
//     //   }
//     //
//     //   return completer.future;
//     // }
//     // Future<String?> _createChartImage3(List<AttendanceRecord> attendanceData) async {
//     //   print("attendanceData==$attendanceData");
//     //   final Completer<String?> completer = Completer<String?>();
//     //   final chartKey = GlobalKey();
//     //
//     //   // Create a controller to check when the chart is ready
//     //   final chartReadyCompleter = Completer<void>();
//     //
//     //   // Build the chart within a StatefulBuilder to notify when it's built
//     //   final chartWidget = StatefulBuilder(
//     //     builder: (context, setState) {
//     //       // Notify when the chart is built (first frame)
//     //       WidgetsBinding.instance.addPostFrameCallback((_) {
//     //         if (!chartReadyCompleter.isCompleted) {
//     //           chartReadyCompleter.complete();
//     //         }
//     //       });
//     //       return RepaintBoundary(
//     //         key: chartKey,
//     //         child: _buildEarlyLateClockInsChartForEmail(attendanceData),
//     //       );
//     //     },
//     //   );
//     //
//     //   // Create an overlay entry to show the chart off-screen
//     //   final overlayEntry = OverlayEntry(
//     //     builder: (context) => chartWidget,
//     //   );
//     //
//     //   // Insert the overlay entry to render the chart off-screen
//     //   Overlay.of(context).insert(overlayEntry);
//     //
//     //   // Wait for the chart to signal that it's ready
//     //   await chartReadyCompleter.future;
//     //
//     //   // Now capture the image, giving the chart enough time to render
//     //   await Future.delayed(Duration(milliseconds: 2000));
//     //
//     //   try {
//     //     RenderRepaintBoundary boundary =
//     //     chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     //     ui.Image image = await boundary.toImage(pixelRatio: 0.643);
//     //     ByteData? byteData =
//     //     await image.toByteData(format: ui.ImageByteFormat.png);
//     //
//     //     if (byteData != null) {
//     //       final List<int> pngBytes = byteData.buffer.asUint8List();
//     //
//     //       // 2. Resize the image using the image package
//     //       img.Image originalImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
//     //       img.Image resizedImage = img.copyResize(originalImage, width: 300); // Adjust width as needed
//     //
//     //       // Encode the resized image
//     //       List<int> compressedPng = img.encodePng(originalImage);
//     //
//     //       completer.complete(base64Encode(compressedPng));
//     //     } else {
//     //       completer.complete(null);
//     //     }
//     //   } catch (e) {
//     //     print('Error creating chart image: $e');
//     //     completer.complete(null);
//     //   } finally {
//     //     // Remove the overlay entry to avoid memory leaks
//     //     overlayEntry.remove();
//     //   }
//     //
//     //   return completer.future;
//     // }
//
//
//     Widget _buildClockInOutTrendsChartForEmail(List<AttendanceRecord> attendanceData) {
//     // Define the time format (assuming it's in hh:mm a format)
//     final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//
//     return Card(
//     elevation: 3,
//     child: Container(
//     height: 300,
//     padding: EdgeInsets.all(16.0),
//     child: SfCartesianChart(
//     title: ChartTitle(text: 'Clock-In and Clock-Out Trends (When People Clock In (Green) and Clock Out (Red))',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), ),
//     primaryXAxis: CategoryAxis(
//     labelStyle: TextStyle(fontSize: 20),
//     title: AxisTitle(text: 'Days of the Week',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),) // Add X-axis title
//     ),
//     primaryYAxis: NumericAxis(
//     labelStyle: TextStyle(fontSize: 20), // Style for Y-axis labels
//     title: AxisTitle(text: 'Time of the Day',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//
//     ),
//     tooltipBehavior: TooltipBehavior(
//     enable: true,
//     format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
//     ),
//     series: <CartesianSeries<AttendanceRecord, String>>[
//     LineSeries<AttendanceRecord, String>(
//     dataSource: attendanceData,
//     xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//     yValueMapper: (data, _) {
//     // Parse clockInTime string to DateTime
//     DateTime clockIn = timeFormat.parse(data.clockInTime);
//     // Return rounded value for plotting
//     return double.parse((clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
//     },
//     name: 'Clock-In',
//     color: Colors.green,
//     dataLabelSettings: DataLabelSettings(
//     isVisible: true,
//     labelAlignment: ChartDataLabelAlignment.middle,
//     textStyle: TextStyle(fontSize: 20, color: Colors.black),
//     builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//     return Text(
//     timeFormat.format(timeFormat.parse(data.clockInTime)),
//     style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//     );
//     }
//
//     ),
//     ),
//     LineSeries<AttendanceRecord, String>(
//     dataSource: attendanceData,
//     xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//     yValueMapper: (data, _) {
//     // Parse clockOutTime string to DateTime
//     DateTime clockOut = timeFormat.parse(data.clockOutTime);
//     // Return rounded value for plotting
//     return double.parse((clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
//     },
//     name: 'Clock-Out',
//     color: Colors.red,
//     dataLabelSettings: DataLabelSettings(
//     isVisible: true,
//     labelAlignment: ChartDataLabelAlignment.middle,
//     textStyle: TextStyle(fontSize: 20, color: Colors.black),
//     builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//     return Text(
//     timeFormat.format(timeFormat.parse(data.clockOutTime)),
//     style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//     );
//     }
//
//     ),
//     ),
//     ],
//     ),
//     ),
//     );
//     }
//
//     Widget _buildDurationWorkedDistributionChartForEmail(List<AttendanceRecord> attendanceData) {
//     return Card(
//     elevation: 3,
//     child: Container(
//     height: 300,
//     padding: EdgeInsets.all(16.0),
//     child: SfCartesianChart(
//     // key: _durationWorkedDistributionChartKey,
//     title: ChartTitle(text: 'Distribution of Hours Worked (How Many Hours You Worked (For example, if you see a "2" on top of a bar between 8 and 9, it means you worked between 8 and 9 hours two times.)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//     primaryXAxis: NumericAxis(
//     labelStyle: TextStyle(fontSize: 20),
//     title: AxisTitle(text: 'Duration of Hours Worked (Grouped By Hours)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),) // Add X-axis title
//     ),
//     primaryYAxis: NumericAxis(
//     labelStyle: TextStyle(fontSize: 20), // Style for Y-axis labels
//     title: AxisTitle(text: 'Frequency',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//
//     ),
//     tooltipBehavior: TooltipBehavior(enable: true),
//     series: <HistogramSeries<AttendanceRecord, double>>[
//     HistogramSeries<AttendanceRecord, double>(
//     dataSource: attendanceData,
//     yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime,data.clockOutTime),// Calculate duration in hours
//     binInterval: 1,
//     color: Colors.purple,
//     // Add data label settings here
//     dataLabelSettings: DataLabelSettings(
//     isVisible: true,
//     // Customize appearance (optional):
//     textStyle: TextStyle(fontSize: 20, color: Colors.black,fontWeight: FontWeight.bold),
//     // labelAlignment: ChartDataLabelAlignment.top,
//     ),
//     ),
//     ],
//     ),
//     ),
//     );
//     }
//
//     Widget _buildAttendanceByLocationChartForEmail(List<AttendanceRecord> attendanceData){
//     List<LocationRecord> _locationData1 = _getLocationData(attendanceData);
//     return Card(
//     elevation: 3,
//     child: Container(
//     height: 300,
//     padding: EdgeInsets.all(16.0),
//     child: SfCircularChart(
//     //key: _attendanceByLocationChartKey,
//     title: ChartTitle(text: 'Where you Clocked In (Attendance by Location)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//
//     legend: Legend(isVisible: true,textStyle: TextStyle(fontSize: 20),), // Style for legend text),
//     series: <CircularSeries>[
//     PieSeries<LocationRecord, String>(
//     dataSource: _locationData1,
//     xValueMapper: (LocationRecord data, _) => data.location,
//     yValueMapper: (LocationRecord data, _) => data.attendanceCount,
//     dataLabelSettings: DataLabelSettings(
//     isVisible: true,
//     // labelAlignment: ChartDataLabelAlignment.middle,
//     textStyle: TextStyle(fontSize: 18, color: Colors.black,fontWeight: FontWeight.bold),
//
//     ),
//     ),
//     ],
//     ),
//     ),
//     );
//     }
//
//
//     Widget _buildEarlyLateClockInsChartForEmail(List<AttendanceRecord> attendanceData) {
//
//     // Define the time format for clock-in time
//     final timeFormat = DateFormat('hh:mm a'); // AM/PM format
//     // Calculate early/late minutes for each record
//     List<Map<String, dynamic>> chartData = attendanceData.map((record) {
//     int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
//     return {
//     'date': DateFormat('dd-MMM').format(record.date),
//     'earlyLateMinutes': earlyLateMinutes,
//     'clockInTime': timeFormat.format(timeFormat.parse(record.clockInTime)),
//     };
//     }).toList();
//
//     return Card(
//     elevation: 3,
//     child: Container(
//     height: 300,
//     padding: EdgeInsets.all(16.0),
//     child: SfCartesianChart(
//     // key: _earlyLateClockInsChartKey,
//     title: ChartTitle(text: 'Did You Clock In Early or Late? (Green = Early, Red = Late, 0 = On Time)',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//     primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 20),
//     title: AxisTitle(text: 'Days Of the Week',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),)
//     ),
//     primaryYAxis: NumericAxis(
//     title: AxisTitle(text: 'Number of minutes before ,on or after 8:00 AM',textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
//     // Center the Y-axis around zero
//     labelStyle: TextStyle(fontSize: 20),
//     minimum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b) < 0
//     ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b).toDouble()
//         : null,
//     maximum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b) > 0
//     ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b).toDouble()
//         : null,
//     ),
//     tooltipBehavior: TooltipBehavior(enable: true),
//     series: <CartesianSeries<Map<String, dynamic>, String>>[
//     ColumnSeries<Map<String, dynamic>, String>(
//     dataSource: chartData,
//     xValueMapper: (data, _) => data['date'] as String,
//     yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
//     name: 'Clock-In/Out',
//     pointColorMapper: (data, _) =>
//     (data['earlyLateMinutes'] as int) >= 0 ? Colors.red : Colors.green, // Green for positive, red for negative
//     dataLabelSettings: DataLabelSettings(
//     isVisible: true, // Make data labels visible
//     // You can further customize the appearance of data labels
//     // using properties like:
//     // textStyle: TextStyle(fontSize: 12, color: Colors.black),
//     // labelAlignment: ChartDataLabelAlignment.top,
//     // Custom data labels showing clock-in time and early/late minutes
//     builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
//     // Display clock-in time and early/late minutes in brackets
//     return Text(
//     '${data['clockInTime']} (${data['earlyLateMinutes']} mins)',
//     style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
//     );
//     },
//     textStyle: TextStyle(fontSize: 20, color: Colors.black,fontWeight: FontWeight.bold), // Adjust label text style
//
//     ),
//     ),
//     ],
//     ),
//     ),
//     );
//     }
//
//
//     final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//     Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
//     final records = <AttendanceRecord>[];
//     final firestore = FirebaseFirestore.instance;
//
//     try {
//     final staffSnapshot = await firestore.collection('Staff').get();
//
//     for (var staffDoc in staffSnapshot.docs) {
//     final userId = staffDoc.id;
//     //  final staffData = staffDoc.data(); // You don't need this line here anymore
//     //  final primaryFacility = staffData['location'] ?? '';
//
//     for (var date = startDate;
//     date.isBefore(endDate.add(const Duration(days: 1)));
//     date = date.add(const Duration(days: 1))) {
//     final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//     final recordSnapshot = await firestore
//         .collection('Staff')
//         .doc(userId)
//         .collection('Record')
//         .doc(formattedDate)
//         .get();
//
//     if (recordSnapshot.exists) {
//     final attendanceRecord = AttendanceRecord.fromFirestore(recordSnapshot);
//
//     // Fetch staff data and assign it to the AttendanceRecord
//     attendanceRecord.staffData = staffDoc.data() as Map<String, dynamic>?;
//
//     records.add(attendanceRecord);
//     }
//     }
//     }
//
//     print('Successfully fetched attendance records.');
//     } catch (e) {
//     print('Error fetching data: $e');
//     rethrow;
//     }
//
//     return records;
//     }
//
//
//
//
//
// // Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
//     //   final records = <AttendanceRecord>[];
//     //
//     //
//     //   try{
//     //     for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
//     //       final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//     //       print("formattedDate=== $formattedDate");
//     //
//     //       // Fetch the attendance record document for the user and date
//     //       final recordSnapshot = await _firestore
//     //           .collection('Staff')
//     //           .doc("0A0ySoctMZcmJVh5OaJ5uUTcn073")
//     //           .collection('Record')
//     //           .doc(formattedDate)
//     //           .get();
//     //
//     //       if (recordSnapshot.exists) {
//     //         records.add(AttendanceRecord.fromFirestore(recordSnapshot));
//     //       }
//     //     }
//     //   }catch(e){
//     //     print('Error fetching data: $e');
//     //     rethrow;
//     //   }
//     //   print("record====${records}");
//     //   return records;
//     // }
//
//
//
//     Future<String> imageToBase64(String imagePath) async {
//     final ByteData bytes = await rootBundle.load(imagePath);
//     final buffer = bytes.buffer;
//     return base64Encode(Uint8List.view(buffer));
//     }
//
//     Future<void> getRecordsForDateRange(DateTime startDate, DateTime endDate) async {
//     final firestore = FirebaseFirestore.instance;
//
//     try {
//     final staffSnapshot = await firestore.collection('Staff').get();
//     final locationSnapshot = await firestore.collection('Location').get();
//
//     // Assuming 'assets/caritas_logo.png' is the path to your image
//     String base64Image = await imageToBase64('assets/image/caritaslogo1.png');
//
//     // Map to store locations categorized by type (Facility, Hotel, etc.)
//     final locationTypeMap = <String, Map<String, String>>{};
//
//     // Iterate through each state document and its sub-collections
//     for (var stateDoc in locationSnapshot.docs) {
//     final stateName = stateDoc.id;
//     final subCollectionSnapshot = await firestore
//         .collection('Location')
//         .doc(stateName)
//         .collection(stateName) // Sub-collection with the same name as the state
//         .get();
//
//     for (var locationDoc in subCollectionSnapshot.docs) {
//     final locationName = locationDoc.id;
//     final locationData = locationDoc.data();
//     final category = locationData['category'] ?? ''; // Assuming category field exists
//     final locationName2 = locationData['LocationName'] ?? ''; // Assuming category field exists
//
//     if (!locationTypeMap.containsKey(category)) {
//     locationTypeMap[category] = {};
//     }
//     locationTypeMap[category]![locationName2] = 'Within CARITAS ${category}s';
//     }
//     }
//
//     // Now process the attendance records for each staff member
//     for (var staffDoc in staffSnapshot.docs) {
//     final userId = staffDoc.id;
//     final staffData = staffDoc.data();
//     final primaryFacility = staffData['location'] ?? '';
//
//     final userRecords = <AttendanceRecord>[];
//
//     for (var date = startDate;
//     date.isBefore(endDate.add(const Duration(days: 1)));
//     date = date.add(const Duration(days: 1))) {
//     final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
//     print("formattedDate == $formattedDate");
//     final recordSnapshot = await firestore
//         .collection('Staff')
//         .doc(userId)
//         .collection('Record')
//         .doc(formattedDate)
//         .get();
//
//     if (recordSnapshot.exists) {
//     userRecords.add(AttendanceRecord.fromFirestore(recordSnapshot));
//     }
//     }
//
//
//
//     // Location Summary Counts
//     int withinPrimaryFacilityCountClockIn = 0;
//     int withinOtherCaritasLocationsCountClockIn = 0;
//     int outsideCaritasLocationsCountClockIn = 0;
//
//     int withinPrimaryFacilityCountClockOut = 0;
//     int withinOtherCaritasLocationsCountClockOut = 0;
//     int outsideCaritasLocationsCountClockOut = 0;
//
//     for (var record in userRecords) {
//     final clockInLocation = record.clockInLocation;
//     final clockOutLocation = record.clockOutLocation;
//
//     // Clock In Location Check
// // Clock In Location Check
//     if (clockInLocation == primaryFacility) {
//     withinPrimaryFacilityCountClockIn++;
//     } else if (isWithinCaritasLocations(clockInLocation, locationTypeMap) && clockInLocation != primaryFacility) {
//     // Exclude primary facility from other CARITAS locations
//     withinOtherCaritasLocationsCountClockIn++;
//     } else {
//     outsideCaritasLocationsCountClockIn++;
//     }
//
//     // Clock Out Location Check
//     if (clockOutLocation == primaryFacility) {
//     withinPrimaryFacilityCountClockOut++;
//     } else if (isWithinCaritasLocations(clockOutLocation, locationTypeMap) && clockOutLocation != primaryFacility) {
//     // Exclude primary facility from other CARITAS locations
//     withinOtherCaritasLocationsCountClockOut++;
//     } else {
//     outsideCaritasLocationsCountClockOut++;
//     }
//     }
//
//
//
//     // Generate chart images (as Uint8List)
//     final chartImage1 = await _createChartImage5(
//     userRecords, _buildClockInOutTrendsChartForEmail);
//     final chartImage2 = await _createChartImage5(
//     userRecords, _buildDurationWorkedDistributionChartForEmail);
//     final chartImage3 = await _createChartImage5(
//     userRecords, _buildAttendanceByLocationChartForEmail);
//     final chartImage4 = await _createChartImage5(
//     userRecords, _buildEarlyLateClockInsChartForEmail);
//
//     // Upload chart images to Firebase Storage and get URLs
//     List<String?> chartImageUrls = await Future.wait([
//     _uploadImageToStorage(chartImage1, 'chart1_$userId.png'),
//     _uploadImageToStorage(chartImage2, 'chart2_$userId.png'),
//     _uploadImageToStorage(chartImage3, 'chart3_$userId.png'),
//     _uploadImageToStorage(chartImage4, 'chart4_$userId.png'),
//     ]);
//
//
//     // Send email if there are any records to send
//     if (userRecords.isNotEmpty) {
//     await _sendEmailWithRecords(
//     staffData,
//     userRecords,
//     DateFormat('dd-MMMM-yyyy').format(startDate),
//     DateFormat('dd-MMMM-yyyy').format(endDate),
//     withinPrimaryFacilityCountClockIn,
//     withinOtherCaritasLocationsCountClockIn,
//     outsideCaritasLocationsCountClockIn,
//     withinPrimaryFacilityCountClockOut,
//     withinOtherCaritasLocationsCountClockOut,
//     outsideCaritasLocationsCountClockOut,
//     base64Image,
//     chartImageUrls,
//
//     );
//     }
//     }
//
//     print('Successfully processed records and sent emails.');
//
//     } catch (e) {
//     print('Error fetching data or sending emails: $e');
//     rethrow;
//     }
//     }
//
//     Future<String?> _uploadImageToStorage2(String? base64ImageData, String imageName) async {
//     if (base64ImageData == null) return null;
//
//     try {
//     final decodedBytes = base64Decode(base64ImageData); // Decode base64 string to bytes
//     final storageRef = FirebaseStorage.instance.ref().child('images/$imageName');
//     final uploadTask = await storageRef.putData(decodedBytes);
//     return await uploadTask.ref.getDownloadURL();
//     } catch (e) {
//     print('Error uploading image: $e');
//     return null;
//     }
//     }
//
//
//
//     // Function to create chart image and return Uint8List
//     Future<Uint8List?> _createChartImage5(List<AttendanceRecord> attendanceData, Function chartBuilder) async {
//     final Completer<Uint8List?> completer = Completer<Uint8List?>();
//     final chartKey = GlobalKey();
//
//     final chartReadyCompleter = Completer<void>();
//
//     final chartWidget = StatefulBuilder(
//     builder: (context, setState) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (!chartReadyCompleter.isCompleted) {
//     chartReadyCompleter.complete();
//     }
//     });
//     return RepaintBoundary(
//     key: chartKey,
//     child: chartBuilder(attendanceData), // Use the provided chart builder
//     );
//     },
//     );
//
//     final overlayEntry = OverlayEntry(
//     builder: (context) => chartWidget,
//     );
//     Overlay.of(context).insert(overlayEntry);
//     await chartReadyCompleter.future;
//     await Future.delayed(Duration(milliseconds: 4000));
//
//     try {
//     RenderRepaintBoundary boundary = chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//     ui.Image image = await boundary.toImage(pixelRatio: 0.8); // Adjust pixelRatio as needed
//     ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//
//     if (byteData != null) {
//     completer.complete(byteData.buffer.asUint8List());
//     } else {
//     completer.complete(null);
//     }
//     } catch (e) {
//     print('Error creating chart image: $e');
//     completer.complete(null);
//     } finally {
//     overlayEntry.remove();
//     }
//
//     return completer.future;
//     }
//
// // Function to upload image to Firebase Storage
//     Future<String?> _uploadImageToStorage(
//     Uint8List? imageData, String imageName) async {
//     if (imageData == null) return null;
//
//     try {
//     final storageRef = FirebaseStorage.instance
//         .ref()
//         .child('chart_images/$imageName'); // Adjust storage path
//     final uploadTask = await storageRef.putData(imageData);
//     return await uploadTask.ref.getDownloadURL();
//     } catch (e) {
//     print('Error uploading image: $e');
//     return null;
//     }
//     }
//
//     bool isWithinCaritasLocations(String location, Map<String, Map<String, String>> locationTypeMap) {
//     for (var category in locationTypeMap.keys) {
//     if (locationTypeMap[category]!.containsKey(location)) {
//     return true;
//     }
//     }
//     return false;
//     }
//
//     Future<void> _sendEmailWithRecords(
//     Map<String, dynamic> staffData,
//     List<AttendanceRecord> records,
//     String startDate,
//     String endDate,
//     int withinPrimaryFacilityCountClockIn,
//     int withinOtherCaritasLocationsCountClockIn,
//     int outsideCaritasLocationsCountClockIn,
//     int withinPrimaryFacilityCountClockOut,
//     int withinOtherCaritasLocationsCountClockOut,
//     int outsideCaritasLocationsCountClockOut,
//     String base64Image, // Add this line
//     List<String?> chartImageUrls
//
//     ) async {
//     final firstName = staffData['firstName'] ?? '';
//     final lastName = staffData['lastName'] ?? '';
//     final email = staffData['emailAddress'] ?? '';
//     final primaryFacility = staffData['location'] ?? '';
//     final supervisorEmail = staffData['supervisorEmail'] ?? '';
//     final logoImageUrl = await _uploadImageToStorage2(base64Image, 'caritaslogo1.png');
//
//     //final subject = 'Monthly Attendance Summary for September 2024: $startDate to $endDate';
//     final subject = 'Weekly Attendance Records for the week: $startDate to $endDate';
//     int earlyClockInsCount = 0;
//     int totalClockIns = records.length;
//
//     final body = """
//   <!DOCTYPE html>
//   <html>
//   <head>
//     <meta charset="UTF-8">
//   </head>
//   <body>
//
//     <p>Dear $firstName $lastName,</p>
//     <br>
//
//     <p>Primary Facility/Office Location: $primaryFacility</p>
//     <br>
//
//     <h2>Weekly Attendance Summary:</h2>
//
//     <h3>1) Attendance Details:</h3>
//
//     <ul>
//       ${records.map((record) {
//     final date = record.date;
//     final clockInTime = record.clockInTime ?? '';
//     final clockOutTime = record.clockOutTime ?? '';
//     final clockInLocation = record.clockInLocation ?? '';
//     final clockOutLocation = record.clockOutLocation ?? '';
//     final comments = record.comments ?? '';
//     final durationWorked = record.durationWorked ?? '';
//
//     // Parse clock-in time from string to DateTime
//     DateTime? clockInDateTime;
//     if (clockInTime != null && clockInTime.isNotEmpty) {
//     try {
//     clockInDateTime = DateFormat("HH:mm").parse(clockInTime);
//     } catch (e) {
//     print("Error parsing clock-in time: $e");
//     }
//     }
//
//     // Check if clock-in time is before 8:00 AM
//     if (clockInDateTime != null && clockInDateTime.hour < 8) {
//     earlyClockInsCount++;
//     }
//
//     return "&nbsp;&nbsp;&nbsp;&nbsp;☐ ${DateFormat('dd-MMMM-yyyy').format(date)} (${DateFormat('EEEE').format(record.date)}): Clocked in at $clockInTime, Clocked out at $clockOutTime, Duration: $durationWorked, Comments: $comments, Clock In Location: $clockInLocation, Clock Out Location: $clockOutLocation";
//     }).join('<br><br>')}
//     </ul>
//     <br>
//         ${chartImageUrls[0] != null ? '<img src="${chartImageUrls[0]}" alt="Clock-In/Out Trends" style="max-width: 600px; height: auto;"><br>' : ''}
//         <br>
//     ${chartImageUrls[1] != null ? '<img src="${chartImageUrls[1]}" alt="Work Duration Distribution" style="max-width: 600px; height: auto;"><br>' : ''}
//     <br>
//
//
//
//     <h3>2) Location Summary:</h3>
//
//     <ul>
//       <li>Early Clock-ins (Number of Clock-Ins done on or before 8:00AM): $earlyClockInsCount/${totalClockIns} day(s) (${(earlyClockInsCount / totalClockIns * 100).toStringAsFixed(2)}%)</li></ul>
//       <br>
//       ${chartImageUrls[3] != null ? '<img src="${chartImageUrls[3]}" alt="Early/Late Clock-Ins" style="max-width: 600px; height: auto;"><br>' : ''}
//       <br><br>
//       <ul><li>Clock-Ins: Within Primary Facility: $withinPrimaryFacilityCountClockIn, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockIn, Outside CARITAS Locations: $outsideCaritasLocationsCountClockIn</li>
//       <li>Clock-Outs: Within Primary Facility: $withinPrimaryFacilityCountClockOut, Within Any other CARITAS Location: $withinOtherCaritasLocationsCountClockOut, Outside CARITAS Locations: $outsideCaritasLocationsCountClockOut</li></ul>
//       <br>
//       ${chartImageUrls[2] != null ? '<img src="${chartImageUrls[2]}" alt="Attendance By Location" style="max-width: 600px; height: auto;"><br>' : ''}
//
//
//
//
//     <p>For further details, kindly visit the dashboard at: <a href="https://lookerstudio.google.com/reporting/e021c456-efe7-43ae-86c9-ca25ebfbdd2f">https://lookerstudio.google.com/reporting/e021c456-efe7-43ae-86c9-ca25ebfbdd2f</a></p>
//     <br>
//
//     <p>Please note that if you have synced any attendance that is not reflected in this report or on the dashboard, kindly click on the sync icon on each of the Attendance to perform singular synchronization of the missing Attendance. Note that this is only available for Version 1.5 upward.</p>
//     <br>
//
//     <p style="color:black; font-size:15px; font-weight:bold;">Best Regards,</p>
//     <p style="color:black; font-size:16px; font-weight:bold;">VEGHER, Emmanuel.</p>
//     <p style="color:black; font-size:16px; font-weight:bold;">SENIOR Technical Specialist  - Health Informatics.</p>
//     <p style="color:red; font-size:16px; font-weight:bold;">Caritas Nigeria (CCFN)</p>
//
//     <p style="color:black;">Catholic Secretariat of Nigeria Building,<br>
//     Plot 459 Cadastral Zone B2, Durumi 1, Garki, Abuja<br>
//     Mobile: (Office) +234-8103465662, +234-9088988551<br>
//     Email: <a href="mailto:Evegher@ccfng.org">Evegher@ccfng.org</a> | Facebook: <a href="https://www.facebook.com/CaritasNigeria">www.facebook.com/CaritasNigeria</a><br>
//     Website: <a href="https://www.caritasnigeria.org">www.caritasnigeria.org</a> | Linkedin: <a href="https://www.linkedin.com/in/emmanuel-vegher-221718190/">www.linkedin.com/in/emmanuel-vegher-221718190/</a></p>
//
//      <br>
//
//     ${logoImageUrl != null ? '<img src="$logoImageUrl" alt="Caritas Nigeria Logo" style="max-width: 200px; height: auto;">' : ''}
//     <br>
//
//   </body>
//   </html>
// """;
//
//     try {
//     await sendEmail(email, subject, body, cc: supervisorEmail);
//     // await sendEmail(email, subject, body, cc: supervisorEmail, attachments: [
//     //   if (chartImagePath1 != null) File(chartImagePath1),
//     //   if (chartImagePath2 != null) File(chartImagePath2),
//     //   if (chartImagePath3 != null) File(chartImagePath3),
//     //   if (chartImagePath4 != null) File(chartImagePath4),
//     // ]);
//     print('Email sent successfully to $email (CC: $supervisorEmail)');
//     } catch (e) {
//     print('Error sending email: $e');
//     }
//     }
//
//
// // Modified sendEmail function to fit into the code structure
//     Future<void> sendEmail(String recipient, String subject, String body, {String? cc}) async {
//     final url = Uri.parse('$URL/send-email');
//     final response = await http.post(
//     url,
//     headers: {'Content-Type': 'application/json'},
//     body: jsonEncode({
//     'recipient': "vegher.emmanuel@gmail.com",
//     'subject': subject,
//     'body': body,
//     //'cc': "ieloka@ccfng.org",
//     }),
//     );
//
//     if (response.statusCode == 200) {
//     print('Email request successful');
//     } else {
//     throw Exception('Failed to send email: ${response.body}');
//     }
//     }
//
//
//     }
//
//
//
//
//     class LocationRecord {
//     final String location;
//     final int attendanceCount;
//
//     LocationRecord({required this.location, required this.attendanceCount});
//     }
//
//     class HeatmapData {
//     final int dayOfWeek;
//     final int weekNumber;
//     final double attendanceScore; // Assuming attendance score is a double
//
//     HeatmapData({
//     required this.dayOfWeek,
//     required this.weekNumber,
//     required this.attendanceScore,
//     });
//     }
//     headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'recipient': "vegher.emmanuel@gmail.com",
//         'subject': subject,
//         'body': body,
//         //'cc': "ieloka@ccfng.org",
//       }),
//     );
//
//     if (response.statusCode == 200) {
//       print('Email request successful');
//     } else {
//       throw Exception('Failed to send email: ${response.body}');
//     }
//   }
//
//
// }
//
//
//
//
// class LocationRecord {
//   final String location;
//   final int attendanceCount;
//
//   LocationRecord({required this.location, required this.attendanceCount});
// }
//
// class HeatmapData {
//   final int dayOfWeek;
//   final int weekNumber;
//   final double attendanceScore; // Assuming attendance score is a double
//
//   HeatmapData({
//     required this.dayOfWeek,
//     required this.weekNumber,
//     required this.attendanceScore,
//   });
// }