import 'dart:io';

import 'package:attendanceappmailtool/screens/timesheet/pending_timesheet_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw; // Changed import prefix to pw for clarity
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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

    final pdfDoc = pw.Document(pageMode: PdfPageMode.outlines);
    final pageFormat = PdfPageFormat.a4.landscape;

    try {
      final ByteData logoBytes =
      await rootBundle.load('assets/image/ccfn_logo.png');
      final Uint8List logoImageData = logoBytes.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoImageData);


      for (String timesheetPath in selectedTimesheetPaths) {
        DocumentReference timesheetRef = FirebaseFirestore.instance.doc(timesheetPath);
        DocumentSnapshot timesheetSnapshot = await timesheetRef.get();
        if (timesheetSnapshot.exists) {
          Map<String, dynamic> timesheetData = timesheetSnapshot.data() as Map<String, dynamic>;

          DateTime? timesheetDate1;
          try {
            final dateString = timesheetData['date'];
            if (dateString != null && dateString is String) {
              timesheetDate1 = DateFormat('MMMM dd, yyyy').parse(dateString);
            } else {
              timesheetDate1 = DateTime.now();
              print("Warning: Timesheet date is null or not a string, using current date as default.");
            }
          } catch (e) {
            print("Error parsing date: $e, using current date as default.");
            timesheetDate1 = DateTime.now();
          }
          timesheetDate1 ??= DateTime.now();
          final monthYear1 = DateFormat('MMMM_yyyy').format(timesheetDate1);
          final staffName = timesheetData['staffName'] ?? 'N/A';

          final supervisorNames = await _getSupervisorNamesForTimesheet(timesheetData); // Assuming you need supervisor names per timesheet
          final signatureColumns = await _buildSignatureColumnsForTimesheet(supervisorNames); // Assuming signature columns per timesheet

          pdfDoc.addPage(
            pw.Page(
              pageFormat: pageFormat,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStaffInfoForPDF(context, timesheetData), // Staff info for each timesheet
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
                    _buildTimesheetTableForPDF(context, timesheetData), // Timesheet table for each timesheet
                    pw.SizedBox(height: 10),
                    _buildSignatureSectionForPDF(context, signatureColumns), // Signature section for each timesheet
                  ],
                );
              },
            ),
          );

          // Conditionally add Task Summary Page
          if (_includeTaskSummary) {
            final taskSummaryContent = await _prepareTaskSummaryContentForTimesheet(timesheetData);
            if (taskSummaryContent.isNotEmpty) {
              pdfDoc.addPage(
                pw.MultiPage(
                  // pageFormat: pageFormat, // You can set page format if needed, or let MultiPage handle it
                  header: (pw.Context context) {
                    return pw.Header(
                      level: 0,
                      child: pw.Text('Task Summary Report - $monthYear1 - ${timesheetData['staffName'] ?? 'N/A'}', // Include staff name in task summary header
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
                          "Task Summary for ${monthYear1} - ${timesheetData['staffName'] ?? 'N/A'}", // Include staff name in task summary title
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Column(children: taskSummaryContent), // Use the prepared task summary content
                    ];
                  },
                ),
              );}
          }
        }
      }

      Uint8List pdfBytes = await pdfDoc.save();

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "Selected_Timesheets.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/Selected_Timesheets.pdf");
        await file.writeAsBytes(pdfBytes);
        // Optionally, use Printing.sharePdf here if you want to enable sharing/printing on mobile
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

  // Placeholder methods - You need to implement these based on your _createAndExportPDF and data structure
  Future<List<String>> _getSupervisorNamesForTimesheet(Map<String, dynamic> timesheetData) async {
    // Implement logic to get supervisor names based on timesheetData
    // This might involve fetching from Firestore based on user roles or data in timesheetData
    return ["Supervisor 1 Name", "Supervisor 2 Name"]; // Example placeholder
  }

  Future<List<pw.Widget>> _buildSignatureColumnsForTimesheet(List<String> supervisorNames) async {
    // Implement logic to build signature columns based on supervisorNames
    // Replicate the structure from your _buildSignatureColumns
    return [
      pw.Column(children: [pw.Text("Supervisor 1 Signature")]),
      pw.Column(children: [pw.Text("Supervisor 2 Signature")])
    ]; // Example placeholder
  }


  pw.Widget _buildStaffInfoForPDF(pw.Context context, Map<String, dynamic> timesheetData) {
    final staffName = timesheetData['staffName'] ?? 'N/A';
    // Add other staff info from timesheetData as needed
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("$staffName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          // pw.Text("Staff ID: [Staff ID here]"), // Add staff ID if available in timesheetData
          // pw.Text("Location: [Location here]"), // Add location if available
        ]
    );
  }

  pw.Widget _buildTimesheetTableForPDF(pw.Context context, Map<String, dynamic> timesheetData) {
    // Implement logic to build timesheet table for PDF based on timesheetData
    // Replicate the structure from your _buildTimesheetTable, adapting to use timesheetData
    return pw.Text("Timesheet Table Content Here"); // Placeholder - Implement your table building logic
  }

  pw.Widget _buildSignatureSectionForPDF(pw.Context context, List<pw.Widget> signatureColumns) {
    // Implement logic to build signature section for PDF
    // Replicate the structure from your _buildSignatureSection, using signatureColumns
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: signatureColumns
    ); // Placeholder - Implement your signature section
  }


  Future<List<pw.Widget>> _prepareTaskSummaryContentForTimesheet(Map<String, dynamic> timesheetData) async {
    // Adapt your _prepareTaskSummaryContent or _prepareTaskSummaryContent1 here
    // to work with timesheetData to fetch task summary for the specific staff/timesheet
    // You will need to adjust data fetching logic to use staffId or other relevant identifiers
    return [pw.Center(child: pw.Text("Task Summary Content for ${timesheetData['staffName'] ?? 'N/A'}"))]; // Placeholder
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
          final timesheetDocPath = '/Staff/${timesheet['staffId']}/TimeSheets/${_timesheetCollectionName}';
          bool isSelected = selectedTimesheetPaths.contains(timesheetDocPath);

          print("timesheet ===$timesheet");
          print("timesheets[index] ===${timesheets[index]}");
          print("timesheetDocPath ===$timesheetDocPath");
          print("isSelected ===$isSelected");

          return Card(
            child: ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedTimesheetPaths.add(timesheetDocPath);
                      print("selectedTimesheetPaths True ===$selectedTimesheetPaths");
                    } else {
                      selectedTimesheetPaths.remove(timesheetDocPath);
                      print("selectedTimesheetPaths False ===$selectedTimesheetPaths");
                    }
                  });
                },
              ),
              title: Text(timesheet['staffName'] ?? 'N/A'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_getApprovalStatusText(timesheet)}'),
                  Row(
                    children: [
                      const Text('Duration: '),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getDurationColor(timesheet).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format((timesheet['timesheetSubmissionDate'] as Timestamp?)?.toDate() ?? DateTime.now()),
                          style: TextStyle(color: _getDurationColor(timesheet)),
                        ),
                      ),
                    ],
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
}