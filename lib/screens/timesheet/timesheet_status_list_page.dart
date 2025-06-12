import 'dart:io';

import 'package:attendanceappmailtool/screens/timesheet/pending_timesheet_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw; // Changed import prefix to pw for clarity
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle; // Import for rootBundle


class TimesheetStatusListPage extends StatefulWidget {
  final List<Map<String, dynamic>> timesheetDataList; // Receive timesheet data list
  const TimesheetStatusListPage({super.key, this.timesheetDataList = const []}); // Initialize with empty list by default


  @override
  TimesheetStatusListPageState createState() => TimesheetStatusListPageState();
}

class TimesheetStatusListPageState extends State<TimesheetStatusListPage> {
  List<Map<String, dynamic>> timesheets = [];
  bool isLoading = true;
  List<String> selectedTimesheetPaths = [];
  String? _currentUserState;
  String? _currentUserLocation;
  String? _timesheetCollectionName;
  bool _includeTaskSummary = false; // New state for task summary checkbox
  bool _isPDFLoading = false; // loading state for PDF generation

  @override
  void initState() {
    super.initState();
    //  _loadCurrentUserStateAndFetchTimesheets();
    _initializeTimesheets();
  }

  Future<void> _initializeTimesheets() async {
    await _loadCurrentUserBioData(); // Still load bio data for consistency if needed in this page
    _loadInitialTimesheets(); // Load timesheets from passed data
  }

  Future<void> _loadCurrentUserStateAndFetchTimesheets() async {
    await _loadCurrentUserBioData();
    await _fetchTimesheets();
  }


  Future<void> _loadCurrentUserBioData() async {
    try {
      final userUUID = FirebaseAuth.instance.currentUser?.uid;
      if (userUUID == null) {
        print("No user logged in.");
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> bioDataSnapshot =
      await FirebaseFirestore.instance.collection("Staff").doc(userUUID).get();

      if (bioDataSnapshot.exists) {
        final bioData = bioDataSnapshot.data();
        if (bioData != null) {
          setState(() {
            _currentUserState = bioData['state'] as String?;
            _currentUserLocation = bioData['location'] as String?;
          });
          print(
              "Current User State: $_currentUserState, Location: $_currentUserLocation");
        } else {
          print("Bio data is null for UUID: $userUUID");
        }
      } else {
        print("No bio data found for UUID: $userUUID");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }

  Future<void> _loadInitialTimesheets() async {
    setState(() {
      isLoading = false; // No longer loading initially, data is passed
      timesheets = widget.timesheetDataList; // Initialize timesheets from passed data
    });
  }

  Future<void> _fetchTimesheets() async {
    setState(() {
      isLoading = true;
    });
    try {
      final now = DateTime.now();
      if (now.day >= 20) {
        _timesheetCollectionName = DateFormat('MMMM_yyyy').format(DateTime(now.year, now.month));
      } else {
        _timesheetCollectionName = DateFormat('MMMM_yyyy').format(DateTime(now.year, now.month - 1));
      }

      List<Map<String, dynamic>> fetchedTimesheets = [];
      if (_currentUserState != null) {
        QuerySnapshot staffSnapshot = await FirebaseFirestore.instance
            .collection('Staff')
            .where('state', isEqualTo: _currentUserState)
            .where('staffCategory', isEqualTo: "Facility Staff")
            .get();

        for (var staffDoc in staffSnapshot.docs) {
          final staffId = staffDoc.id;
          DocumentSnapshot timesheetDoc = await staffDoc.reference
              .collection('TimeSheets')
              .doc(_timesheetCollectionName)
              .get();

          if (timesheetDoc.exists) {
            final timesheetData = timesheetDoc.data() as Map<String, dynamic>?;
            if (timesheetData != null) {
              // Fetch Staff Name separately to ensure it's always available and up-to-date
              DocumentSnapshot staffBioData = await FirebaseFirestore.instance.collection("Staff").doc(staffId).get();
              final staffBio = staffBioData.data() as Map<String, dynamic>?;
              String staffName = staffBio?['firstName'] != null && staffBio?['lastName'] != null
                  ? '${staffBio!['firstName']} ${staffBio['lastName']}'
                  : 'N/A';

              fetchedTimesheets.add({...timesheetData, 'staffName': staffName, 'staffId': staffId}); // Add staffName to timesheet data
            }
          }
        }
      }

      setState(() {
        timesheets = fetchedTimesheets;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching timesheets: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getApprovalStatusText(Map<String, dynamic> timesheet) {
    String caritasStatus = timesheet['caritasSupervisorSignatureStatus'] ?? 'N/A';
    String facilityStatus = timesheet['facilitySupervisorSignatureStatus'] ?? 'N/A';

    if (caritasStatus == 'Approved' && facilityStatus == 'Approved') {
      return 'Fully Approved';
    } else if (caritasStatus == 'Approved' || facilityStatus == 'Approved') {
      return 'Partially Approved';
    } else if (caritasStatus == 'Pending' || facilityStatus == 'Pending') {
      return 'Pending Approval';
    } else if (caritasStatus == 'Rejected' || facilityStatus == 'Rejected') {
      return 'Rejected';
    } else {
      return 'Submitted'; // Or another status if needed
    }
  }


  Color _getDurationColor(Map<String, dynamic> timesheet) {
    Timestamp? createdDateTimestamp = timesheet['timesheetSubmissionDate'] as Timestamp?;
    if (createdDateTimestamp == null) {
      return Colors.grey; // Default color if no submission date
    }
    DateTime createdDate = createdDateTimestamp.toDate();
    Duration difference = DateTime.now().difference(createdDate);
    if (difference.inDays > 2) {
      return Colors.red;
    } else if (difference.inDays > 1) {
      return Colors.yellow;
    }
    return Colors.green;
  }


  Future<void> _downloadSelectedTimesheetsAsPDF() async {
    if (selectedTimesheetPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No timesheets selected for download.')),
      );
      return;
    }

    setState(() {
      _isPDFLoading = true;
    });

    try {
      // Create a combined PDF document
      final pdfDoc = pw.Document(pageMode: PdfPageMode.outlines);

      // Load logo once for all timesheets
      final ByteData logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final Uint8List logoImageData = logoBytes.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoImageData);

      for (String timesheetPath in selectedTimesheetPaths) {
        // Get the timesheet data from Firestore
        DocumentReference timesheetRef = FirebaseFirestore.instance.doc(timesheetPath);
        DocumentSnapshot timesheetSnapshot = await timesheetRef.get();

        if (timesheetSnapshot.exists) {
          Map<String, dynamic> timesheetData = timesheetSnapshot.data() as Map<String, dynamic>;

          // Parse the timesheet date
          DateTime? timesheetDate;
          try {
            final dateString = timesheetData['date'];
            if (dateString != null && dateString is String) {
              timesheetDate = DateFormat('MMMM dd, yyyy').parse(dateString);
            } else {
              timesheetDate = DateTime.now();
              print("Warning: Timesheet date is null or not a string, using current date as default.");
            }
          } catch (e) {
            print("Error parsing date: $e, using current date as default.");
            timesheetDate = DateTime.now();
          }
          timesheetDate ??= DateTime.now();

          final monthYear = DateFormat('MMMM_yyyy').format(timesheetDate);
          final staffName = timesheetData['staffName'] ?? 'N/A';

          // Get supervisor names and signature data
          final supervisorNames = await _getSupervisorNamesForTimesheet(timesheetData);
          final signatureColumns = await _buildSignatureColumnsForTimesheet(supervisorNames);

          // Add the timesheet page to the PDF
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header with logo and title
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStaffInfoForPDF(context, timesheetData),
                        pw.Column(
                            children: [
                              pw.Text("CARITAS NIGERIA",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                              pw.SizedBox(height: 10),
                              pw.Text("Monthly Time Report ($monthYear)")
                            ]
                        ),
                        pw.Container(
                          child: pw.Image(logoImage, width: 50, height: 50),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    // Timesheet table
                    _buildTimesheetTableForPDF(context, timesheetData),
                    pw.SizedBox(height: 10),
                    // Signature section
                    _buildSignatureSectionForPDF(context, signatureColumns),
                  ],
                );
              },
            ),
          );

          // Conditionally add task summary page
          if (_includeTaskSummary) {
            final taskSummaryContent = await _prepareTaskSummaryContentForTimesheet(timesheetData);
            if (taskSummaryContent.isNotEmpty) {
              pdfDoc.addPage(
                pw.MultiPage(
                  header: (pw.Context context) {
                    return pw.Header(
                      level: 0,
                      child: pw.Text('Task Summary Report - $monthYear - $staffName',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    );
                  },
                  footer: (pw.Context context) {
                    return pw.Container(
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
                        child: pw.Text(
                            'Page ${context.pageNumber} of ${context.pagesCount}',
                            style: pw.Theme.of(context)
                                .defaultTextStyle
                                .copyWith(color: PdfColors.grey)
                        ));
                  },
                  build: (pw.Context context) {
                    return [
                      pw.SizedBox(height: 20),
                      pw.Center(
                        child: pw.Text(
                          "Task Summary for $monthYear - $staffName",
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Column(children: taskSummaryContent),
                    ];
                  },
                ),
              );
            }
          }
        }
      }

      // Save and download the PDF
      final Uint8List pdfBytes = await pdfDoc.save();

      if (kIsWeb) {
        // Web download logic
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Selected_Timesheets.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile/desktop download logic
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/Selected_Timesheets.pdf");
        await file.writeAsBytes(pdfBytes);
        // Optionally share/print the PDF
        // await Printing.sharePdf(bytes: pdfBytes, filename: 'Selected_Timesheets.pdf');
      }
    } catch (e) {
      print("Error generating PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      setState(() {
        _isPDFLoading = false;
      });
    }
  }

// Helper function to get supervisor names for a timesheet
  Future<Map<String, String>> _getSupervisorNamesForTimesheet(Map<String, dynamic> timesheetData) async {
    return {
      'staffName': timesheetData['staffName'] ?? 'Not Assigned',
      'projectCoordinatorName': timesheetData['facilitySupervisor'] ?? 'Not Assigned',
      'caritasSupervisorName': timesheetData['caritasSupervisor'] ?? 'Not Assigned',
      'projectCoordinatorSignature': timesheetData['facilitySupervisorSignature'] ?? '',
      'caritasSupervisorSignature': timesheetData['caritasSupervisorSignature'] ?? '',
      'staffSignature': timesheetData['staffSignature'] ?? '',
      'staffSignatureDate': timesheetData['staffSignatureDate'] ?? '',
      'facilitySupervisorSignatureDate': timesheetData['facilitySupervisorSignatureDate'] ?? '',
      'caritasSupervisorSignatureDate': timesheetData['caritasSupervisorSignatureDate'] ?? '',
    };
  }

// Helper function to build signature columns
  Future<List<pw.Widget>> _buildSignatureColumnsForTimesheet(Map<String, String> supervisorData) async {
    final staffSig = supervisorData['staffSignature']!.isNotEmpty
        ? await networkImageToByte(supervisorData['staffSignature']!)
        : null;
    final coordSig = supervisorData['projectCoordinatorSignature']!.isNotEmpty
        ? await networkImageToByte(supervisorData['projectCoordinatorSignature']!)
        : null;
    final caritasSig = supervisorData['caritasSupervisorSignature']!.isNotEmpty
        ? await networkImageToByte(supervisorData['caritasSupervisorSignature']!)
        : null;

    return [
      _buildSingleSignatureColumn(
          'Name of Staff',
          supervisorData['staffName']!.toUpperCase(),
          staffSig,
          supervisorData['staffSignatureDate']!
      ),
      _buildSingleSignatureColumn(
          'Name of Project Coordinator',
          supervisorData['projectCoordinatorName']!.toUpperCase(),
          coordSig,
          supervisorData['facilitySupervisorSignatureDate']!
      ),
      _buildSingleSignatureColumn(
          'Name of Caritas Supervisor',
          supervisorData['caritasSupervisorName']!.toUpperCase(),
          caritasSig,
          supervisorData['caritasSupervisorSignatureDate']!
      ),
    ];
  }

// Helper function to build a single signature column
  pw.Widget _buildSingleSignatureColumn(String title, String name, Uint8List? imageBytes, String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(name),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 100,
          width: 150,
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Center(
            child: imageBytes != null
                ? pw.Image(pw.MemoryImage(imageBytes))
                : pw.Text("Signature"),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text("Date: $date"),
      ],
    );
  }

// Helper function to build staff info section
  pw.Widget _buildStaffInfoForPDF(pw.Context context, Map<String, dynamic> timesheetData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Name: ${timesheetData['staffName'] ?? 'N/A'}'),
        pw.Text('Department: ${timesheetData['department'] ?? 'N/A'}'),
        pw.Text('Designation: ${timesheetData['designation'] ?? 'N/A'}'),
        pw.Text('Location: ${timesheetData['location'] ?? 'N/A'}'),
        pw.Text('State: ${timesheetData['state'] ?? 'N/A'}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

// Helper function to build the timesheet table
  pw.Widget _buildTimesheetTableForPDF(pw.Context context, Map<String, dynamic> timesheetData) {
    DateTime? timesheetDate;
    try {
      final dateString = timesheetData['date'];
      if (dateString != null && dateString is String) {
        timesheetDate = DateFormat('MMMM dd, yyyy').parse(dateString);
      } else {
        timesheetDate = DateTime.now();
      }
    } catch (e) {
      timesheetDate = DateTime.now();
    }
    timesheetDate ??= DateTime.now();

    final month = DateFormat('MM').format(timesheetDate);
    final year = DateFormat('yyyy').format(timesheetDate);
    final daysInRange = initializeDateRange(int.parse(month), int.parse(year));
    final projectName = timesheetData['projectName'] ?? 'N/A';
    final attendanceData = timesheetData['timesheetEntries']?.cast<Map<String, dynamic>>() ?? [];

    // Helper function to get duration for a date
    String getDurationForDate(DateTime date, String projectName, String category, List<Map<String, dynamic>> data) {
      double totalHoursForDate = 0;

      for (var attendance in data) {
        try {
          String dateString = attendance['date'] as String;
          DateTime attendanceDate = DateFormat('yyyy-MM-dd').parse(dateString);

          if (attendanceDate.year == date.year &&
              attendanceDate.month == date.month &&
              attendanceDate.day == date.day) {
            if (category == projectName) {
              if (!attendance['offDay']) {
                totalHoursForDate += attendance['noOfHours'] > 8.0 ? 8.0 : attendance['noOfHours'] as double;
              }
            } else {
              if (attendance['offDay'] as bool &&
                  (attendance['durationWorked'] as String?)?.toLowerCase() == category.toLowerCase()) {
                totalHoursForDate += attendance['noOfHours'] > 8.0 ? 8.0 : attendance['noOfHours'] as double;
              }
            }
          }
        } catch (e) {
          print("Error processing attendance data: $e");
        }
      }
      return totalHoursForDate.toStringAsFixed(2);
    }

    // Calculate totals and percentages
    double calculateTotalHours() {
      double totalHours = 0;
      for (var date in daysInRange) {
        if (!isWeekend(date)) {
          totalHours += double.parse(getDurationForDate(date, projectName, projectName, attendanceData));
        }
      }
      return totalHours;
    }

    double calculateCategoryHours(String category) {
      double totalHours = 0;
      for (var date in daysInRange) {
        if (!isWeekend(date)) {
          totalHours += double.parse(getDurationForDate(date, projectName, category, attendanceData));
        }
      }
      return totalHours;
    }

    double calculatePercentage(int workingDays, double hours) {
      return (workingDays * 8) > 0 ? (hours / (workingDays * 8)) * 100 : 0;
    }

    int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
    double projectTotal = calculateTotalHours();
    double projectPercentage = calculatePercentage(workingDays, projectTotal);

    // Build the table rows
    List<pw.TableRow> tableRows = [
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Container(
              width: 250,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text('Project Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ...daysInRange.map((date) => pw.Container(
              width: 80,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              color: isWeekend(date) ? PdfColors.grey900 : PdfColors.grey300,
              child: pw.Text(DateFormat('dd').format(date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text('Total Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text('%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),

      // Project row
      pw.TableRow(
        children: [
          pw.Container(
              width: 250,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(projectName)),
          ...daysInRange.map((date) {
            String hours = getDurationForDate(date, projectName, projectName, attendanceData);
            return pw.Container(
              width: 80,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              color: isWeekend(date) ? PdfColors.grey900 : null,
              child: pw.Text(hours),
            );
          }),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(projectTotal.toStringAsFixed(2))),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text('${projectPercentage.toStringAsFixed(2)}%')),
        ],
      ),

      // Out-of-office categories
      ...['Annual leave', 'Holiday', 'Maternity'].map((category) {
        double categoryHours = calculateCategoryHours(category);
        double categoryPercentage = calculatePercentage(workingDays, categoryHours);

        return pw.TableRow(
          children: [
            pw.Container(
                width: 250,
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.all(1.0),
                child: pw.Text(category)),
            ...daysInRange.map((date) {
              String hours = getDurationForDate(date, projectName, category, attendanceData);
              return pw.Container(
                width: 80,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(1.0),
                color: isWeekend(date) ? PdfColors.grey900 : null,
                child: pw.Text(hours),
              );
            }),
            pw.Container(
                width: 200,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(1.0),
                child: pw.Text(categoryHours.toStringAsFixed(2))),
            pw.Container(
                width: 200,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(1.0),
                child: pw.Text('${categoryPercentage.toStringAsFixed(2)}%')),
          ],
        );
      }),

      // Total row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          pw.Container(
              width: 250,
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ...List.generate(daysInRange.length, (_) => pw.SizedBox(width: 80)),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(
                  (projectTotal + ['Annual leave', 'Holiday', 'Maternity']
                      .fold(0.0, (sum, category) => sum + calculateCategoryHours(category)))
                      .toStringAsFixed(2),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Container(
              width: 200,
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(
                  '${((projectPercentage + ['Annual leave', 'Holiday', 'Maternity']
                      .fold(0.0, (sum, category) => sum + calculatePercentage(workingDays, calculateCategoryHours(category)))))
                      .toStringAsFixed(2)}%',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(250),
        for (int i = 1; i <= daysInRange.length; i++) i: const pw.FixedColumnWidth(80),
        daysInRange.length + 1: const pw.FixedColumnWidth(200),
        daysInRange.length + 2: const pw.FixedColumnWidth(200),
      },
      children: tableRows,
    );
  }

// Helper function to build signature section
  pw.Widget _buildSignatureSectionForPDF(pw.Context context, List<pw.Widget> signatureColumns) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Signature & Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: signatureColumns,
        ),
      ],
    );
  }

// Helper function to prepare task summary content
  Future<List<pw.Widget>> _prepareTaskSummaryContentForTimesheet(Map<String, dynamic> timesheetData) async {
    // Implement your task summary logic here based on timesheetData
    // This should return a list of pw.Widgets that make up the task summary

    // Placeholder implementation - replace with your actual logic
    return [
      pw.Text("Task summary for ${timesheetData['staffName']}"),
      pw.SizedBox(height: 20),
      pw.Text("No task summary data available", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
    ];
  }

// Helper function to check if a date is a weekend
  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

// Helper function to initialize date range
  List<DateTime> initializeDateRange(int month, int year) {
    DateTime startDate = DateTime(year, month - 1, 20);
    DateTime endDate = DateTime(year, month, 19);

    List<DateTime> daysInRange = [];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      daysInRange.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return daysInRange;
  }

// Helper function to convert network image to bytes
  Future<Uint8List?> networkImageToByte(String imageUrl) async {
    try {
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        if (response.data is List<int>) {
          return Uint8List.fromList(response.data as List<int>);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching image: $e');
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet Status List'),
        actions: [
          if (selectedTimesheetPaths.isNotEmpty)
            Row(
              children: [
                Checkbox(
                  value: _includeTaskSummary,
                  onChanged: (bool? value) {
                    setState(() {
                      _includeTaskSummary = value ?? false;
                    });
                  },
                ),
                const Text('Include Task Summary'),
                IconButton(
                  icon: _isPDFLoading ? const CircularProgressIndicator() : const Icon(Icons.download),
                  onPressed: _isPDFLoading ? null : _downloadSelectedTimesheetsAsPDF,
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : timesheets.isEmpty
          ? const Center(child: Text('No timesheets submitted yet.'))
          : ListView.builder(
        itemCount: timesheets.length,
        itemBuilder: (context, index) {
          final timesheet = timesheets[index];
          final timesheetDocPath = '/Staff/${timesheet['staffId']}/TimeSheets/$_timesheetCollectionName';
          bool isSelected = selectedTimesheetPaths.contains(timesheetDocPath);


          return Card(
            child: ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedTimesheetPaths.add(timesheetDocPath);
                    } else {
                      selectedTimesheetPaths.remove(timesheetDocPath);
                    }
                  });
                },
              ),
              title: Text(timesheet['staffName'] ?? 'N/A'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('State: ${timesheet['state'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('Facility Name: ${timesheet['location'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('Staff Email: ${timesheet['staffEmail'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('Status: ${_getApprovalStatusText(timesheet)}'),
                  const SizedBox(height: 8,),
                  const Divider(),
                  Text('Timesheet Submission Date: ${timesheet['timesheetSubmissionTimestamp'] != null ? _formatTimestamp(timesheet['timesheetSubmissionTimestamp']) : 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('Project Coordinator: ${timesheet['facilitySupervisor'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('Project Coordinator Approval Status: ${timesheet['facilitySupervisorSignatureStatus'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('CARITAS Supervisor: ${timesheet['caritasSupervisor'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  Text('CARITAS Supervisor\'s Approval Status: ${timesheet['caritasSupervisorSignatureStatus'] ?? 'N/A'}'),
                  const SizedBox(height: 4,),
                  _buildApprovalDurationText(
                    title: 'Duration of Approval Time for Project Coordinator',
                    submissionTimestamp: timesheet['timesheetSubmissionTimestamp'],
                    approvalTimestamp: timesheet['facilitySupervisorTimesheetSubmissionTimestamp'],
                  ),
                  const SizedBox(height: 4,),
                  _buildApprovalDurationText(
                    title: 'Duration of Approval Time for CARITAS Supervisor',
                    submissionTimestamp: timesheet['timesheetSubmissionTimestamp'],
                    approvalTimestamp: timesheet['caritasSupervisorTimesheetSubmissionTimestamp'],
                  ),

                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TimesheetDetailsScreen2(

                        timesheetData: timesheet,
                        staffId: timesheet['staffId'],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
    } else if (timestamp is String) {
      // Try to parse the string as DateTime, if it fails, return 'N/A' or handle accordingly
      try {
        DateTime dateTime = DateTime.parse(timestamp);
        return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      } catch (e) {
        print("Error parsing timestamp string: $e");
        return 'N/A (Invalid Date)';
      }
    }
    return 'N/A'; // Default case if it's neither Timestamp nor String
  }


  Widget _buildApprovalDurationText({
    required String title,
    required dynamic submissionTimestamp, // Changed to dynamic
    required dynamic approvalTimestamp,   // Changed to dynamic
  }) {
    DateTime? submissionDate;
    DateTime? approvalDate;

    if (submissionTimestamp == null || approvalTimestamp == null) {
      return Text('$title: N/A');
    }

    if (submissionTimestamp is Timestamp) {
      submissionDate = submissionTimestamp.toDate();
    } else if (submissionTimestamp is String) {
      try {
        submissionDate = DateTime.parse(submissionTimestamp);
      } catch (e) {
        submissionDate = null;
        print("Error parsing submissionTimestamp string: $e");
      }
    }

    if (approvalTimestamp is Timestamp) {
      approvalDate = approvalTimestamp.toDate();
    } else if (approvalTimestamp is String) {
      try {
        approvalDate = DateTime.parse(approvalTimestamp);
      } catch (e) {
        approvalDate = null;
        print("Error parsing approvalTimestamp string: $e");
      }
    }

    if (submissionDate == null || approvalDate == null) {
      return Text('$title: N/A');
    }


    Duration duration = approvalDate.difference(submissionDate);

    return Text('$title: ${duration.inDays} days');
  }
}