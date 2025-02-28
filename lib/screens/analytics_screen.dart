// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart'; // For charts
//
// import 'package:intl/intl.dart';
//
// import '../api/attendance_api.dart';
// import '../models/attendance_record.dart';
// import '../utils/date_helper.dart'; // For date formatting
// import 'dart:typed_data';
// import 'dart:ui' as ui;
//
// class AnalyticsScreen extends StatefulWidget {
//   @override
//   _AnalyticsScreenState createState() => _AnalyticsScreenState();
// }
//
// class _AnalyticsScreenState extends State<AnalyticsScreen> {
//   final AttendanceAPI _attendanceAPI = AttendanceAPI();
//   List<AttendanceRecord> _attendanceData = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   late GlobalKey<SfCartesianChartState> _cartesianChartKey;
//   List<LocationRecord> _locationData = []; // Initialize with an empty list
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchAttendanceData();
//     _cartesianChartKey = GlobalKey();
//   }
//
//   Future<void> _fetchAttendanceData() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       final specificDate = DateTime(2024, 9, 30);
//       final startDate = DateHelper.getStartDateOfWeek(specificDate);
//       _attendanceData = await _attendanceAPI.getWeeklyRecords('user_id', startDate);
//
//     } catch (error) {
//       _errorMessage = 'Error fetching data: ${error.toString()}';
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Attendance Analytics'),
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//           ? Center(child: Text(_errorMessage!))
//           : _buildAnalyticsDashboard(),
//     );
//   }
//
//   List<LocationRecord> _getLocationData() {
//     // Use a Map to store location counts
//     Map<String, int> locationCounts = {};
//
//     // Iterate through attendance data and count locations
//     for (var record in _attendanceData) {
//       final location = record.clockInLocation;
//       if (location != null) { // Ensure location is not null
//         if (locationCounts.containsKey(location)) {
//           locationCounts[location] = locationCounts[location]! + 1;
//         } else {
//           locationCounts[location] = 1;
//         }
//       }
//     }
//
//     // Convert the Map to a List of LocationRecord objects
//     List<LocationRecord> locationData = locationCounts.entries.map((entry) {
//       return LocationRecord(location: entry.key, attendanceCount: entry.value);
//     }).toList();
//
//     return locationData;
//   }
//
//
//   Widget _buildAnalyticsDashboard() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             _buildSummaryCard(),
//             TextButton(
//               child: const Text('Export as image'),
//               onPressed: () {
//                 _renderChartAsImage ();
//               },
//             ),
//             SizedBox(height: 20),
//             _buildClockInChart(),
//             SizedBox(height: 20),
//             _buildDurationWorkedChart(),
//             // ... add more analytics widgets
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSummaryCard() {
//     // ... (Calculate summary data from _attendanceData)
//     return Card(
//       elevation: 3,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Weekly Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             SizedBox(height: 10),
//             // ... (Display summary data using Text widgets)
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildClockInChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           key: _cartesianChartKey,
//           primaryXAxis: CategoryAxis(
//             labelStyle: TextStyle(fontSize: 10),
//           ),
//           title: ChartTitle(text: 'Clock-In Times'),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[ // Specify CartesianSeries type
//             ColumnSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('E').format(data.date),
//               yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime, data.clockOutTime),
//               name: 'Clock-In Time',
//               color: Colors.blueAccent,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDurationWorkedChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: _attendanceData.isEmpty // Check for empty data
//             ? Center(child: Text('No data available.'))
//             : SfCartesianChart(
//           primaryXAxis: CategoryAxis(
//             labelStyle: TextStyle(fontSize: 10),
//           ),
//           title: ChartTitle(text: 'Duration Worked (minutes)'),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             ColumnSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('E').format(data.date),
//               yValueMapper: (data, _) =>
//                   DateHelper.calculateDurationWorkedInMinutes(data.clockInTime, data.clockOutTime),
//               name: 'Duration Worked',
//               color: Colors.green,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildClockInOutTrendsChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Clock-In and Clock-Out Trends'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             LineSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime, data.clockOutTime),
//               name: 'Clock-In',
//               color: Colors.green,
//             ),
//             LineSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockOutTime, data.clockOutTime),
//               name: 'Clock-Out',
//               color: Colors.red,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
// /*  Widget _buildAttendanceComplianceChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Attendance Compliance'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             StackedColumnSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => data.compliant ? 1 : 0,
//               name: 'Compliant',
//               color: Colors.green,
//             ),
//             StackedColumnSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => data.compliant ? 0 : 1,
//               name: 'Non-Compliant',
//               color: Colors.red,
//             ),
//           ],
//         ),
//       ),
//     );
//   }*/
//
//   Widget _buildDurationWorkedDistributionChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Work Duration Distribution'),
//           primaryXAxis: NumericAxis(labelStyle: TextStyle(fontSize: 10)), // Use NumericAxis for duration bins
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <HistogramSeries<AttendanceRecord, double>>[
//             HistogramSeries<AttendanceRecord, double>(
//               dataSource: _attendanceData,
//               yValueMapper: (data, _) => double.parse(data.durationWorked ?? '0'), // Parse the work duration
//               binInterval: 1, // Define bin size, e.g., 1-hour intervals
//               color: Colors.purple,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildAttendanceByLocationChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCircularChart(
//           title: ChartTitle(text: 'Attendance by Location'),
//           legend: Legend(isVisible: true),
//           series: <CircularSeries>[
//             PieSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => data.location,
//               yValueMapper: (data, _) => data.attendanceCount,
//               dataLabelSettings: DataLabelSettings(isVisible: true),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEarlyLateClockInsChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Early Clock-Ins and Late Clock-Outs'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             ScatterSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => DateHelper.calculateEarlyLateTime(data.clockInTime),
//               markerSettings: MarkerSettings(isVisible: true),
//               name: 'Clock-In/Out',
//               color: Colors.orange,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAttendanceHeatmap() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Weekly Attendance Heatmap'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           primaryYAxis: NumericAxis(),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             HeatMapSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('EEEE').format(data.date),
//               yValueMapper: (data, _) => data.attendanceScore,
//               color: Colors.teal,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEarlyClockInsBarChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Early Clock-Ins Breakdown'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             BarSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => data.earlyClockInCount,
//               color: Colors.blue,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildDailyWorkingHoursComparisonChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCircularChart(
//           title: ChartTitle(text: 'Daily Working Hours Comparison'),
//           series: <CircularSeries>[
//             RadarSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
//               yValueMapper: (data, _) => double.parse(data.durationWorked ?? '0'),
//               name: 'Work Hours',
//               color: Colors.greenAccent,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildAttendanceAccuracyChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Attendance Accuracy'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             BoxPlotSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => data.date.toString(),
//               yValueMapper: (data, _) => double.parse(data.accuracy),
//               color: Colors.indigo,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDepartmentalAttendanceChart() {
//     return Card(
//       elevation: 3,
//       child: Container(
//         height: 300,
//         padding: EdgeInsets.all(16.0),
//         child: SfCartesianChart(
//           title: ChartTitle(text: 'Departmental Attendance'),
//           primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: 10)),
//           tooltipBehavior: TooltipBehavior(enable: true),
//           series: <CartesianSeries<AttendanceRecord, String>>[
//             BarSeries<AttendanceRecord, String>(
//               dataSource: _attendanceData,
//               xValueMapper: (data, _) => data.department,
//               yValueMapper: (data, _) => data.attendanceCount,
//               color: Colors.brown,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//
//
//
//
//
//
//   Future<void> _renderChartAsImage() async {
//     final ui.Image? data = await _cartesianChartKey.currentState!.toImage(pixelRatio : 3.0);
//     final ByteData? bytes = await data?.toByteData(format : ui.ImageByteFormat.png);
//     final Uint8List imageBytes = bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
//     await Navigator.of(context).push<dynamic>(
//       MaterialPageRoute<dynamic>(
//         builder: (BuildContext context) {
//           return Scaffold(
//               body:Image.memory(imageBytes)
//           );
//         },
//       ),
//     );
//   }
//
//
// }
//
// class LocationRecord {
//   final String location; // Assuming location is a String
//   final int attendanceCount;
//
//   LocationRecord({required this.location, required this.attendanceCount});
// }