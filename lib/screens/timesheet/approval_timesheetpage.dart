import 'dart:developer';
import 'dart:html' as html; // Import for web-specific APIs
import 'dart:convert'; // For base64 encoding if needed
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'package:pdf/pdf.dart';
import 'package:refreshable_widget/refreshable_widget.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pending_approvals.dart';

class TimesheetDetailsScreen1 extends StatefulWidget {
  final Map<String, dynamic> timesheetData;
  //final String timesheetId;
  final String staffId;

  const TimesheetDetailsScreen1({super.key,
    required this.timesheetData,
    //required this.timesheetId,
    required this.staffId,
  });


  @override
  State<TimesheetDetailsScreen1> createState() => _TimesheetDetailsScreen1State();
}

class _TimesheetDetailsScreen1State extends State<TimesheetDetailsScreen1> {

  String? selectedProjectName;
  String? selectedBioFirstName;
  String? selectedBioLastName;
  String? selectedBioDepartment;
  String? selectedBioState;
  String? selectedBioDesignation;
  String? selectedBioLocation;
  String? selectedBioStaffCategory;
  String? selectedSignatureLink;
  String? selectedBioEmail;
  String? selectedBioPhone;
  String? selectedFirebaseId;
  String? selectedSupervisor; // State variable to store the selected supervisor
  String? facilitySupervisorSignatureDate;
  String? caritasSupervisorSignatureDate;
  String? _caritasSupervisorSignatureLink;
  String? _selectedSupervisorEmail;
  Uint8List? staffSignature1; // Store staff signature as Uint8List
  String formattedDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
  var facilitySupervisorSignature;
  var caritasSupervisorSignature;
  String? _facilitySupervisorSignatureLink;
  List<Map<String, dynamic>> pendingTimesheetsFacilitySupervisor = [];
  List<Map<String, dynamic>> pendingTimesheetsCaritasSupervisor = [];
  bool isLoading = true;
  List<Uint8List> checkSignatureImage = []; // Initialize as empty list
  List<String> attachments = [];
  //List<AttendanceModel> attendanceData = [];


  @override
  void initState() {
    super.initState();
    _loadBioData().then((_){
      _fetchPendingApprovals();
    });
  }


  Future<void> _fetchPendingApprovals() async {
    setState(() {
      isLoading = true;
    });

    try {
      final bioData = await _fetchBioDataFromFirestore(widget.staffId);
      if (bioData == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final caritasSupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('caritasSupervisorEmail', isEqualTo: bioData['emailAddress'])
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved')
          .get();

      final facilitySupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('facilitySupervisorEmail', isEqualTo: bioData['emailAddress'])
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
          .get();


      setState(() {
        pendingTimesheetsFacilitySupervisor = facilitySupervisorTimesheetsSnapshot.docs.map((doc) => doc.data()).toList();
        pendingTimesheetsCaritasSupervisor = caritasSupervisorTimesheetsSnapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching pending approvals: $e');
      Fluttertoast.showToast(
        msg: "'Error fetching pending approvals: $e'",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchBioDataFromFirestore(String staffId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(staffId)
          .get();
      return docSnapshot.data();
    } catch (e) {
      print("Error fetching bio data: $e");
      return null;
    }
  }


  Future<void> _uploadSignatureAndSync() async {
    final bioData = await _fetchBioDataFromFirestore(widget.staffId);
    if (bioData == null) return;

    if (selectedSignatureLink == null) {
      if (checkSignatureImage.isNotEmpty) {
        try {
          String bucketName = "attendanceapp-a6853.appspot.com";
          String storagePath = 'signatures/${selectedFirebaseId}_signature.jpg';
          final storageRef = FirebaseStorage.instance.ref('$bucketName/$storagePath');
          final uploadTask = storageRef.putData(checkSignatureImage.first);
          final snapshot = await uploadTask;
          final downloadURL = await snapshot.ref.getDownloadURL();

          selectedSignatureLink = downloadURL;


        } catch (e) {
          print('Error uploading signature or updating database: $e');
        }
      } else {
        if (selectedBioStaffCategory == "Facility Supervisor"){
          Fluttertoast.showToast(
            msg: "Cannot send timesheet without Facility Supervisor's signature.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }
        else{
          Fluttertoast.showToast(
            msg: "Cannot send timesheet without Facility Supervisor's signature.",
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.black54,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }
      }
    }

    if (selectedSignatureLink != null ) {
      DateTime timesheetDate1;
      try {
        timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
      } catch (e) {
        print("Error parsing date: $e");
        timesheetDate1 = DateTime.now();
      }

      final staffId = widget.timesheetData['staffId'] ?? 'N/A';
      String monthYear = DateFormat('MMMM_yyyy').format(timesheetDate1);

      try {
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection("Staff")
            .where("id", isEqualTo: staffId)
            .get();

        Map<String, dynamic> timesheetDataUpdate = {};
        if (selectedBioStaffCategory == "Facility Supervisor"){
          timesheetDataUpdate = {
            'facilitySupervisorSignature': selectedSignatureLink,
            'facilitySupervisorSignatureDate':DateFormat('MMMM dd, yyyy').format(DateTime.now()),
            'facilitySupervisorSignatureStatus':"Approved",
          };
        } else {
          timesheetDataUpdate = {
            'caritasSupervisorSignature': selectedSignatureLink,
            'caritasSupervisorSignatureDate':DateFormat('MMMM dd, yyyy').format(DateTime.now()),
            'caritasSupervisorSignatureStatus':"Approved",
          };
        }

        await FirebaseFirestore.instance
            .collection("Staff")
            .doc(snap.docs[0].id)
            .collection("TimeSheets")
            .doc(monthYear)
            .set(timesheetDataUpdate, SetOptions(merge: true));

        print('Timesheet signed and updated in Firestore');
        Fluttertoast.showToast(
          msg: "Timesheet Signed",
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
  }



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



  Future<void> _createAndExportPDF() async {
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final monthYear1 = DateFormat('MMMM_yyyy').format(timesheetDate1);
    final staffName = widget.timesheetData['staffName'] ?? 'N/A';

    final pdf = pw.Document(pageMode: PdfPageMode.outlines);
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
                    pw.Column(
                        children: [
                          pw.Text("CARITAS NIGERIA", style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 20),),
                          pw.SizedBox(height: 10,),
                          pw.Text("Monthly Time Report ($monthYear1)")
                        ]
                    ),
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
                _buildTimesheetTable(context),
                pw.SizedBox(height: 10),
                _buildSignatureSection(context, signatureColumns),
              ],
            );
          },
        ),
      );

      // **Web-compatible download logic:**
      final pdfData = await pdf.save(); // Get PDF as Uint8List

      // Create a Blob from the PDF data
      final blob = html.Blob([pdfData], 'application/pdf');

      // Create a download URL
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Create a temporary anchor element to trigger the download
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none' // Make it invisible
        ..download = 'timesheet_${monthYear1}_$staffName.pdf'; // Set filename

      html.document.body!.children.add(anchor);
      anchor.click();

      // Clean up: remove the anchor and revoke the ObjectURL
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);


    } catch (e) {
      print("Error generating PDF: $e");
      Fluttertoast.showToast(
        msg: "Error generating PDF: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> sendEmailToProjectManagementTeam() async {


    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    //final daysInRange = getDaysInRange(timesheetDate);
    final staffName = widget.timesheetData['staffName'] ?? 'N/A';
    final staffId = widget.timesheetData['staffId'] ?? 'N/A';

    final monthYear = DateFormat('MMMM, yyyy').format(timesheetDate1);
    final monthYear1 = DateFormat('MMMM_yyyy').format(timesheetDate1);


    final pdf = pw.Document(pageMode: PdfPageMode.outlines);

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



    } catch (e) {
      print("Error generating PDF: $e");
      // Handle the error, e.g., show a dialog to the user
    }
    // Clear the attachments list before adding new attachments
    attachments.clear();

    final pdfData = await pdf.save(); // Get PDF as Uint8List

    // **Option 1: Send PDF data to server for email sending (Recommended)**

    // Convert PDF data to Base64 (if your server expects Base64) - or send as raw bytes
    String base64Pdf = base64Encode(pdfData);

    final Email email = Email(
      body: '''
Greetings !!!,

Please find attached the completely signed timesheet for $staffName for $monthYear.

Best regards,
$selectedBioFirstName $selectedBioLastName

''',
      subject: 'Timesheet for $staffName for $monthYear',
      recipients: [selectedBioEmail!],
      // **No file attachments in this client-side code for web**
      isHTML: false,
    );

    // **Send email data and base64Pdf to your server endpoint (using http package)**
    // Example using http package (you'll need to add http: ^latest to pubspec.yaml)


    try {
      final response = await http.post(
        Uri.parse('YOUR_SERVER_EMAIL_ENDPOINT_URL'), // Replace with your server's URL
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8', // Or appropriate content type
        },
        body: jsonEncode(<String, dynamic>{
          'toEmail': selectedBioEmail,
          'subject': email.subject,
          'body': email.body,
          'pdfBase64': base64Pdf, // Send base64 encoded PDF data
          'filename': 'Timesheet_${monthYear1}_$staffName.pdf',
        }),
      );

      if (response.statusCode == 200) {
        print('Email sending request sent to server successfully!');
        // ... handle success (e.g., show toast)
      } else {
        print('Failed to send email request to server. Status code: ${response.statusCode}');
        // ... handle error (e.g., show error toast)
      }

    } catch (error) {
      print('Error sending email request to server: $error');
      // ... handle error
    }
    String platformResponse;

    try {
     // await FlutterEmailSender.send(email);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PendingApprovalsPage()),
      );
      platformResponse = 'success';
    } catch (error) {
      print(error);
      platformResponse = error.toString();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(platformResponse),
      ),
    );
  }


  Future<Map<String, String>> _getSupervisorNames() async {
    // ... (Supervisor names fetching logic - same as before, but ensure it uses widget.timesheetData) ...
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final staffId = widget.timesheetData['staffId'] ?? 'N/A';
    final monthYear1 = DateFormat('MMMM_yyyy').format(timesheetDate1);

    try {
      final timesheetDoc = await FirebaseFirestore.instance
          .collection("Staff")
          .doc(staffId)
          .collection("TimeSheets")
          .doc(monthYear1)
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
              '',
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
    // ... (Staff info building logic - same as before, but ensure it uses widget.timesheetData) ...
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final staffName = widget.timesheetData['staffName'] ?? 'N/A';
    final department = widget.timesheetData['department'] ?? 'N/A';
    final designation = widget.timesheetData['designation'] ?? 'N/A';
    final location = widget.timesheetData['location'] ?? 'N/A';
    final state = widget.timesheetData['state'] ?? 'N/A';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Name: $staffName'),
        pw.Text('Department: $department'),
        pw.Text('Designation: $designation'),
        pw.Text('Location: $location'),
        pw.Text('State: $state'),
        pw.SizedBox(height: 20),

      ],
    );
  }


  double _getCappedHoursForDate(DateTime date, String? projectName, String category) {
    double totalHoursForDate = 0;

    final attendanceData = widget.timesheetData['timesheetEntries'] as List?;

    if (attendanceData != null) {
      for (var attendance in attendanceData.cast<Map<String, dynamic>>()) {
        try {
          DateTime attendanceDate = DateFormat('yyyy-MM-dd').parse(attendance['date']);

          if (attendanceDate.year == date.year &&
              attendanceDate.month == date.month &&
              attendanceDate.day == date.day) {
            if (category == projectName && !attendance['offDay']) {
              double hours = attendance['noOfHours'];
              totalHoursForDate += hours > 8 ? 8 : hours;

            } else if (attendance['offDay'] && attendance['durationWorked']?.toLowerCase() == category.toLowerCase()) {
              double hours = attendance['noOfHours'];
              totalHoursForDate += hours > 8 ? 8 : hours;
            }
          }
        } catch (e) {
          print("Error parsing date or calculating hours: $e");
        }
      }
    }

    return totalHoursForDate;
  }


// Updated function to calculate total hours for a project (with capping)
  double calculateTotalHours1() {
    double totalHours = 0;
    DateTime timesheetDate1 = DateTime.now(); // Initialize with a default value
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
    }

    //final daysInRange = getDaysInRange(timesheetDate1);
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month),int.parse(year));
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        totalHours += _getCappedHoursForDate(
            date, projectName, projectName!); // Use helper function
      }
    }
    return totalHours;
  }

  double calculateGrandTotalHours1() {
    DateTime timesheetDate1 = DateTime.now(); // Initialize with a default value
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
    }

    //final daysInRange = getDaysInRange(timesheetDate1);
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month),int.parse(year));
    double projectTotal = calculateTotalHours1();

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

  // Updated function to calculate total hours for a category (with capping)
  double calculateCategoryHours1(String category) {
    DateTime timesheetDate1 = DateTime.now(); // Initialize with a default value
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
    }

    //final daysInRange = getDaysInRange(timesheetDate1);
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month),int.parse(year));
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        totalHours += _getCappedHoursForDate(
            date, projectName, category); // Use helper function
      }
    }
    return totalHours;
  }

  // Corrected grand percentage calculation (using capped grand total)
  double calculateGrandPercentageWorked() {
    DateTime timesheetDate1 = DateTime.now(); // Initialize with a default value
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
    }

    //final daysInRange = getDaysInRange(timesheetDate1);
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month),int.parse(year));
    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double cappedGrandTotalHours = calculateGrandTotalHours1();
    return (workingDays * 8) > 0 ? (cappedGrandTotalHours / (workingDays * 8)) *
        100 : 0; // Correct denominator

  }

  double calculateCategoryPercentage(String category) {
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing timesheet date: $e");
      timesheetDate1 = DateTime.now(); // Fallback to current date if parsing fails
    }

    final month = timesheetDate1.month;
    final year = timesheetDate1.year;
    final daysInRange = initializeDateRange(month, year);

    int workingDays = daysInRange.where((date) => !isWeekend(date)).length;

    // Use calculateCategoryHours1 which already handles capping
    double cappedCategoryHours = calculateCategoryHours1(category);

    // Check for division by zero
    return (workingDays * 8) > 0 ? (cappedCategoryHours / (workingDays * 8)) * 100 : 0;
  }


  double calculateCategoryHours(String category) {
    // Parse the timesheet date
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing timesheet date: $e");
      timesheetDate1 = DateTime.now(); // Fallback to current date if parsing fails
    }

    // Extract timesheet entries
    final attendanceData = widget.timesheetData['timesheetEntries'] as List<dynamic>?;

    // Determine the month and year
    final month = timesheetDate1.month;
    final year = timesheetDate1.year;

    // Initialize the date range
    final daysInRange = initializeDateRange(month, year);

    // Calculate total hours
    double totalHours = 0;
    for (var date in daysInRange) {
      if (!isWeekend(date)) {
        for (var entry in attendanceData ?? []) {
          if (entry is Map<String, dynamic>) {
            try {
              DateTime attendanceDate = DateFormat('dd-MMMM-yyyy').parse(entry['date']);
              if (attendanceDate.year == date.year &&
                  attendanceDate.month == date.month &&
                  attendanceDate.day == date.day &&
                  entry['offDay'] == true &&
                  (entry['durationWorked'] as String?)?.toLowerCase() == category.toLowerCase()) {
                double? hours = entry['noOfHours'] as double?;
                if (hours != null) {
                  totalHours += hours;
                }
              }
            } catch (e) {
              print("Error parsing attendance entry or calculating hours: $e");
            }
          }
        }
      }
    }

    return totalHours;
  }

  pw.Widget _buildTimesheetTable(pw.Context context) {
    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now(); // Use current date as a fallback
    }

    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month), int.parse(year)).cast<DateTime>();
    final data = widget.timesheetData['timesheetEntries'].cast<Map<String, dynamic>>();


    // Store row data and totals
    final rowData = <String, List<double>>{};  // Simplified data structure
    final categories = ['Annual leave', 'Holiday', 'Paternity', 'Maternity'];

    // Helper function to build table cells with weekend styling
    pw.Widget buildTableCell(String text, bool isWeekend) {
      return pw.Container(
        width: 80, // Fixed width for data cells
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(1.0),
        color: isWeekend ? PdfColors.grey900 : null,
        child: pw.Text(text),
      );
    }


    // Build Table Rows (including data and totals calculation)
    List<pw.TableRow> tableRows = [];
    for (final category in [projectName, ...categories]) {
      List<pw.Widget> rowChildren = [];
      List<double> rowDataList = []; // Accumulate data for each category

      rowChildren.add(pw.Container(width: 250, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.all(1.0), child: pw.Text(category)));


      double rowTotal = 0;

      for (var date in daysInRange) {
        double duration = _getDurationForDate3(date, projectName, category, data);
        rowTotal += duration;
        rowDataList.add(duration);
        rowChildren.add(buildTableCell(duration.round().toString(), isWeekend(date)));
      }

      rowData[category] = rowDataList;  // Store data row for totals calculation
      rowChildren.add(pw.Container(width: 200, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text(rowTotal.round().toString())));


      int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
      double percentage = (workingDays * 8) > 0 ? (rowTotal / (workingDays * 8)) * 100 : 0;
      rowChildren.add(pw.Container(width: 200, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('${percentage.round()}%')));
      tableRows.add(pw.TableRow(children: rowChildren));
    }


    // Total Row
    List<pw.Widget> totalRowChildren = [pw.Container(width: 250, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))];
    double grandTotalHours = 0;
    for (int i = 0; i < daysInRange.length; i++) {
      double dayTotal = 0;
      rowData.forEach((_, durations) {
        dayTotal += durations[i]; // Accessing by index is safe now
      });

      totalRowChildren.add(pw.Container(width:80, color: isWeekend(daysInRange[i]) ? PdfColors.grey900 : PdfColors.grey300, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text(dayTotal.round().toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))); // Added bold style and background color
      grandTotalHours += dayTotal;
    }


    int workingDaysTotal = daysInRange.where((date) => !isWeekend(date)).length;
    double grandPercentage = (workingDaysTotal * 8) > 0 ? (grandTotalHours / (workingDaysTotal * 8)) * 100 : 0;


    totalRowChildren.add(pw.Container(width: 200, color: PdfColors.grey300, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text(grandTotalHours.round().toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))));
    totalRowChildren.add(pw.Container(width: 200, color: PdfColors.grey300, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('${grandPercentage.round()}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))));
    tableRows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: totalRowChildren));




    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(250),
        for (int i = 1; i <= daysInRange.length; i++) i: const pw.FixedColumnWidth(80),
        daysInRange.length + 1: const pw.FixedColumnWidth(200),
        daysInRange.length + 2: const pw.FixedColumnWidth(200),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Container(width: 250, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('Project Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ...daysInRange.map((date) => pw.Container(width: 80, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), color: isWeekend(date) ? PdfColors.grey900 : PdfColors.grey300,child: pw.Text(DateFormat('dd').format(date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))), // Added bold style and background color
            pw.Container(width: 200, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('Total Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Container(width: 200, alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(1.0), child: pw.Text('%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),


          ],
        ),


        ...tableRows,
      ],
    );
  }




  List<pw.Widget> _buildRowChildrenWithWeekendColor1(pw.Context context, List<String> rowData,List<DateTime> daysInRange) {

    return rowData.asMap().entries.map((entry) {
      final i = entry.key;
      final data = entry.value;
      final isWeekendColumn = i > 0 && i <= daysInRange.length && isWeekend(daysInRange[i - 1]); // Check for weekend columns

      return pw.Container(
        color: isWeekendColumn ? PdfColors.grey900 : null, // Grey for weekend cells
        padding: const pw.EdgeInsets.all(1.0),
        alignment: pw.Alignment.center, // Center the text
        child: pw.Text(data),
      );

    }).toList();
  }

  List<pw.Widget> _buildRowChildrenWithWeekendColor(pw.Context context, List<String> rowData, List<DateTime> daysInRange) {  // Correct type here
    return rowData.asMap().entries.map((entry) {
      final i = entry.key;
      final data = entry.value;
      final isWeekendColumn = i > 0 && i <= daysInRange.length && isWeekend(daysInRange[i - 1]);

      return pw.Container(
        color: isWeekendColumn ? PdfColors.grey900 : null,
        padding: const pw.EdgeInsets.all(1.0),
        alignment: pw.Alignment.center,
        child: pw.Text(data),
      );
    }).toList();
  }


  // ... (rest of the code)


  //timesheet_details.dart
  double _getDurationForDate3(DateTime date, String? projectName, String category, List<Map<String, dynamic>> attendanceData) {
    double totalHoursForDate = 0;

    for (var attendance in attendanceData) {
      try {
        DateTime attendanceDate = DateFormat('yyyy-MM-dd').parse(attendance['date']);

        if (attendanceDate.year == date.year &&
            attendanceDate.month == date.month &&
            attendanceDate.day == date.day) {
          if (category == projectName) {
            if (!attendance['offDay']) {
              double hours = attendance['noOfHours'];
              totalHoursForDate += hours > 8 ? 8 : hours; // Cap at 8

            }
          } else {
            if (attendance['offDay'] &&
                attendance['durationWorked']?.toLowerCase() == category.toLowerCase()) {
              double hours = attendance['noOfHours'];
              totalHoursForDate += hours > 8 ? 8 : hours; // Cap at 8

            }
          }
        }
      } catch (e) {
        print("Error processing attendance data: $e");
      }
    }
    return totalHoursForDate;
  }



  Map<String, double> _calculateRowTotals1(List<String> rowData, List<DateTime> daysInRange) {

    double rowTotal = 0;
    for (int i = 1; i <= daysInRange.length; i++) {
      rowTotal += double.tryParse(rowData[i]) ?? 0;

    }
    int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
    double percentage = (workingDays * 8) != 0 ? (rowTotal / (workingDays * 8)) * 100 : 0;



    return {
      'totalHours': rowTotal.roundToDouble(),
      'percentage': percentage.roundToDouble(),
    };

  }

  Map<String, double> _calculateRowTotals(List<String> rowData, List<DateTime> daysInRange) { // Correct type here
    double rowTotal = 0;
    for (int i = 1; i <= daysInRange.length; i++) {
      rowTotal += double.tryParse(rowData[i]) ?? 0;
    }

    int workingDays = daysInRange.where((date) => !isWeekend(date)).length;
    double percentage = (workingDays * 8) != 0 ? (rowTotal / (workingDays * 8)) * 100 : 0;


    return {
      'totalHours': rowTotal,
      'percentage': percentage,
    };
  }




  Future<Uint8List?> networkImageToByte(String imageUrl) async {
    log("networkImageToByte called for URL: $imageUrl");

    if (imageUrl == null || imageUrl.isEmpty) { // Explicit null/empty check at start
      log("networkImageToByte received NULL or empty URL. Returning null.");
      return null;
    }

    try {
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      log("Response status code for URL: $imageUrl is ${response.statusCode}"); // Print status code

      if (response.statusCode == 200) { // Check for 200 OK explicitly
        log("Response type for URL: $imageUrl is ${response.data.runtimeType}");

        if (response.data is List<int>) {
          final byteList = response.data as List<int>;
          log("Successfully fetched ${byteList.length} bytes for URL: $imageUrl");
          return Uint8List.fromList(byteList);
        } else {
          log("Unexpected response type: ${response.data.runtimeType} for URL: $imageUrl (Not List<int>)");
          return null;
        }
      } else {
        log("HTTP Error ${response.statusCode} for URL: $imageUrl. Returning null."); // Handle non-200 status
        return null;
      }
    } catch (e) {
      print('Exception in networkImageToByte for URL: $imageUrl: $e');
      return null;
    }
  }

  Future<List<pw.Widget>> _buildSignatureColumns(Map<String, String> supervisorData) async {
    final staffSig = (supervisorData['staffSignature'] != null && supervisorData['staffSignature']!.isNotEmpty) ? await networkImageToByte(supervisorData['staffSignature']!) : null;
    final coordSig = (supervisorData['projectCoordinatorSignature'] != null && supervisorData['projectCoordinatorSignature']!.isNotEmpty) ? await networkImageToByte(supervisorData['projectCoordinatorSignature']!) : null;
    final caritasSig = (supervisorData['caritasSupervisorSignature'] != null && supervisorData['caritasSupervisorSignature']!.isNotEmpty) ? await networkImageToByte(supervisorData['caritasSupervisorSignature']!) : null;

    final staffName = supervisorData['staffName']?.toUpperCase() ?? 'UNKNOWN';
    final projectCoordinatorName = supervisorData['projectCoordinatorName']?.toUpperCase() ?? 'UNKNOWN';
    final caritasSupervisorName = supervisorData['caritasSupervisorName']?.toUpperCase() ?? 'UNKNOWN';

    final staffSignatureDate = supervisorData['staffSignatureDate'] ?? formattedDate;
    final facilitySupervisorSignatureDate = supervisorData['facilitySupervisorSignatureDate'] ?? 'UNKNOWN';
    final caritasSupervisorSignatureDate = supervisorData['caritasSupervisorSignatureDate'] ?? 'UNKNOWN';


    return [
      _buildSingleSignatureColumn('Name of Staff', staffName, staffSig, staffSignatureDate),
      _buildSingleSignatureColumn('Name of Project Coordinator', projectCoordinatorName, coordSig,facilitySupervisorSignatureDate ),
      _buildSingleSignatureColumn('Name of Caritas Supervisor', caritasSupervisorName, caritasSig,caritasSupervisorSignatureDate),
    ];
  }


  pw.Widget _buildSingleSignatureColumn(String title, String name, Uint8List? imageBytes, String date) {
    return  pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(name),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 100,
          width: 150,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Center(
            child: imageBytes != null ? pw.Image(pw.MemoryImage(imageBytes)) : pw.Text("Signature"),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text("Date: $date"),
      ],
    );
  }


  pw.Widget _buildSignatureSection(pw.Context context, List<pw.Widget> signatureColumns) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Signature & Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: signatureColumns,

          ),
        ]
    );
  }




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
    final entries = widget.timesheetData['timesheetEntries'] as List?;
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

  Future<List<Uint8List>?> _readImagesFromDatabase() async {
    // No local database, return null or empty list
    return null;
  }

  Future<void> _rejectTimesheet(String staffId, String monthYear, String selectedBioStaffCategory) async {
    // ... (Reject timesheet logic - update to Firestore directly) ...
    String rejectionReason = "";
    bool isValidReason = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reject Timesheet'),
          content: TextFormField(
            onChanged: (value) {
              rejectionReason = value;
              isValidReason = value.trim().isNotEmpty;
            },
            decoration: InputDecoration(
              labelText: 'Reason for Rejection',
              hintText: 'Enter reason for rejecting this timesheet',
              border: const OutlineInputBorder(),
              errorText: !isValidReason && rejectionReason.isNotEmpty ? 'Please enter a valid reason' : null,
            ),
            maxLines: 3,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => value == null || value.isEmpty ? 'Please enter a reason' : null,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: !isValidReason
                  ? () async {
                try {
                  Map<String, dynamic> updateData = {};
                  if(selectedBioStaffCategory == "Facility Supervisor"){
                    updateData = {'facilitySupervisorSignatureStatus': 'Rejected', 'facilitySupervisorRejectionReason': rejectionReason};
                  } else {
                    updateData = {'caritasSupervisorSignatureStatus': 'Rejected', 'caritasSupervisorRejectionReason': rejectionReason};
                  }

                  await FirebaseFirestore.instance
                      .collection("Staff")
                      .doc(staffId)
                      .collection("TimeSheets")
                      .doc(monthYear)
                      .update(updateData);


                  Navigator.of(context).pop();

                  Fluttertoast.showToast(
                    msg: "Timesheet Rejected",
                    toastLength: Toast.LENGTH_SHORT,
                    backgroundColor: Colors.black54,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PendingApprovalsPage(), // Ensure PendingApprovalsPage is updated if needed
                    ),
                  ).then((_) => _fetchPendingApprovals());
                } catch (e) {
                  print('Error rejecting timesheet: $e');
                  Fluttertoast.showToast(msg: 'Error rejecting timesheet');
                }
              }
                  : null,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }



  Future<void> _loadBioData() async {
    final bioData = await _fetchBioDataFromFirestore(widget.staffId);
    if (bioData != null) {
      setState(() {
        selectedBioFirstName = bioData['firstName'];
        selectedBioLastName = bioData['lastName'];
        selectedBioDepartment = bioData['department'];
        selectedBioState = bioData['state'];
        selectedBioDesignation = bioData['designation'];
        selectedBioLocation = bioData['location'];
        selectedBioStaffCategory = bioData['staffCategory'];
        selectedSignatureLink = bioData['signatureLink'];
        selectedBioEmail = bioData['emailAddress'];
        selectedBioPhone = bioData['mobile'];
        selectedFirebaseId = widget.staffId;
      });
    } else {
      print("No bio data found!");
    }
    try{
      facilitySupervisorSignature = widget.timesheetData['facilitySupervisorSignature'];
      caritasSupervisorSignature = widget.timesheetData['caritasSupervisorSignature'];
    }catch(e){}
  }


  Future<void> _facilitySupervisorSignatureToFirestore() async {
    // ... (Facility Supervisor Signature to Firestore logic - update to Firestore directly) ...
    if (selectedSignatureLink == null) {
      Fluttertoast.showToast(
        msg: "Cannot send timesheet without Project Coordinator Signature.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      print("Cannot send timesheet without staff signature.");
      return;
    }

    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final staffId = widget.timesheetData['staffId'] ?? 'N/A';
    String monthYear = DateFormat('MMMM_yyyy').format(timesheetDate1);

    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("Staff")
          .where("id", isEqualTo: staffId)
          .get();

      Map<String, dynamic> timesheetData = {
        'facilitySupervisorSignature': selectedSignatureLink,
        'facilitySupervisorSignatureDate':DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        'facilitySupervisorSignatureStatus':"Approved",
      };


      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(snap.docs[0].id)
          .collection("TimeSheets")
          .doc(monthYear)
          .set(timesheetData, SetOptions(merge: true));

      print('Timesheet signed by Facility Supervisor and updated in Firestore');
      Fluttertoast.showToast(
        msg: "Timesheet Signed",
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

  Future<void> _caritasSupervisorSignatureToFirestore() async {
    // ... (Caritas Supervisor Signature to Firestore logic - update to Firestore directly) ...
    if (selectedSignatureLink == null) {
      Fluttertoast.showToast(
        msg: "Cannot send timesheet without CARITAS Supervisor Signature.",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      print("Cannot send timesheet without staff signature.");
      return;
    }


    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final staffId = widget.timesheetData['staffId'] ?? 'N/A';
    String monthYear = DateFormat('MMMM_yyyy').format(timesheetDate1);

    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("Staff")
          .where("id", isEqualTo: staffId)
          .get();

      Map<String, dynamic> timesheetData = {
        'caritasSupervisorSignature': selectedSignatureLink,
        'caritasSupervisorSignatureDate':DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        'caritasSupervisorSignatureStatus':"Approved",
      };

      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(snap.docs[0].id)
          .collection("TimeSheets")
          .doc(monthYear)
          .set(timesheetData, SetOptions(merge: true));


      print('Timesheet signed by Caritas Supervisor and updated in Firestore');
      Fluttertoast.showToast(
        msg: "Timesheet Signed",
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


  // Checks if a date falls on a weekend.
  bool isWeekend(DateTime date) => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  // Computes total hours worked for a specific category.
  double getCategoryHours(String category) {
    return (widget.timesheetData['timesheetEntries'] as List?)
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
    return (widget.timesheetData['timesheetEntries'] as List?)
        ?.fold<double>(0.0, (sum, entry) => sum + entry['noOfHours']) ??
        0.0;
  }

  // Calculates hours for a specific project.
  double calculateTotalHours(String projectName) {
    return (widget.timesheetData['timesheetEntries'] as List?)
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

  double calculatePercentageWorked1() {
    DateTime timesheetDate1 = DateTime.now(); // Initialize with a default value
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
    }

    //final daysInRange = getDaysInRange(timesheetDate1);
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange = initializeDateRange(int.parse(month), int.parse(year)).cast<DateTime>();


    int workingDays = daysInRange
        .where((date) => !isWeekend(date))
        .length;
    double cappedTotalHours = calculateTotalHours1(); // Use capped total hours
    return (workingDays * 8) > 0
        ? (cappedTotalHours / (workingDays * 8)) * 100
        : 0;
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
              totalHoursForDate += attendance['noOfHours'] > 8.0 ? 8.0:attendance['noOfHours']  as double; // Access 'noOfHours'
            }

            // if (attendance['offDay'] == null ) {  // Access 'offDay' from the map
            //   totalHoursForDate += attendance['noOfHours'] as double; // Access 'noOfHours'
            // }
          } else {
            if (attendance['offDay'] as bool &&
                (attendance['durationWorked'] as String?)?.toLowerCase() == category.toLowerCase()) {
              totalHoursForDate += attendance['noOfHours'] > 8.0 ? 8.0:attendance['noOfHours']  as double;
            }
          }
        }
      } catch (e) {
        print("Error processing attendance data: $e"); // More general error message
      }
    }
    return totalHoursForDate.toStringAsFixed(2);
  }

  List initializeDateRange(int month, int year) {
    DateTime selectedMonthDate = DateTime(year, month, 1);
    var startDate = DateTime(selectedMonthDate.year, selectedMonthDate.month - 1, 20); //Start from the 19th of previous month
    var endDate = DateTime(selectedMonthDate.year, selectedMonthDate.month, 19);    //End on the 20th of current month


    var daysInRange1 = [];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      daysInRange1.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return daysInRange1;
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
        selectedSignatureLink = null; // Clear the old link, force reload from memory
        staffSignature1 = imageBytes;
        checkSignatureImage = [imageBytes]; // Directly update checkSignatureImage
      });


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



  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    DateTime timesheetDate;
    try {
      timesheetDate = dateFormat.parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate = DateTime.now();
    }


    DateTime timesheetDate1;
    try {
      timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(widget.timesheetData['date']);
    } catch (e) {
      print("Error parsing date: $e");
      timesheetDate1 = DateTime.now();
    }

    final daysInRange = getDaysInRange(timesheetDate);
    final staffName = widget.timesheetData['staffName'] ?? 'N/A';
    final staffId = widget.timesheetData['staffId'] ?? 'N/A';
    final projectName = widget.timesheetData['projectName'] ?? 'N/A';
    final facilitySupervisorName = widget.timesheetData['facilitySupervisor'] ?? 'N/A';
    final caritasSupervisorName = widget.timesheetData['caritasSupervisor'] ?? 'N/A';
    final timeSheetDate = widget.timesheetData['staffSignatureDate'] ?? 'N/A';
    final department = widget.timesheetData['department'] ?? 'N/A';
    final designation = widget.timesheetData['designation'] ?? 'N/A';
    final location = widget.timesheetData['location'] ?? 'N/A';
    final state = widget.timesheetData['state'] ?? 'N/A';
    final grandTotalHours = calculateGrandTotalHours();
    // final staffSignature = widget.timesheetData['staffSignature'] != null
    //     ? Uint8List.fromList(List<int>.from(widget.timesheetData['staffSignature']))
    //     : null;
    final staffSignature = widget.timesheetData['staffSignature'] ?? 'N/A';
    final monthYear = DateFormat('MMMM, yyyy').format(timesheetDate1);
    final filteredMonthYear = DateFormat('MMMM_yyyy').format(timesheetDate1);
    final month = DateFormat('MM').format(timesheetDate1);
    final year = DateFormat('yyyy').format(timesheetDate1);
    final daysInRange2 = initializeDateRange(int.parse(month),int.parse(year));




    return Scaffold(
      appBar: AppBar(
        title: const Text('Timesheet Details'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _createAndExportPDF,
          ),
          const Icon(Icons.picture_as_pdf),
          const SizedBox(width: 15)
          // IconButton(
          //   icon: const Icon(Icons.save_alt), // Use a suitable icon for Excel
          //   onPressed: _createAndExportExcel,
          // ),
        ],
      ),
      body: SingleChildScrollView(

        child: Column(
            children:[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  //mainAxisAlignment:MainAxisAlignment.start,
                    children: [
                      Image(
                        image: const AssetImage("./assets/image/ccfn_logo.png"),
                        width: MediaQuery
                            .of(context)
                            .size
                            .width * (MediaQuery
                            .of(context)
                            .size
                            .shortestSide < 600 ? 0.15 : 0.10),
                        //height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.30),
                      ),
                      Text('Name: $staffName',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: MediaQuery
                            .of(context)
                            .size
                            .width * (MediaQuery
                            .of(context)
                            .size
                            .shortestSide < 600 ? 0.035 : 0.020),),),
                      const SizedBox(height: 5),
                      Text('Department: $department',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: MediaQuery
                            .of(context)
                            .size
                            .width * (MediaQuery
                            .of(context)
                            .size
                            .shortestSide < 600 ? 0.035 : 0.020),),),
                      const SizedBox(height: 5),
                      Text('Designation: $designation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: MediaQuery
                            .of(context)
                            .size
                            .width * (MediaQuery
                            .of(context)
                            .size
                            .shortestSide < 600 ? 0.035 : 0.020),),),
                      const SizedBox(height: 5),
                      Text('Location: $location', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: MediaQuery
                          .of(context)
                          .size
                          .width * (MediaQuery
                          .of(context)
                          .size
                          .shortestSide < 600 ? 0.035 : 0.020),),),
                      const SizedBox(height: 5),
                      Text('State: $state', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: MediaQuery
                          .of(context)
                          .size
                          .width * (MediaQuery
                          .of(context)
                          .size
                          .shortestSide < 600 ? 0.035 : 0.020),),),
                      const SizedBox(height: 10),
                      // Add some spacing
                    ]
                ),),
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
              SingleChildScrollView(
                scrollDirection:Axis.horizontal,
                // padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [

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
                                    width: 50,
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
                                  String hours = _getDurationForDate(date, projectName, projectName!,widget.timesheetData['timesheetEntries'].cast<Map<String, dynamic>>() );
                                  return Container(
                                    width: 50, // Set a fixed width for each day
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
                                  child: Text(
                                    "${calculateTotalHours1()
                                        .round()} hrs",
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(8.0),
                                  color: Colors.white,
                                  child: Text(
                                    '${calculatePercentageWorked1(
                                    ).round()}%',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                            ...['Annual leave', 'Holiday', 'Paternity', 'Maternity'].map((category) {
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
                                    String offDayHours = _getDurationForDate(date, projectName, category,widget.timesheetData['timesheetEntries'].cast<Map<String, dynamic>>() );


                                    return Container(
                                      width: 50, // Set a fixed width for each day
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
                                    child: Text(
                                      //'${outOfOfficeHours.toStringAsFixed(2)} hrs',
                                      "${calculateCategoryHours1(category)
                                          .round()} hrs",
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    width: 100,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(8.0),
                                    color: Colors.white,
                                    child: Text(
                                      //'${outOfOfficePercentage.toStringAsFixed(2)}%',
                                      '${calculateCategoryPercentage(category
                                      ).round()}%',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
                                    "${calculateGrandTotalHours1()
                                        .toStringAsFixed(0)} hrs",
                                    //'$totalGrandHours hrs',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(8.0),
                                  color: Colors.white,
                                  child: Text(
                                    '${calculateGrandPercentageWorked()
                                        .round()}%',

                                    // '${grandPercentageWorked.toStringAsFixed(2)}%',

                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),



                          ],
                        ),
                        const Divider(),
                        // buildCategoryRows(projectName, daysInRange),
                        // Row(
                        //   children: [
                        //     _buildTableCell('Grand Total', Colors.grey, fontWeight: FontWeight.bold),
                        //     ...List.generate(daysInRange.length, (_) => SizedBox(width: 100)),
                        //     _buildTableCell('$grandTotalHours hrs', Colors.grey, fontWeight: FontWeight.bold),
                        //     _buildTableCell('100%', Colors.grey, fontWeight: FontWeight.bold),
                        //   ],
                        // ),

                      ],
                    ),
                  ],
                ),
              ),

              //Signature and Details
              const Divider(),
              Text('Signature & Date', style: TextStyle(fontWeight: FontWeight.bold,fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.030),)),
              const Divider(),
              Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children:[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),
                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.25 : 0.25),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //color: Colors.white,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center, // Vertically center the content
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Name of Staff', style: TextStyle(fontWeight: FontWeight.bold,fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.07 : 0.05)),
                              Text(
                                '${staffName.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.035 : 0.015),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "NexaLight",
                                ),
                              ),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.13 : 0.10)),// Adjust path and size accordingly
                            ],
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        // Signature of Staff
                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.35 : 0.35),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //  color: Colors.grey.shade200,
                          child: Column(
                            children: [
                              Text('Signature', style: TextStyle(fontWeight: FontWeight.bold,fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 24,
                                ),
                                height: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                width: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  //color: Colors.grey.shade300,
                                ),
                                child: staffSignature != null?  CachedNetworkImage(
                                  imageUrl: staffSignature!,
                                  placeholder: (context, url) => const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ) :const Text('No signature available.'),
                              ),// Adjust path and size accordingly
                              // StreamBuilder<DocumentSnapshot>(
                              //   // Stream the supervisor signature
                              //   stream: FirebaseFirestore.instance
                              //       .collection("Staff")
                              //       .doc(staffId) // Replace with how you get the staff document ID
                              //       .collection("TimeSheets")
                              //       .doc(filteredMonthYear) // Replace monthYear with the timesheet document ID // Replace monthYear with the timesheet document ID
                              //       .snapshots(),
                              //   builder: (context, snapshot) {
                              //     if (snapshot.hasData &&
                              //         snapshot.data!.exists) {
                              //       final data = snapshot.data!
                              //           .data() as Map<
                              //           String,
                              //           dynamic>;
                              //
                              //       final staffSignature = data['staffSignature']; // Assuming this stores the image URL
                              //       //final facilitySupervisorSignatureStatus = data['staffSignature']; // Assuming you store the date
                              //
                              //       if (staffSignature != null) {
                              //         // caritasSupervisorSignature is a URL/path to the image
                              //         return Container(
                              //           margin: const EdgeInsets
                              //               .only(
                              //             top: 20,
                              //             bottom: 24,
                              //           ),
                              //           height: MediaQuery
                              //               .of(context)
                              //               .size
                              //               .width *
                              //               (MediaQuery
                              //                   .of(context)
                              //                   .size
                              //                   .shortestSide < 600
                              //                   ? 0.30
                              //                   : 0.15),
                              //           width: MediaQuery
                              //               .of(context)
                              //               .size
                              //               .width *
                              //               (MediaQuery
                              //                   .of(context)
                              //                   .size
                              //                   .shortestSide < 600
                              //                   ? 0.30
                              //                   : 0.30),
                              //           alignment: Alignment.center,
                              //           decoration: BoxDecoration(
                              //             borderRadius: BorderRadius
                              //                 .circular(20),
                              //             //color: Colors.grey.shade300,
                              //           ),
                              //           child:
                              //           //Image.network(Uri.decodeFull(staffSignature!)),
                              //
                              //           CachedNetworkImage(
                              //             imageUrl: staffSignature!,
                              //             placeholder: (context, url) => const CircularProgressIndicator(),
                              //             errorWidget: (context, url, error) => const Icon(Icons.error),
                              //           ),
                              //
                              //         );
                              //       }
                              //       else {
                              //         return Column(
                              //           mainAxisAlignment: MainAxisAlignment
                              //               .center,
                              //           children: [
                              //             Icon(
                              //               Icons
                              //                   .upload_file,
                              //               size: MediaQuery
                              //                   .of(
                              //                   context)
                              //                   .size
                              //                   .width *
                              //                   (MediaQuery
                              //                       .of(
                              //                       context)
                              //                       .size
                              //                       .shortestSide <
                              //                       600
                              //                       ? 0.075
                              //                       : 0.05),
                              //               color: Colors
                              //                   .grey
                              //                   .shade600,
                              //             ),
                              //             const SizedBox(
                              //                 height: 8),
                              //             const Text(
                              //               "Click to Upload Signature Image Here",
                              //               style: TextStyle(
                              //                 fontSize: 14,
                              //                 color: Colors
                              //                     .grey,
                              //                 fontWeight: FontWeight
                              //                     .bold,
                              //               ),
                              //               textAlign: TextAlign
                              //                   .center,
                              //             ),
                              //           ],
                              //         );
                              //       }
                              //     }
                              //     else {
                              //       return Column(
                              //         mainAxisAlignment: MainAxisAlignment
                              //             .center,
                              //         children: [
                              //           Icon(
                              //             Icons
                              //                 .upload_file,
                              //             size: MediaQuery
                              //                 .of(
                              //                 context)
                              //                 .size
                              //                 .width *
                              //                 (MediaQuery
                              //                     .of(
                              //                     context)
                              //                     .size
                              //                     .shortestSide <
                              //                     600
                              //                     ? 0.075
                              //                     : 0.05),
                              //             color: Colors
                              //                 .grey
                              //                 .shade600,
                              //           ),
                              //           const SizedBox(
                              //               height: 8),
                              //           const Text(
                              //             "Click to Upload Signature Image Here",
                              //             style: TextStyle(
                              //               fontSize: 14,
                              //               color: Colors
                              //                   .grey,
                              //               fontWeight: FontWeight
                              //                   .bold,
                              //             ),
                              //             textAlign: TextAlign
                              //                 .center,
                              //           ),
                              //         ],
                              //       );
                              //     }
                              //   },
                              // ),

                            ],
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        // Date of Signature of Staff

                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.07 : 0.05)),
                              Text("$timeSheetDate", style: const TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.13 : 0.10)),
                            ],
                          ),
                        ),
                        SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),


                      ],
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.005 : 0.005)),
                    const Divider(),
                    //Second - Project Coordinator Section
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),
                        //Name of Project Cordinator
                        Container(
                          width: MediaQuery.of(context).size.width *
                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.25),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //  color: Colors.grey.shade200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email of Project Cordinator
                              Text(
                                'Name of Project Coordinator',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),
                                ),
                              ),
                              SizedBox(
                                height: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.03 : 0.01),
                              ),

                              Text(
                                '${facilitySupervisorName.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.035 : 0.015),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "NexaLight",
                                ),
                              ),

                              SizedBox(
                                height: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.005 : 0.005),
                              ),
                            ],
                          ),
                        ),


                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        //Signature of Project Cordinator
                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.35 : 0.35),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //color: Colors.grey.shade200,
                          child: Column(
                            children: [
                              Text('Signature', style: TextStyle(fontWeight: FontWeight.bold,fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                              StreamBuilder<DocumentSnapshot>(
                                // Stream the supervisor signature
                                stream: FirebaseFirestore.instance
                                    .collection("Staff")
                                    .doc(staffId) // Replace with how you get the staff document ID
                                    .collection("TimeSheets")
                                    .doc(filteredMonthYear) // Replace monthYear with the timesheet document ID
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>;

                                    final facilitySupervisorSignature = data['facilitySupervisorSignature']; // Assuming this stores the image URL
                                    final facilitySupervisorSignatureStatus = data['facilitySupervisorSignatureStatus']; // Assuming you store the date



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


                                    else if(facilitySupervisorSignature == null && selectedSignatureLink ==null && selectedBioStaffCategory == "Facility Supervisor"){
                                      return GestureDetector(
                                        onTap: () {
                                          _pickImage();
                                        },

                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: 20,
                                            bottom: 24,
                                          ),
                                          height: MediaQuery.of(context).size.width *
                                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                          width: MediaQuery.of(context).size.width *
                                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            //color: Colors.grey.shade300,
                                          ),
                                          child: RefreshableWidget<List<Uint8List>?>(
                                            refreshCall: () async {
                                              return await _readImagesFromDatabase();
                                            },
                                            refreshRate: const Duration(seconds: 1),
                                            errorWidget: Icon(
                                              Icons.upload_file,
                                              size: 80,
                                              color: Colors.grey.shade300,
                                            ),
                                            loadingWidget: Icon(
                                              Icons.upload_file,
                                              size: 80,
                                              color: Colors.grey.shade300,
                                            ),
                                            builder: (context, value) {
                                              if (value != null && value.isNotEmpty) {
                                                return ListView.builder(
                                                  itemCount: value.length,
                                                  itemBuilder: (context, index) => Container(
                                                    margin: const EdgeInsets.only(
                                                      top: 20,
                                                      bottom: 24,
                                                    ),
                                                    height: MediaQuery.of(context).size.width *
                                                        (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                    width: MediaQuery.of(context).size.width *
                                                        (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(20),
                                                      //color: Colors.grey.shade300,
                                                    ),
                                                    child: Image.memory(value.first),
                                                  ),


                                                );
                                              } else {
                                                return Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.upload_file,
                                                      size: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.075 : 0.05),
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      "Click to Upload Signature Image Here",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ],
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                    else if(facilitySupervisorSignature == null && selectedSignatureLink !=null && selectedBioStaffCategory == "Facility Supervisor"){
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
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
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus (Awaiting Approval)",
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
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
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
                                                    "$facilitySupervisorSignatureStatus (Approved)",
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
                                    else if(facilitySupervisorSignature != null && selectedSignatureLink !=null && selectedBioStaffCategory == "Facility Supervisor" ){
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
                                          ),
                                          const SizedBox(height:8),
                                          facilitySupervisorSignatureStatus == "Pending"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.access_time, color: Colors.orange),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus (Awaiting Approval)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ):
                                          facilitySupervisorSignatureStatus == "Rejected"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.cancel, color: Colors.red),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          )
                                              :Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.check_circle, color: Colors.green),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus (Approved)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ),

                                        ],
                                      );
                                    }
                                    else if(facilitySupervisorSignature == null && facilitySupervisorSignatureStatus =="Pending" && selectedBioStaffCategory == "Facility Supervisor" ){
                                      return Column(
                                        children: [
                                          const Text("Awaiting Facility Supervisor Signature"),
                                          const SizedBox(height:8),
                                          facilitySupervisorSignatureStatus == "Pending"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.access_time, color: Colors.orange),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ):facilitySupervisorSignatureStatus == "Rejected"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.cancel, color: Colors.red),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          )
                                              :Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.check_circle, color: Colors.green),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ),


                                        ],
                                      );
                                    }
                                    else if (selectedBioStaffCategory == "Facility Supervisor") {
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
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
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$facilitySupervisorSignatureStatus (Awaiting Approval)",
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
                                                    "$facilitySupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                              : facilitySupervisorSignatureStatus == "Approved"
                                              ? Row(
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
                                                    "$facilitySupervisorSignatureStatus (Approved)",
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
                                      return const SizedBox.shrink();

                                    }
                                  } else {
                                    return const Text("Timesheet Yet to be submitted for Project Cordinator's Signature");
                                  }
                                },
                              ),



                            ],
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        //Date of Project Signature Date

                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20.0),
                              StreamBuilder<DocumentSnapshot>(
                                // Stream the supervisor signature
                                stream: FirebaseFirestore.instance
                                    .collection("Staff")
                                    .doc(staffId) // Replace with how you get the staff document ID
                                    .collection("TimeSheets")
                                    .doc(filteredMonthYear) // Replace monthYear with the timesheet document ID
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>;

                                    final facilitySupervisorSignatureDate = data['facilitySupervisorSignatureDate']; // Assuming this stores the image URL
                                    final facilitySupervisorSignatureStatus = data['facilitySupervisorSignatureStatus']; // Assuming you store the date

                                    if (facilitySupervisorSignatureDate != null) {
                                      // caritasSupervisorSignature is a URL/path to the image
                                      return Text("$facilitySupervisorSignatureDate", style: const TextStyle(fontWeight: FontWeight.bold));

                                    }

                                    else {
                                      return Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold));

                                    }
                                  } else {
                                    return const Text("Timesheet Yet to be submitted for Project Cordinator's Signature");
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        //SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),
                      ],
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.005 : 0.005)),
                    const Divider(),
                    // Third - CARITAS Supervisor Section
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width:MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02),),
                        // Name of CARITAS Supervisor
                        Container(
                          width: MediaQuery.of(context).size.width *
                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.25),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //color: Colors.grey.shade200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Name of CARITAS Supervisor',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),
                                ),
                              ),
                              SizedBox(
                                height: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.03 : 0.01),
                              ),
                              Text(
                                '${caritasSupervisorName.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.035 : 0.015),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "NexaLight",
                                ),
                              ),
                              SizedBox(
                                height: MediaQuery.of(context).size.width *
                                    (MediaQuery.of(context).size.shortestSide < 600 ? 0.005 : 0.005),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        //Signature of CARITAS Supervisor
                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.35 : 0.35),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8.0),
                          //color: Colors.grey.shade200,
                          child: Column(
                            children: [
                              Text('Signature', style: TextStyle(fontWeight: FontWeight.bold,fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.040 : 0.020),)),
                              SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.02 : 0.02)),
                              StreamBuilder<DocumentSnapshot>(
                                // Stream the supervisor signature
                                stream: FirebaseFirestore.instance
                                    .collection("Staff")
                                    .doc(staffId) // Replace with how you get the staff document ID
                                    .collection("TimeSheets")
                                    .doc(filteredMonthYear) // Replace monthYear with the timesheet document ID
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>;

                                    final caritasSupervisorSignature = data['caritasSupervisorSignature']; // Assuming this stores the image URL
                                    final caritasSupervisorSignatureStatus = data['caritasSupervisorSignatureStatus']; // Assuming you store the date

                                    // if (caritasSupervisorSignature != null) {
                                    //   // caritasSupervisorSignature is a URL/path to the image
                                    //   return Container(
                                    //     margin: const EdgeInsets.only(
                                    //       top: 20,
                                    //       bottom: 24,
                                    //     ),
                                    //     height: MediaQuery.of(context).size.width *
                                    //         (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                    //     width: MediaQuery.of(context).size.width *
                                    //         (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                    //     alignment: Alignment.center,
                                    //     decoration: BoxDecoration(
                                    //       borderRadius: BorderRadius.circular(20),
                                    //       //color: Colors.grey.shade300,
                                    //     ),
                                    //     child: Image.network(caritasSupervisorSignature!),
                                    //   );
                                    //
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
                                    else if(caritasSupervisorSignature == null && selectedSignatureLink ==null && selectedBioStaffCategory != "Facility Supervisor" ){
                                      return GestureDetector(
                                        onTap: () {
                                          _pickImage();
                                        },

                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: 20,
                                            bottom: 24,
                                          ),
                                          height: MediaQuery.of(context).size.width *
                                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                          width: MediaQuery.of(context).size.width *
                                              (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            //color: Colors.grey.shade300,
                                          ),
                                          child: RefreshableWidget<List<Uint8List>?>(
                                            refreshCall: () async {
                                              return await _readImagesFromDatabase();
                                            },
                                            refreshRate: const Duration(seconds: 1),
                                            errorWidget: Icon(
                                              Icons.upload_file,
                                              size: 80,
                                              color: Colors.grey.shade300,
                                            ),
                                            loadingWidget: Icon(
                                              Icons.upload_file,
                                              size: 80,
                                              color: Colors.grey.shade300,
                                            ),
                                            builder: (context, value) {
                                              if (value != null && value.isNotEmpty) {
                                                return ListView.builder(
                                                  itemCount: value.length,
                                                  itemBuilder: (context, index) => Container(
                                                    margin: const EdgeInsets.only(
                                                      top: 20,
                                                      bottom: 24,
                                                    ),
                                                    height: MediaQuery.of(context).size.width *
                                                        (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                                    width: MediaQuery.of(context).size.width *
                                                        (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(20),
                                                      //color: Colors.grey.shade300,
                                                    ),
                                                    child: Image.memory(value.first),
                                                  ),


                                                );
                                              } else {
                                                return Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.upload_file,
                                                      size: MediaQuery.of(context).size.width *
                                                          (MediaQuery.of(context).size.shortestSide < 600 ? 0.075 : 0.05),
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    const Text(
                                                      "Click to Upload Signature Image Here",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ],
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                    else if(caritasSupervisorSignature == null && selectedSignatureLink !=null && selectedBioStaffCategory != "Facility Supervisor"   ){
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
                                          ),
                                          const SizedBox(height: 8),
                                          caritasSupervisorSignatureStatus == "Pending"
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
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus (Awaiting Approval)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                              : caritasSupervisorSignatureStatus == "Rejected"
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
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
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
                                                    "$caritasSupervisorSignatureStatus (Approved)",
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
                                    else if(caritasSupervisorSignature != null && selectedSignatureLink !=null && selectedBioStaffCategory != "Facility Supervisor" ){
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
                                          ),
                                          const SizedBox(height:8),
                                          caritasSupervisorSignatureStatus == "Pending"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.access_time, color: Colors.orange),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus (Awaiting Approval)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ):
                                          caritasSupervisorSignatureStatus == "Rejected"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.cancel, color: Colors.red),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          )
                                              :Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.check_circle, color: Colors.green),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus (Approved)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ),

                                        ],
                                      );
                                    }
                                    else if(caritasSupervisorSignature == null && caritasSupervisorSignatureStatus =="Pending" && selectedBioStaffCategory != "Facility Supervisor"  ){
                                      return Column(
                                        children: [
                                          const Text("Awaiting Facility Supervisor Signature"),
                                          const SizedBox(height:8),
                                          caritasSupervisorSignatureStatus == "Pending"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.access_time, color: Colors.orange),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ):caritasSupervisorSignatureStatus == "Rejected"?
                                          Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.cancel, color: Colors.red),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          )
                                              :Row(
                                              children:[
                                                const Padding(
                                                  padding: EdgeInsets.only(top: 0.0),
                                                  child:
                                                  Icon(Icons.check_circle, color: Colors.green),
                                                ),
                                                const SizedBox(width:8),
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ]
                                          ),


                                        ],
                                      );
                                    }
                                    else if(selectedBioStaffCategory != "Facility Supervisor"  ) {
                                      return Column(
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 20,
                                              bottom: 24,
                                            ),
                                            height: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.15),
                                            width: MediaQuery.of(context).size.width *
                                                (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              //color: Colors.grey.shade300,
                                            ),
                                            child: Image.network(selectedSignatureLink!),
                                          ),
                                          const SizedBox(height: 8),
                                          caritasSupervisorSignatureStatus == "Pending"
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
                                                  padding: const EdgeInsets.only(bottom: 0.0),
                                                  child: Text(
                                                    "$caritasSupervisorSignatureStatus (Awaiting Approval)",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                              : caritasSupervisorSignatureStatus == "Rejected"
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
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                              : caritasSupervisorSignatureStatus == "Approved"
                                              ? Row(
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
                                                    "$caritasSupervisorSignatureStatus",
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
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
                                                    "$caritasSupervisorSignatureStatus (Approved)",
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
                                      return const Text("Awaiting Signature from Facility Supervisor");

                                    }
                                  } else {
                                    return const Text("Timesheet Yet to be submitted for Project Cordinator's Signature");
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.01 : 0.009)),
                        //Date of CARITAS Staff Signature Date

                        Container(
                          width: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.30 : 0.30),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20.0),
                              Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.005 : 0.005)),
                    const Divider(),
                    SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.020 : 0.020)),

                    StreamBuilder<DocumentSnapshot>(
                      // Stream the supervisor signature
                      stream: FirebaseFirestore.instance
                          .collection("Staff")
                          .doc(staffId) // Replace with how you get the staff document ID
                          .collection("TimeSheets")
                          .doc(filteredMonthYear) // Replace monthYear with the timesheet document ID
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

                              ElevatedButton.icon(
                                onPressed: () {
                                  sendEmailToProjectManagementTeam();
                                },
                                icon: const Icon(
                                  Icons.email, // Add an appropriate icon
                                  color: Colors.white, // Icon color
                                  size: 16, // Reduce the size of the icon
                                ),
                                label: const Flexible(
                                  child: Text(
                                    'Email Signed Timesheet to Project Managament Team',
                                    style: TextStyle(
                                      color: Colors.white, // Text color
                                      fontSize: 12, // Reduce font size
                                    ),
                                    textAlign: TextAlign.center, // Center-align text
                                    overflow: TextOverflow.clip, // Ensure text wraps instead of overflowing
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue, // Button background color
                                  foregroundColor: Colors.white, // Text and icon color
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduce button padding
                                  minimumSize: const Size(100, 30), // Set minimum size for the button
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize touch target size
                                ),
                              );
                          } else {
                            return Row(
                                crossAxisAlignment : CrossAxisAlignment.center,
                                mainAxisAlignment : MainAxisAlignment.center,
                                children:[
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _uploadSignatureAndSync();
                                    },
                                    icon: const Icon(
                                      Icons.credit_score, // Add an appropriate icon
                                      color: Colors.white, // Icon color
                                      size: 16, // Reduce the size of the icon
                                    ),
                                    label: const Flexible(
                                      child: Text(
                                        'Approve Timesheet',
                                        style: TextStyle(
                                          color: Colors.white, // Text color
                                          fontSize: 12, // Reduce font size
                                        ),
                                        textAlign: TextAlign.center, // Center-align text
                                        overflow: TextOverflow.clip, // Ensure text wraps instead of overflowing
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, // Button background color
                                      foregroundColor: Colors.white, // Text and icon color
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduce button padding
                                      minimumSize: const Size(100, 30), // Set minimum size for the button
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize touch target size
                                    ),
                                  ),

                                  const SizedBox(width:8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _rejectTimesheet(staffId, filteredMonthYear,selectedBioStaffCategory!);
                                    },
                                    icon: const Icon(
                                      Icons.cancel, // Add an appropriate icon
                                      color: Colors.white, // Icon color
                                      size: 16, // Reduce the size of the icon
                                    ),
                                    label: const Flexible(
                                      child: Text(
                                        'Reject Timesheet',
                                        style: TextStyle(
                                          color: Colors.white, // Text color
                                          fontSize: 12, // Reduce font size
                                        ),
                                        textAlign: TextAlign.center, // Center-align text
                                        overflow: TextOverflow.clip, // Ensure text wraps instead of overflowing
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red, // Button background color
                                      foregroundColor: Colors.white, // Text and icon color
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduce button padding
                                      minimumSize: const Size(100, 30), // Set minimum size for the button
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize touch target size
                                    ),
                                  ),



                                ]
                            );
                          }
                        } else {
                          return Row(
                              crossAxisAlignment : CrossAxisAlignment.center,
                              mainAxisAlignment : MainAxisAlignment.center,
                              children:[
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _uploadSignatureAndSync();
                                  },
                                  icon: const Icon(
                                    Icons.credit_score, // Add an appropriate icon
                                    color: Colors.white, // Icon color
                                    size: 16, // Reduce the size of the icon
                                  ),
                                  label: const Flexible(
                                    child: Text(
                                      'Approve Timesheet',
                                      style: TextStyle(
                                        color: Colors.white, // Text color
                                        fontSize: 12, // Reduce font size
                                      ),
                                      textAlign: TextAlign.center, // Center-align text
                                      overflow: TextOverflow.clip, // Ensure text wraps instead of overflowing
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green, // Button background color
                                    foregroundColor: Colors.white, // Text and icon color
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduce button padding
                                    minimumSize: const Size(100, 30), // Set minimum size for the button
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize touch target size
                                  ),
                                ),

                                const SizedBox(width:8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _rejectTimesheet(staffId, filteredMonthYear,selectedBioStaffCategory!);
                                  },
                                  icon: const Icon(
                                    Icons.cancel, // Add an appropriate icon
                                    color: Colors.white, // Icon color
                                    size: 16, // Reduce the size of the icon
                                  ),
                                  label: const Flexible(
                                    child: Text(
                                      'Reject Timesheet',
                                      style: TextStyle(
                                        color: Colors.white, // Text color
                                        fontSize: 12, // Reduce font size
                                      ),
                                      textAlign: TextAlign.center, // Center-align text
                                      overflow: TextOverflow.clip, // Ensure text wraps instead of overflowing
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red, // Button background color
                                    foregroundColor: Colors.white, // Text and icon color
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduce button padding
                                    minimumSize: const Size(100, 30), // Set minimum size for the button
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize touch target size
                                  ),
                                ),



                              ]
                          );
                        }
                      },
                    ),



                    SizedBox(height: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.090 : 0.020)),
                  ]
              ) ,

            ]
        ),
        //  caritasSupervisorSignature

      ),
    );
  }
}


