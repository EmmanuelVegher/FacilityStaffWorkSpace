import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/attendance_model.dart';
import '../../models/bio_model.dart';
import '../../widgets/drawer.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Alignment,Border; // Import and hide conflicting classes
import 'package:flutter_email_sender/flutter_email_sender.dart';

// report_model.dart
class ReportEntry {
  String key;
  String value;
  String? enteredBy;
  String? editedBy;
  String? reviewedBy;
  String? reviewStatus;
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  List<String>? attachments;
  String? appAnalysis;
  String? reviewerId;

  ReportEntry({
    this.key = "",
    this.value = "",
    this.enteredBy,
    this.editedBy,
    this.reviewedBy,
    this.reviewStatus,
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
    this.attachments,
    this.appAnalysis,
    this.reviewerId,
  });

  factory ReportEntry.fromMap(Map<String, dynamic> map) {
    return ReportEntry(
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      enteredBy: map['enteredBy'],
      editedBy: map['editedBy'],
      reviewedBy: map['reviewedBy'],
      reviewStatus: map['reviewStatus'],
      supervisorName: map['supervisorName'],
      supervisorEmail: map['supervisorEmail'],
      supervisorApprovalStatus: map['supervisorApprovalStatus'],
      supervisorFeedBackComment: map['supervisorFeedBackComment'],
      attachments: (map['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      appAnalysis: map['appAnalysis'],
      reviewerId: map['reviewerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      if (enteredBy != null) 'enteredBy': enteredBy,
      if (editedBy != null) 'editedBy': editedBy,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewStatus != null) 'reviewStatus': reviewStatus,
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
      if (attachments != null) 'attachments': attachments,
      if (appAnalysis != null) 'appAnalysis': appAnalysis,
      if (reviewerId != null) 'reviewerId': reviewerId,
    };
  }

  /// **Add the copyWith method**
  ReportEntry copyWith({
    String? key,
    String? value,
    String? enteredBy,
    String? editedBy,
    String? reviewedBy,
    String? reviewStatus,
    String? supervisorName,
    String? supervisorEmail,
    String? supervisorApprovalStatus,
    String? supervisorFeedBackComment,
    List<String>? attachments,
    String? appAnalysis,
    String? reviewerId,
  }) {
    return ReportEntry(
      key: key ?? this.key,
      value: value ?? this.value,
      enteredBy: enteredBy ?? this.enteredBy,
      editedBy: editedBy ?? this.editedBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorEmail: supervisorEmail ?? this.supervisorEmail,
      supervisorApprovalStatus:
      supervisorApprovalStatus ?? this.supervisorApprovalStatus,
      supervisorFeedBackComment:
      supervisorFeedBackComment ?? this.supervisorFeedBackComment,
      attachments: attachments ?? this.attachments,
      appAnalysis: appAnalysis ?? this.appAnalysis,
      reviewerId: reviewerId ?? this.reviewerId,
    );
  }
}


class Report {
  String? id;
  DateTime? date;
  String? reportType;
  String? reportingWeek;
  String? reportingMonth;
  String? reportStatus;
  String? reportFeedbackComment;
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  List<String>? attachments;
  bool? isSynced;
  // Modified reportEntries to be a Map as per requirement
  Map<String, Map<String, List<ReportEntry>>>? reportEntries;

  Report({
    this.id,
    this.date,
    this.reportType,
    this.reportingWeek,
    this.reportingMonth,
    this.reportStatus,
    this.attachments,
    this.reportFeedbackComment,
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
    this.isSynced,
    this.reportEntries,
  });

  factory Report.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return Report(
      id: snapshot.id,
      reportType: data?['reportType'],
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      reportingWeek: data?['reportingWeek'],
      reportingMonth: data?['reportingMonth'],
      reportStatus: data?['reportStatus'],
      reportFeedbackComment: data?['reportFeedbackComment'],
      supervisorName: data?['supervisorName'],
      supervisorEmail: data?['supervisorEmail'],
      supervisorApprovalStatus: data?['supervisorApprovalStatus'],
      supervisorFeedBackComment: data?['supervisorFeedBackComment'],
      attachments:
      (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      isSynced: data?['isSynced'],
      // Deserialize reportEntries correctly
      reportEntries: (data?['reportEntries'] as Map<String, dynamic>?)?.map(
            (username, indicatorMap) => MapEntry(
          username,
          (indicatorMap as Map<String, dynamic>).map(
                (indicator, entryList) => MapEntry(
              indicator,
              (entryList as List<dynamic>)
                  .map((entryData) =>
                  ReportEntry.fromMap(entryData as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (reportType != null) 'reportType': reportType,
      if (date != null) 'date': date,
      if (reportingWeek != null) 'reportingWeek': reportingWeek,
      if (reportingMonth != null) 'reportingMonth': reportingMonth,
      if (reportStatus != null) 'reportStatus': reportStatus,
      if (reportFeedbackComment != null) 'reportFeedbackComment': reportFeedbackComment,
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
      if (attachments != null) 'attachments': attachments,
      if (isSynced != null) 'isSynced': isSynced,
      // Serialize reportEntries correctly
      if (reportEntries != null)
        'reportEntries': reportEntries!.map(
              (username, indicatorMap) => MapEntry(
            username,
            indicatorMap.map(
                  (indicator, entryList) => MapEntry(
                indicator,
                entryList.map((e) => e.toMap()).toList(),
              ),
            ),
          ),
        ),
    };
  }
}

class Task {
  int? id; // Not used in Firestore, Firestore generates document IDs
  DateTime? date;
  String? taskTitle;
  String? taskDescription;
  bool? isSynced;
  String? taskStatus;
  List<String>? attachments;
  String? reviewedBy; // ADDED: Field to store the reviewer's name
  String? appAnalysis; // ADDED: Field to store Gemini analysis for tasks
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  String? firestoreId;
  Task({
    this.id,
    this.date,
    this.taskTitle,
    this.firestoreId, // ADDED
    this.taskDescription,
    this.isSynced,
    this.taskStatus,
    this.attachments,
    this.reviewedBy, // ADDED: Include in constructor
    this.appAnalysis, // ADDED: Include in constructor
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
  });


  factory Task.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return Task(
      id: null, // Firestore doesn't use integer IDs, document ID is used instead
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      taskTitle: data?['taskTitle'],
      taskDescription: data?['taskDescription'],
      isSynced: data?['isSynced'],
      firestoreId: snapshot.id,
      taskStatus: data?['taskStatus'],
      attachments:
      (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      reviewedBy: data?['reviewedBy'], // ADDED: Retrieve from Firestore data
      appAnalysis: data?['appAnalysis'], // ADDED: Retrieve appAnalysis from Firestore
      supervisorName: data?['supervisorName'],
      supervisorEmail: data?['supervisorEmail'],
      supervisorApprovalStatus: data?['supervisorApprovalStatus'],
      supervisorFeedBackComment: data?['supervisorFeedBackComment'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (date != null) 'date': date,
      if (taskTitle != null) 'taskTitle': taskTitle,
      if (taskDescription != null) 'taskDescription': taskDescription,
      if (isSynced != null) 'isSynced': isSynced,
      if (firestoreId != null) 'firestoreId': firestoreId,
      if (taskStatus != null) 'taskStatus': taskStatus,
      if (attachments != null) 'attachments': attachments,
      if (reviewedBy != null) 'reviewedBy': reviewedBy, // ADDED: Include in Firestore data
      if (appAnalysis != null) 'appAnalysis': appAnalysis, // ADDED: Include appAnalysis in Firestore data
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
    };
  }
}

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  _TimesheetScreenState createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  // ADDED: State for handling split September timesheets
  int _selectedTimesheetPart = 1; // 1 for the first half, 2 for the second
  bool _isSeptemberSelected = false; // To conditionally show the part selector UI

  late DateTime startDate;
  late DateTime endDate;
  List<DateTime> daysInRange = [];
  TextEditingController facilitySupervisorController = TextEditingController();
  TextEditingController caritasSupervisorController = TextEditingController();
  late int selectedMonth; // Selected month index (0-based, 0=January)
  late int selectedYear;
  List<Map<String, dynamic>> facilitySupervisorsList = [];
  Map<String,
      dynamic>? _selectedFacilitySupervisor; // Holds the selected supervisor's data
  String? _selectedFacilitySupervisorFullName; // Holds the full name of the selected supervisor
  String? _selectedFacilitySupervisorEmail;
  String? _selectedFacilitySupervisorSignatureLink;

  bool _isLoading = true;
  bool _pageLoading = true; // For initial page loading progress


  String formattedDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
  List<AttendanceModel> attendanceData = [];
  GlobalKey _globalKey = GlobalKey(); // Define the GlobalKey
  ScrollController _scrollController = ScrollController(); // Add a scroll controller
  ScrollController _horizontalScrollController =
  ScrollController(); // Controller for horizontal scrolling

  List<String?> projectNames = []; // Store project names from Isar
  List<String?> supervisorNames = []; // Store project names from Isar
  //late final bioData;
  String _currentUsername = "";
  String? selectedProjectName;
  String? selectedBioFirstName;
  String? selectedBioLastName;
  String? selectedBioDepartment;
  String? selectedBioState;
  String? selectedBioDesignation;
  String? selectedBioLocation;
  String? selectedBioStaffCategory;
  String? selectedBioEmail;
  String? selectedBioPhone;
  String? selectedFirebaseId;
  String? facilitySupervisor;
  String? caritasSupervisor;
  DateTime? selectedDate;
  String? staffSignatureLink;
  BioModel? bioData; // Make bioData nullable// Currently selected project
  String? selectedSupervisor; // State variable to store the selected supervisor
  String? selectedFacilitySupervisor; // State variable to store the selected supervisor
  String? _selectedSupervisorEmail;
  String? _signatureLink;
  Uint8List? staffSignature; // Store staff signature as Uint8List
  Uint8List? facilitySupervisorSignature; // Array field for facility supervisor signature
  Uint8List? caritasSupervisorSignature; // Array field for Caritas supervisor signature
  List<String> attachments = [];
  bool isHTML = false;
  List<Uint8List> checkSignatureImage = []; // Initialize as empty list
  bool _isPDFLoading = false;
  bool _includeTaskSummary = false;

    // Responsive Scaling Factors for PDF Text Sizes - Adjust these as needed
  final double pdfTitleFontSizeFactor = 1.0; // Reduced from 20 to 16
  final double pdfHeaderFontSizeFactor = 0.8; // Reduced from 12 to 10
  final double pdfTableFontSizeFactor = 0.7; // Reduced from 12 to 9
  final double pdfSignatureFontSizeFactor = 0.7; // Reduced from 12 to 9

  // Responsive scaling factors
  late double appBarHeightFactor;
  late double titleFontSizeFactor;
  late double fontSizeFactor;
  late double paddingFactor;
  late double marginFactor;
  late double iconSizeFactor;
  late double tableFontSizeFactor;
  late double dropdownFontSizeFactor;


  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    setState(() {
      _pageLoading = true; // Start loading
    });
    await _loadInitialData();
    await _loadBioData(); // Load bio data first
    if (bioData != null && bioData!.department != null && bioData!.state != null) {
      await getSupervisor(bioData!.firebaseAuthId!, selectedYear, selectedMonth);
      await _loadSupervisorNames(bioData!.department!, bioData!.state!);
    } else {
      _showErrorToast("Bio data or department/state is missing!");
    }
    setState(() {
      _pageLoading = false; // Stop loading after bio data and initial data are loaded
    });
  }

  // NEW: Helper getter to generate the correct Firestore document ID
  String get _timesheetDocId {
    final monthFormat = DateFormat('MMMM_yyyy');
    final baseId = monthFormat.format(DateTime(selectedYear, selectedMonth + 1));

    // For September (month index 8), append the part number to make the ID unique
    if (selectedMonth == 8) {
      return '${baseId}_part$_selectedTimesheetPart';
    }

    // For all other months, return the standard ID
    return baseId;
  }

  Future<void> _loadInitialData() async {
    await _readImagesFromDatabase().then((images) {
      setState(() {
        checkSignatureImage = images ?? [];
      });
    });
    _fetchFacilitySupervisor();
    _globalKey = GlobalKey();
    DateTime now = DateTime.now();
    selectedMonth = now.month - 1;
    selectedYear = now.year;
    initializeDateRange(selectedMonth, selectedYear);
    await _loadProjectNames();
    await _loadAttendanceData();
    _scrollController = ScrollController();
    _horizontalScrollController = ScrollController(); // Initialize horizontal scroll controller
  }

  // <<<--- NEW METHOD: Centralizes the daily hour cap logic ---<<<
  /// Returns the maximum allowed work hours for a given date.
  /// 8.0 for Monday-Friday, and 0.0 for weekends.
  double _getMaximumHoursForDay(DateTime date) {
    if (isWeekend(date)) {
      return 0.0;
    }
    // Monday to Friday are capped at 8.0 hours
    return 8.0;
  }


  void _startInitialTimer() {
    Timer(const Duration(seconds: 7), () async {
      await _loadBioData().then((_) async {
        if (bioData != null && bioData!.department != null && bioData!.state != null) {
          await getSupervisor(bioData!.firebaseAuthId!, selectedYear, selectedMonth);
          await _loadSupervisorNames(bioData!.department!, bioData!.state!);
        } else {
          _showErrorToast("Bio data or department/state is missing!");
        }
      });
      setState(() {
        _pageLoading = false;
      });
    });
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }


  DateTime createCustomDate(int selectedMonth, int selectedYear) {
    return DateTime(
        selectedYear, selectedMonth, 20); // Directly create the DateTime object
  }

  // ---------------

  Future<void> _showLogo() async {
    try {
      // Load the image as bytes
      final logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      pw.Container(
        child: pw.Image(
          logoImage,
          width: 50, // Adjust width
          height: 50, // Adjust height
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _createAndExportPDF1() async {
    final pdf = pw.Document(pageMode: PdfPageMode.outlines);
    String monthYear = DateFormat('MMMM, yyyy').format(
        DateTime(selectedYear, selectedMonth + 1));
    // A4 page in landscape mode
    final pageFormat = PdfPageFormat.a4.landscape;

    try {
      // Fetch supervisor names and signature columns
      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);

      // Load the image as bytes
      final logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

      // Add content to a single page
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Staff Information and Logo Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStaffInfo(context),
                    pw.Column(
                        children: [
                          pw.Text("CARITAS NIGERIA", style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 20),),
                          pw.SizedBox(height: 10,),
                          pw.Text("Monthly Time Report ($monthYear)")
                        ]
                    ),
                    pw.Container(
                      child: pw.Image(
                        logoImage,
                        width: 50, // Adjust width
                        height: 50, // Adjust height
                      ),
                    ),
                  ],
                ),

                // Timesheet Table Section
                pw.SizedBox(height: 10), // Adjust spacing
                // Bio Info Section
                _buildStaffInfo(context),
                pw.SizedBox(height: 10), // Adjust spacing
                _buildTimesheetTable(context),

                // Signature Section
                pw.SizedBox(height: 10), // Adjust spacing
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );


      final output = await getDownloadsDirectory(); // Use getDownloadsDirectory() - CORRECT WAY!
      final file = File("${output?.path}/timesheet_${monthYear}_$selectedBioLastName.pdf");
      await file.writeAsBytes(await pdf.save());

      Fluttertoast.showToast( // Confirmation message
        msg: "PDF Timesheet downloaded to: ${file.path}",
        // ... toast properties ...
      );
      //OpenFilex.open(file.path);
    } catch (e) {
      print("Error generating PDF: $e");
      // Handle the error, e.g., show a dialog to the user
      Fluttertoast.showToast(
        msg: "Error generating PDF: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _createAndExportPDF2() async {

    setState(() {
      _isPDFLoading = true;
    });
    final pdf = pw.Document();
    String monthYear =
    DateFormat('MMMM, yyyy').format(DateTime(selectedYear, selectedMonth + 1));

    try {
      final ByteData logoBytes =
      await rootBundle.load('assets/image/ccfn_logo.png');
      final Uint8List logoImageData = logoBytes.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoImageData);
      final pageFormat = PdfPageFormat.a4.landscape;

      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);

      // **Fetch Task Summary Data BEFORE building PDF**
      final taskSummaryContent = await _prepareTaskSummaryContent(); // New method to prepare task summary content

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(children: [
                      pw.Text("CARITAS NIGERIA",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 20 * pdfTitleFontSizeFactor)), // Reduced title size
                      pw.SizedBox(height: 10),
                      pw.Text("Monthly Time Sheet ($monthYear)",
                          style: pw.TextStyle(
                              fontSize: 14 * pdfHeaderFontSizeFactor)) // Reduced header size
                    ]),
                    pw.Image(logoImage, width: 50, height: 50),
                  ],
                ),
                pw.SizedBox(height: 10),
                _buildStaffInfo(context), // Added Staff Info here in _createAndExportPD
                pw.SizedBox(height: 10),
                _buildTimesheetTable(context),
                pw.SizedBox(height: 10),
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );

      // Add Task Summary Page using MultiPage, now passing pre-fetched content
      // Conditionally add Task Summary Page
      if (_includeTaskSummary) {
        pdf.addPage(
          pw.MultiPage(
           // pageFormat: pageFormat,
            header: (pw.Context context) {
              return pw.Header(
                level: 0,
                child: pw.Text('Task Summary Report - $monthYear',
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
                    "Task Summary for ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth + 1))}",
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                _buildTaskSummaryPage(logoImage, taskSummaryContent), // Pass pre-fetched content here
              ];
            },
          ),
        );}


      final Uint8List pdfBytes = await pdf.save();

      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Timesheet_${monthYear}_${selectedBioFirstName}_$selectedBioLastName.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print("Error generating PDF: $e");
    }finally {
      setState(() {
        _isPDFLoading = false;
      });
    }
  }

  Future<void> _createAndExportPDF() async {
    setState(() {
      _isPDFLoading = true;
    });

    final pdf = pw.Document();

    // CHANGED: Logic to handle display titles and filenames for the split fiscal period
    String monthYearDisplay; // For the title inside the PDF
    String monthYearFilename; // For the downloaded file's name

    if (selectedMonth == 8) { // September is month index 8
      monthYearDisplay = "September, $selectedYear (Part $_selectedTimesheetPart)";
      monthYearFilename = "September_${selectedYear}_part$_selectedTimesheetPart";
    } else {
      monthYearDisplay = DateFormat('MMMM, yyyy').format(DateTime(selectedYear, selectedMonth + 1));
      monthYearFilename = DateFormat('MMMM_yyyy').format(DateTime(selectedYear, selectedMonth + 1));
    }

    try {
      final ByteData logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final Uint8List logoImageData = logoBytes.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoImageData);

      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);
      final taskSummaryContent = await _prepareTaskSummaryContent();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(children: [
                      pw.Text("CARITAS NIGERIA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                      pw.SizedBox(height: 10),
                      // Use the new display title variable
                      pw.Text("Monthly Time Sheet ($monthYearDisplay)", style: pw.TextStyle(fontSize: 14))
                    ]),
                    pw.Image(logoImage, width: 50, height: 50),
                  ],
                ),
                pw.SizedBox(height: 10),
                _buildStaffInfo(context),
                pw.SizedBox(height: 10),
                _buildTimesheetTable(context),
                pw.SizedBox(height: 10),
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );

      if (_includeTaskSummary) {
        pdf.addPage(
          pw.MultiPage(
            header: (pw.Context context) => pw.Header(level: 0, child: pw.Text('Task Summary Report - $monthYearDisplay')),
            build: (pw.Context context) => [
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text("Task Summary for ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth + 1))}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              _buildTaskSummaryPage(logoImage, taskSummaryContent),
            ],
          ),
        );
      }

      final Uint8List pdfBytes = await pdf.save();
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Use the new filename variable
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Timesheet_${monthYearFilename}_${selectedBioFirstName}_$selectedBioLastName.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print("Error generating PDF: $e");
    } finally {
      setState(() {
        _isPDFLoading = false;
      });
    }
  }

  // New method to pre-fetch and prepare task summary content
  Future<List<pw.Widget>> _prepareTaskSummaryContent() async {
    String monthYear = DateFormat('MMMM, yyyy').format(
        DateTime(selectedYear, selectedMonth + 1));

    DateTime now = DateTime(selectedYear, selectedMonth + 1);
    DateTime startDateOfMonth = DateTime(now.year, now.month - 1, 20);
    DateTime endDateOfMonth = DateTime(now.year, now.month, 19);

    Map<DateTime, Map<String, Map<String, dynamic>>> summaryDataByDate = {};
    Map<DateTime, List<Task>> otherTasksByDate = {};
    Map<DateTime, List<Report>> reportsByDate = {};


    // Loop through each day of the month, EXCLUDING SATURDAYS AND SUNDAYS
    for (DateTime date = startDateOfMonth; date.isBefore(endDateOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        print("_createTaskSummaryPDF: Skipping weekend date: ${DateFormat('dd-MMM-yyyy').format(date)}");
        continue; // Skip weekends
      }

      final formattedDateForReportPath = DateFormat('dd-MMM-yyyy').format(date);
      final formattedDateForTaskPath = DateFormat('yyyy-MM-dd').format(date); // Format for task path

      // Fetch Daily Reports (as before - with logging)
      print("_createTaskSummaryPDF: Fetching REPORTS for date: $formattedDateForReportPath");
      // Fetch Daily Reports
      String reportCollectionPath = 'Reports/$selectedBioState/$selectedBioState/$selectedBioLocation/$formattedDateForReportPath'; // Construct path dynamically
      print("_createTaskSummaryPDF: Report Collection Path: $reportCollectionPath"); // ADDED DEBUG LOG

      QuerySnapshot<Map<String, dynamic>> reportSnapshot = await FirebaseFirestore.instance
          .collection('Reports')
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDateForReportPath)
          .get();
      print("_createTaskSummaryPDF: Number of REPORTS found for $formattedDateForReportPath: ${reportSnapshot.docs.length}");


      List<Report> dailyReports = reportSnapshot.docs
          .map((doc) => Report.fromFirestore(doc, null))
          .where((report) {
        if (report.reportEntries != null) {
          return report.reportEntries!.keys.any((username) => username == _currentUsername);
        }
        return false;
      }).toList();

      reportsByDate[date] = dailyReports; // Store daily reports
      print("_createTaskSummaryPDF: Number of USER REPORTS found for $formattedDateForReportPath: ${dailyReports.length}");

// Fetch Other Tasks for the date (with detailed logging)
      print("_createTaskSummaryPDF: Fetching TASKS for date: $formattedDateForTaskPath"); // ADDED DEBUG LOG
      String taskCollectionPath = 'Reports/$selectedBioState/Task/$selectedBioLocation/$formattedDateForReportPath/$selectedFirebaseId/$selectedFirebaseId'; // Construct path dynamically
      print("_createTaskSummaryPDF: Task Collection Path: $taskCollectionPath"); // ADDED DEBUG LOG

      // Fetch Other Tasks for the date
      QuerySnapshot<Map<String, dynamic>> taskSnapshot = await FirebaseFirestore.instance
          .collection('Reports')
          .doc(selectedBioState)
          .collection('Task')
          .doc(selectedBioLocation)
          .collection(formattedDateForReportPath)
          .doc(selectedFirebaseId)
          .collection(selectedFirebaseId!)
          .get();

      List<Task> dailyTasks = taskSnapshot.docs
          .map((doc) => Task.fromFirestore(doc, null))
          .toList();
      otherTasksByDate[date] = dailyTasks; // Store daily tasks
    }

    if (reportsByDate.isEmpty && otherTasksByDate.isEmpty) {
      return [pw.Center(child: pw.Text("No reports or tasks found for this period."))];
    }

    reportsByDate.forEach((date, dailyReports) {
      summaryDataByDate[date] = {};

      for (Report report in dailyReports) {
        if (report.reportEntries != null) {
          for (var usernameEntry in report.reportEntries!.entries) {
            String username = usernameEntry.key;
            for (var indicatorEntry in usernameEntry.value.entries) {
              String indicatorName = indicatorEntry.key;
              String indicatorValue = indicatorEntry.value.first.value;
              int value = int.tryParse(indicatorValue) ?? 0;

              if (!summaryDataByDate[date]!.containsKey(indicatorName)) {
                summaryDataByDate[date]![indicatorName] = {'Total': 0};
              }

              summaryDataByDate[date]![indicatorName]![username] = value;
              summaryDataByDate[date]![indicatorName]!['Total'] = (summaryDataByDate[date]![indicatorName]!['Total'] as int) + value;
            }
          }
        }
      }
    });

    List<pw.Widget> content = [];

    content.add(pw.Center(
      child: pw.Text(
        "Task Summary for period: ${DateFormat('dd MMMM yyyy').format(startDateOfMonth)} - ${DateFormat('dd MMMM yyyy').format(endDateOfMonth)}", // Dynamic date range
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    ));
    content.add(pw.SizedBox(height: 20));

    // 1. Tabular Summary of Reports
    summaryDataByDate.forEach((date, indicatorData) {
      List<List<String>> tableData = [];
      tableData.add(['Indicator', 'What You Entered', 'Total Value']);

      indicatorData.forEach((indicatorName, userData) {
        String userValue = (userData[_currentUsername]?.toString()) ?? '0'; // Adapt _currentUsername if necessary
        String totalValue = (userData['Total']?.toString()) ?? '0';
        tableData.add([indicatorName, userValue, totalValue]);
      });

      content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10, top: 20),
          child: pw.Text(DateFormat('EEEE, dd MMMM yyyy').format(date), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))));
      content.add(pw.Table.fromTextArray(
          context: null, // Context is not needed here as we are building widgets outside the build method
          border: pw.TableBorder.all(),
          data: tableData,
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
      ));
    });

    // 2. Summary of Other Tasks
    if (otherTasksByDate.isNotEmpty) {
      content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 30),
          child: pw.Text("Summary of Other Tasks:", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));

      otherTasksByDate.forEach((date, taskList) {
        if (taskList.isNotEmpty) {
          content.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5, top: 10),
              child: pw.Text(DateFormat('EEEE, dd MMMM yyyy').format(date), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))));
          for (Task task in taskList) {
            content.add(pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: taskList.map((task) => pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 5, top: 2),
                    child: pw.Text('•'),
                  ),
                  pw.Expanded(
                    child: pw.Text("${task.taskTitle}: ${task.taskDescription}"),
                  ),
                ],
              )).toList(),
            ));
          }
        }
      });
    }
    return content;
  }


  // Modified _buildPdfTaskSummaryPage to be synchronous and accept pre-fetched content
  pw.Widget _buildTaskSummaryPage(pw.MemoryImage logoImage, List<pw.Widget> taskSummaryContent) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: taskSummaryContent // Use the pre-built content directly
    );
  }



  Future<void> sendEmailToSelf1() async {
    String monthYear1 = DateFormat('MMMM_yyyy').format(
        DateTime(selectedYear, selectedMonth + 1));

    final pdf = pw.Document(pageMode: PdfPageMode.outlines);
    String monthYear = DateFormat('MMMM, yyyy').format(
        DateTime(selectedYear, selectedMonth + 1));
    // A4 page in landscape mode
    final pageFormat = PdfPageFormat.a4.landscape;

    try {
      // Fetch supervisor names and signature columns
      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);

      // Load the image as bytes
      final logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

      // Add content to a single page
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Staff Information and Logo Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStaffInfo(context),
                    pw.Column(
                        children: [
                          pw.Text("CARITAS NIGERIA", style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 20),),
                          pw.SizedBox(height: 10,),
                          pw.Text("Monthly Time Report ($monthYear)")
                        ]
                    ),
                    pw.Container(
                      child: pw.Image(
                        logoImage,
                        width: 50, // Adjust width
                        height: 50, // Adjust height
                      ),
                    ),
                  ],
                ),

                // Timesheet Table Section
                pw.SizedBox(height: 10), // Adjust spacing
                _buildTimesheetTable(context),

                // Signature Section
                pw.SizedBox(height: 10), // Adjust spacing
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );

      // Save and open the PDF
      // final output = await getTemporaryDirectory();
      // final file = File("${output.path}/timesheet.pdf");
      // await file.writeAsBytes(await pdf.save());
      // await OpenFilex.open(file.path);


    } catch (e) {
      print("Error generating PDF: $e");
      // Handle the error, e.g., show a dialog to the user
    }

    // Clear the attachments list before adding new attachments
    attachments.clear();

    // 2. Save the PDF to a temporary file
    final tempDir = await getTemporaryDirectory();
    final pdfFile = File('${tempDir
        .path}/Timesheet_${monthYear1}_${selectedBioFirstName}_$selectedBioLastName.pdf');
    await pdfFile.writeAsBytes(await pdf.save());

    // 3. Add the PDF file path to attachments
    attachments.add(pdfFile.path);


    final Email email = Email(
      body: '''
Greetings $selectedBioFirstName,

Please find attached your timesheet for $monthYear.

Best regards,
$selectedBioFirstName $selectedBioLastName

''',
      subject: 'Timesheet for $selectedBioFirstName $selectedBioLastName ,$monthYear',
      recipients: [selectedBioEmail!],
      attachmentPaths: attachments,
      isHTML: isHTML,
    );
    String platformResponse;

    try {
      await FlutterEmailSender.send(email);
      platformResponse = 'success';
    } catch (error) {
      print(error);
      platformResponse = error.toString();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(platformResponse, style: TextStyle(fontSize: 14 * fontSizeFactor)),
      ),
    );
  }

  Future<void> sendEmailToSelf() async {
    String monthYear1 =
    DateFormat('MMMM_yyyy').format(DateTime(selectedYear, selectedMonth + 1));

    final pdf = pw.Document(pageMode: PdfPageMode.outlines);
    String monthYear =
    DateFormat('MMMM, yyyy').format(DateTime(selectedYear, selectedMonth + 1));
    final pageFormat = PdfPageFormat.a4.landscape;

    try {
      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);
      final logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStaffInfo(context),
                    pw.Column(children: [
                      pw.Text("CARITAS NIGERIA",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 20 * pdfTitleFontSizeFactor)), // Reduced title size
                      pw.SizedBox(
                        height: 10,
                      ),
                      pw.Text("Monthly Time Report ($monthYear)",
                          style: pw.TextStyle(
                              fontSize: 14 * pdfHeaderFontSizeFactor)) // Reduced header size
                    ]),
                    pw.Container(
                      child: pw.Image(
                        logoImage,
                        width: 50,
                        height: 50,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                _buildStaffInfo(context),
                pw.SizedBox(height: 10),
                _buildTimesheetTable(context),
                pw.SizedBox(height: 10),
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );

      Uint8List pdfBytes = await pdf.save();

      attachments.clear();

      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      attachments.add(url);

      final Email email = Email(
        body: '''
Greetings $selectedBioFirstName,

Please find attached your timesheet for $monthYear.
**(WARNING: Direct PDF attachment in this web version may not work as expected due to browser limitations and library constraints.  If the attachment fails, please use the 'Save PDF' button to download the timesheet separately.)**

Best regards,
$selectedBioFirstName $selectedBioLastName
''',
        subject:
        'Timesheet for $selectedBioFirstName $selectedBioLastName, $monthYear (Attempted PDF Attachment - Web Version)',
        recipients: [selectedBioEmail!],
        attachmentPaths: attachments,
        isHTML: isHTML,
      );
      String platformResponse;

      try {
        await FlutterEmailSender.send(email);
        platformResponse = 'success';
      } catch (error) {
        print("Error sending email (attachment may have failed): $error");
        platformResponse = error.toString();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(platformResponse,
              style: TextStyle(fontSize: 14 * fontSizeFactor)),
        ),
      );
      Fluttertoast.showToast(
        msg:
        "Email sent. Please check if PDF attachment is present (Attachment may fail in web version).",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print("Error generating PDF for email: $e");
      Fluttertoast.showToast(
        msg: "Error generating PDF for email: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }


  Future<Map<String, String>> _getSupervisorNames1() async {
    try {
      String monthYear = DateFormat('MMMM_yyyy').format(
          DateTime(selectedYear, selectedMonth + 1));
      final timesheetDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(monthYear)
          .get();

      if (timesheetDoc.exists) {
        final data = timesheetDoc.data() as Map<String, dynamic>;
        return {
          'staffName': data['staffName'] as String? ?? 'Not Assigned',
          'projectCoordinatorName': data['facilitySupervisor'] as String? ??
              'Not Assigned',
          'caritasSupervisorName': data['caritasSupervisor'] as String? ??
              'Not Assigned',
          'projectCoordinatorSignature': data['facilitySupervisorSignature'] as String? ??
              '', // Get signature URLs
          'caritasSupervisorSignature': data['caritasSupervisorSignature'] as String? ??
              '',
          'staffSignature': data['staffSignature'] as String? ?? '',
          'staffSignatureDate': data['staffSignatureDate'] as String? ?? '',
          'facilitySupervisorSignatureDate': data['facilitySupervisorSignatureDate'] as String? ??
              '',
          'caritasSupervisorSignatureDate': data['caritasSupervisorSignatureDate'] as String? ??
              '',
        };
      } else {
        return {
          'staffName': 'Not Assigned',
          'projectCoordinatorName': 'Not Assigned',
          'caritasSupervisorName': 'Not Assigned',
          'projectCoordinatorSignature': '',
          'caritasSupervisorSignature': '',
          'staffSignature': '',
          'staffSignatureDate': '',
          'facilitySupervisorSignatureDate': '',
          'caritasSupervisorSignatureDate': '',
        };
      }
    } catch (e) {
      print("Error fetching supervisor data: $e");
      return {
        'staffName': 'Error fetching name',
        'projectCoordinatorName': 'Error fetching name',
        'caritasSupervisorName': 'Error fetching name',
        'projectCoordinatorSignature': '',
        'caritasSupervisorSignature': '',
        'staffSignature': '',
        'staffSignatureDate': '',
        'facilitySupervisorSignatureDate': '',
        'caritasSupervisorSignatureDate': '',
      };
    }
  }

  Future<Map<String, String>> _getSupervisorNames() async {
    try {
      // CHANGED: Uses the helper getter for the correct document ID
      final timesheetDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(_timesheetDocId)
          .get();

      if (timesheetDoc.exists) {
        final data = timesheetDoc.data() as Map<String, dynamic>;
        return {
          'staffName': data['staffName'] as String? ?? 'Not Assigned',
          'projectCoordinatorName': data['facilitySupervisor'] as String? ?? 'Not Assigned',
          'caritasSupervisorName': data['caritasSupervisor'] as String? ?? 'Not Assigned',
          'projectCoordinatorSignature': data['facilitySupervisorSignature'] as String? ?? '',
          'caritasSupervisorSignature': data['caritasSupervisorSignature'] as String? ?? '',
          'staffSignature': data['staffSignature'] as String? ?? '',
          'staffSignatureDate': data['staffSignatureDate'] as String? ?? '',
          'facilitySupervisorSignatureDate': data['facilitySupervisorSignatureDate'] as String? ?? '',
          'caritasSupervisorSignatureDate': data['caritasSupervisorSignatureDate'] as String? ?? '',
        };
      } else {
        // Return default values if the document doesn't exist
        return {
          'staffName': 'Not Assigned',
          'projectCoordinatorName': 'Not Assigned',
          'caritasSupervisorName': 'Not Assigned',
          'projectCoordinatorSignature': '',
          'caritasSupervisorSignature': '',
          'staffSignature': '',
          'staffSignatureDate': '',
          'facilitySupervisorSignatureDate': '',
          'caritasSupervisorSignatureDate': '',
        };
      }
    } catch (e) {
      print("Error fetching supervisor data: $e");
      // Return error values
      return {
        'staffName': 'Error fetching name',
        'projectCoordinatorName': 'Error fetching name',
        'caritasSupervisorName': 'Error fetching name',
        'projectCoordinatorSignature': '',
        'caritasSupervisorSignature': '',
        'staffSignature': '',
        'staffSignatureDate': '',
        'facilitySupervisorSignatureDate': '',
        'caritasSupervisorSignatureDate': '',
      };
    }
  }



  pw.Widget _buildStaffInfo(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Name: $selectedBioFirstName $selectedBioLastName',
            style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
        pw.Text('Department: $selectedBioDepartment',
            style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
        pw.Text('Designation: $selectedBioDesignation',
            style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
        pw.Text('Location: $selectedBioLocation',
            style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
        pw.Text('State: $selectedBioState',
            style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildTimesheetTable1(pw.Context context) {
    final tableHeaders = [
      'Project Name',
      ...daysInRange.map((date) => DateFormat('dd').format(date)),
      'Total Hours',
      '%'
    ];

    List<List<String>> allRows = [];

    final projectData = [
      selectedProjectName ?? '',
      ...daysInRange.map((date) {
        return _getDurationForDate3(
            date, selectedProjectName, selectedProjectName!)
            .round()
            .toString();
      }),
      '0',
      '0%'
    ];
    allRows.add(projectData);

    final outOfOfficeCategories = [
      'Annual leave',
      'Holiday',
     // 'Paternity',
      'Maternity'
    ];
    final outOfOfficeData = outOfOfficeCategories.map((category) {
      final rowData = [
        category,
        ...daysInRange.map((date) {
          return _getDurationForDate3(date, selectedProjectName, category)
              .round()
              .toString();
        }),
        '0',
        '0%'
      ];
      allRows.add(rowData);
      return rowData;
    }).toList();

    for (List<String> row in allRows) {
      double rowTotal = 0;
      for (int i = 1; i <= daysInRange.length; i++) {
        rowTotal += double.tryParse(row[i]) ?? 0;
      }
      row[daysInRange.length + 1] = rowTotal.round().toString();

      int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
      double percentage = (workingDays * 8) != 0
          ? (rowTotal / (workingDays * 8)) * 100
          : 0;
      row[daysInRange.length + 2] = '${percentage.round()}%';
    }

    List<String> totalRow = [
      'Total',
      ...List.generate(daysInRange.length, (index) => '0'),
      '0',
      '0%'
    ];
    for (int i = 1; i <= daysInRange.length; i++) {
      double dayTotal = 0;
      for (List<String> row in allRows) {
        dayTotal += double.tryParse(row[i]) ?? 0.0;
      }
      totalRow[i] = dayTotal.round().toString();
    }

    int grandTotalHours = 0;
    for (int i = 1; i <= daysInRange.length; i++) {
      grandTotalHours += int.parse(totalRow[i]);
    }
    totalRow[daysInRange.length + 1] = grandTotalHours.toString();

    int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
    double grandPercentage = (workingDays * 8) > 0
        ? (grandTotalHours / (workingDays * 8)) * 100
        : 0;
    totalRow[daysInRange.length + 2] = '${grandPercentage.round()}%';

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(250),
        for (int i = 1; i <= daysInRange.length; i++)
          i: const pw.FixedColumnWidth(80),
        daysInRange.length + 1: const pw.FixedColumnWidth(200),
        daysInRange.length + 2: const pw.FixedColumnWidth(200),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: tableHeaders
              .map((header) => pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12 * pdfHeaderFontSizeFactor), // Reduced header size
              ),
            ),
          ))
              .toList(),
        ),
        ...allRows.map((rowData) {
          return pw.TableRow(
            children: rowData
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final data = entry.value;
              final isWeekendColumn =
                  i > 0 && i <= daysInRange.length && isWeekend(daysInRange[i - 1]);

              return pw.Container(
                color: isWeekendColumn ? PdfColors.grey900 : null,
                padding: const pw.EdgeInsets.all(1.0),
                alignment: pw.Alignment.center,
                child: pw.Text(data,
                    style: pw.TextStyle(fontSize: 10 * pdfTableFontSizeFactor)), // Reduced table text size
              );
            }).toList(),
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: totalRow
              .map((data) => pw.Center(
              child: pw.Padding(
                  padding: const pw.EdgeInsets.all(1.0),
                  child: pw.Text(data,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12 * pdfHeaderFontSizeFactor))))) // Reduced header size
              .toList(),
        ),
      ],
    );
  }

  pw.Widget _buildTimesheetTable(pw.Context context) {
    // Data for the table
    final tableHeaders = [
      'Project Name',
      ...daysInRange.map((date) => DateFormat('dd').format(date)),
      'Total Hours',
      '%'
    ];

    List<List<String>> allRows = []; // List to hold all rows



    // Project Data Row
    final projectData = [
      selectedProjectName ?? '',
      ...daysInRange.map((date) {
        return isWeekend(date) ? '0' : _getDurationForDate3(
            date, selectedProjectName, selectedProjectName!)
            .round()
            .toString(); // No rounding here
      }),
      // calculateTotalHours1(selectedProjectName).toStringAsFixed(2),  // Calculate total for project, 2 decimal places
      // '${calculatePercentageWorked1(selectedProjectName).toStringAsFixed(2)}%'
      //  calculateTotalHours1(selectedProjectName).round().toString(), // Round total hours
      // '${calculatePercentageWorked1(selectedProjectName).round()}%' // Round percentage
      // Total hours and percentage will be calculated later based on rounded values
      '0',
      // Placeholder for Total Hours
      '0%'
      // Placeholder for Percentage


    ];
    allRows.add(projectData); // Add project data to allRows

    // Out-of-office Rows
    final outOfOfficeCategories = [
      'Annual leave',
      'Holiday',
      // 'Paternity',
      'Maternity'
    ];
    final outOfOfficeData = outOfOfficeCategories.map((category) {
      final rowData = [
        category,
        ...daysInRange.map((date) {
          return isWeekend(date) ? '0' : _getDurationForDate3(date, selectedProjectName, category)
              .round()
              .toString(); // No rounding here
        }),
        // calculateCategoryHours(category).toStringAsFixed(2), // Calculate total for category, 2 decimal places
        // '${calculateCategoryPercentage(category).toStringAsFixed(1)}%'
        // calculateCategoryHours(category).round().toString(),  // Round category hours
        // '${calculateCategoryPercentage(category).round()}%' // Round percentage
        '0',
        // Placeholder for Total Hours
        '0%'
        // Placeholder for Percentage
      ];
      allRows.add(rowData); // Add each category row to allRows
      return rowData;
    }).toList();

    // Now calculate totals AFTER rounding for ALL rows (including project data)
    for (List<String> row in allRows) {
      double rowTotal = 0;
      for (int i = 1; i <=
          daysInRange.length; i++) { // Sum the rounded daily hours
        rowTotal += double.tryParse(row[i]) ?? 0;
      }

      row[daysInRange.length + 1] =
          rowTotal.round().toString(); // Rounded total hours

      int workingDays = daysInRange
          .where((date) => !isWeekend(date))
          .length;
      double percentage = (workingDays * 8) != 0 ? (rowTotal /
          (workingDays * 8)) * 100 : 0;
      row[daysInRange.length + 2] =
      '${percentage.round()}%'; // Rounded percentage
    }


    // Total Row Calculation (rounding to whole numbers)
    List<String> totalRow = [
      'Total',
      ...List.generate(daysInRange.length, (index) => '0'),
      '0',
      '0%'
    ];
    for (int i = 1; i <= daysInRange.length; i++) { // Iterate over day columns
      double dayTotal = 0; // Use double to accumulate, round later
      for (List<String> row in allRows) {
        if (!isWeekend(daysInRange[i-1])) { // <---- ADDED WEEKEND CHECK HERE
          dayTotal += double.tryParse(row[i]) ?? 0.0;
        }
      }
      totalRow[i] =
          dayTotal.round().toString(); // Round day total before storing
    }

    // Calculate grand total and percentage (using rounded day totals)
    int grandTotalHours = 0;
    for (int i = 1; i <= daysInRange.length; i++) {
      grandTotalHours += int.parse(totalRow[i]);
    }
    totalRow[daysInRange.length + 1] =
        grandTotalHours.toString(); // Grand total

    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double grandPercentage = (workingDays * 8) > 0 ? (grandTotalHours /
        (workingDays * 8)) * 100 : 0;
    totalRow[daysInRange.length + 2] =
    '${grandPercentage.round()}%'; // Round percentage


    // Build the table
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(250),
        for (int i = 1; i <= daysInRange.length; i++) i: const pw
            .FixedColumnWidth(80),
        // Fixed width for date columns
        daysInRange.length + 1: const pw.FixedColumnWidth(200),
        // Fixed width for "Total Hours"
        daysInRange.length + 2: const pw.FixedColumnWidth(200),
        // Fixed width for "Percentage"
      },
      children: [
        // Header row

        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: tableHeaders
              .map((header) => pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11 * pdfHeaderFontSizeFactor), // Reduced header size
              ),
            ),
          ))
              .toList(),
        ),


        // Combined loop for project and out-of-office rows, including Total row:
        ...allRows.map((rowData) {
          return pw.TableRow(
            children: rowData
                .asMap()
                .entries
                .map((entry) { // Use asMap().entries to get index
              final i = entry.key;
              final data = entry.value;
              final isWeekendColumn = i > 0 && i <= daysInRange.length &&
                  isWeekend(daysInRange[i - 1]);

              return pw.Container(
                color: isWeekendColumn ? PdfColors.grey900 : null,
                padding: const pw.EdgeInsets.all(1.0),
                alignment: pw.Alignment.center,
                child: pw.Text(data,
                    style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
              );
            }).toList(),
          );
        }),


        // Total Row (updated to use rounded values)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: totalRow.map((data) => pw.Center(child: pw.Padding(
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.Text(data,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 12 * pdfHeaderFontSizeFactor)))))
              .toList(),
        ),
      ],
    );
  }



  Future<Uint8List?> networkImageToByte(String imageUrl) async {
    try {
      final response = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } catch (e) {
      print('Error fetching image: $e');
      return null;
    }
  }

  Future<List<pw.Widget>> _buildSignatureColumns(
      Map<String, String> supervisorData) async {
    final staffSig =
    (supervisorData['staffSignature'] != null && supervisorData['staffSignature']!.isNotEmpty)
        ? await networkImageToByte(supervisorData['staffSignature']!)
        : await networkImageToByte(staffSignatureLink!);

    final coordSig = (supervisorData['projectCoordinatorSignature'] != null &&
        supervisorData['projectCoordinatorSignature']!.isNotEmpty)
        ? await networkImageToByte(supervisorData['projectCoordinatorSignature']!)
        : null;

    final caritasSig = (supervisorData['caritasSupervisorSignature'] != null &&
        supervisorData['caritasSupervisorSignature']!.isNotEmpty)
        ? await networkImageToByte(supervisorData['caritasSupervisorSignature']!)
        : null;

    final staffName =
    '${selectedBioFirstName?.toUpperCase() ?? 'UNKNOWN'} ${selectedBioLastName?.toUpperCase() ?? ''}'
        .trim();
    final projectCoordinatorName =
        supervisorData['projectCoordinatorName']?.toUpperCase() ?? 'UNKNOWN';
    final caritasSupervisorName =
        supervisorData['caritasSupervisorName']?.toUpperCase() ?? 'UNKNOWN';

    final staffSignatureDate = supervisorData['staffSignatureDate'] ?? formattedDate;
    final facilitySupervisorSignatureDate =
        supervisorData['facilitySupervisorSignatureDate'] ?? 'UNKNOWN';
    final caritasSupervisorSignatureDate =
        supervisorData['caritasSupervisorSignatureDate'] ?? 'UNKNOWN';

    return [
      _buildSingleSignatureColumn(
          'Name of Staff', staffName, staffSig, staffSignatureDate),
      _buildSingleSignatureColumn('Name of Project Coordinator',
          projectCoordinatorName, coordSig, facilitySupervisorSignatureDate),
      _buildSingleSignatureColumn('Name of Caritas Supervisor',
          caritasSupervisorName, caritasSig, caritasSupervisorSignatureDate),
    ];
  }

  pw.Widget _buildSingleSignatureColumn(
      String title, String name, Uint8List? imageBytes, String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12 * pdfSignatureFontSizeFactor)), // Reduced signature section size
        pw.SizedBox(height: 10),
        pw.Text(name,
            style: pw.TextStyle(fontSize: 12 * pdfSignatureFontSizeFactor)), // Reduced signature section size
        pw.SizedBox(height: 10),
        pw.Container(
          height: 100 * pdfSignatureFontSizeFactor, // Reduced signature section size
          width: 150 * pdfSignatureFontSizeFactor, // Reduced signature section size
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Center(
            child: imageBytes != null
                ? pw.Image(pw.MemoryImage(imageBytes))
                : pw.Text("Signature",
                style: pw.TextStyle(fontSize: 10 * pdfSignatureFontSizeFactor)), // Reduced signature section size
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text("Date: $date",
            style: pw.TextStyle(fontSize: 12 * pdfSignatureFontSizeFactor)), // Reduced signature section size
      ],
    );
  }

  pw.Widget _buildSignatureSection(
      pw.Context context, List<pw.Widget> signatureColumns) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Signature & Date',
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 16 * pdfHeaderFontSizeFactor)), // Further reduced signature header size
      pw.Divider(),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: signatureColumns,
      ),
    ]);
  }

  // <<<--- MODIFIED: Updated to use the new capping method ---<<<
  String _getDurationForDate2(DateTime date, String? projectName, String category) {
    double totalHoursForDate = 0;
    // Use the new helper to get the maximum allowed hours for the specific day.
    double maxHours = _getMaximumHoursForDay(date);

    for (var attendance in attendanceData) {
      try {
        // The date from Firestore is already the doc ID 'dd-MMMM-yyyy'
        DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          double hours = attendance.noOfHours ?? 0;
          if (category == projectName && !attendance.offDay!) {
            // Apply the dynamic cap (now 8.0)
            totalHoursForDate += hours > maxHours ? maxHours : hours;
          } else if (attendance.offDay! &&
              attendance.durationWorked?.toLowerCase() == category.toLowerCase()) {
            // Also apply the dynamic cap for off-days.
            totalHoursForDate += hours > maxHours ? maxHours : hours;
          }
        }
      } catch (e) {
        print("Error parsing date or calculating hours: $e");
      }
    }
    return totalHoursForDate.toStringAsFixed(2);
  }

  double _getDurationForDate3(DateTime date, String? projectName,
      String category) {
    double totalHoursForDate = 0;
    for (var attendance in attendanceData) {
      try {
        DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
            attendance.date!);
        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          if (category == projectName && !attendance.offDay!) {
            double hours = attendance.noOfHours ?? 0; // Null-safe access
            totalHoursForDate += hours > 8.0 ? 8.0 : hours; // Applying the cap
          } else if (attendance.offDay! &&
              attendance.durationWorked?.toLowerCase() ==
                  category.toLowerCase()) {
            double hours = attendance.noOfHours ?? 0; // Null-safe access
            totalHoursForDate +=
            hours > 8.0 ? 8.0 : hours; // Cap for off-days too
          }
        }
      } catch (e) {
        print("Error parsing date or calculating hours: $e");
      }
    }
    return totalHoursForDate;
  }

  // <<<--- MODIFIED: Updated to use the new capping method ---<<<
  double _getCappedHoursForDate(DateTime date, String? projectName, String category) {
    double totalHoursForDate = 0;
    // Use the new helper to get the maximum allowed hours for the specific day.
    double maxHours = _getMaximumHoursForDay(date);

    for (var attendance in attendanceData) {
      try {
        DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          double hours = attendance.noOfHours ?? 0.0;
          if (category == projectName && !attendance.offDay!) {
            // Apply the dynamic cap (8.0).
            totalHoursForDate += hours > maxHours ? maxHours : hours;
          } else if (attendance.offDay! &&
              attendance.durationWorked?.toLowerCase() == category.toLowerCase()) {
            // Also apply the dynamic cap for off-days.
            totalHoursForDate += hours > maxHours ? maxHours : hours;
          }
        }
      } catch (e) {
        print("Error parsing date or calculating hours: $e");
      }
    }
    return totalHoursForDate;
  }


// Updated function to calculate total hours for a project (with capping)
  double calculateTotalHours1(String? projectName) {
    if (projectName == null) return 0; // Handle null projectName
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        totalHours += _getCappedHoursForDate(
            date, projectName, projectName); // Use helper function
      }
    }
    return totalHours;
  }

// Updated function to calculate total hours for a category (with capping)
  double calculateCategoryHours1(String category) {
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        totalHours += _getCappedHoursForDate(
            date, selectedProjectName, category); // Use helper function
      }
    }
    return totalHours;
  }


  double calculateTotalHours2(String? projectName) {
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        totalHours +=
            double.parse(_getDurationForDate2(date, projectName, projectName!));
      }
    }
    return totalHours;
  }

  // double calculatePercentageWorked1(String? projectName) {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
  //   double totalHours = calculateTotalHours1(projectName);
  //   return (workingDays * 8) != 0 ? (totalHours / (workingDays * 8)) * 100 : 0;
  // }

  // Updated percentage calculation for a project (using capped hours)
  double calculatePercentageWorked1(String? projectName) {
    if (projectName == null) return 0; // Handle null projectName
    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double cappedTotalHours = calculateTotalHours1(
        projectName); // Use capped total hours
    return (workingDays * 8) > 0
        ? (cappedTotalHours / (workingDays * 8)) * 100
        : 0;
  }


  // String _getDurationForDate(DateTime date, String? projectName, String category) {
  //   double totalHoursForDate = 0;
  //   for (var attendance in attendanceData) {
  //     try {
  //       DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
  //       if (attendanceDate.year == date.year &&
  //           attendanceDate.month == date.month &&
  //           attendanceDate.day == date.day) {
  //         if (category == projectName && !attendance.offDay!) {
  //           totalHoursForDate += attendance.noOfHours! > 8 ? 8 : attendance.noOfHours!;
  //         } else if (attendance.offDay! && attendance.durationWorked!.toLowerCase() == category.toLowerCase()) {
  //           totalHoursForDate += attendance.noOfHours! > 8 ? 8 : attendance.noOfHours!;
  //         }
  //       }
  //     } catch (e) {
  //       print("Error parsing date or calculating hours: $e"); // More specific error message
  //     }
  //   }
  //   return totalHoursForDate.toStringAsFixed(2); //Removed "hrs", let PDF handle formatting
  // }

  //Modify calculateTotalHours to use the new capped _getDurationForDate
  // int calculateTotalHours() {
  //   int totalHours = 0;
  //   for (var date in daysInRange) {
  //     if (!isWeekend(date)) {
  //       totalHours += int.parse(_getDurationForDate(date, selectedProjectName, selectedProjectName!)); //Parsing to int since _getDurationForDate returns a string now
  //     }
  //   }
  //   return totalHours;
  // }

  // ----------------


  Future<void> _createAndExportExcel() async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];

    // Add header row
    sheet.getRangeByName('A1').setText('Project Name');
    for (int i = 0; i < daysInRange.length; i++) {
      sheet.getRangeByIndex(1, i + 2).setText(
          DateFormat('dd MMM').format(daysInRange[i]));
    }
    sheet.getRangeByName('A${daysInRange.length + 2}').setText('Total Hours');
    // Add data rows (similar to how you build the UI table)
    // Example:
    sheet.getRangeByName('A2').setText(selectedProjectName ?? '');


    for (var i = 0; i < daysInRange.length; i++) {
      bool weekend = isWeekend(daysInRange[i]);
      String hours = _getDurationForDate2(
          daysInRange[i], selectedProjectName, selectedProjectName!);

      sheet.getRangeByIndex(2, i + 2).setText(weekend ? '' : hours);
    }

    sheet.getRangeByName('A${daysInRange.length + 2}').setText(
        '${calculateTotalHours()}');


    // Save and launch the file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final String path = (await getApplicationSupportDirectory()).path;
    final String fileName = '$path/timesheet.xlsx';
    final File file = File(fileName);
    await file.writeAsBytes(bytes, flush: true);
    // OpenFile.open(fileName);
  }


  // Future<void> _createAndExportPDF1() async {
  //   //Create a new PDF document
  //   final PdfDocument document = PdfDocument();
  //   //Add a new page and draw text
  //   document.pages.add().graphics.drawString(
  //       'Hello World!', PdfStandardFont(PdfFontFamily.helvetica, 12));
  //   //Save the document
  //   final List<int> bytes = await document.save();
  //   //Dispose the document
  //   document.dispose();
  //
  //
  //   final String path = (await getApplicationSupportDirectory()).path;
  //   final String fileName = '$path/timesheet.pdf';
  //   final File file = File(fileName);
  //   await file.writeAsBytes(bytes, flush: true);
  //   OpenFile.open(fileName);
  //
  // }

  // Future<void> _createAndExportPDF() async {
  //   final PdfDocument document = PdfDocument();
  //
  //   // Add a page and set it to landscape orientation
  //   final PdfPage page = document.pages.add();
  //   final PdfGraphics graphics = page.graphics;
  //
  //   // Rotate the content for landscape layout
  //   graphics.translateTransform(page.size.height, 0);
  //   graphics.rotateTransform(90);
  //
  //   final PdfGrid grid = PdfGrid();
  //
  //   // Define grid columns
  //   grid.columns.add(count: daysInRange.length + 2); // +2 for Project Name and Total Hours
  //
  //
  //   // Add header row without the month
  //   final PdfGridRow headerRow = grid.headers.add(1)[0];
  //   headerRow.cells[0].value = 'Project Name';
  //   for (int i = 0; i < daysInRange.length; i++) {
  //     headerRow.cells[i + 1].value = DateFormat('dd').format(daysInRange[i]); // Only day
  //   }
  //   headerRow.cells[daysInRange.length + 1].value = 'Total';
  //   headerRow.style.backgroundBrush = PdfBrushes.lightGray; // Optional: highlight header
  //
  //   // Populate data rows with rounded hours
  //   PdfGridRow projectRow = grid.rows.add();
  //   projectRow.cells[0].value = selectedProjectName;
  //   for (int i = 0; i < daysInRange.length; i++) {
  //     double duration = _getDurationForDate1(daysInRange[i], selectedProjectName, selectedProjectName!);
  //     projectRow.cells[i + 1].value = duration.round().toString(); // Rounded hours
  //   }
  //   projectRow.cells[daysInRange.length + 1].value = calculateTotalHours().round().toString(); // Rounded total
  //
  //   // Add out-of-office rows for categories
  //   for (final category in [
  //     'Absent', 'Annual leave', 'Holiday', 'Other Leaves', 'Security Crisis',
  //     'Sick leave', 'Remote working', 'Sit at home', 'Trainings', 'Travel'
  //   ]) {
  //     PdfGridRow row = grid.rows.add();
  //     row.cells[0].value = category;
  //     for (int i = 0; i < daysInRange.length; i++) {
  //       double duration = _getDurationForDate1(daysInRange[i], selectedProjectName, category);
  //       row.cells[i + 1].value = duration.round().toString(); // Now this works as duration is a double
  //     }
  //     double categoryHours = calculateCategoryHours(category).roundToDouble();
  //     row.cells[daysInRange.length + 1].value = categoryHours.toInt().toString(); // Ensure this is a double too
  //   }
  //
  //   // Add a row for the grand total
  //   PdfGridRow totalRow = grid.rows.add();
  //   totalRow.cells[0].value = "Total";
  //   totalRow.cells[daysInRange.length + 1].value = calculateGrandTotalHours().round().toString(); // Rounded grand total
  //
  //   // Set grid to fit the page width for landscape layout
  //   final double gridWidth = page.size.height - 0.02; // Use height as width after rotation
  //   final double gridHeight = page.size.width - 0.02; // Use width as height after rotation
  //   grid.style = PdfGridStyle(
  //     cellPadding: PdfPaddings(left: 2, top: 2, right: 2, bottom: 2),
  //     font: PdfStandardFont(PdfFontFamily.helvetica, 10),
  //   );
  //
  //   for (int i = 0; i < grid.columns.count; i++) {
  //     grid.columns[i].width = 30; // Or another fixed width
  //   }
  //   // Draw the grid within adjusted bounds
  //   grid.draw(page: page, bounds: Rect.fromLTWH(10, 0, gridHeight, gridWidth)); // Adjust bounds
  //
  //  // grid.draw(page: page, bounds: Rect.fromLTWH(0, 0, page.size.height, page.size.width));
  //
  //   // Save and open the PDF
  //   final List<int> bytes = await document.save();
  //   document.dispose();
  //   final String path = (await getApplicationSupportDirectory()).path;
  //   final String fileName = '$path/timesheet.pdf';
  //   final File file = File(fileName);
  //   await file.writeAsBytes(bytes, flush: true);
  //   OpenFile.open(fileName);
  // }

  // Example of how to calculate total content width (you'll need to adapt this)
  double totalContentWidth() {
    // Example: If each column has a width of 300 and you have 3 columns:
    int numberOfColumns = 300; // Replace with actual number of your columns
    double columnWidth = 3000; // Replace with actual your column width
    return numberOfColumns * columnWidth; // Example implementation

  }

// Calculate scrollable width

  double calculateScrollableWidth(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is RenderBox) {
      return box.size.width; // Use the RepaintBoundary's width directly since
      // we're manually scrolling with ScrollController.
    }
    return 0;
  }


  // Future<void> _createAndExportPDF() async {
  //   try {
  //     final RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  //     final context = _globalKey.currentContext!;
  //
  //     // Get dimensions
  //     final totalWidth = context.size!.width; // Use context.size for visible width
  //     final totalHeight = boundary.size.height;
  //
  //     final pdf = pw.Document();
  //     List<ui.Image> images = [];
  //     double currentScrollOffset = 0;
  //
  //
  //     while (currentScrollOffset < calculateScrollableWidth(context)) { // corrected condition
  //       // Scroll
  //       await _scrollController.animateTo(
  //         currentScrollOffset,
  //         duration: Duration(milliseconds: 300),
  //         curve: Curves.linear,
  //       );
  //       await Future.delayed(Duration(milliseconds: 200)); // short delay
  //
  //       // Capture image
  //       ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  //       images.add(image);
  //
  //       currentScrollOffset += context.size!.width;
  //     }
  //
  //     for (var image in images) {
  //       final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  //       final pngBytes = byteData!.buffer.asUint8List();
  //
  //       pdf.addPage(pw.Page(
  //           build: (pw.Context context) => pw.Center(child: pw.FittedBox(
  //             fit: pw.BoxFit.contain,
  //             child: pw.Image(pw.MemoryImage(pngBytes)),
  //           ))
  //       ));
  //     }
  //
  //     final output = await getExternalStorageDirectory();
  //     final file = File("${output?.path}/timesheet.pdf");
  //     await file.writeAsBytes(await pdf.save()); // Corrected line
  //     // Open the PDF file
  //     await OpenFilex.open(file.path);
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('PDF saved to: ${file.path}')),
  //     );
  //
  //   } catch (e) {
  //     print("Error generating PDF: $e");
  //     // Handle error (e.g., show a dialog)
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error generating PDF')),
  //     );
  //   }
  // }



  Future<void> _loadAttendanceData1() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid; // Get the logged-in user ID

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('Record')
          .get();

      List<AttendanceModel> fetchedAttendance = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['date'] = doc.id; // Store the document name (date) in the data map
        return AttendanceModel.fromJson(data); // Convert to AttendanceModel
      }).toList();

      setState(() {
        attendanceData = fetchedAttendance; // Assign the list of AttendanceModel
      });

      if (attendanceData.isEmpty) {
        print("No attendance records found for user: $userId");
      }
    } catch (e) {
      print("Error loading attendance data: $e");
    }
  }


  Future<void> _loadAttendanceData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('Record')
          .get();

      List<AttendanceModel> fetchedAttendance = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data();
          // Correctly handle potential integer values for 'offDay'
          if (data['offDay'] is int) {
            data['offDay'] = data['offDay'] == 1; // Convert 1/0 to true/false
          }
          data['date'] = doc.id;
          fetchedAttendance.add(AttendanceModel.fromJson(data));
        } catch (e) {
          print("Error loading attendance record for date ${doc.id}: $e");
          // Optionally, show a toast or snackbar to inform the user about skipped records
        }
      }


      setState(() {
        attendanceData = fetchedAttendance;
      });

      if (attendanceData.isEmpty) {
        print("No attendance records found for user: $userId");
      }
    } catch (e) {
      print("Error loading attendance data: $e");
    }
  }

  double _getDurationForDate1(DateTime date, String? projectName,
      String category) {
    double totalHoursForDate = 0;

    for (var attendance in attendanceData) {
      try {
        DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
            attendance.date!);

        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          if (category == projectName) {
            if (!attendance.offDay!) {
              totalHoursForDate += attendance.noOfHours ?? 0; // Null-safe access
            }
          } else {
            if (attendance.offDay! &&
                attendance.durationWorked?.toLowerCase() ==
                    category.toLowerCase()) {
              totalHoursForDate += attendance.noOfHours ?? 0; // Null-safe access
            }
          }
        }
      } catch (e) {
        print("Error parsing date: $e");
      }
    }

    // Return the total hours as a double
    return totalHoursForDate; // Change here
  }


  Future<void> _loadSupervisorNames(String department, String state) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(state) // Get the state document
          .collection(state) // Access the sub-collection named after the state
          .where('department', isEqualTo: department) // Filter by department
          .get();

      List<String> fetchedSupervisors = querySnapshot.docs.map((doc) {
        return doc['supervisor'] as String; // Extract supervisor name
      }).toList();

      setState(() {
        supervisorNames = fetchedSupervisors; // Update the supervisor names
      });

      if (supervisorNames.isEmpty) {
        print("No supervisors found for department: $department, state: $state");
      }else{
        print("Supervisors found for department: $department, state: $state");
      }
    } catch (e) {
      print("Error loading supervisors: $e");
    }
  }


  Future<void> _loadProjectNames() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
      await FirebaseFirestore.instance.collection('Project').get();

      List<String> fetchedProjectNames = querySnapshot.docs.map((doc) => doc.id).toList();

      if (fetchedProjectNames.isNotEmpty) {
        setState(() {
          projectNames = fetchedProjectNames;
          selectedProjectName = projectNames[0]; // Select the first project initially
        });
      } else {
        print("No projects found in Firestore.");
      }
    } catch (e) {
      print("Error loading project names: $e");
    }
  }

  Future<void> _loadBioData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid; // Get the user UUID

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data()!;
        setState(() {
          selectedBioFirstName = data['firstName'] ?? '';
          selectedBioLastName = data['lastName'] ?? '';
          selectedBioDepartment = data['department'] ?? '';
          selectedBioState = data['state'] ?? '';
          selectedBioDesignation = data['designation'] ?? '';
          selectedBioLocation = data['location'] ?? '';
          selectedBioStaffCategory = data['staffCategory'] ?? '';
          selectedBioEmail = data['emailAddress'] ?? '';
          selectedBioPhone = data['mobile'] ?? '';
          staffSignatureLink = data['signatureLink'] ?? '';
          selectedFirebaseId = userId; // Store the Firebase UUID
          bioData = BioModel.fromJson(data); // Assign bioData here
          if (bioData!.firstName != null && bioData!.lastName != null) {
            _currentUsername = "${bioData!.firstName!} ${bioData!.lastName!}";
          } else {
            _currentUsername = "Unknown User";
          }
        });


      } else {
        print("No bio data found for user ID: $userId");
        _showErrorToast("No bio data found for user. Please ensure your profile is complete.");
      }
    } catch (e) {
      print("Error loading bio data: $e");
      _showErrorToast("Error loading bio data. Please check your internet connection.");
    } finally {
      if (mounted) { // Check if the widget is still mounted before setting state
        setState(() {
          _pageLoading = false; // Ensure loading stops even on error
        });
      }
    }
  }



  Future<void> getDateFromUser() async {
    DateTime? pickerDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2090),
    );

    if (pickerDate != null) {
      setState(() {
        selectedDate = pickerDate;
      });
    } else {
      print("It's null or something is wrong");
    }
  }


  void initializeDateRange1(int month, int year) {
    DateTime selectedMonthDate = DateTime(year, month + 1, 1);
    startDate = DateTime(selectedMonthDate.year, selectedMonthDate.month - 1,
        20); //Start from the 19th of previous month
    endDate = DateTime(selectedMonthDate.year, selectedMonthDate.month,
        19); //End on the 20th of current month


    daysInRange = [];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      daysInRange.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
  }

  void initializeDateRange(int month, int year) {
    // month is 0-indexed (0=Jan, 8=Sep, 9=Oct)

    // Update the UI state to show/hide the September part selector
    setState(() {
      _isSeptemberSelected = (month == 8);
      // If the newly selected month is not September, reset the part to its default
      if (!_isSeptemberSelected) {
        _selectedTimesheetPart = 1;
      }
    });

    if (month == 8) { // Special case: September (FY End)
      if (_selectedTimesheetPart == 1) {
        // Part 1: August 20th to September 19th
        startDate = DateTime(year, 8, 20); // August 20th
        endDate = DateTime(year, 9, 19);   // September 19th
      } else { // Part 2
        // Part 2: September 20th to September 30th
        startDate = DateTime(year, 9, 20); // September 20th
        endDate = DateTime(year, 9, 30);   // September 30th
      }
    } else if (month == 9) { // Special case: October (FY Start)
      // October 1st to October 19th
      startDate = DateTime(year, 10, 1);  // October 1st
      endDate = DateTime(year, 10, 19); // October 19th
    } else { // Standard case for all other months
      // The 19th of the selected month
      endDate = DateTime(year, month + 1, 19);
      // The 20th of the previous month. Using `endDate` as a reference is robust.
      startDate = DateTime(endDate.year, endDate.month - 1, 20);
    }

    // This part remains common: populate the list of days for the determined range
    daysInRange = [];
    DateTime currentDate = startDate;
    while (currentDate.isAtSameMomentAs(endDate) || currentDate.isBefore(endDate)) {
      daysInRange.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
  }
  // // Dummy data for supervisors
  // List<String> facilitySupervisors = ['Supervisor A', 'Supervisor B', 'Supervisor C'];
  // List<String> caritasSupervisors = ['Caritas A', 'Caritas B', 'Caritas C'];

  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  int calculateTotalHours() {
    double totalHours = 0;

    for (var date in daysInRange) {
      if (!isWeekend(date)) { // Skip weekends
        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
                attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day &&
                !attendance.offDay!) {
              totalHours += attendance.noOfHours ?? 0; // Null-safe access
            }
          } catch (e) {
            print("Error parsing date: $e");
          }
        }
      }
    }
    return totalHours.toInt();
  }

  int calculateGrandTotalHours() {
    double totalGrandHours = 0;

    for (var date in daysInRange) {
      if (!isWeekend(date)) { // Skip weekends
        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
                attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day) {
              totalGrandHours += attendance.noOfHours ?? 0; // Null-safe access
            }
          } catch (e) {
            print("Error parsing date: $e");
          }
        }
      }
    }
    return totalGrandHours.toInt();
  }

  double calculateGrandTotalHours1() {
    double projectTotal = calculateTotalHours1(selectedProjectName);

    double categoriesTotal = [
      'Annual leave',
      'Holiday',
     // 'Paternity',
      'Maternity'
    ].fold<double>(0.0, (sum, category) {
      return sum + calculateCategoryHours1(category);
    });

    return projectTotal + categoriesTotal;
  }

  // double calculatePercentageWorked() {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
  //   double totalExpectedHours = 0; // To store the total possible working hours
  //
  //   if (workingDays == 0) {
  //     return 0; // Avoid division by zero
  //   }
  //
  //
  //   for (var date in daysInRange) {
  //     if (!isWeekend(date)) {
  //       for (var attendance in attendanceData) {
  //         try {
  //           DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
  //           if (attendanceDate.year == date.year &&
  //               attendanceDate.month == date.month &&
  //               attendanceDate.day == date.day &&
  //               !attendance.offDay!) { // Include all entries for the day, offDay or not.
  //             totalExpectedHours += attendance.noOfHours!; // Sum the expected hours, even if 0
  //             break; // Go to next date once expected hours for this date found
  //           }
  //         } catch (e) {
  //           print("Error parsing date: $e");
  //         }
  //       }
  //     }
  //   }
  //
  //
  //   int totalWorkedHours = calculateTotalHours(); // Calculate worked hours (excluding weekends and off-days)
  //
  //
  //   if (totalExpectedHours == 0) {
  //     return 0; // Avoid division by zero if no expected hours are found
  //   }
  //
  //   return (totalWorkedHours / totalExpectedHours) * 100;
  // }

  double calculatePercentageWorked() {
    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length; // Correctly calculates working days in the selected month's date range.

    int totalHours = calculateTotalHours();

    if (workingDays * 8 == 0) {
      return 0;
    }

    return (totalHours / (workingDays * 8)) * 100;
  }

  // double calculateGrandPercentageWorked() {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length; // Correctly calculates working days in the selected month's date range.
  //
  //   int totalHours = calculateGrandTotalHours();
  //
  //   if (workingDays * 8 == 0) {
  //     return 0;
  //   }
  //
  //   return (totalHours / (workingDays * 8)) * 100;
  // }

// Corrected grand percentage calculation (using capped grand total)
  double calculateGrandPercentageWorked() {
    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double cappedGrandTotalHours = calculateGrandTotalHours1();
    return (workingDays * 8) > 0 ? (cappedGrandTotalHours / (workingDays * 8)) *
        100 : 0; // Correct denominator

  }


  Future<void> getSupervisor1(String selectedFirebaseId, int selectedYear, int selectedMonth) async {
    log("getSupervisor selectedFirebaseId == $selectedFirebaseId");
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(DateFormat('MMMM_yyyy').format(
          DateTime(selectedYear, selectedMonth + 1)))
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final facilitySupervisor2 = data['facilitySupervisor'];
        final caritasSupervisor2 = data['caritasSupervisor'];
        setState(() {
          facilitySupervisor = facilitySupervisor2;
          caritasSupervisor = caritasSupervisor2;
        });
        //return facilitySupervisor ?? ""; // Return empty string if null
      } else {
        print("No timesheet data found.");
      }
    } catch (e) {
      print("Error fetching facility supervisor: $e");
      //return "Error fetching data."; // Or handle the error as needed
    }
  }


  Future<void> getSupervisor(String selectedFirebaseId, int selectedYear, int selectedMonth) async {
    log("getSupervisor selectedFirebaseId == $selectedFirebaseId");
    try {
      // CHANGED: Uses the helper getter for the correct document ID
      final docSnapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(_timesheetDocId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final facilitySupervisor2 = data['facilitySupervisor'];
        final caritasSupervisor2 = data['caritasSupervisor'];
        setState(() {
          facilitySupervisor = facilitySupervisor2;
          caritasSupervisor = caritasSupervisor2;
        });
      } else {
        print("No timesheet data found for doc ID: $_timesheetDocId");
      }
    } catch (e) {
      print("Error fetching facility supervisor: $e");
    }
  }

  // Function to create the Firestore stream
  Stream<DocumentSnapshot> getSupervisorStream1(String selectedFirebaseId,
      int selectedYear, int selectedMonth) {
    return FirebaseFirestore.instance
        .collection("Staff")
        .doc(selectedFirebaseId)
        .collection("TimeSheets")
        .doc(DateFormat('MMMM_yyyy').format(
        DateTime(selectedYear, selectedMonth + 1)))
        .snapshots();
  }

  Stream<DocumentSnapshot> getSupervisorStream(String selectedFirebaseId, int selectedYear, int selectedMonth) {
    // CHANGED: Uses the helper getter for the correct document ID
    return FirebaseFirestore.instance
        .collection("Staff")
        .doc(selectedFirebaseId)
        .collection("TimeSheets")
        .doc(_timesheetDocId)
        .snapshots();
  }

  Stream<List<String?>> getSupervisorsFromFirestore(String department, String state) {
    return FirebaseFirestore.instance
        .collection('Supervisors')
        .doc(state)
        .collection(state)
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => doc['supervisor'] as String?).toList());
  }

  Stream<List<String?>> getFacilitySupervisorsFromFirestore(String location, String state) {
    return FirebaseFirestore.instance
        .collection('Staff')
        .where('location', isEqualTo: location)
        .where('state', isEqualTo: state)
        .where('staffCategory', isEqualTo: "Facility Supervisor")
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => "${doc['firstName']} ${doc['lastName']}")
        .toList());
  }



  Future<String?> getSupervisorEmailFromFirestore(String state, String supervisorName) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(state)
          .collection(state)
          .doc(supervisorName)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final emailField = data['email'];

        // If emailField is a list and not empty, return the first email
        if (emailField is List && emailField.isNotEmpty) {
          return emailField[0] as String;
        }
        // If emailField is already a String, return it directly
        else if (emailField is String) {
          return emailField;
        }
      }
      return null;
    } catch (e) {
      print("Error fetching supervisor email: $e");
      return null;
    }
  }



  Future<String?> getFacilitySupervisorEmailFromFirestore(String location,String state, String supervisorName) async {
    try {
      // Query the "Staff" collection for documents with the matching state.
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('location', isEqualTo: location)
          .where('state', isEqualTo: state)
          .where('staffCategory', isEqualTo: "Facility Supervisor")
          .get();

      // Loop through each document in the query snapshot.
      for (var doc in querySnapshot.docs) {
        String firstName = doc['firstName'] as String;
        String lastName = doc['lastName'] as String;
        // Concatenate firstName and lastName with a space.
        String fullName = "$firstName $lastName";
        // Check if the fullName matches the provided supervisorName.
        if (fullName == supervisorName) {
          return doc['emailAddress'] as String?;
        }
      }
      // Return null if no matching supervisor is found.
      return null;
    } catch (e) {
      print("Error fetching supervisor email: $e");
      return null;
    }
  }



  Widget buildSupervisorDropdown() {
    return StreamBuilder<List<String?>>(
      stream: (selectedBioDepartment != null && selectedBioState != null)
          ? getSupervisorsFromFirestore(selectedBioDepartment!, selectedBioState!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<String?> supervisorNames = snapshot.data ?? [];

          return SizedBox(
            width: double.infinity,
            child: DropdownButton<String?>(
              isExpanded: true,
              value: selectedSupervisor,
              items: supervisorNames.map((supervisorName) {
                return DropdownMenuItem<String?>(
                  value: supervisorName,
                  child: Text(
                    supervisorName ?? 'No Supervisor',
                    style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                setState(() {
                  selectedSupervisor = newValue;
                });
                print("Selected Caritas Supervisor: $newValue");

                if (newValue != null) {
                  String? supervisorEmail = await getSupervisorEmailFromFirestore(selectedBioState!, newValue);
                  setState(() {
                    _selectedSupervisorEmail = supervisorEmail;
                  });
                  print("Caritas Supervisor Email: $_selectedSupervisorEmail");
                }
              },
              hint: const Text('Select Supervisor', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 12),),
            ),
          );
        }
      },
    );
  }


  Widget buildFacilitySupervisorDropdown() {
    return StreamBuilder<List<String?>>(
      stream: (selectedBioLocation != null && selectedBioState != null)
          ? getFacilitySupervisorsFromFirestore(selectedBioLocation!, selectedBioState!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<String?> supervisorNames = snapshot.data ?? [];

          return SizedBox(
            width: double.infinity,
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedFacilitySupervisorFullName,
              items: supervisorNames.map((supervisorName) {
                return DropdownMenuItem<String?>(
                  value: supervisorName,
                  child: Text(
                    supervisorName ?? 'No Supervisor',
                    style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 12),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                setState(() {
                  _selectedFacilitySupervisorFullName = newValue;
                });
                print("Selected Facility Supervisor: $newValue");

                if (newValue != null) {
                  String? supervisorEmail = await getFacilitySupervisorEmailFromFirestore(selectedBioLocation!,selectedBioState!, newValue);
                  setState(() {
                    _selectedFacilitySupervisorEmail = supervisorEmail;
                  });
                  print("Facility Supervisor Email: $_selectedFacilitySupervisorEmail");
                }
              },
              hint: const Text('Select Supervisor', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 12),),
            ),
          );
        }
      },
    );
  }


  // Calculate total hours for a specific category
  double calculateCategoryHours(String category) {
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
                attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day &&
                attendance.offDay! && //Check for offDay for these categories
                attendance.durationWorked?.toLowerCase() ==
                    category.toLowerCase()) {
              totalHours += attendance.noOfHours ?? 0; // Null-safe access
            }
          } catch (e) {
            print("Error parsing date: $e");
          }
        }
      }
    }
    return totalHours;
  }


// Calculate percentage for a specific category
//   double calculateCategoryPercentage(String category) {
//
//     double categoryHours = calculateCategoryHours(category);
//
//     int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
//     double totalExpectedHours = 0;
//
//     if (workingDays == 0) {
//       return 0; // Avoid division by zero
//     }
//
//     for (var date in daysInRange) {
//       if (!isWeekend(date)) {
//         for (var attendance in attendanceData) {
//           try {
//             DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
//             if (attendanceDate.year == date.year &&
//                 attendanceDate.month == date.month &&
//                 attendanceDate.day == date.day) {
//               totalExpectedHours += attendance.noOfHours!;
//               break; // Ensure to only count expected hours for the specific day once
//             }
//           } catch (e) {
//             print("Error parsing date: $e");
//           }
//         }
//       }
//     }
//
//     if (totalExpectedHours == 0) {
//       return 0; // Avoid division by zero if no expected hours found
//     }
//
//     return (categoryHours / totalExpectedHours) * 100;
//
//
//   }

  // double calculateCategoryPercentage(String category) {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length; // Correctly calculates working days in the selected month's date range.
  //
  //   double totalHours = calculateCategoryHours(category);
  //
  //   if (workingDays * 8 == 0) {
  //     return 0;
  //   }
  //
  //   return (totalHours / (workingDays * 8)) * 100;
  // }

  // Updated percentage calculation for a category (using capped hours)
  double calculateCategoryPercentage(String category) {
    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double cappedCategoryHours = calculateCategoryHours(
        category); // Use capped category hours
    return (workingDays * 8) > 0 ? (cappedCategoryHours / (workingDays * 8)) *
        100 : 0;
  }

// Replace this method in your _TimesheetScreenState class
  void _showDeleteConfirmationDialog() async { // Make the method async
    if (selectedFirebaseId == null) {
      Fluttertoast.showToast(msg: "Error: User not identified.");
      return;
    }

    // <<< MODIFICATION START: Real-time check against Firestore >>>
    bool timesheetExists = false;
    try {
      final docRef = FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(_timesheetDocId); // Use the getter for the correct ID

      final docSnapshot = await docRef.get();
      timesheetExists = docSnapshot.exists;
    } catch (e) {
      print("Error checking for timesheet: $e");
      Fluttertoast.showToast(msg: "Could not verify timesheet status. Please try again.");
      return;
    }
    // <<< MODIFICATION END >>>

    if (!timesheetExists) {
      Fluttertoast.showToast(
        msg: "No submitted timesheet found for the selected period to delete.",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    // If the timesheet exists, show the confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this submitted timesheet? This will allow you to submit a new one for this period, but this action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog first
                await _deleteTimesheet(); // Then perform the delete action
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTimesheet() async {
    if (selectedFirebaseId == null) {
      Fluttertoast.showToast(msg: "Error: User not identified.");
      return;
    }

    setState(() {
      _isLoading = true; // Show a loading indicator during deletion
    });

    try {
      // Use the _timesheetDocId getter to ensure the correct document is targeted
      final String docId = _timesheetDocId;

      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(docId)
          .delete();

      // After successful deletion, reset the local state to reflect the change.
      // This will make the UI show the supervisor dropdowns again.
      setState(() {
        facilitySupervisor = null;
        caritasSupervisor = null;
      });

      Fluttertoast.showToast(
        msg: "Timesheet deleted successfully.",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print("Error deleting timesheet: $e");
      Fluttertoast.showToast(
        msg: "Failed to delete timesheet. Please try again.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide the loading indicator
      });
    }
  }

  // double calculatePercentageWorked() {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length; // Correctly calculates working days in the selected month's date range.
  //
  //   int totalHours = calculateTotalHours();
  //
  //   if (workingDays * 8 == 0) {
  //     return 0;
  //   }
  //
  //   return (totalHours / (workingDays * 8)) * 100;
  // }

  // int calculateTotalHours() {
  //   // Mock calculation, replace with actual logic to query Isar database for total hours
  //   return daysInRange.where((date) => !isWeekend(date)).length * 8; // Example: 8 hours per day
  // }
  //
  // double calculatePercentageWorked() {
  //   int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
  //   return (calculateTotalHours() / (workingDays * 8)) * 100; // Assuming 8-hour workday
  // }

  @override
  Widget build(BuildContext context) {
// Responsiveness calculations based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
    bool isTablet = screenWidth >= 600 && screenWidth < 1200;
    bool isDesktop = screenWidth >= 1200 && screenWidth < 1920;
    bool isLargeDesktop = screenWidth >= 1920;

    if (isMobile) {
      appBarHeightFactor = 0.8;
      titleFontSizeFactor = 1.2;
      fontSizeFactor = 0.9;
      paddingFactor = 0.8;
      marginFactor = 0.8;
      iconSizeFactor = 0.8;
      tableFontSizeFactor = 0.8;
      dropdownFontSizeFactor = 0.9;
    } else if (isTablet) {
      appBarHeightFactor = 1.0;
      titleFontSizeFactor = 1.5;
      fontSizeFactor = 1.0;
      paddingFactor = 1.0;
      marginFactor = 1.0;
      iconSizeFactor = 1.0;
      tableFontSizeFactor = 1.0;
      dropdownFontSizeFactor = 1.0;
    } else if (isDesktop) {
      appBarHeightFactor = 1.2;
      titleFontSizeFactor = 1.8;
      fontSizeFactor = 1.1;
      paddingFactor = 1.2;
      marginFactor = 1.2;
      iconSizeFactor = 1.2;
      tableFontSizeFactor = 1.1;
      dropdownFontSizeFactor = 1.1;
    } else { // isLargeDesktop
      appBarHeightFactor = 1.4;
      titleFontSizeFactor = 2.0;
      fontSizeFactor = 1.2;
      paddingFactor = 1.4;
      marginFactor = 1.4;
      iconSizeFactor = 1.4;
      tableFontSizeFactor = 1.2;
      dropdownFontSizeFactor = 1.2;
    }

    int totalHours = calculateTotalHours();
    double percentageWorked = calculatePercentageWorked();
    int totalGrandHours = calculateGrandTotalHours();
    double grandPercentageWorked = calculateGrandPercentageWorked();

    return Scaffold(
      appBar: AppBar(
        title: Text('Timesheet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20 *
                    dev.max(0.8,
                        dev.min(1.2, MediaQuery.of(context).size.shortestSide / 600)))),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF722F37), Color(0xFFB34A5A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          _isPDFLoading
              ? const CircularProgressIndicator()
              : Row(children: [
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Download PDF',
              onPressed: _createAndExportPDF,
            ),
            const Icon(Icons.picture_as_pdf),
            const SizedBox(width: 15),
            // IconButton(
            //   icon: const Icon(Icons.share),
            //   tooltip: 'Share PDF',
            //   onPressed: _shareTimesheet,
            // ),
            // <<< MODIFICATION START: Added Delete Icon Button >>>
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Delete Submitted Timesheet',
              onPressed: _showDeleteConfirmationDialog, // This will trigger the confirmation
            ),
            // <<< MODIFICATION END >>>
          ]),
          const SizedBox(width: 15),
          Container(
            margin: const EdgeInsets.only(top: 15, right: 15, bottom: 15),
            child: Image.asset("assets/image/ccfn_logo.png"),
          )
        ],
      ),
      drawer: drawer(this.context),
      body: _pageLoading // Conditional rendering based on loading state
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : SingleChildScrollView(
        // Wrap the entire body in SingleChildScrollView
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0 * paddingFactor),
              child: Column(
                //mainAxisAlignment:MainAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          checkColor: Colors.black,
                          value: _includeTaskSummary,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _includeTaskSummary = newValue ?? false;
                            });
                          },
                        ),
                        const Text(
                            'Include Task Summary in Timesheet PDF',
                            style:
                            TextStyle(color: Colors.black, fontSize: 12)),
                      ],
                    ),
                    Image(
                      image: const AssetImage("./assets/image/ccfn_logo.png"),
                      width: MediaQuery.of(context).size.width *
                          0.10 *
                          iconSizeFactor,
                    ),
                    Text(
                      'Name: $selectedBioFirstName $selectedBioLastName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * fontSizeFactor,
                      ),
                    ),
                    SizedBox(height: 5 * marginFactor),
                    Text(
                      'Department: $selectedBioDepartment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * fontSizeFactor,
                      ),
                    ),
                    SizedBox(height: 5 * marginFactor),
                    Text(
                      'Designation: $selectedBioDesignation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * fontSizeFactor,
                      ),
                    ),
                    SizedBox(height: 5 * marginFactor),
                    Text(
                      'Location: $selectedBioLocation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * fontSizeFactor,
                      ),
                    ),
                    SizedBox(height: 5 * marginFactor),
                    Text(
                      'State: $selectedBioState',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * fontSizeFactor,
                      ),
                    ),
                    SizedBox(height: 10 * marginFactor),
                  ]),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0 * paddingFactor),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 10 * marginFactor),
                      const Text(
                        'Select Month:',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(width: 10 * marginFactor),
                      DropdownButton<int>(
                        value: selectedMonth,
                        items: List.generate(12, (index) {
                          DateTime monthDate = DateTime(2024, index + 1, 1);
                          return DropdownMenuItem<int>(
                            value: index,
                            child: Text(DateFormat.MMMM().format(monthDate),
                                style: TextStyle(
                                    fontSize: 14 * dropdownFontSizeFactor)),
                          );
                        }),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedMonth = newValue;
                              initializeDateRange(selectedMonth, selectedYear);
                            });
                          }
                        },
                      ),
                      SizedBox(width: 10 * marginFactor),
                      const Text(
                        'Select Year:',
                        style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(width: 10 * marginFactor),
                      DropdownButton<int>(
                        value: selectedYear,
                        items: List.generate(10, (index) {
                          int year = DateTime.now().year - index;
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString(),
                                style: TextStyle(
                                    fontSize: 14 * dropdownFontSizeFactor)),
                          );
                        }),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedYear = newValue;
                              initializeDateRange(selectedMonth, selectedYear);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_isSeptemberSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Timesheet Period for September:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ToggleButtons(
                            isSelected: [
                              _selectedTimesheetPart == 1,
                              _selectedTimesheetPart == 2,
                            ],
                            onPressed: (int index) {
                              setState(() {
                                _selectedTimesheetPart = index + 1;
                                initializeDateRange(
                                    selectedMonth, selectedYear);
                                if (bioData != null) {
                                  getSupervisor(bioData!.firebaseAuthId!,
                                      selectedYear, selectedMonth);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8.0),
                            selectedBorderColor: Colors.red[700],
                            selectedColor: Colors.white,
                            fillColor: Colors.red[200],
                            color: Colors.red[400],
                            constraints:
                            const BoxConstraints(minHeight: 40.0),
                            children: const <Widget>[
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Text('Part 1 (Aug 20 - Sep 19)'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Text('Part 2 (Sep 20 - Sep 30)'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 20 * marginFactor),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  tooltip: 'Scroll Left',
                  onPressed: () {
                    _horizontalScrollController.animateTo(
                      _horizontalScrollController.offset - 300,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  tooltip: 'Scroll Right',
                  onPressed: () {
                    _horizontalScrollController.animateTo(
                      _horizontalScrollController.offset + 300,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
            ),
            Container(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          _horizontalScrollController.animateTo(
                            _horizontalScrollController.offset - 200,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      Expanded(
                          child: RepaintBoundary(
                              key: _globalKey,
                              child: Column(children: [
                                SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10 * paddingFactor),
                                  dragStartBehavior: DragStartBehavior.start,
                                  clipBehavior: Clip.hardEdge,
                                  keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                                  child: Column(
                                    children: [
                                      Column(
                                        children: [
                                          // Header Row
                                          Row(
                                            children: [
                                              Container(
                                                width: 150,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.blue.shade100,
                                                child: const Text(
                                                  'Project Name',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                              ...daysInRange.map((date) {
                                                return Container(
                                                  width: 60,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: isWeekend(date)
                                                      ? Colors.grey.shade300
                                                      : Colors.blue.shade100,
                                                  child: Text(
                                                    DateFormat('dd MMM')
                                                        .format(date),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                );
                                              }),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.blue.shade100,
                                                child: const Text(
                                                  'Total Hours',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.blue.shade100,
                                                child: const Text(
                                                  'Percentage',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          // Project Data Row
                                          Row(
                                            children: [
                                              Container(
                                                width: 150,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: projectNames.isEmpty
                                                    ? const Text(
                                                    'No projects found')
                                                    : DropdownButton<String>(
                                                  value:
                                                  selectedProjectName,
                                                  isExpanded: true,
                                                  items: projectNames.map(
                                                          (projectName) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: projectName,
                                                          child: FittedBox(
                                                              fit: BoxFit
                                                                  .scaleDown,
                                                              alignment: Alignment
                                                                  .centerLeft,
                                                              child: Text(
                                                                  projectName ??
                                                                      'No Project Name')),
                                                        );
                                                      }).toList(),
                                                  onChanged: (String?
                                                  newValue) {
                                                    setState(() {
                                                      selectedProjectName =
                                                          newValue;
                                                    });
                                                  },
                                                  hint: const Text(
                                                      'Select Project'),
                                                ),
                                              ),
                                              ...daysInRange.map((date) {
                                                AttendanceModel?
                                                attendanceForDay;
                                                try {
                                                  attendanceForDay =
                                                      attendanceData.firstWhere(
                                                              (att) {
                                                            if (att.date == null) {
                                                              return false;
                                                            }
                                                            final attDate =
                                                            DateFormat(
                                                                'dd-MMMM-yyyy')
                                                                .parse(att.date!);
                                                            return attDate.year ==
                                                                date.year &&
                                                                attDate.month ==
                                                                    date.month &&
                                                                attDate.day ==
                                                                    date.day &&
                                                                att.offDay ==
                                                                    false;
                                                          });
                                                } catch (e) {
                                                  attendanceForDay = null;
                                                }

                                                bool weekend = isWeekend(date);
                                                String hours =
                                                _getDurationForDate2(
                                                    date,
                                                    selectedProjectName,
                                                    selectedProjectName!);
                                                Color cellColor = weekend
                                                    ? Colors.grey.shade300
                                                    : _getCellColor(
                                                    attendanceForDay
                                                        ?.deductionStatus);
                                                double? recommendedHours =
                                                    attendanceForDay
                                                        ?.recommendation
                                                        ?.deductedHours;
                                                String recommendationText = '';
                                                if (recommendedHours != null &&
                                                    recommendedHours > 0) {
                                                  recommendationText =
                                                  '-${recommendedHours.toStringAsFixed(1)}';
                                                }

                                                return Container(
                                                  width: 60,
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4.0),
                                                  decoration: BoxDecoration(
                                                    color: cellColor,
                                                    border: Border.all(
                                                        color: Colors.black12),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                    children: [
                                                      if (!weekend)
                                                        Text(hours,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .blueAccent)),
                                                      if (recommendationText
                                                          .isNotEmpty &&
                                                          !weekend)
                                                        Padding(
                                                          padding:
                                                          const EdgeInsets
                                                              .only(
                                                              top: 2.0),
                                                          child: Text(
                                                            recommendationText,
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .red
                                                                    .shade800,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: Text(
                                                  "${calculateTotalHours1(selectedProjectName).round()} hrs",
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: Text(
                                                  '${calculatePercentageWorked1(selectedProjectName).round()}%',
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          Row(
                                            children: [
                                              Container(
                                                width: 150,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: const Text(
                                                  'Out-of-office',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18),
                                                ),
                                              ),
                                              ...List.generate(
                                                  daysInRange.length, (index) {
                                                return Container(
                                                  width: 60,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: Colors.white,
                                                  child: const Text(''),
                                                );
                                              }),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: const Text(''),
                                              ),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: const Text(''),
                                              ),
                                            ],
                                          ),
                                          ...[
                                            'Annual leave',
                                            'Holiday',
                                            'Maternity'
                                          ].map((category) {
                                            return Row(
                                              children: [
                                                Container(
                                                  width: 150,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: Colors.white,
                                                  child: Text(
                                                    category,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                ),
                                                ...daysInRange.map((date) {
                                                  bool weekend =
                                                  isWeekend(date);
                                                  String offDayHours =
                                                  _getDurationForDate2(
                                                      date,
                                                      selectedProjectName,
                                                      category);
                                                  return Container(
                                                    width: 60,
                                                    decoration: BoxDecoration(
                                                      color: weekend
                                                          ? Colors.grey.shade300
                                                          : Colors.white,
                                                      border: Border.all(
                                                          color:
                                                          Colors.black12),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                      children: [
                                                        weekend
                                                            ? const SizedBox
                                                            .shrink()
                                                            : Text(
                                                          offDayHours,
                                                          style:
                                                          const TextStyle(
                                                              color: Colors
                                                                  .blueAccent),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                                Container(
                                                  width: 100,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: Colors.white,
                                                  child: Text(
                                                    "${calculateCategoryHours1(category).round()} hrs",
                                                    style: const TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                ),
                                                Container(
                                                  width: 100,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: Colors.white,
                                                  child: Text(
                                                    '${calculateCategoryPercentage(category).round()}%',
                                                    style: const TextStyle(
                                                        color: Colors.green,
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
                                          Row(
                                            children: [
                                              Container(
                                                width: 150,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: const Text(
                                                  'Total',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 20),
                                                ),
                                              ),
                                              ...List.generate(
                                                  daysInRange.length, (index) {
                                                return Container(
                                                  width: 60,
                                                  alignment: Alignment.center,
                                                  padding:
                                                  const EdgeInsets.all(8.0),
                                                  color: Colors.white,
                                                  child: const Text(''),
                                                );
                                              }),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: Text(
                                                  "${calculateGrandTotalHours1().toStringAsFixed(0)} hrs",
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                              Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                padding:
                                                const EdgeInsets.all(8.0),
                                                color: Colors.white,
                                                child: Text(
                                                  '${calculateGrandPercentageWorked().round()}%',
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                      FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5 * marginFactor),
                                _buildDeductionsSummary(),
                                const Divider(),
                                Text('Signature & Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25 * fontSizeFactor,
                                    )),
                                const Divider(),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text(
                                                'Name of Staff',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                    18 * fontSizeFactor),
                                              ),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              Text(
                                                '${selectedBioFirstName?.toUpperCase()} ${selectedBioLastName?.toUpperCase()}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize:
                                                    14 * fontSizeFactor,
                                                    fontFamily: "NexaLight"),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Signature',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState ==
                                                      ConnectionState.waiting) {
                                                    if (staffSignatureLink !=
                                                        null &&
                                                        staffSignatureLink!
                                                            .isNotEmpty) {
                                                      return Image.network(
                                                          staffSignatureLink!,
                                                          height: 80,
                                                          fit: BoxFit.contain);
                                                    }
                                                    return const CircularProgressIndicator();
                                                  }
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final signatureUrl =
                                                    data['staffSignature'];
                                                    if (signatureUrl != null &&
                                                        signatureUrl
                                                            .isNotEmpty) {
                                                      return Image.network(
                                                          signatureUrl,
                                                          height: 80,
                                                          fit: BoxFit.contain);
                                                    }
                                                  }
                                                  if (staffSignatureLink !=
                                                      null &&
                                                      staffSignatureLink!
                                                          .isNotEmpty) {
                                                    return Image.network(
                                                        staffSignatureLink!,
                                                        height: 80,
                                                        fit: BoxFit.contain);
                                                  }
                                                  return GestureDetector(
                                                    onTap: _pickImage,
                                                    child: Container(
                                                      height: 80,
                                                      width: 150,
                                                      decoration: BoxDecoration(
                                                          border: Border.all(
                                                              color:
                                                              Colors.grey)),
                                                      child: const Center(
                                                          child: Text(
                                                              "Upload Signature")),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final signatureDate = data[
                                                    'staffSignatureDate'];
                                                    if (signatureDate !=
                                                        null) {
                                                      return Text(signatureDate,
                                                          style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              fontSize: 14 *
                                                                  fontSizeFactor));
                                                    }
                                                  }
                                                  return Text(formattedDate,
                                                      style: TextStyle(
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          fontSize: 14 *
                                                              fontSizeFactor));
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text(
                                                  'Name of Project Cordinator',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final supervisorName = data[
                                                    'facilitySupervisor'];
                                                    if (supervisorName !=
                                                        null) {
                                                      return Text(supervisorName,
                                                          style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              fontSize: 14 *
                                                                  fontSizeFactor));
                                                    }
                                                  }
                                                  return buildFacilitySupervisorDropdown();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // <<< MODIFICATION START: Project Coordinator Signature/Status >>>
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * fontSizeFactor)),
                                              SizedBox(height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(selectedFirebaseId!, selectedYear, selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const Text("Loading status...");
                                                  }
                                                  if (snapshot.hasData && snapshot.data!.exists) {
                                                    final data = snapshot.data!.data() as Map<String, dynamic>;
                                                    final signatureUrl = data['facilitySupervisorSignature'];
                                                    final status = data['facilitySupervisorSignatureStatus'];
                                                    final rejectionReason = data['facilitySupervisorRejectionReason'];

                                                    if (status == "Approved" && signatureUrl != null) {
                                                      return Column(
                                                        children: [
                                                          Image.network(signatureUrl, height: 80, fit: BoxFit.contain),
                                                          const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                                                              SizedBox(width: 4),
                                                              Text("Approved", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        ],
                                                      );
                                                    } else if (status == "Rejected") {
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(Icons.cancel, color: Colors.red, size: 16),
                                                              SizedBox(width: 4),
                                                              Text("Rejected", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                                            ],
                                                          ),
                                                          if (rejectionReason != null && rejectionReason.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 4.0),
                                                              child: Text(
                                                                'Reason: $rejectionReason',
                                                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                                                textAlign: TextAlign.center,
                                                                softWrap: true,
                                                              ),
                                                            ),
                                                        ],
                                                      );
                                                    } else {
                                                      return Column(
                                                        children: [
                                                          const Text("Awaiting Signature", style: TextStyle(fontSize: 12)),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              const Icon(Icons.access_time, color: Colors.orange, size: 16),
                                                              const SizedBox(width: 4),
                                                              Text(status ?? "Pending", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        ],
                                                      );
                                                    }
                                                  } else {
                                                    return const Text("Timesheet not submitted", style: TextStyle(fontSize: 12));
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // <<< MODIFICATION END >>>
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final signatureDate = data[
                                                    'facilitySupervisorSignatureDate'];
                                                    if (signatureDate !=
                                                        null) {
                                                      return Text(signatureDate,
                                                          style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              fontSize: 14 *
                                                                  fontSizeFactor));
                                                    }
                                                  }
                                                  return const Text(
                                                      "Awaiting Date",
                                                      style: TextStyle(
                                                          fontSize: 12));
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text(
                                                  'Name of CARITAS Supervisor',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final supervisorName = data[
                                                    'caritasSupervisor'];
                                                    if (supervisorName !=
                                                        null) {
                                                      return Text(supervisorName,
                                                          style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              fontSize: 14 *
                                                                  fontSizeFactor));
                                                    }
                                                  }
                                                  return buildSupervisorDropdown();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // <<< MODIFICATION START: CARITAS Supervisor Signature/Status >>>
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 * fontSizeFactor)),
                                              SizedBox(height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(selectedFirebaseId!, selectedYear, selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const Text("Loading status...");
                                                  }
                                                  if (snapshot.hasData && snapshot.data!.exists) {
                                                    final data = snapshot.data!.data() as Map<String, dynamic>;
                                                    final signatureUrl = data['caritasSupervisorSignature'];
                                                    final status = data['caritasSupervisorSignatureStatus'];
                                                    final rejectionReason = data['caritasSupervisorRejectionReason'];
                                                    final facilityStatus = data['facilitySupervisorSignatureStatus'];

                                                    if (status == "Approved" && signatureUrl != null) {
                                                      return Column(
                                                        children: [
                                                          Image.network(signatureUrl, height: 80, fit: BoxFit.contain),
                                                          const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                                                              SizedBox(width: 4),
                                                              Text("Approved", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        ],
                                                      );
                                                    } else if (status == "Rejected") {
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(Icons.cancel, color: Colors.red, size: 16),
                                                              SizedBox(width: 4),
                                                              Text("Rejected", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                                            ],
                                                          ),
                                                          if (rejectionReason != null && rejectionReason.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 4.0),
                                                              child: Text(
                                                                'Reason: $rejectionReason',
                                                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                                                textAlign: TextAlign.center,
                                                                softWrap: true,
                                                              ),
                                                            ),
                                                        ],
                                                      );
                                                    } else {
                                                      if (facilityStatus != "Approved") {
                                                        return const Text(
                                                          "Awaiting approval from Project Coordinator first.",
                                                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                                          textAlign: TextAlign.center,
                                                          softWrap: true,
                                                        );
                                                      } else {
                                                        return Column(
                                                          children: [
                                                            const Text("Awaiting Signature", style: TextStyle(fontSize: 12)),
                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                const Icon(Icons.access_time, color: Colors.orange, size: 16),
                                                                const SizedBox(width: 4),
                                                                Text(status ?? "Pending", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                              ],
                                                            ),
                                                          ],
                                                        );
                                                      }
                                                    }
                                                  } else {
                                                    return const Text("Timesheet not submitted", style: TextStyle(fontSize: 12));
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // <<< MODIFICATION END >>>
                                        SizedBox(
                                          width: screenWidth * 0.3,
                                          child: Column(
                                            children: [
                                              Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      fontSize: 18 *
                                                          fontSizeFactor)),
                                              SizedBox(
                                                  height: 5 * marginFactor),
                                              StreamBuilder<DocumentSnapshot>(
                                                stream: getSupervisorStream(
                                                    selectedFirebaseId!,
                                                    selectedYear,
                                                    selectedMonth),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.exists) {
                                                    final data = snapshot.data!
                                                        .data()
                                                    as Map<String, dynamic>;
                                                    final signatureDate = data[
                                                    'caritasSupervisorSignatureDate'];
                                                    if (signatureDate !=
                                                        null) {
                                                      return Text(signatureDate,
                                                          style: TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold,
                                                              fontSize: 14 *
                                                                  fontSizeFactor));
                                                    }
                                                  }
                                                  return const Text(
                                                      "Awaiting Date",
                                                      style: TextStyle(
                                                          fontSize: 12));
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: getSupervisorStream(
                                          selectedFirebaseId!,
                                          selectedYear,
                                          selectedMonth),
                                      builder: (context, snapshot) {
                                        bool isFullySigned = false;
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          final data = snapshot.data!.data()
                                          as Map<String, dynamic>;
                                          if (data['caritasSupervisorSignature'] !=
                                              null &&
                                              data['facilitySupervisorSignature'] !=
                                                  null &&
                                              data['staffSignature'] != null) {
                                            isFullySigned = true;
                                          }
                                        }
                                        return ElevatedButton(
                                          onPressed: isFullySigned
                                              ? sendEmailToSelf
                                              : _saveTimesheetToFirestore,
                                          child: Text(isFullySigned
                                              ? 'Email Signed Timesheet to Self'
                                              : 'Submit Timesheet'),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 20 * marginFactor),
                                  ],
                                ),
                              ]))),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () {
                          _horizontalScrollController.animateTo(
                            _horizontalScrollController.offset + 200,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ])),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchFacilitySupervisor() async {
    print("_fetchPendingApprovals");

    setState(() {
      _isLoading = true; // Show loading indicator
    });
    try {
      // Fetch pending leaves
      final leavesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('Staff')
          .where('state', isEqualTo: selectedBioState)
          .where('location', isEqualTo: selectedBioLocation)
          .where('staffCategory', isEqualTo: 'Facility Supervisor')
          .get();


      setState(() {
        facilitySupervisorsList =
            leavesSnapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false; // Hide loading indicator after data is fetched
      });
      print("facilitySupervisorsList == $facilitySupervisorsList");
    } catch (e) {
      print('Error fetching Facility supervisors: $e');
      Fluttertoast.showToast(
        msg: "'Error fetching Facility supervisors: $e'",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Uint8List>?> _readImagesFromDatabase() async {

    return null;
  }

  Future<void> _pickImage() async {
    try {
      ImagePicker imagePicker = ImagePicker();
      XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 512,
        maxWidth: 512,
        imageQuality: 90,
      );
      if (image == null) return;

      Uint8List imageBytes = await image.readAsBytes();

      setState(() {
        staffSignature = imageBytes; // Update staffSignature variable
      });
      _saveTimesheetToFirestore(); // Save after signature is selected


    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error:${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> _saveTimesheetToFirestore1() async {
    print("Step One");

    if (staffSignatureLink == null) {
      Fluttertoast.showToast(
        msg: "Cannot send timesheet without staff signature",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (selectedSupervisor == null || _selectedFacilitySupervisorFullName == null) {
      Fluttertoast.showToast(
        msg: "Cannot send timesheet without Selecting Project Coordinator Name or CARITAS Supervisor.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      log("Cannot send timesheet without staff signature.");
      return;
    }

    log("selectedSupervisor ===$selectedSupervisor");
    log("_selectedFacilitySupervisorFullName ==$_selectedFacilitySupervisorFullName");

    String monthYear = DateFormat('MMMM_yyyy').format(DateTime(selectedYear, selectedMonth + 1));

    try {
      log("Start Pushing timesheet");

      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("Staff")
          .where("id", isEqualTo: selectedFirebaseId)
          .get();

      List<Map<String, dynamic>> timesheetEntries = [];

      for (var date in daysInRange) {
        Map<String, dynamic>? entryForDate;

        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day) {
              entryForDate = {
                'date': DateFormat('yyyy-MM-dd').format(date),
                'noOfHours': attendance.noOfHours,
                'projectName': selectedProjectName,
                'offDay': attendance.offDay,
                'durationWorked': attendance.durationWorked,
              };
              break;
            }
          } catch (e) {
            log("Error parsing date: $e");
          }
        }

        if (entryForDate != null) {
          timesheetEntries.add(entryForDate);
        }
      }

      Map<String, dynamic> timesheetData = {
        'projectName': selectedProjectName,
        'staffName': '$selectedBioFirstName $selectedBioLastName',
        'staffSignature': staffSignatureLink,
        'staffSignatureDate': DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        'facilitySupervisorSignatureDate': null,
        'caritasSupervisorSignatureDate': null,
        'department': selectedBioDepartment,
        'state': selectedBioState,
        'facilitySupervisorSignatureStatus': 'Pending',
        'caritasSupervisorSignatureStatus': 'Pending',
        'facilitySupervisorTimesheetSubmissionTimestamp':null,
        'caritasSupervisorTimesheetSubmissionTimestamp':null,
        'timesheetEntries': timesheetEntries,
        'facilitySupervisor': _selectedFacilitySupervisorFullName,
        'facilitySupervisorEmail': _selectedFacilitySupervisorEmail,
        'facilitySupervisorSignature': facilitySupervisorSignature,
        'caritasSupervisor': selectedSupervisor,
        'caritasSupervisorSignature': caritasSupervisorSignature,
        'caritasSupervisorEmail': _selectedSupervisorEmail,
        'staffId': selectedFirebaseId,
        'designation': selectedBioDesignation,
        'location': selectedBioLocation,
        'staffCategory': selectedBioStaffCategory,
        'staffEmail': selectedBioEmail,
        'staffPhone': selectedBioPhone,
        'month': '${selectedMonth}_$selectedYear',
        'timesheetSubmissionTimestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(snap.docs[0].id)
          .collection("TimeSheets")
          .doc(monthYear)
          .set(timesheetData, SetOptions(merge: true));

      print('Timesheet saved to Firestore');
      Fluttertoast.showToast(
        msg: "Timesheet sent to supervisor",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print('Error saving timesheet: $e');
    }
  }

// In _TimesheetScreenState class

  Future<void> _saveTimesheetToFirestore() async {
    print("Step One: Starting timesheet save process.");

    if (staffSignatureLink == null || staffSignatureLink!.isEmpty) {
      Fluttertoast.showToast(msg: "Cannot submit timesheet without a staff signature. Please update your profile.");
      return;
    }

    if (selectedSupervisor == null || _selectedFacilitySupervisorFullName == null) {
      Fluttertoast.showToast(msg: "Please select both a Project Coordinator and a CARITAS Supervisor before submitting.");
      return;
    }

    log("Selected Project Coordinator: $_selectedFacilitySupervisorFullName");
    log("Selected CARITAS Supervisor: $selectedSupervisor");

    final String timesheetDocumentId = _timesheetDocId;
    final String monthFieldIdentifier = selectedMonth == 8
        ? '${selectedMonth}_${selectedYear}_part$_selectedTimesheetPart'
        : '${selectedMonth}_$selectedYear';

    try {
      log("Start Pushing timesheet with doc ID: $timesheetDocumentId");

      List<Map<String, dynamic>> timesheetEntries = [];

      // <<<--- FIX: Iterate through daysInRange but only process weekdays ---<<<
      for (var date in daysInRange) {
        // Add this check to skip weekends entirely
        if (isWeekend(date)) {
          continue; // Skips to the next iteration of the loop
        }

        Map<String, dynamic>? entryForDate;
        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day) {

              entryForDate = {
                'date': DateFormat('yyyy-MM-dd').format(date),
                'noOfHours': attendance.noOfHours,
                'projectName': selectedProjectName,
                'offDay': attendance.offDay,
                'durationWorked': attendance.durationWorked,
                'deductionStatus': attendance.deductionStatus,
                'evidenceImageUrl': attendance.evidenceImageUrl,
                'recommendation': attendance.recommendation?.toJson(),
              };
              break; // Found the attendance for this day, so exit the inner loop
            }
          } catch (e) {
            log("Error parsing date: $e");
          }
        }

        // Only add an entry if a corresponding attendance record was found for that weekday
        if (entryForDate != null) {
          timesheetEntries.add(entryForDate);
        }
      }

      Map<String, dynamic> timesheetData = {
        'projectName': selectedProjectName,
        'staffName': '$selectedBioFirstName $selectedBioLastName',
        'staffSignature': staffSignatureLink,
        'staffSignatureDate': DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        'facilitySupervisorSignatureDate': null,
        'caritasSupervisorSignatureDate': null,
        'department': selectedBioDepartment,
        'state': selectedBioState,
        'facilitySupervisorSignatureStatus': 'Pending',
        'caritasSupervisorSignatureStatus': 'Pending',
        'facilitySupervisorTimesheetSubmissionTimestamp': null,
        'caritasSupervisorTimesheetSubmissionTimestamp': null,
        'timesheetEntries': timesheetEntries,
        'facilitySupervisor': _selectedFacilitySupervisorFullName,
        'facilitySupervisorEmail': _selectedFacilitySupervisorEmail,
        'facilitySupervisorSignature': facilitySupervisorSignature,
        'caritasSupervisor': selectedSupervisor,
        'caritasSupervisorSignature': caritasSupervisorSignature,
        'caritasSupervisorEmail': _selectedSupervisorEmail,
        'staffId': selectedFirebaseId,
        'designation': selectedBioDesignation,
        'location': selectedBioLocation,
        'staffCategory': selectedBioStaffCategory,
        'staffEmail': selectedBioEmail,
        'staffPhone': selectedBioPhone,
        'month': monthFieldIdentifier,
        'timesheetSubmissionTimestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(selectedFirebaseId)
          .collection("TimeSheets")
          .doc(timesheetDocumentId)
          .set(timesheetData, SetOptions(merge: true));

      print('Timesheet saved to Firestore with ID: $timesheetDocumentId');
      Fluttertoast.showToast(msg: "Timesheet sent to supervisor successfully!");
    } catch (e) {
      print('Error saving timesheet: $e');
      Fluttertoast.showToast(msg: "Error saving timesheet: $e");
    }
  }


  // <<<--- NEW METHOD: For cell color-coding ---<<<
  Color _getCellColor(String? deductionStatus) {
    switch (deductionStatus) {
      case 'Partial': // Partial Deduction
        return Colors.yellow.shade300;
      case 'Full': // Full Deduction
        return Colors.red.shade300;
      case 'ApprovedPartial': // Partial Approval
        return Colors.blue.shade200;
      case 'ApprovedFull': // Full Approval (Manual creation)
        return Colors.green.shade200;
      default:
        return Colors.white;
    }
  }

  // <<<--- NEW METHOD: To build the deductions summary section with dividers ---<<<
  Widget _buildDeductionsSummary() {
    double totalDeductedHours = 0;
    List<Widget> deductionBreakdown = [];

    // Filter for attendance records within the current timesheet range that have deductions
    final relevantAttendance = attendanceData.where((att) {
      if (att.date == null) return false;
      try {
        final attDate = DateFormat('dd-MMMM-yyyy').parse(att.date!);
        return daysInRange.any((day) =>
        day.year == attDate.year &&
            day.month == attDate.month &&
            day.day == attDate.day) &&
            att.recommendation?.deductedHours != null &&
            att.recommendation!.deductedHours! > 0;
      } catch (e) {
        return false;
      }
    }).toList();

    if (relevantAttendance.isEmpty) {
      return const SizedBox.shrink(); // Don't show the section if there are no deductions
    }

    // Use an indexed loop to add dividers between items
    for (int i = 0; i < relevantAttendance.length; i++) {
      final att = relevantAttendance[i];
      final double deducted = att.recommendation!.deductedHours!;
      totalDeductedHours += deducted;

      deductionBreakdown.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('${att.date}: (${att.recommendation?.notes ?? "No reason"})')),
                Text(
                  '-${deducted.toStringAsFixed(1)} hrs',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
      );

      // Add a thin divider if it's not the last item in the list
      if (i < relevantAttendance.length - 1) {
        deductionBreakdown.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Divider(height: 8, thickness: 0.5),
            )
        );
      }
    }

    if (totalDeductedHours == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Deductions & Adjustments Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        ListTile(
          title: const Text('Total Hours Recommended for Deduction:', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text(
            '${totalDeductedHours.toStringAsFixed(1)} hrs',
            style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const Text('Breakdown:', style: TextStyle(fontStyle: FontStyle.italic)),
        ...deductionBreakdown,
        const SizedBox(height: 10),
      ],
    );
  }

  // Function to load and append coordinator signature

  Future<void> _loadAndAppendCoordinatorSignature(String monthYear) async {
    try {



      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("Staff")
          .where("id", isEqualTo: bioData!.firebaseAuthId)
          .get();

      DocumentSnapshot timesheetDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(snap.docs[0].id)
          .collection("TimeSheets")
          .doc(monthYear) // Assuming monthYear is the document ID
          .get();


      if (timesheetDoc.exists) {
        Map<String, dynamic> data = timesheetDoc.data() as Map<String,
            dynamic>;
        Uint8List coordinatorSignature = data['facilitySupervisorSignature']; // Get coordinator signature


        // Update the timesheet with the coordinator's signature

      } else {
        log('Timesheet document not found.');
      }
    } catch (e) {
      log("Error loading coordinator signature $e");
    }
  }
}