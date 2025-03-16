import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:refreshable_widget/refreshable_widget.dart';

import '../../models/attendance_model.dart';
import '../../models/bio_model.dart';
import '../../widgets/drawer.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Alignment,Border; // Import and hide conflicting classes
import 'package:flutter_email_sender/flutter_email_sender.dart';


class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  _TimesheetScreenState createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
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

  List<String?> projectNames = []; // Store project names from Isar
  List<String?> supervisorNames = []; // Store project names from Isar
  //late final bioData;
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
    await _loadInitialData();
    _startInitialTimer();
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

  Future<void> _createAndExportPDF() async {
    final pdf = pw.Document();
    String monthYear =
    DateFormat('MMMM, yyyy').format(DateTime(selectedYear, selectedMonth + 1));

    try {
      final ByteData logoBytes =
      await rootBundle.load('assets/image/ccfn_logo.png');
      final Uint8List logoImageData = logoBytes.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoImageData);

      final supervisorNames = await _getSupervisorNames();
      final signatureColumns = await _buildSignatureColumns(supervisorNames);

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

      final Uint8List pdfBytes = await pdf.save();

      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "timesheet_${monthYear}_$selectedBioLastName.pdf")
        ..click();

      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print("Error generating PDF: $e");
    }
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


  Future<Map<String, String>> _getSupervisorNames() async {
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

  pw.Widget _buildTimesheetTable(pw.Context context) {
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
      'Paternity',
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
                    style: pw.TextStyle(fontSize: 12 * pdfTableFontSizeFactor)), // Reduced table text size
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

  String _getDurationForDate2(DateTime date, String? projectName,
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

  // Helper function to calculate capped hours for a single date
  double _getCappedHoursForDate(DateTime date, String? projectName,
      String category) {
    double totalHoursForDate = 0;
    for (var attendance in attendanceData) {
      try {
        DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
            attendance.date!);
        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          double hours = attendance.noOfHours ?? 0; // Null-safe access
          if (category == projectName && !attendance.offDay!) {
            totalHoursForDate += hours > 8 ? 8 : hours;
          } else if (attendance.offDay! &&
              attendance.durationWorked?.toLowerCase() ==
                  category.toLowerCase()) {
            totalHoursForDate += hours > 8 ? 8 : hours;
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
        });

        await getSupervisor(
            userId, selectedYear, selectedMonth);
        _loadSupervisorNames(data['department'], data['state']);
      } else {
        print("No bio data found for user ID: $userId");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }


  getDateFromUser() async {
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


  void initializeDateRange(int month, int year) {
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
      'Paternity',
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


  Future<void> getSupervisor(String selectedFirebaseId, int selectedYear,
      int selectedMonth) async {
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

  // Function to create the Firestore stream
  Stream<DocumentSnapshot> getSupervisorStream(String selectedFirebaseId,
      int selectedYear, int selectedMonth) {
    return FirebaseFirestore.instance
        .collection("Staff")
        .doc(selectedFirebaseId)
        .collection("TimeSheets")
        .doc(DateFormat('MMMM_yyyy').format(
        DateTime(selectedYear, selectedMonth + 1)))
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              hint: const Text('Select Supervisor'),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
              hint: const Text('Select Supervisor'),
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
        title: Text('Timesheet', style: TextStyle(fontSize: 12 * titleFontSizeFactor)),
        toolbarHeight: 50 * appBarHeightFactor,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save_alt, size: 24 * iconSizeFactor),
            onPressed: _createAndExportPDF,
          ),
          Icon(Icons.picture_as_pdf, size: 24 * iconSizeFactor),
          SizedBox(width: 15 * marginFactor)
          // IconButton(
          //   icon: const Icon(Icons.save_alt), // Use a suitable icon for Excel
          //   onPressed: _createAndExportExcel,
          // ),
        ],
      ),
      drawer:
      // role == "User"
      //     ?
      drawer(this.context),
      // : drawer2(this.context, IsarService()),
      body: _isLoading // Conditional rendering based on loading state
          ? const Center(
          child: CircularProgressIndicator()) // Show loading indicator
          :
      SingleChildScrollView( // Wrap the entire body in SingleChildScrollView
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Padding(
              padding: EdgeInsets.all(8.0 * paddingFactor),
              child: Column(
                //mainAxisAlignment:MainAxisAlignment.start,
                  children: [
                    Image(
                      image: const AssetImage("./assets/image/ccfn_logo.png"),
                      width: MediaQuery.of(context).size.width * 0.10 * iconSizeFactor,
                      //height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.30),
                    ),
                    Text('Name: $selectedBioFirstName $selectedBioLastName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),),
                    SizedBox(height: 5 * marginFactor),
                    Text('Department: $selectedBioDepartment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),),
                    SizedBox(height: 5 * marginFactor),
                    Text('Designation: $selectedBioDesignation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),),
                    SizedBox(height: 5 * marginFactor),
                    Text('Location: $selectedBioLocation', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),),
                    SizedBox(height: 5 * marginFactor),
                    Text('State: $selectedBioState', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),),
                    SizedBox(height: 10 * marginFactor),
                  ]
              ),),


            // Month Picker Dropdown
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0 * paddingFactor),
              child: Row(
                children: [
                  const Text(
                    'Select Month:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 10 * marginFactor),
                  DropdownButton<int>(
                    value: selectedMonth,
                    items: List.generate(12, (index) {
                      DateTime monthDate = DateTime(2024, index + 1, 1);
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(DateFormat.MMMM().format(monthDate), style: TextStyle(fontSize: 14 * dropdownFontSizeFactor)),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 10 * marginFactor),


                  DropdownButton<int>(
                    value: selectedYear,
                    items: List.generate(10, (index) {
                      int year = DateTime
                          .now()
                          .year - index;
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString(), style: TextStyle(fontSize: 14 * dropdownFontSizeFactor)),
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
            ),
            Divider(height: 20 * marginFactor),
            // Attendance Sheet in a Container with 50% screen height
            Container(
              //height: MediaQuery.of(context).size.height * 0.5, // Adjusted height for better visibility
                child: RepaintBoundary(
                    key: _globalKey,
                    child: Column(
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(), // Smooth scrolling effect
                            padding: EdgeInsets.symmetric(horizontal: 10 * paddingFactor),
                            dragStartBehavior: DragStartBehavior.start,
                            clipBehavior: Clip.hardEdge,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            child:
                            // SizedBox( // <-- Use SizedBox to constrain the width
                            //     width: totalContentWidth(), // Calculate this dynamically
                            //     child:
                            Column(
                              children: [
                                Column(
                                  children: [
                                    // Header Row
                                    Row(
                                      children: [
                                        Container(
                                          width: 150,
                                          // Set a width for the "Project Name" header
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.blue.shade100,
                                          child: const Text(
                                            'Project Name',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ...daysInRange.map((date) {
                                          return Container(
                                            width: 50,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.all(8.0),
                                            color: isWeekend(date) ? Colors.grey
                                                .shade300 : Colors.blue
                                                .shade100,
                                            child: Text(
                                              DateFormat('dd MMM').format(date),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
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
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          width: 100,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.blue.shade100,
                                          child: const Text(
                                            'Percentage',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        Container(
                                          width: 150,
                                          // Keep the fixed width if you need it
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.white,
                                          child: projectNames.isEmpty
                                              ? const Text('No projects found')
                                              : DropdownButton<String>(
                                            value: selectedProjectName,
                                            isExpanded: true,
                                            // This will expand the dropdown to the Container's width
                                            items: projectNames.map((
                                                projectName) {
                                              return DropdownMenuItem<String>(
                                                value: projectName,
                                                child: FittedBox( // Use FittedBox to wrap the Text
                                                  fit: BoxFit.scaleDown,
                                                  // Scales down text to fit
                                                  alignment: Alignment
                                                      .centerLeft,
                                                  // Align text to the left
                                                  child: Text(projectName ??
                                                      'No Project Name'),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                selectedProjectName = newValue;
                                              });
                                            },
                                            hint: const Text('Select Project'),
                                          ),
                                        ),
                                        ...daysInRange.map((date) {
                                          bool weekend = isWeekend(date);
                                          String hours = _getDurationForDate2(
                                              date, selectedProjectName,
                                              selectedProjectName!);
                                          return Container(
                                            width: 50,
                                            // Set a fixed width for each day
                                            decoration: BoxDecoration(
                                              color: weekend ? Colors.grey
                                                  .shade300 : Colors.white,
                                              border: Border.all(
                                                  color: Colors.black12),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment
                                                  .center,
                                              children: [
                                                weekend
                                                    ? const SizedBox
                                                    .shrink() // No hours on weekends
                                                    : Text(
                                                  hours,
                                                  // Placeholder, replace with Isar data
                                                  style: const TextStyle(
                                                      color: Colors.blueAccent),
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
                                          child: Text(
                                            //'$totalHours hrs',
                                            "${calculateTotalHours1(
                                                selectedProjectName)
                                                .round()} hrs",

                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          width: 100,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.white,
                                          child: Text(
                                            // '${percentageWorked.toStringAsFixed(2)}%',
                                            '${calculatePercentageWorked1(
                                                selectedProjectName).round()}%',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
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
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18),
                                          ),
                                        ),
                                        ...List.generate(
                                            daysInRange.length, (index) {
                                          return Container(
                                            width: 50,
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
                                    ...[
                                      'Annual leave',
                                      'Holiday',
                                      'Paternity',
                                      'Maternity'
                                    ].map((category) {
                                      double outOfOfficeHours = calculateCategoryHours(
                                          category);
                                      double outOfOfficePercentage = calculateCategoryPercentage(
                                          category);
                                      return Row(
                                        children: [
                                          Container(
                                            width: 150,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.all(8.0),
                                            color: Colors.white,
                                            child: Text(
                                              category,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          ...daysInRange.map((date) {
                                            bool weekend = isWeekend(date);
                                            String offDayHours = _getDurationForDate2(
                                                date, selectedProjectName,
                                                category);


                                            return Container(
                                              width: 50,
                                              // Set a fixed width for each day
                                              decoration: BoxDecoration(
                                                color: weekend ? Colors.grey
                                                    .shade300 : Colors.white,
                                                border: Border.all(
                                                    color: Colors.black12),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment
                                                    .center,
                                                children: [
                                                  weekend
                                                      ? const SizedBox
                                                      .shrink() // No hours on weekends
                                                      : Text(
                                                    offDayHours,
                                                    // Placeholder, replace with Isar data
                                                    style: const TextStyle(
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
                                            padding: const EdgeInsets.all(8.0),
                                            color: Colors.white,
                                            child: Text(
                                              //'${outOfOfficeHours.toStringAsFixed(1)} hrs',
                                              "${calculateCategoryHours1(category)
                                                  .round()} hrs",
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Container(
                                            width: 100,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.all(8.0),
                                            color: Colors.white,
                                            child: Text(
                                              //'${outOfOfficePercentage.toStringAsFixed(1)}%',
                                              '${calculateCategoryPercentage(
                                                  category).round()}%',
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    // Attendance Rows
                                    Row(
                                      children: [
                                        Container(
                                          width: 150,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.white,
                                          child: const Text(
                                            'Total',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20),
                                          ),
                                        ),
                                        ...List.generate(
                                            daysInRange.length, (index) {
                                          return Container(
                                            width: 50,
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
                                          child: Text(
                                            // '$totalGrandHours hrs',
                                            "${calculateGrandTotalHours1()
                                                .toStringAsFixed(0)} hrs",
                                            // Or .round().toString() if grand total should also be rounded.
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          width: 100,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.all(8.0),
                                          color: Colors.white,
                                          child: Text(
                                            //'${grandPercentageWorked.toStringAsFixed(2)}%',
                                            '${calculateGrandPercentageWorked()
                                                .round()}%',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),


                                  ],
                                ),


                              ],
                            ),
                            //),
                          ),
                          SizedBox(height: 5 * marginFactor),
                          //Signature and Detials

                          const Divider(),
                          Text('Signature & Date', style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 25 * fontSizeFactor,),),
                          const Divider(),
                          Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.02 : 0.02),),
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.25 : 0.25),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //color: Colors.white,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment
                                            .center,
                                        // Vertically center the content
                                        crossAxisAlignment: CrossAxisAlignment
                                            .center,
                                        children: [
                                          Text('Name of Staff',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),),
                                          SizedBox(height: 5 * marginFactor),
                                          Text(
                                            '${selectedBioFirstName.toString()
                                                .toUpperCase()} ${selectedBioLastName
                                                .toString().toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 16 * fontSizeFactor,
                                              // fontWeight: FontWeight.bold,
                                              fontFamily: "NexaLight",
                                            ),
                                          ),
                                          SizedBox(height: 5 * marginFactor),
                                          // Adjust path and size accordingly
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.01 : 0.009)),
                                    // Signature of Staff
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.35 : 0.35),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //  color: Colors.grey.shade200,
                                      child: Column(
                                        children: [
                                          Text('Signature', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),),
                                          SizedBox(height: 5 * marginFactor),

                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final staffSignature = data['staffSignature']; // Assuming this stores the image URL
                                                //final facilitySupervisorSignatureStatus = data['staffSignature']; // Assuming you store the date

                                                if (staffSignature != null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return Container(
                                                    margin: const EdgeInsets
                                                        .only(
                                                      top: 20,
                                                      bottom: 24,
                                                    ),
                                                    height: MediaQuery
                                                        .of(context)
                                                        .size
                                                        .width *
                                                        (MediaQuery
                                                            .of(context)
                                                            .size
                                                            .shortestSide < 600
                                                            ? 0.30
                                                            : 0.15),
                                                    width: MediaQuery
                                                        .of(context)
                                                        .size
                                                        .width *
                                                        (MediaQuery
                                                            .of(context)
                                                            .size
                                                            .shortestSide < 600
                                                            ? 0.30
                                                            : 0.30),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius
                                                          .circular(20),
                                                      //color: Colors.grey.shade300,
                                                    ),
                                                    child:
                                                    //Image.network(Uri.decodeFull(staffSignature!)),

                                                    CachedNetworkImage(
                                                      imageUrl: staffSignature!,
                                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                                    ),

                                                  );
                                                }
                                                else
                                                if (staffSignature == null &&
                                                    staffSignatureLink ==
                                                        null) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      _pickImage();
                                                    },

                                                    child: Container(
                                                      margin: const EdgeInsets
                                                          .only(
                                                        top: 20,
                                                        bottom: 24,
                                                      ),
                                                      height: MediaQuery
                                                          .of(context)
                                                          .size
                                                          .width *
                                                          (MediaQuery
                                                              .of(context)
                                                              .size
                                                              .shortestSide <
                                                              600
                                                              ? 0.30
                                                              : 0.15),
                                                      width: MediaQuery
                                                          .of(context)
                                                          .size
                                                          .width *
                                                          (MediaQuery
                                                              .of(context)
                                                              .size
                                                              .shortestSide <
                                                              600
                                                              ? 0.30
                                                              : 0.30),
                                                      alignment: Alignment
                                                          .center,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius
                                                            .circular(20),
                                                        //color: Colors.grey.shade300,
                                                      ),
                                                      child: RefreshableWidget<
                                                          List<Uint8List>?>(
                                                        refreshCall: () async {
                                                          return await _readImagesFromDatabase();
                                                        },
                                                        refreshRate: const Duration(
                                                            seconds: 1),
                                                        errorWidget: Icon(
                                                          Icons.upload_file,
                                                          size: 80,
                                                          color: Colors.grey
                                                              .shade300,
                                                        ),
                                                        loadingWidget: Icon(
                                                          Icons.upload_file,
                                                          size: 80,
                                                          color: Colors.grey
                                                              .shade300,
                                                        ),
                                                        builder: (context,
                                                            value) {
                                                          if (value != null &&
                                                              value
                                                                  .isNotEmpty) {
                                                            return ListView
                                                                .builder(
                                                              itemCount: value
                                                                  .length,
                                                              itemBuilder: (
                                                                  context,
                                                                  index) =>
                                                                  Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                      top: 20,
                                                                      bottom: 24,
                                                                    ),
                                                                    height: MediaQuery
                                                                        .of(
                                                                        context)
                                                                        .size
                                                                        .width *
                                                                        (MediaQuery
                                                                            .of(
                                                                            context)
                                                                            .size
                                                                            .shortestSide <
                                                                            600
                                                                            ? 0.30
                                                                            : 0.15),
                                                                    width: MediaQuery
                                                                        .of(
                                                                        context)
                                                                        .size
                                                                        .width *
                                                                        (MediaQuery
                                                                            .of(
                                                                            context)
                                                                            .size
                                                                            .shortestSide <
                                                                            600
                                                                            ? 0.30
                                                                            : 0.30),
                                                                    alignment: Alignment
                                                                        .center,
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius
                                                                          .circular(
                                                                          20),
                                                                      //color: Colors.grey.shade300,
                                                                    ),
                                                                    child: Image
                                                                        .memory(
                                                                        value
                                                                            .first),
                                                                  ),


                                                            );
                                                          } else {
                                                            return Column(
                                                              mainAxisAlignment: MainAxisAlignment
                                                                  .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .upload_file,
                                                                  size: MediaQuery
                                                                      .of(
                                                                      context)
                                                                      .size
                                                                      .width *
                                                                      (MediaQuery
                                                                          .of(
                                                                          context)
                                                                          .size
                                                                          .shortestSide <
                                                                          600
                                                                          ? 0.075
                                                                          : 0.05),
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                ),
                                                                const SizedBox(
                                                                    height: 8),
                                                                const Text(
                                                                  "Click to Upload Signature Image Here",
                                                                  style: TextStyle(
                                                                    fontSize: 14,
                                                                    color: Colors
                                                                        .grey,
                                                                    fontWeight: FontWeight
                                                                        .bold,
                                                                  ),
                                                                  textAlign: TextAlign
                                                                      .center,
                                                                ),
                                                              ],
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                } else
                                                if (staffSignature == null &&
                                                    staffSignatureLink !=
                                                        null) {
                                                  return Column(
                                                    children: [
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          top: 20,
                                                          bottom: 24,
                                                        ),
                                                        height: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.15),
                                                        width: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.30),
                                                        alignment: Alignment
                                                            .center,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius
                                                              .circular(20),
                                                          //color: Colors.grey.shade300,
                                                        ),
                                                        child: Image.network(
                                                            staffSignatureLink!),
                                                      ),


                                                    ],
                                                  );
                                                } else
                                                if (staffSignature != null &&
                                                    staffSignatureLink !=
                                                        null) {
                                                  return Column(
                                                    children: [
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          top: 20,
                                                          bottom: 24,
                                                        ),
                                                        height: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.15),
                                                        width: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.30),
                                                        alignment: Alignment
                                                            .center,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius
                                                              .circular(20),
                                                          //color: Colors.grey.shade300,
                                                        ),
                                                        child: Image.network(
                                                            staffSignatureLink!),
                                                      ),

                                                    ],
                                                  );
                                                }
                                                else {
                                                  return Column(
                                                    children: [
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          top: 20,
                                                          bottom: 24,
                                                        ),
                                                        height: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.15),
                                                        width: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.30),
                                                        alignment: Alignment
                                                            .center,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius
                                                              .circular(20),
                                                          //color: Colors.grey.shade300,
                                                        ),
                                                        child: Image.network(
                                                            staffSignatureLink!),
                                                      ),


                                                    ],
                                                  );
                                                }
                                              }
                                              else {
                                                if (staffSignatureLink ==
                                                    null) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      _pickImage();
                                                    },

                                                    child: Container(
                                                      margin: const EdgeInsets
                                                          .only(
                                                        top: 20,
                                                        bottom: 24,
                                                      ),
                                                      height: MediaQuery
                                                          .of(context)
                                                          .size
                                                          .width *
                                                          (MediaQuery
                                                              .of(context)
                                                              .size
                                                              .shortestSide <
                                                              600
                                                              ? 0.30
                                                              : 0.15),
                                                      width: MediaQuery
                                                          .of(context)
                                                          .size
                                                          .width *
                                                          (MediaQuery
                                                              .of(context)
                                                              .size
                                                              .shortestSide <
                                                              600
                                                              ? 0.30
                                                              : 0.30),
                                                      alignment: Alignment
                                                          .center,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius
                                                            .circular(20),
                                                        //color: Colors.grey.shade300,
                                                      ),
                                                      child: RefreshableWidget<
                                                          List<Uint8List>?>(
                                                        refreshCall: () async {
                                                          return await _readImagesFromDatabase();
                                                        },
                                                        refreshRate: const Duration(
                                                            seconds: 1),
                                                        errorWidget: Icon(
                                                          Icons.upload_file,
                                                          size: 80,
                                                          color: Colors.grey
                                                              .shade300,
                                                        ),
                                                        loadingWidget: Icon(
                                                          Icons.upload_file,
                                                          size: 80,
                                                          color: Colors.grey
                                                              .shade300,
                                                        ),
                                                        builder: (context,
                                                            value) {
                                                          if (value != null &&
                                                              value
                                                                  .isNotEmpty) {
                                                            return ListView
                                                                .builder(
                                                              itemCount: value
                                                                  .length,
                                                              itemBuilder: (
                                                                  context,
                                                                  index) =>
                                                                  Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                      top: 20,
                                                                      bottom: 24,
                                                                    ),
                                                                    height: MediaQuery
                                                                        .of(
                                                                        context)
                                                                        .size
                                                                        .width *
                                                                        (MediaQuery
                                                                            .of(
                                                                            context)
                                                                            .size
                                                                            .shortestSide <
                                                                            600
                                                                            ? 0.30
                                                                            : 0.15),
                                                                    width: MediaQuery
                                                                        .of(
                                                                        context)
                                                                        .size
                                                                        .width *
                                                                        (MediaQuery
                                                                            .of(
                                                                            context)
                                                                            .size
                                                                            .shortestSide <
                                                                            600
                                                                            ? 0.30
                                                                            : 0.30),
                                                                    alignment: Alignment
                                                                        .center,
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius
                                                                          .circular(
                                                                          20),
                                                                      //color: Colors.grey.shade300,
                                                                    ),
                                                                    child: Image
                                                                        .memory(
                                                                        value
                                                                            .first),
                                                                  ),


                                                            );
                                                          } else {
                                                            return Column(
                                                              mainAxisAlignment: MainAxisAlignment
                                                                  .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .upload_file,
                                                                  size: MediaQuery
                                                                      .of(
                                                                      context)
                                                                      .size
                                                                      .width *
                                                                      (MediaQuery
                                                                          .of(
                                                                          context)
                                                                          .size
                                                                          .shortestSide <
                                                                          600
                                                                          ? 0.075
                                                                          : 0.05),
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                ),
                                                                const SizedBox(
                                                                    height: 8),
                                                                const Text(
                                                                  "Click to Upload Signature Image Here",
                                                                  style: TextStyle(
                                                                    fontSize: 14,
                                                                    color: Colors
                                                                        .grey,
                                                                    fontWeight: FontWeight
                                                                        .bold,
                                                                  ),
                                                                  textAlign: TextAlign
                                                                      .center,
                                                                ),
                                                              ],
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                } else if (staffSignatureLink !=
                                                    null) {
                                                  return Column(
                                                    children: [
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          top: 20,
                                                          bottom: 24,
                                                        ),
                                                        height: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.15),
                                                        width: MediaQuery
                                                            .of(context)
                                                            .size
                                                            .width *
                                                            (MediaQuery
                                                                .of(context)
                                                                .size
                                                                .shortestSide <
                                                                600
                                                                ? 0.30
                                                                : 0.30),
                                                        alignment: Alignment
                                                            .center,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius
                                                              .circular(20),
                                                          //color: Colors.grey.shade300,
                                                        ),
                                                        child: Image.network(
                                                            staffSignatureLink!),
                                                      ),


                                                    ],
                                                  );
                                                }
                                              }
                                              return const Text(
                                                  "Loading Signature...");
                                            },
                                          ),

                                          // Adjust path and size accordingly
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.01 : 0.009)),
                                    // Date of Signature of Staff

                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.30 : 0.30),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          const Text('Date', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20 ),),
                                          SizedBox(height: 5 * marginFactor),

                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final staffSignatureDate = data['staffSignatureDate']; // Assuming this stores the image URL
                                                //  final caritasSupervisorDate = data['date']; // Assuming you store the date

                                                if (staffSignatureDate !=
                                                    null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return Column(
                                                    children: [
                                                      //Image.network(facilitySupervisorSignature!), // Load the image from the cloud URL
                                                      Text(staffSignatureDate
                                                          .toString()),
                                                    ],
                                                  );
                                                } else {
                                                  return Text(
                                                      formattedDate,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold));
                                                }
                                              } else {
                                                return Text(formattedDate,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold));
                                              }
                                            },
                                          ),
                                          SizedBox(height: 5 * marginFactor),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.02 : 0.02),),


                                  ],
                                ),
                                SizedBox(width: MediaQuery
                                    .of(context)
                                    .size
                                    .width * (MediaQuery
                                    .of(context)
                                    .size
                                    .shortestSide < 600 ? 0.005 : 0.005)),
                                const Divider(),
                                //Second - Project Coordinator Section
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.02 : 0.02),),
                                    //Name of Project Cordinator
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width *
                                          (MediaQuery
                                              .of(context)
                                              .size
                                              .shortestSide < 600
                                              ? 0.30
                                              : 0.25),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //  color: Colors.grey.shade200,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          // Email of Project Cordinator
                                          Text(
                                            'Name of Facility Supervisor',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),
                                          ),
                                          SizedBox(height: 5 * marginFactor),
                                          //
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final facilitySupervisor = data['facilitySupervisor']; // Assuming this stores the image URL
                                                //final caritasSupervisorDate = data['date'];
                                                //Assuming you store the date
                                                print("facilitySupervisor == $facilitySupervisor");

                                                if (facilitySupervisor == null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return  buildFacilitySupervisorDropdown();
                                                } else {
                                                  return Text(
                                                      "$facilitySupervisor",style: TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),);
                                                }
                                              } else {
                                                return buildFacilitySupervisorDropdown();
                                              }
                                            },
                                          ),
                                          //


                                          SizedBox(height: 5 * marginFactor),
                                        ],
                                      ),
                                    ),


                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.01 : 0.009)),
                                    //Signature of Project Cordinator
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.35 : 0.35),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //color: Colors.grey.shade200,
                                      child: Column(
                                        children: [
                                          Text('Signature', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),
                                          ),
                                          SizedBox(height: 5 * marginFactor),
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final facilitySupervisorSignature = data['facilitySupervisorSignature']; // Assuming this stores the image URL
                                                final facilitySupervisorSignatureStatus = data['facilitySupervisorSignatureStatus']; // Assuming you store the date
                                                final facilitySupervisorRejectionReason = data['facilitySupervisorRejectionReason']; // Assuming you store the date

                                                if (facilitySupervisorSignature != null && facilitySupervisorSignatureStatus == "Approved") {
                                                  return Container(
                                                    margin: const EdgeInsets.only(
                                                      top: 20,
                                                      bottom: 24,
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxHeight: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                      maxWidth: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                    ),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(20),
                                                      // color: Colors.grey.shade300, // Uncomment if needed
                                                    ),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min, // Prevents expanding to fill space
                                                      children: [
                                                        Flexible(
                                                          child: Image.network(
                                                            facilitySupervisorSignature!,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            const Icon(Icons.check_circle, color: Colors.green),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }

                                                else if(facilitySupervisorSignature !=
                                                    null && facilitySupervisorSignatureStatus == "Rejected"){
                                                  return Column(
                                                    children: [
                                                      const Text("Awaiting Facility Supervisor Signature"),
                                                      const SizedBox(height: 8),
                                                      if (facilitySupervisorSignatureStatus == "Rejected")
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.cancel, color: Colors.red),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                            const SizedBox(width: 15),
                                                            GestureDetector(
                                                              onTap: () {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (context) {
                                                                    return AlertDialog(
                                                                      title: const Text("Reason for Rejection"),
                                                                      content: Text(facilitySupervisorRejectionReason ?? "No reason provided."),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () {
                                                                            Navigator.of(context).pop();
                                                                          },
                                                                          child: const Text("Close"),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                              child: const Icon(
                                                                Icons.info_outline,
                                                                color: Colors.blue,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      else
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.check_circle, color: Colors.green),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  );
                                                }
                                                else {
                                                  return Column(
                                                    children: [
                                                      const Text("Awaiting Facility Supervisor Signature"),
                                                      const SizedBox(height: 8),
                                                      if (facilitySupervisorSignatureStatus == "Pending")
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.access_time, color: Colors.orange),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        )
                                                      else if (facilitySupervisorSignatureStatus == "Rejected")
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.cancel, color: Colors.red),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                            const SizedBox(width: 15),
                                                            GestureDetector(
                                                              onTap: () {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (context) {
                                                                    return AlertDialog(
                                                                      title: const Text("Reason for Return"),
                                                                      content: Text(facilitySupervisorRejectionReason ?? "No reason provided."),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () {
                                                                            Navigator.of(context).pop();
                                                                          },
                                                                          child: const Text("Close"),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                              child: const Icon(
                                                                Icons.info_outline,
                                                                color: Colors.blue,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      else
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.check_circle, color: Colors.green),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$facilitySupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  );

                                                }
                                              } else {
                                                return const Text(
                                                    "Timesheet Yet to be submitted for Project Cordinator's Signature");
                                              }
                                            },
                                          ), // Adjust path and size accordingly
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 5 * marginFactor),
                                    //Date of Project Signature Date

                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.30 : 0.30),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          const Text('Date', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20 ,),),
                                          SizedBox(height: 5 * marginFactor),
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final facilitySupervisorDate = data['facilitySupervisorSignatureDate']; // Assuming this stores the image URL
                                                //  final caritasSupervisorDate = data['date']; // Assuming you store the date

                                                if (facilitySupervisorDate !=
                                                    null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return Column(
                                                    children: [
                                                      //Image.network(facilitySupervisorSignature!), // Load the image from the cloud URL
                                                      Text(
                                                          facilitySupervisorDate
                                                              .toString()),
                                                    ],
                                                  );
                                                } else {
                                                  return const Text(
                                                      "Awaiting Facility Supervisor Date");
                                                }
                                              } else {
                                                return const Text(
                                                    "Timesheet Yet to be submitted for Project Cordinator's Signature Date");
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    //SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),
                                  ],
                                ),
                                SizedBox(width: MediaQuery
                                    .of(context)
                                    .size
                                    .width * (MediaQuery
                                    .of(context)
                                    .size
                                    .shortestSide < 600 ? 0.005 : 0.005)),
                                const Divider(),
                                // Third - CARITAS Supervisor Section
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.02 : 0.02),),
                                    // Name of CARITAS Supervisor
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width *
                                          (MediaQuery
                                              .of(context)
                                              .size
                                              .shortestSide < 600
                                              ? 0.30
                                              : 0.25),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //color: Colors.grey.shade200,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            'Name of CARITAS Supervisor',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),
                                            ),

                                          SizedBox(height: 5 * marginFactor),
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final caritasSupervisor = data['caritasSupervisor']; // Assuming this stores the image URL
                                                //final caritasSupervisorDate = data['date'];
                                                //Assuming you store the date
                                                print("caritasSupervisor == $caritasSupervisor");

                                                if (caritasSupervisor == null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return  buildSupervisorDropdown();
                                                } else {
                                                  return Text(
                                                      "$caritasSupervisor",style: TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 16 * fontSizeFactor,),);
                                                }
                                              } else {
                                                return buildSupervisorDropdown();
                                              }
                                            },
                                          ),
                                          SizedBox(height: 5 * marginFactor),

                                        ],
                                      ),
                                    ),

                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.01 : 0.009)),
                                    //Signature of CARITAS Supervisor
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.35 : 0.35),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8.0),
                                      //color: Colors.grey.shade200,
                                      child: Column(
                                        children: [
                                          Text('Signature', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20 * fontSizeFactor,),
                                          ),
                                          SizedBox(height: 5 * marginFactor),
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;
                                                final caritasSupervisorSignature = data['caritasSupervisorSignature']; // Assuming this stores the image URL
                                                final caritasSupervisorSignatureStatus = data['caritasSupervisorSignatureStatus']; // Assuming you store the date
                                                final caritasSupervisorRejectionReason = data['caritasSupervisorRejectionReason'];
                                                final facilitySupervisorSignatureStatus = data['facilitySupervisorSignatureStatus'];

                                                // if (caritasSupervisorSignature !=
                                                //     null) {
                                                //   // caritasSupervisorSignature is a URL/path to the image
                                                //   return Container(
                                                //     margin: const EdgeInsets
                                                //         .only(
                                                //       top: 20,
                                                //       bottom: 24,
                                                //     ),
                                                //     height: MediaQuery
                                                //         .of(context)
                                                //         .size
                                                //         .width *
                                                //         (MediaQuery
                                                //             .of(context)
                                                //             .size
                                                //             .shortestSide < 600
                                                //             ? 0.30
                                                //             : 0.15),
                                                //     width: MediaQuery
                                                //         .of(context)
                                                //         .size
                                                //         .width *
                                                //         (MediaQuery
                                                //             .of(context)
                                                //             .size
                                                //             .shortestSide < 600
                                                //             ? 0.30
                                                //             : 0.30),
                                                //     alignment: Alignment.center,
                                                //     decoration: BoxDecoration(
                                                //       borderRadius: BorderRadius
                                                //           .circular(20),
                                                //       //color: Colors.grey.shade300,
                                                //     ),
                                                //     child: Image.network(
                                                //         caritasSupervisorSignature!),
                                                //   );
                                                // }

                                                if (caritasSupervisorSignature != null && caritasSupervisorSignatureStatus == "Approved") {
                                                  return Container(
                                                    margin: const EdgeInsets.only(
                                                      top: 20,
                                                      bottom: 24,
                                                    ),
                                                    constraints: BoxConstraints(
                                                      maxHeight: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                      maxWidth: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                    ),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(20),
                                                      // color: Colors.grey.shade300, // Uncomment if needed
                                                    ),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min, // Prevents expanding to fill space
                                                      children: [
                                                        Flexible(
                                                          child: Image.network(
                                                            caritasSupervisorSignature!,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            const Icon(Icons.check_circle, color: Colors.green),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              "$caritasSupervisorSignatureStatus",
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }



                                                else if (caritasSupervisorSignatureStatus == "Pending" && facilitySupervisorSignatureStatus == "Pending") {
                                                  return Column(
                                                    children: [
                                                    const Text(
                                                    "Awaiting Approved Signature from Facility Supervisor before signature from CARITAS Supervisor ",
                                                    // style: TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                              const SizedBox(height: 8),
                                              facilitySupervisorSignatureStatus == "Pending"
                                              ? Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets.only(top: 0.0),
                                              child: Icon(Icons.access_time, color: Colors.orange),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                              child: Padding(
                                              padding: const EdgeInsets.only(top: 0.0),
                                              child: Text(
                                              "$facilitySupervisorSignatureStatus (Awaiting Approval from Facility Supervisor)",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              ),
                                              ),
                                              ],
                                              )
                                                  : facilitySupervisorSignatureStatus == "Rejected"
                                              ? Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets.only(top: 0.0),
                                              child: Icon(Icons.cancel, color: Colors.red),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                              child: Padding(
                                              padding: const EdgeInsets.only(bottom: 0.0),
                                              child: Text(
                                              "$facilitySupervisorSignatureStatus (Approval Rejected by Facility Supervisor)",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                              onTap: () {
                                              showDialog(
                                              context: context,
                                              builder: (context) {
                                              return AlertDialog(
                                              title: const Text("Reason for Rejection"),
                                              content: Text(
                                              facilitySupervisorSignatureStatus ?? "No reason provided.",
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              actions: [
                                              TextButton(
                                              onPressed: () {
                                              Navigator.of(context).pop();
                                              },
                                              child: const Text("Close"),
                                              ),
                                              ],
                                              );
                                              },
                                              );
                                              },
                                              child: const Icon(
                                              Icons.info_outline,
                                              color: Colors.blue,
                                              size: 20,
                                              ),
                                              ),]
                                              )
                                                  : Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets.only(top: 0.0),
                                              child: Icon(Icons.check_circle, color: Colors.green),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                              child: Padding(
                                              padding: const EdgeInsets.only(bottom: 0.0),
                                              child: Text(
                                              "$facilitySupervisorSignatureStatus",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              ),
                                              ),
                                              ],
                                              ),
                                              ],
                                              );
                                              }
                                              else if (caritasSupervisorSignatureStatus == "Pending" && facilitySupervisorSignatureStatus == "Rejected") {
                                              return Column(
                                              children: [
                                              const Text(
                                              "Awaiting Approved Signature from Facility Supervisor before signature from CARITAS Supervisor ",
                                              // style: TextStyle(fontWeight: FontWeight.w100),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              const SizedBox(height: 8),
                                              facilitySupervisorSignatureStatus == "Rejected"
                                              ? const Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              Padding(
                                              padding: EdgeInsets.only(top: 0.0),
                                              child: Icon(Icons.cancel, color: Colors.red),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                              child: Padding(
                                              padding: EdgeInsets.only(bottom: 0.0),
                                              child: Text(
                                              "(Approval Rejected by Facility Supervisor)",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              ),
                                              ),
                                              SizedBox(width: 8),

                                              ],
                                              )
                                                  : Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets.only(top: 0.0),
                                              child: Icon(Icons.check_circle, color: Colors.green),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                              child: Padding(
                                              padding: const EdgeInsets.only(bottom: 0.0),
                                              child: Text(
                                              "$facilitySupervisorSignatureStatus",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                              ),
                                              ),
                                              ),
                                              ],
                                              ),
                                              ],
                                              );
                                              }


                                              else {
                                              return Column(
                                              children: [
                                              const Text(
                                              "Awaiting Caritas Supervisor Signature"),
                                              const SizedBox(height: 8),
                                              caritasSupervisorSignatureStatus ==
                                              "Pending"
                                              ?
                                              Row(
                                              //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets
                                                  .only(
                                              top: 0.0),
                                              child:
                                              Icon(Icons
                                                  .access_time,
                                              color: Colors
                                                  .orange),
                                              ),
                                              const SizedBox(width: 8),
                                              Padding(
                                              padding: const EdgeInsets
                                                  .only(
                                              top: 0.0),
                                              child: Text(
                                              "$caritasSupervisorSignatureStatus",
                                              style: const TextStyle(
                                              fontWeight: FontWeight
                                                  .bold),
                                              ),
                                              ),
                                              ]
                                              )
                                                  : caritasSupervisorSignatureStatus ==
                                              "Rejected" ?
                                              Row(
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets
                                                  .only(
                                              top: 0.0),
                                              child:
                                              Icon(Icons.cancel,
                                              color: Colors
                                                  .red),
                                              ),
                                              const SizedBox(width: 8),
                                              Padding(
                                              padding: const EdgeInsets
                                                  .only(
                                              bottom: 0.0),
                                              child: Text(
                                              "$caritasSupervisorSignatureStatus",
                                              style: const TextStyle(
                                              fontWeight: FontWeight
                                                  .bold),
                                              ),
                                              ),
                                              const SizedBox(width:8),
                                              GestureDetector(
                                              onTap: () {
                                              showDialog(
                                              context: context,
                                              builder: (context) {
                                              return AlertDialog(
                                              title: const Text("Reason for Rejection"),
                                              content: Text(caritasSupervisorRejectionReason ?? "No reason provided."),
                                              actions: [
                                              TextButton(
                                              onPressed: () {
                                              Navigator.of(context).pop();
                                              },
                                              child: const Text("Close"),
                                              ),
                                              ],
                                              );
                                              },
                                              );
                                              },
                                              child: const Icon(
                                              Icons.info_outline,
                                              color: Colors.blue,
                                              size: 20,
                                              ),
                                              ),
                                              ]
                                              )
                                                  : Row(
                                              children: [
                                              const Padding(
                                              padding: EdgeInsets
                                                  .only(
                                              top: 0.0),
                                              child:
                                              Icon(Icons
                                                  .check_circle,
                                              color: Colors
                                                  .green),
                                              ),
                                              const SizedBox(width: 8),
                                              Padding(
                                              padding: const EdgeInsets
                                                  .only(
                                              bottom: 0.0),
                                              child: Text(
                                              "$caritasSupervisorSignatureStatus",
                                              style: const TextStyle(
                                              fontWeight: FontWeight
                                                  .bold),
                                              ),
                                              ),
                                              ]
                                              ),


                                              ],
                                              );
                                              }


                                              } else {
                                              return const Text(
                                              "Timesheet Yet to be submitted for Caritas Supervisor's Signature");
                                              }
                                            },
                                          ), // Adjust path and size accordingly
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * (MediaQuery
                                        .of(context)
                                        .size
                                        .shortestSide < 600 ? 0.01 : 0.009)),

                                    //Date of CARITAS Supervisor
                                    Container(
                                      width: MediaQuery
                                          .of(context)
                                          .size
                                          .width * (MediaQuery
                                          .of(context)
                                          .size
                                          .shortestSide < 600 ? 0.30 : 0.30),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          const Text('Date', style: TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 20),),
                                          SizedBox(height: 5 * marginFactor),
                                          StreamBuilder<DocumentSnapshot>(
                                            // Stream the supervisor signature
                                            stream: FirebaseFirestore.instance
                                                .collection("Staff")
                                                .doc(
                                                selectedFirebaseId) // Replace with how you get the staff document ID
                                                .collection("TimeSheets")
                                                .doc(
                                                DateFormat('MMMM_yyyy').format(
                                                    DateTime(selectedYear,
                                                        selectedMonth +
                                                            1))) // Replace monthYear with the timesheet document ID
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data!.exists) {
                                                final data = snapshot.data!
                                                    .data() as Map<
                                                    String,
                                                    dynamic>;

                                                final caritasSupervisorDate = data['caritasSupervisorSignatureDate']; // Assuming this stores the image URL
                                                //  final caritasSupervisorDate = data['date']; // Assuming you store the date

                                                if (caritasSupervisorDate !=
                                                    null) {
                                                  // caritasSupervisorSignature is a URL/path to the image
                                                  return Column(
                                                    children: [
                                                      //Image.network(facilitySupervisorSignature!), // Load the image from the cloud URL
                                                      Text(
                                                          caritasSupervisorDate
                                                              .toString()),
                                                    ],
                                                  );
                                                } else {
                                                  return const Text(
                                                      "Awaiting Caritas Supervisor Date");
                                                }
                                              } else {
                                                return const Text(
                                                    "Timesheet Yet to be submitted for Caritas Signature Date");
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5 * marginFactor),
                                const Divider(),
                                StreamBuilder<DocumentSnapshot>(
                                  // Stream the supervisor signature
                                  stream: FirebaseFirestore.instance
                                      .collection("Staff")
                                      .doc(
                                      selectedFirebaseId) // Replace with how you get the staff document ID
                                      .collection("TimeSheets")
                                      .doc(DateFormat('MMMM_yyyy').format(
                                      DateTime(selectedYear, selectedMonth +
                                          1))) // Replace monthYear with the timesheet document ID
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data = snapshot.data!.data() as Map<
                                          String,
                                          dynamic>;

                                      final caritasSupervisorSignature = data['caritasSupervisorSignature']; // Assuming this stores the image URL
                                      final facilitySupervisorSignature = data['facilitySupervisorSignature'];
                                      final staffSignature = data['staffSignature']; // Assuming you store the date

                                      if (caritasSupervisorSignature != null &&
                                          facilitySupervisorSignature != null &&
                                          staffSignature != null) {
                                        // caritasSupervisorSignature is a URL/path to the image
                                        return
                                          ElevatedButton(
                                            onPressed: sendEmailToSelf,
                                            // Call the save function
                                            child: const Text(
                                                'Email Signed Timesheet to Self'),
                                          );
                                      } else {
                                        return ElevatedButton(
                                          onPressed: _saveTimesheetToFirestore,
                                          // Call the save function
                                          child: const Text('Submit Timesheet'),
                                        );
                                      }
                                    } else {
                                      return ElevatedButton(
                                        onPressed: _saveTimesheetToFirestore,
                                        // Call the save function
                                        child: const Text('Submit Timesheet'),
                                      );
                                    }
                                  },
                                ),

                                SizedBox(height: MediaQuery
                                    .of(context)
                                    .size
                                    .width * (MediaQuery
                                    .of(context)
                                    .size
                                    .shortestSide < 600 ? 0.020 : 0.020)),
                              ]
                          ),
                        ]
                    )


                )

            ),


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

  Future<void> _saveTimesheetToFirestore() async {

    print("Step One");

    if (staffSignatureLink == null) {
      // Handle case where signature is not present (e.g., show a message)
      Fluttertoast.showToast(
          msg: "Cannot send timesheet without staff signature",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.black54,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0);




    }
    if (selectedSupervisor == null ||
        _selectedFacilitySupervisorFullName == null) {
      // Handle case where signature is not present (e.g., show a message)

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

    String monthYear = DateFormat('MMMM_yyyy').format(
        DateTime(selectedYear, selectedMonth + 1));

    try {
      log("Start Pushing timesheet");
      // // Construct the timesheet data to be saved
      // List<BioModel> getAttendanceForBio =
      // await IsarService().getBioInfoWithUserBio();


      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("Staff")
          .where("id", isEqualTo: selectedFirebaseId)
          .get();

      List<Map<String, dynamic>> timesheetEntries = [];

      for (var date in daysInRange) {
        Map<String,
            dynamic>? entryForDate; // Store the entry for the current date

        for (var attendance in attendanceData) {
          try {
            DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(
                attendance.date!);
            if (attendanceDate.year == date.year &&
                attendanceDate.month == date.month &&
                attendanceDate.day == date.day) {
              entryForDate = {
                // Create or update the entry for this date
                'date': DateFormat('yyyy-MM-dd').format(date),
                'noOfHours': attendance.noOfHours,
                // Use noOfHours directly from attendance
                'projectName': selectedProjectName,
                'offDay': attendance.offDay,
                // Use offDay directly
                'durationWorked': attendance.durationWorked,
                // Use durationWorked directly
              };
              break; // Exit inner loop once an entry is found for the date
            }
          } catch (e) {
            log("Error parsing date: $e");
          }
        }

        if (entryForDate !=
            null) { // Add the entry if it exists for this date
          timesheetEntries.add(entryForDate);
        }
      }

      Map<String, dynamic> timesheetData = {
        'projectName': selectedProjectName,
        'staffName': '$selectedBioFirstName $selectedBioLastName',
        'staffSignature': staffSignatureLink,
        // 'staffSignatureDate': DateFormat('MMMM dd, yyyy').format(
        //     createCustomDate(selectedMonth + 1, selectedYear)),
        'staffSignatureDate': DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        'facilitySupervisorSignatureDate': null,
        'caritasSupervisorSignatureDate': null,
        'department': selectedBioDepartment,
        'state': selectedBioState,
        'facilitySupervisorSignatureStatus': 'Pending',
        'caritasSupervisorSignatureStatus': 'Pending',
        'timesheetEntries': timesheetEntries,
        //<<< The list of date/hour entries
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
      // Handle error (e.g., show a dialog)
    }
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