
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

import 'package:intl/intl.dart';

class PendingTimesheetsScreen extends StatefulWidget {
  const PendingTimesheetsScreen({super.key});

  @override
  _PendingTimesheetsScreenState createState() => _PendingTimesheetsScreenState();
}

class _PendingTimesheetsScreenState extends State<PendingTimesheetsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Timesheets'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup("TimeSheets")
            .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
            .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending timesheets.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot doc = snapshot.data!.docs[index];
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                String staffName = data['staffName'] ?? 'N/A';
                String projectName = data['projectName'] ?? 'N/A';
                String date = data['date'] ?? 'N/A';

                String staffId = doc.reference.parent.parent!.id;

                return ListTile(
                  title: Text(staffName),
                  subtitle: Text('$projectName - $date'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TimesheetDetailsScreen(
                          timesheetData: data,
                          timesheetId: doc.id,
                          staffId: staffId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

class TimesheetDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> timesheetData;
  final String timesheetId;
  final String staffId;

  const TimesheetDetailsScreen({super.key, 
    required this.timesheetData,
    required this.timesheetId,
    required this.staffId,
  });

  // Helper function to generate the list of days from the 19th of the previous month to the 20th of the current month.
  List<DateTime> getDaysInRange(DateTime timesheetDate) {
    DateTime startDate = DateTime(timesheetDate.year, timesheetDate.month - 1, 19);
    DateTime endDate = DateTime(timesheetDate.year, timesheetDate.month, 20);

    List<DateTime> days = [];
    for (DateTime date = startDate; date.isBefore(endDate); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }
    return days;
  }

  // Retrieves hours for a specific date, project, and category.
  String getHoursForDate(DateTime date, String projectName, String category) {
    final entries = timesheetData['timesheetEntries'] as List?;
    if (entries != null) {
      for (final entry in entries) {
        final entryDate = DateTime.parse(entry['date']);
        if (entryDate.year == date.year &&
            entryDate.month == date.month &&
            entryDate.day == date.day &&
            entry['projectName'] == projectName &&
            entry['status'] == category) {
          return entry['noOfHours'].toString();
        }
      }
    }
    return "";
  }

  // Checks if a date falls on a weekend.
  bool isWeekend(DateTime date) => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  // Computes total hours worked for a specific category.
  double getCategoryHours(String category) {
    return (timesheetData['timesheetEntries'] as List?)
        ?.where((entry) => entry['status'] == category)
        .fold(0.0, (sum, entry) => sum! + entry['noOfHours']) ??
        0.0;
  }

  // Calculates the percentage of total hours for a specific category.
  double getCategoryPercentage(String category) {
    final grandTotal = calculateGrandTotalHours();
    if (grandTotal == 0) return 0;
    return (getCategoryHours(category) / grandTotal) * 100;
  }

  // Computes the total hours across all categories.
  double calculateGrandTotalHours() {
    return (timesheetData['timesheetEntries'] as List?)
        ?.fold<double>(0.0, (sum, entry) => sum + entry['noOfHours']) ??
        0.0;
  }

  // Calculates hours for a specific project.
  double calculateTotalHours(String projectName) {
    return (timesheetData['timesheetEntries'] as List?)
        ?.where((entry) => entry['status'] == projectName)
        .fold<double>(0, (sum, entry) => sum + entry['noOfHours']) ??
        0.0;
  }

  // Computes the percentage worked for a specific project.
  double calculatePercentageWorked(String projectName) {
    final grandTotal = calculateGrandTotalHours();
    if (grandTotal == 0) return 0;
    return (calculateTotalHours(projectName) / grandTotal) * 100;
  }

  // Creates the table header row.
  Widget buildTableHeader(List<DateTime> daysInRange) {
    return Row(
      children: [
        _buildTableCell('Project Name', Colors.blue.shade100, fontWeight: FontWeight.bold),
        ...daysInRange.map((date) => _buildTableCell(DateFormat('dd MMM').format(date),
            isWeekend(date) ? Colors.grey.shade300 : Colors.blue.shade100,
            fontWeight: FontWeight.bold)),
        _buildTableCell('Total Hours', Colors.blue.shade100, fontWeight: FontWeight.bold),
        _buildTableCell('Percentage', Colors.blue.shade100, fontWeight: FontWeight.bold),
      ],
    );
  }

  // Builds a row for a project with hours filled in for each day.
  Widget buildProjectRow(String projectName, List<DateTime> daysInRange) {
    final totalHours = calculateTotalHours(projectName);
    final percentageWorked = calculatePercentageWorked(projectName);
    return Row(
      children: [
        _buildTableCell(projectName, Colors.white),
        ...daysInRange.map((date) => _buildTableCell(getHoursForDate(date, projectName, projectName),
            isWeekend(date) ? Colors.grey.shade300 : Colors.white)),
        _buildTableCell('$totalHours hrs', Colors.white, color: Colors.green, fontWeight: FontWeight.bold),
        _buildTableCell('${percentageWorked.toStringAsFixed(2)}%', Colors.white, color: Colors.green, fontWeight: FontWeight.bold),
      ],
    );
  }

  // Helper function to build a table cell.
  Widget _buildTableCell(String text, Color? backgroundColor, {Color? color, FontWeight? fontWeight}) {
    return Container(
      width: 100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Text(text, style: TextStyle(color: color, fontWeight: fontWeight)),
    );
  }

  // Builds rows for each category with their hours and percentage.
  Widget buildCategoryRows(String projectName, List<DateTime> daysInRange) {
    final categories = [
      'Absent', 'Annual leave', 'Holiday', 'Other Leaves', 'Security Crisis',
      'Sick leave', 'Remote working', 'Sit at home', 'Trainings', 'Travel'
    ];
    return Column(
      children: categories.map((category) {
        final categoryHours = getCategoryHours(category);
        final categoryPercentage = getCategoryPercentage(category);

        return Row(
          children: [
            _buildTableCell(category, Colors.white, fontWeight: FontWeight.bold),
            ...daysInRange.map((date) => _buildTableCell(getHoursForDate(date, projectName, category),
                isWeekend(date) ? Colors.grey.shade300 : Colors.white)),
            _buildTableCell('${categoryHours.toStringAsFixed(2)} hrs', Colors.white, color: Colors.green, fontWeight: FontWeight.bold),
            _buildTableCell('${categoryPercentage.toStringAsFixed(2)}%', Colors.white, color: Colors.green, fontWeight: FontWeight.bold),
          ],
        );
      }).toList(),
    );
  }


  String _getDurationForDate(DateTime date, String? projectName, String category, List<Map<String, dynamic>> attendanceData) {
    double totalHoursForDate = 0;
    print("attendanceData === $attendanceData");

    for (var attendance in attendanceData) {
      try {
        // Access the 'date' key from the map.
        String dateString = attendance['date'] as String;  // Type cast to String
        print("dateString === $dateString");

        DateTime attendanceDate = DateFormat('yyyy-MM-dd').parse(dateString);

        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          if (category == projectName) {
            if (!attendance['offDay']) {  // Access 'offDay' from the map
              totalHoursForDate += attendance['noOfHours'] as double; // Access 'noOfHours'
            }

            // if (attendance['offDay'] == null ) {  // Access 'offDay' from the map
            //   totalHoursForDate += attendance['noOfHours'] as double; // Access 'noOfHours'
            // }
          } else {
            if (attendance['offDay'] as bool &&
                (attendance['durationWorked'] as String?)?.toLowerCase() == category.toLowerCase()) {
              totalHoursForDate += attendance['noOfHours'] as double;
            }
          }
        }
      } catch (e) {
        print("Error processing attendance data: $e"); // More general error message
      }
    }
    return "${totalHoursForDate.toStringAsFixed(2)} hrs";
  }

  List initializeDateRange(int month, int year) {
    DateTime selectedMonthDate = DateTime(year, month, 1);
    var startDate = DateTime(selectedMonthDate.year, selectedMonthDate.month - 1, 19); //Start from the 19th of previous month
    var endDate = DateTime(selectedMonthDate.year, selectedMonthDate.month, 20);    //End on the 20th of current month


    var daysInRange1 = [];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      daysInRange1.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return daysInRange1;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    DateTime timesheetDate;
    try {
      timesheetDate = dateFormat.parse(timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate = DateTime.now();
    }


    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final daysInRange = getDaysInRange(timesheetDate);
    final staffName = timesheetData['staffName'] ?? 'N/A';
    final projectName = timesheetData['projectName'] ?? 'N/A';
    final grandTotalHours = calculateGrandTotalHours();
    final staffSignature = timesheetData['staffSignature'] != null
        ? Uint8List.fromList(List<int>.from(timesheetData['staffSignature']))
        : null;
    final monthYear = DateFormat('MMMM, yyyy').format(timesheetDate1);
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange2 = initializeDateRange(int.parse(month),int.parse(year));




    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet Details'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Text(
                          'Month of Timesheet:',
                          style: TextStyle(fontWeight: FontWeight.bold,fontSize:12),
                        ),
                        const SizedBox(width: 10),

                        Text(
                          monthYear,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                      ],
                    ),
                  ),
                  const Divider(),
                  //  buildProjectRow(projectName, daysInRange),
                  Column(
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            width: 150, // Set a width for the "Project Name" header
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.blue.shade100,
                            child: const Text(
                              'Project Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...daysInRange2.map((date) {
                            return Container(
                              width: 100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: isWeekend(date) ? Colors.grey.shade300 : Colors.blue.shade100,
                              child: Text(
                                DateFormat('dd MMM').format(date),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          }),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.blue.shade100,
                            child: const Text(
                              'Total Hours',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.blue.shade100,
                            child: const Text(
                              'Percentage',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Container(
                            width: 150, // Keep the fixed width if you need it
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: Text(projectName),
                          ),
                          ...daysInRange2.map((date) {
                            bool weekend = isWeekend(date);
                            String hours = _getDurationForDate(date, projectName, projectName!,timesheetData['timesheetEntries'].cast<Map<String, dynamic>>() );
                            return Container(
                              width: 100, // Set a fixed width for each day
                              decoration: BoxDecoration(
                                color: weekend ? Colors.grey.shade300 : Colors.white,
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  weekend
                                      ? const SizedBox.shrink() // No hours on weekends
                                      : Text(
                                    hours, // Placeholder, replace with Isar data
                                    style: const TextStyle(color: Colors.blueAccent),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              'hrs',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              '%',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // "Out-of-office" Header Row
                      Row(
                        children: [
                          Container(
                            width: 150,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              'Out-of-office',
                              style: TextStyle(fontWeight: FontWeight.bold,fontSize:18),
                            ),
                          ),
                          ...List.generate(daysInRange2.length, (index) {
                            return Container(
                              width: 100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              child: const Text(
                                '', // Placeholder for out-of-office data, can be replaced later
                              ),
                            );
                          }),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              '', // Placeholder for total hours
                            ),
                          ),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              '', // Placeholder for percentage
                            ),
                          ),
                        ],
                      ),
                      // Rows for out-of-office categories
                      ...['Absent', 'Annual leave', 'Holiday', 'Other Leaves', 'Security Crisis', 'Sick leave', 'Remote working', 'Sit at home', 'Trainings', 'Travel'].map((category) {
                        // double outOfOfficeHours = calculateCategoryHours(category);
                        //double outOfOfficePercentage = calculateCategoryPercentage(category);
                        return Row(
                          children: [
                            Container(
                              width: 150,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              child: Text(
                                category,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...daysInRange2.map((date) {
                              bool weekend = isWeekend(date);
                              String offDayHours = _getDurationForDate(date, projectName, category,timesheetData['timesheetEntries'].cast<Map<String, dynamic>>() );


                              return Container(
                                width: 100, // Set a fixed width for each day
                                decoration: BoxDecoration(
                                  color: weekend ? Colors.grey.shade300 : Colors.white,
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    weekend
                                        ? const SizedBox.shrink() // No hours on weekends
                                        : Text(
                                      offDayHours, // Placeholder, replace with Isar data
                                      style: const TextStyle(color: Colors.blueAccent),
                                    ),
                                  ],
                                ),
                              );

                            }),
                            Container(
                              width: 100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              child: const Text(
                                //'${outOfOfficeHours.toStringAsFixed(2)} hrs',
                                'hrs',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              width: 100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              child: const Text(
                                //'${outOfOfficePercentage.toStringAsFixed(2)}%',
                                '%',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      }),
                      // // Attendance Rows
                      //
                      Row(
                        children: [
                          Container(
                            width: 150,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold,fontSize:20),
                            ),
                          ),
                          ...List.generate(daysInRange2.length, (index) {
                            return Container(
                              width: 100,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              child: const Text(
                                '', // Placeholder for out-of-office data, can be replaced later
                              ),
                            );
                          }),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              'hrs',
                              //'$totalGrandHours hrs',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8.0),
                            color: Colors.white,
                            child: const Text(
                              '%',

                              // '${grandPercentageWorked.toStringAsFixed(2)}%',

                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),



                    ],
                  ),
                  const Divider(),
                  // buildCategoryRows(projectName, daysInRange),
                  Row(
                    children: [
                      _buildTableCell('Grand Total', Colors.grey, fontWeight: FontWeight.bold),
                      ...List.generate(daysInRange.length, (_) => const SizedBox(width: 100)),
                      _buildTableCell('$grandTotalHours hrs', Colors.grey, fontWeight: FontWeight.bold),
                      _buildTableCell('100%', Colors.grey, fontWeight: FontWeight.bold),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Staff Signature:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (staffSignature != null)
                    Image.memory(staffSignature)
                  else
                    const Text('No signature available.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}