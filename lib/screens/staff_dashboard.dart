import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../api/attendance_api.dart';
import '../models/attendance_record.dart';
import '../utils/date_helper.dart';
import 'attendance_report.dart';
import 'clock_attendance_web.dart';
import 'components/clock_attendance.dart';

// void main() => runApp(UserDashboardApp());

class UserDashboardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: UserDashboardPage(),
    );
  }
}

class UserDashboardPage extends StatefulWidget {
  @override
  _UserDashboardPageState createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {

  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? formattedMonth;
  String _reportMessage = '';
  final AttendanceAPI _attendanceAPI = AttendanceAPI();
  List<AttendanceRecord> _attendanceData = [];
  List<LocationRecord> _locationData = [];

  bool _isLoading = true;
  String? _errorMessage;
  // Global Keys for charts
  final GlobalKey<SfCartesianChartState> _clockInOutTrendsChartKey = GlobalKey();
  final GlobalKey<SfCartesianChartState> _durationWorkedDistributionChartKey = GlobalKey();
  final GlobalKey<SfCircularChartState> _attendanceByLocationChartKey = GlobalKey();
  final GlobalKey<SfCartesianChartState> _earlyLateClockInsChartKey = GlobalKey();

  String _selectedDepartment = 'All Departments';
  String _selectedMonth = 'January';
  int _selectedYear = 2024;

  var _totalWorkHours = 23;
  var _minHoursWorked = 8;
  var _minClockInTime = "07:30 AM";
  var _maxHoursWorked = 12;
  var _maxClockOutTime = 8;
  var _averageHoursWorked = 5;

  List<Map<String, dynamic>> _roleAchievements = [
    {'role': 'Doctors', 'achievements': 15, 'kpi': 20, 'badge': 'Top Healer'},
    {'role': 'Pharmacists', 'achievements': 25, 'kpi': 30, 'badge': 'Efficient Dispenser'},
    {'role': 'Lab Technicians', 'achievements': 30, 'kpi': 40, 'badge': 'Fast Processor'},
  ];

  List<Map<String, dynamic>> _leaderboard = [
    {'name': 'John Doe', 'role': 'Doctor', 'points': 120},
    {'name': 'Jane Smith', 'role': 'Pharmacist', 'points': 110},
    {'name': 'Sam Wilson', 'role': 'Lab Technician', 'points': 105},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.white60,
      appBar: AppBar(
        title: Text('Facility Staff Workflow Platform',style: TextStyle(color: Colors.white), ),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // if (constraints.maxWidth > 800) buildSidebar(),
              Container(
                width:MediaQuery.of(context).size.width * 0.12,
                child:buildSidebar(),
              ),
              SizedBox(
                width:MediaQuery.of(context).size.width * 0.01,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child:SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child:Column(
                            children:[

                              // Row(
                              //   children:[
                              //     buildFilterBar(),
                              //     SizedBox(width:MediaQuery.of(context).size.width * 0.01,),
                              //     _buildDatePicker('Start Date', _startDate, (date) {
                              //       setState(() {
                              //         _startDate = date;
                              //       });
                              //     }),
                              //     SizedBox(
                              //       width:MediaQuery.of(context).size.width * 0.01,
                              //     ),
                              //     _buildDatePicker('End Date', _endDate, (date) {
                              //       setState(() {
                              //         _endDate = date;
                              //         formattedMonth = DateFormat('MMMM yyyy').format(_endDate); // Get month and year
                              //       });
                              //     }),
                              //
                              //     SizedBox(
                              //       width:MediaQuery.of(context).size.width * 0.01,
                              //     ),
                              //     ElevatedButton(
                              //       onPressed: _fetchAttendanceData,
                              //       child: Text('Generate Analytics'),
                              //     ),
                              //   ]
                              // ),
                              Container(
                                height: MediaQuery.of(context).size.height * 0.10,
                                width: MediaQuery.of(context).size.width * 0.86, // Full width of the screen
                                child: Card(
                                  margin: EdgeInsets.zero, // Remove any default padding
                                  elevation: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space evenly
                                      children: [
                                        buildFilterBar(),
                                        SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                                        _buildDatePicker('Start Date', _startDate, (date) {
                                          setState(() {
                                            _startDate = date;
                                          });
                                        }),
                                        SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                                        _buildDatePicker('End Date', _endDate, (date) {
                                          setState(() {
                                            _endDate = date;
                                            formattedMonth = DateFormat('MMMM yyyy').format(_endDate); // Get month and year
                                          });
                                        }),
                                        SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                                        ElevatedButton(
                                          onPressed: _fetchAttendanceData,
                                          child: Text('Generate Analytics'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),


                              // SizedBox(
                              //   height:MediaQuery.of(context).size.height * 0.10,
                              //   width:MediaQuery.of(context).size.width * 1,
                              //   child:buildSummaryCards1(),
                              // ),


                              SizedBox(
                                height:MediaQuery.of(context).size.height * 0.005,
                              ),
                              // Divider(),
                              // Divider(),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:CrossAxisAlignment.start,
                                  children:[


                                    Container(
                                      width:MediaQuery.of(context).size.width * 0.41,
                                      height:MediaQuery.of(context).size.height * 0.78,
                                      child: SingleChildScrollView(child:
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [


                                          //  buildAttendanceStatusChart(),

                                          _isLoading
                                              ? _buildEmptyCard()
                                              : _errorMessage != null
                                              ? Center(child: Text(_errorMessage!))
                                              : _buildClockInOutTrendsChartForEmail(_attendanceData),

                                          SizedBox(height:MediaQuery.of(context).size.height * 0.01,),

                                          _isLoading
                                              ? _buildEmptyCard()
                                              : _errorMessage != null
                                              ? Center(child: Text(_errorMessage!))
                                              : _buildEarlyLateClockInsChartForEmail(_attendanceData),
                                          //  _buildSummaryCard(),



                                        ],
                                      ),),
                                    ),
                                    SizedBox(
                                      width:MediaQuery.of(context).size.width * 0.01,
                                    ),


                                    Container(
                                      width:MediaQuery.of(context).size.width * 0.15,
                                      height:MediaQuery.of(context).size.height * 0.78,
                                      child:SingleChildScrollView(child:
                                      Column(


                                          children:[
                                            buildSummaryCards(),
                                          ]
                                      ),),
                                    ),
                                    SizedBox(
                                      width:MediaQuery.of(context).size.width * 0.01,
                                    ),

                                    Container(
                                      width:MediaQuery.of(context).size.width * 0.25,
                                      //color: Colors.white,
                                      child:Column(
                                          children:[
                                            buildAchievementsSection(),
                                            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                                            buildLeaderboard(),

                                          ]
                                      ),
                                    ),

                                  ]

                              ),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment:CrossAxisAlignment.start,
                                  children:[

                                    Container(
                                      width:MediaQuery.of(context).size.width * 0.41,
                                      child:_isLoading
                                          ? _buildEmptyCard()
                                          : _errorMessage != null
                                          ? Center(child: Text(_errorMessage!))
                                          : _buildAttendanceByLocationChartForEmail(_attendanceData),
                                    ),
                                    SizedBox(height:MediaQuery.of(context).size.height * 0.01,),

                                    Container(
                                      width:MediaQuery.of(context).size.width * 0.41,
                                      child:_isLoading
                                          ? _buildEmptyCard()
                                          : _errorMessage != null
                                          ? Center(child: Text(_errorMessage!))
                                          : _buildDurationWorkedDistributionChartForEmail(_attendanceData),
                                    ),


                                  ]
                              ),
                            ]
                        ),
                      )


                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildSidebar() {
    return Container(
      width: 250,
      color: Colors.blueGrey[800],
      child: Column(
        children: [
          DrawerHeader(
            child: Text('Dashboard Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          buildSidebarItem(Icons.home, 'Home'),
          buildSidebarItemAttendance(Icons.lock_clock, 'Attendance'),
          buildSidebarItem(Icons.person, 'User Profile'),
          buildSidebarItem(Icons.settings, 'Settings'),
          buildSidebarItem(Icons.exit_to_app, 'Logout'),
          buildSidebarItem(Icons.star, 'Rewards'),
          buildSidebarItem1(Icons.star, 'DashBoard Report'),
        ],
      ),
    );
  }

  Widget buildSidebarItemAttendance(IconData icon, String title) {
    // Create instances of FirestoreService and ClockAttendanceWebController
    final firestoreService = FirestoreService();
    final clockAttendanceWebController = ClockAttendanceWebController(firestoreService);

    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClockAttendanceWeb(
              firestoreService: firestoreService, // Pass FirestoreService
              controller: clockAttendanceWebController, // Pass ClockAttendanceWebController
            ),
          ),
        );
      },
    );
  }

  Widget buildSidebarItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {},
    );
  }

  Widget buildSidebarItem1(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AttendanceReportScreen()),
        );
      },
    );
  }

  Widget buildFilterBar() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _selectedDepartment,
          items: ['All Departments', 'Doctors', 'Pharmacists', 'Lab Technicians', 'Tracking Staff']
              .map((department) => DropdownMenuItem(value: department, child: Text(department)))
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedDepartment = newValue!;
            });
          },
        ),
        SizedBox(width: 20),
        DropdownButton<String>(
          value: _selectedMonth,
          items: ['January', 'February', 'March', 'April'].map((String month) {
            return DropdownMenuItem(
              value: month,
              child: Text(month),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedMonth = newValue!;
            });
          },
        ),
        SizedBox(width: 10),
        DropdownButton<int>(
          value: _selectedYear,
          items: List.generate(5, (index) => DateTime.now().year - index)
              .map((int year) => DropdownMenuItem(value: year, child: Text(year.toString())))
              .toList(),
          onChanged: (int? newValue) {
            setState(() {
              _selectedYear = newValue!;
            });
          },
        ),
      ],
    );
  }

  Widget buildSummaryCards() {
    return Column(
      // spacing: 16.0,
      // runSpacing: 16.0,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        //SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        buildSummaryCard('Total Hours Worked', _totalWorkHours, Colors.blue),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),

        buildSummaryCard('Total Hours Worked (Lowest)', _minHoursWorked, Colors.purple),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        buildSummaryCard('Total Hours Worked (Highest)', _maxHoursWorked, Colors.purple),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        buildSummaryCard('Average Hours Worked', _averageHoursWorked, Colors.purple),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),

        //buildSummaryCard('Absent', _totalWorkHours, Colors.blue),
        //SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        //buildSummaryCard('Present', _minClockInTime, Colors.green),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        buildSummaryCard('No of Holidays Filled', _minHoursWorked, Colors.purple),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        buildSummaryCard('No of Annual Leave taken', _maxHoursWorked, Colors.purple),
        // SizedBox(height: MediaQuery.of(context).size.height * 0.02,),
        // buildSummaryCard('Other Leaves', _averageHoursWorked, Colors.purple),


      ],
    );
  }

  // Widget buildSummaryCards1() {
  //   return Wrap(
  //     spacing: MediaQuery.of(context).size.width * 0.10,
  //     runSpacing: MediaQuery.of(context).size.width * 0.10,
  //     children: [
  //       buildSummaryCard('Absent', _totalWorkHours, Colors.blue),
  //       buildSummaryCard('Present', _minClockInTime, Colors.green),
  //    //   buildSummaryCard('Lowest Clock-In Time', _minClockInTime, Colors.green),
  //    //   buildSummaryCard('Highest Clock-Out Time', _maxClockOutTime, Colors.orange),
  //       buildSummaryCard('Holiday', _minHoursWorked, Colors.purple),
  //       buildSummaryCard('Annual Leave', _maxHoursWorked, Colors.purple),
  //       buildSummaryCard('Other Leaves', _averageHoursWorked, Colors.purple),
  //
  //
  //     ],
  //   );
  // }

  Widget buildSummaryCards1() {
    return Row(
      // spacing: MediaQuery.of(context).size.width * 0.10,
      //runSpacing: MediaQuery.of(context).size.width * 0.10,
      children: [
        buildSummaryCard('Total Hours Worked', _totalWorkHours, Colors.blue),
        //     buildSummaryCard('Total Hours Worked (Lowest)', _minHoursWorked, Colors.purple),
        //    buildSummaryCard('Total Hours Worked (Highest)', _maxHoursWorked, Colors.purple),
        buildSummaryCard('Average Hours Worked', _averageHoursWorked, Colors.purple),
        buildSummaryCard('Absent', _totalWorkHours, Colors.blue),
        buildSummaryCard('Present', _minClockInTime, Colors.green),
        buildSummaryCard('Holiday', _minHoursWorked, Colors.purple),
        buildSummaryCard('Annual Leave', _maxHoursWorked, Colors.purple),
        //   buildSummaryCard('Other Leaves', _averageHoursWorked, Colors.purple),


      ],
    );
  }

  Widget buildSummaryCard(String title, var count, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.085,  // Fixed width for the card
        height: MediaQuery.of(context).size.height * 0.10,  // Fixed height for the card
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, color: Colors.grey[700]),
                overflow: TextOverflow.visible,  // Allow wrapping if text is too long
                softWrap: true,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.width * 0.008),
            Text(
              '$count',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, color: color),
              overflow: TextOverflow.ellipsis,  // Use ellipsis if the count text is too long
            ),
          ],
        ),
      ),
    );
  }


  Widget buildAttendanceStatusChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Attendance Status - Last 7 Days',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<AttendanceData, String>(
                    dataSource: _createSampleData(),
                    xValueMapper: (AttendanceData data, _) => data.day,
                    yValueMapper: (AttendanceData data, _) => data.onTime,
                    name: 'On-time',
                    color: Colors.blue,
                  ),
                  ColumnSeries<AttendanceData, String>(
                    dataSource: _createSampleData(),
                    xValueMapper: (AttendanceData data, _) => data.day,
                    yValueMapper: (AttendanceData data, _) => data.late,
                    name: 'Late',
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAchievementsSection() {
    return Card(

      //height: MediaQuery.of(context).size.height * 0.35,
      // color:Colors.grey[400],
      color:Colors.white,
      child:
      Container(
        // color:Colors.white,
        height: MediaQuery.of(context).size.height * 0.35,
        child:Padding(padding: EdgeInsets.all(10),
          child:
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role-Based Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ..._roleAchievements.map((achievement) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Text(achievement['badge'][0]),
                    ),
                    title: Text(achievement['role']),
                    subtitle: Text('Achievements: ${achievement['achievements']}/${achievement['kpi']}'),
                    trailing: Text(achievement['badge']),
                  ),
                );
              }).toList(),
            ],
          ),),
      ),
    );
  }

  Widget buildLeaderboard() {
    return Card(

      //height: MediaQuery.of(context).size.height * 0.35,
      color:Colors.grey[400],
      child:
      Container(
        // color:Colors.white,
        height: MediaQuery.of(context).size.height * 0.35,
        child:Padding(padding: EdgeInsets.all(10),
          child:
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ..._leaderboard.map((leader) {
                return ListTile(
                  leading: CircleAvatar(
                    //backgroundImage: NetworkImage('https://via.placeholder.com/50'),
                  ),
                  title: Text(leader['name']),
                  subtitle: Text('${leader['role']} - ${leader['points']} pts'),
                );
              }).toList(),
            ],
          ),),
      ),
    );
  }


  // Function to extract location data from attendance records
  List<LocationRecord> _getLocationData(List<AttendanceRecord> attendanceData) {
    Map<String, int> locationCounts = {};
    for (var record in attendanceData) {
      final location = record.clockInLocation;
      if (location != null) {
        locationCounts.update(location, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return locationCounts.entries
        .map((entry) => LocationRecord(location: entry.key, attendanceCount: entry.value))
        .toList();
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            // Example Summary Data (Replace with your logic)
            Text('Total Hours Worked: ${_calculateTotalHoursWorked()}'),
            Text('Average Clock-In Time: ${_calculateAverageClockInTime()}'),
            // Add more summary data as needed...
          ],
        ),
      ),
    );
  }

  // Example summary calculation functions (Replace with your logic)
  String _calculateTotalHoursWorked() {
    // Calculate total hours worked from _attendanceData
    // Example implementation (replace with your actual calculation)
    double totalHours = 0;
    for (var record in _attendanceData) {
      totalHours += DateHelper.calculateHoursWorked(record.clockInTime, record.clockOutTime);
    }
    return totalHours.toStringAsFixed(2);
  }

  Future<void> _generateReport() async {
    setState(() {
      _reportMessage = 'Generating report...';

    });

    try {
      final startDate = _startDate;
      final endDate = _endDate;

      // Assuming your API has a method to fetch and send the report
      await getRecordsForDateRange(startDate, endDate);

      setState(() {
        _reportMessage = 'Report generation completed. Emails sent!';
      });
    } catch (error) {
      print('Error generating report: $error');
      setState(() {
        _reportMessage = 'Error generating report: $error';
      });
    }

  }

  Widget _buildAnalyticsDashboard() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(),

            SizedBox(height: 20),

            _buildClockInOutTrendsChartForEmail(_attendanceData),
            SizedBox(height: 20),
            _buildDurationWorkedDistributionChartForEmail(_attendanceData),
            SizedBox(height: 20),
            _buildAttendanceByLocationChartForEmail(_attendanceData),
            SizedBox(height: 20),
            _buildEarlyLateClockInsChartForEmail(_attendanceData),
            SizedBox(height: 30),




          ],
        ),
      ),
    );
  }

  Future<void> getRecordsForDateRange(DateTime startDate, DateTime endDate) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final staffSnapshot = await firestore.collection('Staff').get();
      final locationSnapshot = await firestore.collection('Location').get();


      // Map to store locations categorized by type (Facility, Hotel, etc.)
      final locationTypeMap = <String, Map<String, String>>{};

      // Iterate through each state document and its sub-collections
      for (var stateDoc in locationSnapshot.docs) {
        final stateName = stateDoc.id;
        final subCollectionSnapshot = await firestore
            .collection('Location')
            .doc(stateName)
            .collection(stateName) // Sub-collection with the same name as the state
            .get();

        for (var locationDoc in subCollectionSnapshot.docs) {
          final locationName = locationDoc.id;
          final locationData = locationDoc.data();
          final category = locationData['category'] ?? ''; // Assuming category field exists
          final locationName2 = locationData['LocationName'] ?? ''; // Assuming category field exists

          if (!locationTypeMap.containsKey(category)) {
            locationTypeMap[category] = {};
          }
          locationTypeMap[category]![locationName2] = 'Within CARITAS ${category}s';
        }
      }

      // Now process the attendance records for each staff member
      for (var staffDoc in staffSnapshot.docs) {
        final userId = staffDoc.id;
        final staffData = staffDoc.data();
        final primaryFacility = staffData['location'] ?? '';

        final userRecords = <AttendanceRecord>[];

        for (var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
          final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
          print("formattedDate == $formattedDate");
          final recordSnapshot = await firestore
              .collection('Staff')
              .doc(userId)
              .collection('Record')
              .doc(formattedDate)
              .get();

          if (recordSnapshot.exists) {
            userRecords.add(AttendanceRecord.fromFirestore(recordSnapshot));
          }
        }



        for (var record in userRecords) {
          final clockInLocation = record.clockInLocation;
          final clockOutLocation = record.clockOutLocation;

        }


      }

      print('Successfully processed records and sent emails.');

    } catch (e) {
      print('Error fetching data or sending emails: $e');
      rethrow;
    }
  }

  Widget _buildDatePicker(
      String label, DateTime initialDate, Function(DateTime) onDateSelected) {
    return Row(
      children: [
        Text('$label: '),
        TextButton(
          onPressed: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (selectedDate != null) {
              onDateSelected(selectedDate);
            }
          },
          child: Text(DateFormat('dd-MM-yyyy').format(initialDate)),
        ),
      ],
    );
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _attendanceData =
      await getRecordsForDateRangeForChart(_startDate, _endDate);
      _locationData = _getLocationData(_attendanceData);
      print("_attendanceData ==== $_attendanceData");
      print("_locationData ==== $_locationData");
    } catch (error) {
      _errorMessage = 'Error fetching data: ${error.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  String _calculateAverageClockInTime() {
    // Define the time format (assuming HH:mm)
    final timeFormat = DateFormat('HH:mm');

    // Calculate average clock-in time from _attendanceData
    if (_attendanceData.isEmpty) {
      return 'N/A';
    }

    double totalMinutes = 0;
    for (var record in _attendanceData) {
      // Parse the clockInTime string to DateTime
      DateTime clockInTime = timeFormat.parse(record.clockInTime);

      // Add the time in minutes
      totalMinutes += clockInTime.hour * 60 + clockInTime.minute;
    }

    int averageMinutes = totalMinutes ~/ _attendanceData.length;
    int averageHour = averageMinutes ~/ 60;
    int averageMinute = averageMinutes % 60;

    // Return the formatted average time as HH:mm
    return '$averageHour:${averageMinute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.30,
              width:MediaQuery.of(context).size.width * 0.40,
              child: Column(
                  children:[
                    Text(
                      'Please Wait...',
                      style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
                    ),
                  ]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInOutTrendsChartForEmail(List<AttendanceRecord> attendanceData) {
    // Define the time format (assuming it's in hh:mm a format)
    final timeFormat = DateFormat('hh:mm a'); // AM/PM format
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Clock-In and Clock-Out Trends',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.30,
              width:MediaQuery.of(context).size.width * 0.40,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                    labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007),
                    title: AxisTitle(text: 'Days of the Week',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),) // Add X-axis title
                ),
                primaryYAxis: NumericAxis(
                    labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007), // Style for Y-axis labels
                    title: AxisTitle(text: 'Time of the Day',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),)

                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'Clock-In: point.yClockIn\nClock-Out: point.yClockOut',
                ),
                series: <CartesianSeries<AttendanceRecord, String>>[
                  LineSeries<AttendanceRecord, String>(
                    dataSource: attendanceData,
                    xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
                    yValueMapper: (data, _) {
                      // Parse clockInTime string to DateTime
                      DateTime clockIn = timeFormat.parse(data.clockInTime);
                      // Return rounded value for plotting
                      return double.parse((clockIn.hour + (clockIn.minute / 60)).toStringAsFixed(1));
                    },
                    name: 'Clock-In',
                    color: Colors.green,
                    dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.middle,
                        textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007, color: Colors.black),
                        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                          return Text(
                            timeFormat.format(timeFormat.parse(data.clockInTime)),
                            style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007,fontWeight: FontWeight.bold),
                          );
                        }

                    ),
                  ),
                  LineSeries<AttendanceRecord, String>(
                    dataSource: attendanceData,
                    xValueMapper: (data, _) => DateFormat('dd-MMM').format(data.date),
                    yValueMapper: (data, _) {
                      // Parse clockOutTime string to DateTime
                      DateTime clockOut = timeFormat.parse(data.clockOutTime);
                      // Return rounded value for plotting
                      return double.parse((clockOut.hour + (clockOut.minute / 60)).toStringAsFixed(1));
                    },
                    name: 'Clock-Out',
                    color: Colors.red,
                    dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.middle,
                        textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007, color: Colors.black),
                        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                          return Text(
                            timeFormat.format(timeFormat.parse(data.clockOutTime)),
                            style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007,fontWeight: FontWeight.bold),
                          );
                        }

                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationWorkedDistributionChartForEmail(List<AttendanceRecord> attendanceData) {

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Distribution of Hours Worked',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.30,
              width:MediaQuery.of(context).size.width * 0.40,
              child: SfCartesianChart(
                // key: _durationWorkedDistributionChartKey,
                primaryXAxis: NumericAxis(
                    labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007),
                    title: AxisTitle(text: 'Duration of Hours Worked (Grouped By Hours)',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),) // Add X-axis title
                ),
                primaryYAxis: NumericAxis(
                    labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007), // Style for Y-axis labels
                    title: AxisTitle(text: 'Frequency',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),)

                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <HistogramSeries<AttendanceRecord, double>>[
                  HistogramSeries<AttendanceRecord, double>(
                    dataSource: attendanceData,
                    yValueMapper: (data, _) => DateHelper.calculateHoursWorked(data.clockInTime,data.clockOutTime),// Calculate duration in hours
                    binInterval: 1,
                    color: Colors.purple,
                    // Add data label settings here
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      // Customize appearance (optional):
                      textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007, color: Colors.black,fontWeight: FontWeight.bold),
                      // labelAlignment: ChartDataLabelAlignment.top,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceByLocationChartForEmail(List<AttendanceRecord> attendanceData) {
    List<LocationRecord> _locationData1 = _getLocationData(attendanceData);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Attendance by Location',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.30,
              width:MediaQuery.of(context).size.width * 0.40,
              child: SfCircularChart(
                //key: _attendanceByLocationChartKey,
                //title: ChartTitle(text: 'Attendance by Location',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),),

                legend: Legend(isVisible: true,textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007),), // Style for legend text),
                series: <CircularSeries>[
                  PieSeries<LocationRecord, String>(
                    dataSource: _locationData1,
                    xValueMapper: (LocationRecord data, _) => data.location,
                    yValueMapper: (LocationRecord data, _) => data.attendanceCount,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      // labelAlignment: ChartDataLabelAlignment.middle,
                      textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007, color: Colors.black,fontWeight: FontWeight.bold),

                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyLateClockInsChartForEmail(List<AttendanceRecord> attendanceData) {
    // Define the time format for clock-in time
    final timeFormat = DateFormat('hh:mm a'); // AM/PM format
    // Calculate early/late minutes for each record
    List<Map<String, dynamic>> chartData = attendanceData.map((record) {
      int earlyLateMinutes = DateHelper.calculateEarlyLateTime(record.clockInTime);
      return {
        'date': DateFormat('dd-MMM').format(record.date),
        'earlyLateMinutes': earlyLateMinutes,
        'clockInTime': timeFormat.format(timeFormat.parse(record.clockInTime)),
      };
    }).toList();


    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Did You Clock In Early or Late? (Green = Early, Red = Late, 0 = On Time)',
              style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.01, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3257,
              width:MediaQuery.of(context).size.width * 0.40,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007),
                    title: AxisTitle(text: 'Days Of the Week',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),)
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Number of minutes before ,on or after 8:00 AM',textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.008, fontWeight: FontWeight.bold),),
                  // Center the Y-axis around zero
                  labelStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007),
                  minimum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b) < 0
                      ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a < b ? a : b).toDouble()
                      : null,
                  maximum: chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b) > 0
                      ? chartData.map((data) => data['earlyLateMinutes'] as int).reduce((a, b) => a > b ? a : b).toDouble()
                      : null,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<Map<String, dynamic>, String>>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: chartData,
                    xValueMapper: (data, _) => data['date'] as String,
                    yValueMapper: (data, _) => data['earlyLateMinutes'] as int,
                    name: 'Clock-In/Out',
                    pointColorMapper: (data, _) =>
                    (data['earlyLateMinutes'] as int) >= 0 ? Colors.red : Colors.green, // Green for positive, red for negative
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true, // Make data labels visible
                      // You can further customize the appearance of data labels
                      // using properties like:
                      // textStyle: TextStyle(fontSize: 12, color: Colors.black),
                      // labelAlignment: ChartDataLabelAlignment.top,
                      // Custom data labels showing clock-in time and early/late minutes
                      builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                        // Display clock-in time and early/late minutes in brackets
                        return Text(
                          '${data['clockInTime']} (${data['earlyLateMinutes']} mins)',
                          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007,fontWeight: FontWeight.bold),
                        );
                      },
                      textStyle: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.007, color: Colors.black,fontWeight: FontWeight.bold), // Adjust label text style

                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }




  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<List<AttendanceRecord>> getRecordsForDateRangeForChart(DateTime startDate, DateTime endDate) async {
    final records = <AttendanceRecord>[];


    try{
      for (var date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
        final formattedDate = DateFormat('dd-MMMM-yyyy').format(date);
        print("formattedDate=== $formattedDate");

        // Fetch the attendance record document for the user and date
        final recordSnapshot = await _firestore
            .collection('Staff')
            .doc("0A0ySoctMZcmJVh5OaJ5uUTcn073")
            .collection('Record')
            .doc(formattedDate)
            .get();

        if (recordSnapshot.exists) {
          records.add(AttendanceRecord.fromFirestore(recordSnapshot));
        }
      }
    }catch(e){
      print('Error fetching data: $e');
      rethrow;
    }
    print("record====${records}");
    return records;
  }



  List<AttendanceData> _createSampleData() {
    return [
      AttendanceData('Mon', 85, 30),
      AttendanceData('Tue', 75, 20),
      AttendanceData('Wed', 90, 35),
      AttendanceData('Thu', 100, 25),
      AttendanceData('Fri', 80, 15),
      AttendanceData('Sat', 65, 40),
      AttendanceData('Sun', 95, 10),
    ];
  }
}

class AttendanceData {
  final String day;
  final int onTime;
  final int late;

  AttendanceData(this.day, this.onTime, this.late);
}