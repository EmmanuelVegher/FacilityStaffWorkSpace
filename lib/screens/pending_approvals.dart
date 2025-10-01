import 'dart:io';

import 'package:service_delivery_workspace/screens/timesheet/pending_timesheet_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/drawer2.dart';
import 'activity_monitoring/activity_monitoring_page.dart';


// ===================================================================
// MODELS (Copied from your DailyActivityMonitoringPage for context)
// ===================================================================

class BioModel {
  String? firstName, lastName, department, state, designation, location, staffCategory, emailAddress, mobile, firebaseAuthId;
  BioModel({this.firstName, this.lastName, this.department, this.state, this.designation, this.location, this.staffCategory, this.emailAddress, this.mobile, this.firebaseAuthId});
  factory BioModel.fromJson(Map<String, dynamic> json) => BioModel(firstName: json['firstName'], lastName: json['lastName'], department: json['department'], state: json['state'], designation: json['designation'], location: json['location'], staffCategory: json['staffCategory'], emailAddress: json['emailAddress'], mobile: json['mobile'], firebaseAuthId: json['firebaseAuthId']);
}

class ReportEntry {
  String key, value;
  String? enteredBy, editedBy, reviewedBy, reviewStatus, supervisorName, supervisorEmail, supervisorApprovalStatus, supervisorFeedBackComment, appAnalysis, reviewerId;
  List<String>? attachments;

  ReportEntry({this.key = "", this.value = "", this.enteredBy, this.editedBy, this.reviewedBy, this.reviewStatus, this.supervisorName, this.supervisorEmail, this.supervisorApprovalStatus, this.supervisorFeedBackComment, this.attachments, this.appAnalysis, this.reviewerId});

  factory ReportEntry.fromMap(Map<String, dynamic> map) => ReportEntry(key: map['key'] ?? '', value: map['value'] ?? '', enteredBy: map['enteredBy'], editedBy: map['editedBy'], reviewedBy: map['reviewedBy'], reviewStatus: map['reviewStatus'], supervisorName: map['supervisorName'], supervisorEmail: map['supervisorEmail'], supervisorApprovalStatus: map['supervisorApprovalStatus'], supervisorFeedBackComment: map['supervisorFeedBackComment'], attachments: (map['attachments'] as List<dynamic>?)?.cast<String>().toList(), appAnalysis: map['appAnalysis'], reviewerId: map['reviewerId']);

  Map<String, dynamic> toMap() => {'key': key, 'value': value, if (enteredBy != null) 'enteredBy': enteredBy, if (editedBy != null) 'editedBy': editedBy, if (reviewedBy != null) 'reviewedBy': reviewedBy, if (reviewStatus != null) 'reviewStatus': reviewStatus, if (supervisorName != null) 'supervisorName': supervisorName, if (supervisorEmail != null) 'supervisorEmail': supervisorEmail, if (supervisorApprovalStatus != null) 'supervisorApprovalStatus': supervisorApprovalStatus, if (supervisorFeedBackComment != null) 'supervisorFeedBackComment': supervisorFeedBackComment, if (attachments != null) 'attachments': attachments, if (appAnalysis != null) 'appAnalysis': appAnalysis, if (reviewerId != null) 'reviewerId': reviewerId};

  ReportEntry copyWith({String? key, String? value, String? enteredBy, String? editedBy, String? reviewedBy, String? reviewStatus, List<String>? attachments, String? appAnalysis, String? reviewerId}) => ReportEntry(key: key ?? this.key, value: value ?? this.value, enteredBy: enteredBy ?? this.enteredBy, editedBy: editedBy ?? this.editedBy, reviewedBy: reviewedBy ?? this.reviewedBy, reviewStatus: reviewStatus ?? this.reviewStatus, attachments: attachments ?? this.attachments, appAnalysis: appAnalysis ?? this.appAnalysis, reviewerId: reviewerId ?? this.reviewerId);
}

class Report {
  String? id, reportType, reportingWeek, reportingMonth, reportStatus, reportFeedbackComment, supervisorName, supervisorEmail, supervisorApprovalStatus, supervisorFeedBackComment;
  DateTime? date;
  List<String>? attachments;
  bool? isSynced;
  Map<String, Map<String, List<ReportEntry>>>? reportEntries;
  DocumentReference? docRef; // To hold the document reference for easy updates

  Report({this.id, this.date, this.reportType, this.reportingWeek, this.reportingMonth, this.reportStatus, this.attachments, this.reportFeedbackComment, this.supervisorName, this.supervisorEmail, this.supervisorApprovalStatus, this.supervisorFeedBackComment, this.isSynced, this.reportEntries, this.docRef});

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    return Report(
        id: snapshot.id,
        docRef: snapshot.reference, // Store the reference
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
        attachments: (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
        isSynced: data?['isSynced'],
        reportEntries: (data?['reportEntries'] as Map<String, dynamic>?)?.map((username, indicatorMap) => MapEntry(username, (indicatorMap as Map<String, dynamic>).map((indicator, entryList) => MapEntry(indicator, (entryList as List<dynamic>).map((entryData) => ReportEntry.fromMap(entryData as Map<String, dynamic>)).toList())))));
  }

  Map<String, dynamic> toFirestore() => {'reportType': reportType, 'date': date, 'reportingWeek': reportingWeek, 'reportingMonth': reportingMonth, 'reportStatus': reportStatus, 'reportFeedbackComment': reportFeedbackComment, 'supervisorName': supervisorName, 'supervisorEmail': supervisorEmail, 'supervisorApprovalStatus': supervisorApprovalStatus, 'supervisorFeedBackComment': supervisorFeedBackComment, 'attachments': attachments, 'isSynced': isSynced, if (reportEntries != null) 'reportEntries': reportEntries!.map((username, indicatorMap) => MapEntry(username, indicatorMap.map((indicator, entryList) => MapEntry(indicator, entryList.map((e) => e.toMap()).toList()))))};
}


class PendingApprovalsPage extends StatefulWidget {
  const PendingApprovalsPage({super.key});

  @override
  _PendingApprovalsPageState createState() => _PendingApprovalsPageState();
}

class _PendingApprovalsPageState extends State<PendingApprovalsPage> with SingleTickerProviderStateMixin {
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
  BioModel? bioData;
  String? selectedSupervisor;
  List<Map<String, dynamic>> pendingLeaves = [];
  List<Map<String, dynamic>> pendingTimesheets = [];
  List<Map<String, dynamic>> pendingTimesheetsFacilitySupervisor = [];
  List<Map<String, dynamic>> pendingTimesheetsCaritasSupervisor = [];
  List<Report> pendingReviews = []; // List to hold pending reports for review
  bool isLoading = true;
  bool isApproveLoading = false;
  final TextEditingController _rejectReasonController = TextEditingController();
  int _tabIndex = 0; // To manage tab index
  final FirestoreService _firestoreService = FirestoreService(); // Instantiate FirestoreService

  // Define wine color and gradients - Keep your existing styles
  static const Color wineColor = Color(0xFF722F37); // Deep wine color
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)], // Wine to lighter wine shade
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFF8EEDD), Colors.white], // Light beige to white
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient buttonGradientApprove = LinearGradient(
    colors: [Colors.green, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient buttonGradientReject = LinearGradient(
    colors: [Color(0xFFD32F2F), Colors.redAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient buttonGradientNavigate = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  @override
  void initState() {
    super.initState();
    _loadBioDataFromFirebase().then((_) {
      _fetchPendingApprovals();
    });
  }

  Future<void> _loadBioDataFromFirebase1() async {
    setState(() {
      isLoading = true; // Start loading
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userEmail = user.email!;
        // Assuming bio data is stored in 'Staff' collection and email is used as document ID or a field to query
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('Staff')
            .where('emailAddress', isEqualTo: userEmail) // Query based on email
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var staffData = staffQuery.docs.first.data() as Map<String, dynamic>?;
          if (staffData != null) {
            bioData = BioModel.fromJson(staffData);
            setState(() {
              selectedBioFirstName = bioData!.firstName;
              selectedBioLastName = bioData!.lastName;
              selectedBioDepartment = bioData!.department;
              selectedBioState = bioData!.state;
              selectedBioDesignation = bioData!.designation;
              selectedBioLocation = bioData!.location;
              selectedBioStaffCategory = bioData!.staffCategory;
              selectedBioEmail = bioData!.emailAddress;
              selectedBioPhone = bioData!.mobile;
              selectedFirebaseId = bioData!.firebaseAuthId;
            });
          } else {
            print("Staff data is null in Firestore document");
          }
        } else {
          print("No staff document found for email: $userEmail");
        }
      } else {
        print("No user logged in.");
      }
    } catch (e) {
      print("Error loading bio data from Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  // --- NEW HELPER METHOD ---
// Add this helper method inside your _PendingApprovalsPageState class.
  String _formatTimesheetPeriod(String rawPeriod) {
    if (!rawPeriod.contains('_')) return rawPeriod;

    // Replace underscores with spaces
    String formatted = rawPeriod.replaceAll('_', ' ');

    // Capitalize "part" and wrap it in parentheses
    if (formatted.contains('part')) {
      formatted = formatted.replaceFirst('p', 'P');
      formatted = formatted.replaceFirstMapped(
          RegExp(r'(Part \d+)'), (match) => '(${match.group(1)})');
    }
    return formatted;
  }

  Future<void> _fetchPendingApprovals1() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      // Ensure user and bioData (with email) are available before proceeding.
      if (user == null || bioData == null || bioData!.emailAddress == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Convert the current user's email to lowercase for a case-insensitive comparison.
      final userEmailLower = bioData!.emailAddress!.toLowerCase();

      // --- MODIFIED QUERIES ---

      // 1. Fetch pending leaves and then filter by email in the app.
      // NOTE: This is less efficient as it might read more documents than necessary.
      // For optimal performance, consider storing a lowercase version of the email in Firestore.
      final leavesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('Leave Request')
          .where('status', isEqualTo: 'Pending')
          .get();

      final filteredLeavesDocs = leavesSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['selectedSupervisorEmail'] as String?;
        // Compare emails in lowercase.
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }).toList();

      // 2. Fetch pending timesheets for CARITAS Supervisors and filter by email.
      final caritasSupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved')
          .get();

      final filteredCaritasTimesheetsDocs = caritasSupervisorTimesheetsSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['caritasSupervisorEmail'] as String?;
        // Compare emails in lowercase.
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }).toList();

      // 3. Fetch pending timesheets for Facility Supervisors and filter by email.
      final facilitySupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
          .get();

      final filteredFacilityTimesheetsDocs = facilitySupervisorTimesheetsSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['facilitySupervisorEmail'] as String?;
        // Compare emails in lowercase.
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }).toList();


      // Fetch pending reviews (This query logic remains the same as it uses ID, not email)
      List<Report> reviews = [];
      if (selectedFirebaseId != null) {
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('Reports')
            .where('reviewerIds', arrayContains: selectedFirebaseId)
            .where('reportStatus', isEqualTo: 'Pending')
            .get();
        reviews = reviewsSnapshot.docs.map((doc) => Report.fromFirestore(doc, null)).toList();
      }

      if (mounted) {
        setState(() {
          // Use the new, filtered lists of documents.
          pendingLeaves = filteredLeavesDocs.map((doc) => doc.data()).toList();
          pendingTimesheetsFacilitySupervisor = filteredFacilityTimesheetsDocs.map((doc) => doc.data()).toList();
          pendingTimesheetsCaritasSupervisor = filteredCaritasTimesheetsDocs.map((doc) => doc.data()).toList();
          pendingReviews = reviews;
        });
      }
    } catch (e) {
      if(mounted) {
        print('Error fetching approvals: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching approvals: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadBioDataFromFirebase() async {
    setState(() {
      isLoading = true; // Start loading
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Query by the unique Firebase Auth ID (UID) instead of email.
        // This is the most reliable way to link an authenticated user to their profile
        // and avoids any case-sensitivity issues with email addresses.
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('Staff')
            .where('id', isEqualTo: user.uid) // Use the user's UID for the query
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var staffData = staffQuery.docs.first.data() as Map<String, dynamic>?;
          if (staffData != null) {
            bioData = BioModel.fromJson(staffData);
            // Now, we correctly load the bio data, including the email as it is stored in Firestore.
            setState(() {
              selectedBioFirstName = bioData!.firstName;
              selectedBioLastName = bioData!.lastName;
              selectedBioDepartment = bioData!.department;
              selectedBioState = bioData!.state;
              selectedBioDesignation = bioData!.designation;
              selectedBioLocation = bioData!.location;
              selectedBioStaffCategory = bioData!.staffCategory;
              selectedBioEmail = bioData!.emailAddress; // This might be "User.Name@email.com"
              selectedBioPhone = bioData!.mobile;
              selectedFirebaseId = bioData!.firebaseAuthId;
            });
          } else {
            print("Staff data is null in Firestore document");
          }
        } else {
          print("No staff document found for auth UID: ${user.uid}");
        }
      } else {
        print("No user logged in.");
      }
    } catch (e) {
      print("Error loading bio data from Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  Future<void> _fetchPendingApprovals() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      // Ensure user and bioData (with email) are available before proceeding.
      if (user == null || bioData == null || bioData!.emailAddress == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Get the supervisor's email from the loaded bioData and convert it to lowercase
      // for a case-insensitive comparison.
      final userEmailLower = bioData!.emailAddress!.toLowerCase();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allPendingTimesheets = [];

      // --- Fetch and Filter Pending Leaves ---
      final leavesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('Leave Request')
          .where('status', isEqualTo: 'Pending')
          .get();

      final filteredLeavesDocs = leavesSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['selectedSupervisorEmail'] as String?;
        // Compare both emails in lowercase to ensure a match.
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }).toList();

      // Fetch and filter CARITAS supervisor timesheets
      final caritasSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved')
          .get();
      allPendingTimesheets.addAll(caritasSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['caritasSupervisorEmail'] as String?;
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }));

      // --- Fetch and Filter Pending Timesheets (Facility Supervisor) ---
      final facilitySupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
          .get();

      final filteredFacilityTimesheetsDocs = facilitySupervisorTimesheetsSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['facilitySupervisorEmail'] as String?;
        // Compare both emails in lowercase.
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }).toList();


      // Fetch pending reviews (This logic remains the same as it uses ID, not email)
      List<Report> reviews = [];
      if (selectedFirebaseId != null) {
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('Reports')
            .where('reviewerIds', arrayContains: selectedFirebaseId)
            .where('reportStatus', isEqualTo: 'Pending')
            .get();
        reviews = reviewsSnapshot.docs.map((doc) => Report.fromFirestore(doc, null)).toList();
      }

      if (mounted) {
        setState(() {
          // --- THIS IS THE KEY CHANGE ---
          // Map the documents, adding the unique ID of each one to its data map.
          pendingTimesheetsCaritasSupervisor = allPendingTimesheets.map((doc) {
            final data = doc.data();
            data['docId'] = doc.id; // Add the document ID here!
            return data;
          }).toList();
          // --- END OF CHANGE ---

          // (Update other lists like pendingLeaves here if needed)
          // ...
        });
      }
    } catch (e) {
      if(mounted) {
        print('Error fetching approvals: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching approvals: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }



  Future<void> _approveLeave(Map<String, dynamic> leave) async {
    try {
      final leaveRequestId = leave['leaveRequestId'] as String?;
      final staffId = leave['staffId'] as String?;
      if (leaveRequestId != null && staffId != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(staffId)
            .collection('Leave Request')
            .doc(leaveRequestId)
            .update({'status': 'Approved'});
        setState(() {
          pendingLeaves.remove(leave);
        });

        if (pendingLeaves.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending leave approvals')),
          );
        }
      }
    } catch (e) {
      print('Error approving leave: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving leave: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectLeave(Map<String, dynamic> leave) async {
    TextEditingController rejectionReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Return Leave Request", style: TextStyle(color: wineColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Please provide a reason for rejection:", style: TextStyle(color: Colors.black87)),
              TextField(
                controller: rejectionReasonController,
                decoration: const InputDecoration(
                  labelText: "Reason for Rejection",
                  labelStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: wineColor)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
                cursorColor: wineColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectReasonController.clear();
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final leaveRequestId = leave['leaveRequestId'] as String?;
                  final staffId = leave['staffId'] as String?;
                  if (leaveRequestId != null && staffId != null) {
                    await FirebaseFirestore.instance
                        .collection('Staff')
                        .doc(staffId)
                        .collection('Leave Request')
                        .doc(leaveRequestId)
                        .update({
                      'status': 'Rejected',
                      'reasonsForRejectedLeave': rejectionReasonController.text,
                    });

                    setState(() {
                      pendingLeaves.remove(leave);
                    });
                    if (pendingLeaves.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No pending leave approvals')),
                      );
                    }
                  }
                  Navigator.of(context).pop();
                  _rejectReasonController.clear();
                  _fetchPendingApprovals();
                } catch (e) {
                  print('Error rejecting leave: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error rejecting leave: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Returned", style: TextStyle(color: wineColor)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        );
      },
    );
  }

  Widget _buildLeaveCard(BuildContext context, Map<String, dynamic> leave) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth > 600 ? 550 : screenWidth * 0.9;
    double paddingValue = screenWidth > 600 ? 16.0 : 12.0;
    double fontSizeTitle = screenWidth > 600 ? 22.0 : 20.0;
    double fontSizeRegularBold = screenWidth > 600 ? 18.0 : 16.0;
    double fontSizeRegular = screenWidth > 600 ? 16.0 : 14.0;

    // Handle date formatting safely
    String startDateFormatted = 'N/A';
    String endDateFormatted = 'N/A';

    if (leave['startDate'] != null) {
      if (leave['startDate'] is String) {
        startDateFormatted = DateFormat('yyyy-MM-dd').format(DateTime.parse(leave['startDate']));
      } else if (leave['startDate'] is Timestamp) {
        startDateFormatted = DateFormat('yyyy-MM-dd').format((leave['startDate'] as Timestamp).toDate());
      }
    }

    if (leave['endDate'] != null) {
      if (leave['endDate'] is String) {
        endDateFormatted = DateFormat('yyyy-MM-dd').format(DateTime.parse(leave['endDate']));
      } else if (leave['endDate'] is Timestamp) {
        endDateFormatted = DateFormat('yyyy-MM-dd').format((leave['endDate'] as Timestamp).toDate());
      }
    }


    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: screenWidth > 600 ? (screenWidth - cardWidth) / 2 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        gradient: cardGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(paddingValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${leave['firstName']} ${leave['lastName']}",
              style: TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.bold, color: wineColor),
            ),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Leave Type", leave['type'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Duration", "$startDateFormatted - $endDateFormatted", fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Department", leave['staffDepartment'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Designation", leave['staffDesignation'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Location", leave['staffLocation'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Staff Category", leave['staffCategory'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("State", leave['staffState'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Email", leave['staffEmail'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Phone", leave['staffPhone'], fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Reason", leave['reason'] ?? 'No reason provided', fontSizeRegularBold, fontSizeRegular, textColor: Colors.grey[900]),
            SizedBox(height: paddingValue),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text("Approve", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    backgroundColor: Colors.green.shade600,
                  ),
                  onPressed: () => _approveLeave(leave),
                ),
                SizedBox(width: paddingValue / 2),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text("Return", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => _rejectLeave(leave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetCard(BuildContext context, Map<String, dynamic> doc) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth > 600 ? 550 : screenWidth * 0.9;
    double paddingValue = screenWidth > 600 ? 16.0 : 12.0;
    double fontSizeTitle = screenWidth > 600 ? 22.0 : 20.0;
    double fontSizeRegularBold = screenWidth > 600 ? 18.0 : 16.0;
    double fontSizeRegular = screenWidth > 600 ? 16.0 : 14.0;

    final staffName = doc['staffName'] ?? 'N/A';
    final projectName = doc['projectName'] ?? 'N/A';
    final date = doc['staffSignatureDate'] ?? 'N/A';
    final department = doc['department'] ?? 'N/A';
    final caritasSupervisor = doc['caritasSupervisor'] ?? 'N/A';
    final designation = doc['designation'] ?? 'N/A';
    final location = doc['location'] ?? 'N/A';
    final state = doc['state'] ?? 'N/A';
    final staffCategory = doc['staffCategory'] ?? 'N/A';
    final staffEmail = doc['staffEmail'] ?? 'N/A';
    final staffPhone = doc['staffPhone'] ?? 'N/A';
    // --- THIS IS THE UPDATED LINE ---
    // Use the 'docId' for the title, fallback to 'month', then 'N/A'.
    final timesheetPeriod = _formatTimesheetPeriod(doc['docId'] ?? doc['month'] ?? 'N/A');
    //final staffMonth = doc.id ?? 'N/A';


    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: screenWidth > 600 ? (screenWidth - cardWidth) / 2 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        gradient: cardGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(paddingValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$staffName",
              style: TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.bold, color: wineColor),
            ),
            // --- ADD THIS NEW WIDGET FOR THE TIMESHEET PERIOD ---
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(
                "Timesheet for: $timesheetPeriod",
                style: TextStyle(
                  fontSize: fontSizeRegular,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
            // --- END OF ADDITION ---
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Location Name", location, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Date", date, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Department", department, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Designation", designation, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Project Name", projectName, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Staff Category", staffCategory, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("State", state, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("Email Address", staffEmail, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow("PhoneNumber", staffPhone, fontSizeRegularBold, fontSizeRegular),
            SizedBox(height: paddingValue / 2),
            _buildDetailRow(
              selectedBioStaffCategory == "State Office Staff" || selectedBioStaffCategory == "HQ Staff"
                  ? "Facility Supervisor" : "CARITAS Supervisor",
              caritasSupervisor, fontSizeRegularBold, fontSizeRegular, textColor: Colors.grey[900],
            ),

            SizedBox(height: paddingValue),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (selectedBioStaffCategory == "State Office Staff" ||
                    selectedBioStaffCategory == "HQ Staff" ||
                    selectedBioStaffCategory == "Facility Staff")
                  ElevatedButton.icon(
                    label: const Text("Pending", style: TextStyle(color: Colors.white)),
                    icon: const Icon(Icons.access_time, color: Colors.orange),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      backgroundColor: Colors.orange.shade700,
                    ),
                    onPressed: () {},
                  ),
                SizedBox(width: paddingValue / 2),
                isLoading
                    ? const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
                    : ElevatedButton.icon(
                  label: const Text("Approve Timesheet", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.forward, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    backgroundColor: wineColor,
                  ),
                  onPressed: () =>  isApproveLoading
                      ? const CircularProgressIndicator()
                      :_onApprovePressed(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onApprovePressed(Map<String, dynamic> doc) async {
    // This existing method is now correct because `doc` contains the `docId`.
    setState(() {
      isApproveLoading = true;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimesheetDetailsScreen2(
          timesheetData: doc, // Pass the whole map
          staffId: doc['staffId'],
        ),
      ),
    );

    setState(() {
      isApproveLoading = false;
    });
  }



  Widget _buildDetailRow(String label, String? value, double labelFontSize, double valueFontSize, {Color? textColor}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: valueFontSize, color: textColor ?? Colors.black87),
        children: [
          TextSpan(text: "$label: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: labelFontSize, color: Colors.black87)),
          TextSpan(text: value ?? 'N/A'),
        ],
      ),
    );
  }

  // --- START OF INTEGRATED REVIEW LIST TAB FUNCTIONS AND WIDGET ---

  // Function to fetch reports needing review - adapted for PendingApprovalsPage context
  Future<List<Report>> _fetchReportsForReview() async {
    List<Report> reportsForReview = [];
    String? currentUserId = selectedFirebaseId; // Use selectedFirebaseId from bioData load

    if (currentUserId == null) {
      print("Current user ID is null, cannot fetch reports for review.");
      return [];
    }

    try {
      String currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now()); // Format date

      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('Reports')
          .doc(selectedBioState) // Use loaded selectedBioState
          .collection(selectedBioState!) // Use loaded selectedBioState
          .doc(selectedBioLocation) // Use loaded selectedBioLocation
          .collection(currentDate) // Use current date for now, adjust if needed
          .get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          Report report = Report.fromFirestore(doc, null);
          if (report.reportStatus == 'Pending' && report.reportEntries != null) {
            for (var username in report.reportEntries!.keys) {
              var indicatorMap = report.reportEntries![username];
              for (var indicator in indicatorMap!.keys) {
                for (var entry in indicatorMap[indicator]!) {
                  if (entry.reviewerId == currentUserId) {
                    reportsForReview.add(report);
                    break;
                  }
                }
              }
            }
          }
        }
      } else {
        print("No reports found for user ID: $currentUserId");
      }
    } catch (e) {
      print("Error fetching reports for review: $e");
    }
    return reportsForReview;
  }

  // Widget for Review List Tab - Integrated from DailyActivityMonitoringPage
  Widget _buildReviewListTab1() {
    return FutureBuilder<List<Report>>(
      future: _fetchReportsForReview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading review list: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No reports pending your review."));
        } else {
          List<Report> reviewReports = snapshot.data!;

          // Create a set to store unique report identifiers (reportType + date)
          Set<String> uniqueReportIdentifiers = {};
          List<Report> uniqueReviewReports = [];

          for (Report report in reviewReports) {
            String reportIdentifier = "${report.reportType}_${DateFormat('yyyy-MM-dd').format(report.date!)}";
            if (!uniqueReportIdentifiers.contains(reportIdentifier)) {
              uniqueReportIdentifiers.add(reportIdentifier);
              uniqueReviewReports.add(report);
            }
          }

          return ListView.builder(
            itemCount: uniqueReviewReports.length,
            itemBuilder: (context, index) {
              Report report = uniqueReviewReports[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${report.reportType}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text("Date: ${DateFormat('yyyy-MM-dd').format(report.date!)}"),
                      const SizedBox(height: 16),
                      if (report.reportEntries != null && report.reportEntries!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: report.reportEntries!.entries.map((usernameEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: usernameEntry.value.entries.map((indicatorEntry) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: indicatorEntry.value.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start, // Align row content to start
                                            children: [
                                              Text("${entry.key}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Expanded(child: Text(entry.value)), // Use Expanded to wrap Text for long values
                                            ],
                                          ),
                                          if (entry.enteredBy != null)
                                            Text("Entered By: ${entry.enteredBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          if (entry.editedBy != null)
                                            Text("Edited By: ${entry.editedBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          if (entry.reviewedBy != null) // ADDED: Show reviewedBy field
                                            Text("Reviewed By: ${entry.reviewedBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          if (entry.reviewedBy != null) // ADDED: Show reviewedBy field
                                            Text("Review Status: ${entry.reviewStatus}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          if (entry.attachments != null && entry.attachments!.isNotEmpty) // ADDED: Show image thumbnail
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  String? imageUrl = entry.attachments!.firstWhere(
                                                          (attachment) => attachment.toLowerCase().endsWith(('.png')) || attachment.toLowerCase().endsWith(('.jpg')) || attachment.toLowerCase().endsWith(('.jpeg')),
                                                      orElse: () => '' // Return empty string if no image found
                                                  );
                                                  if (imageUrl.isNotEmpty) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => FullScreenImage(imagePath: imageUrl), // Use aliased class
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('No image attachment found.')),
                                                    );
                                                  }
                                                },
                                                child: SizedBox(
                                                  width: 50,
                                                  height: 50,
                                                  child: Image.network(
                                                    entry.attachments!.firstWhere(
                                                            (attachment) => attachment.toLowerCase().endsWith(('.png')) || attachment.toLowerCase().endsWith(('.jpg')) || attachment.toLowerCase().endsWith(('.jpeg')),
                                                        orElse: () => '' // Return empty string if no image found
                                                    ),
                                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.red),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _approveReport(report);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Approve", style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              _returnReport(report);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text("Return", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
  // ===================================================================
  // REVIEW TAB: LOGIC AND WIDGETS
  // ===================================================================

  Widget _buildReviewListTab() {
    return pendingReviews.isNotEmpty
        ? RefreshIndicator(
      onRefresh: _fetchPendingApprovals,
      color: wineColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: pendingReviews.length,
        itemBuilder: (context, index) {
          return _buildReviewCard(context, pendingReviews[index]);
        },
      ),
    )
        : const Center(child: Text("No reports pending your review."));
  }

  Widget _buildReviewCard(BuildContext context, Report report) {
    Map<String, List<Widget>> userEntriesMap = {};

    // Group entries by the user who submitted them
    report.reportEntries?.forEach((username, indicatorMap) {
      List<Widget> userEntryWidgets = [];
      indicatorMap.forEach((indicator, entryList) {
        var relevantEntries = entryList.where((entry) => entry.reviewerId == selectedFirebaseId && entry.reviewStatus == 'Pending');
        for (var entry in relevantEntries) {
          userEntryWidgets.add(_buildIndicatorRowForReview(report, entry, username));
        }
      });
      if (userEntryWidgets.isNotEmpty) {
        userEntriesMap[username] = userEntryWidgets;
      }
    });

    if (userEntriesMap.isEmpty) {
      return const SizedBox.shrink(); // Don't show card if no entries are pending for this supervisor
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.reportType ?? "Review Request", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: wineColor)),
            const SizedBox(height: 4),
            Text("Date: ${DateFormat('EEE, MMM d, yyyy').format(report.date!)}", style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
            const Divider(height: 24),
            ...userEntriesMap.entries.map((userEntry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Submitted by: ${userEntry.key}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...userEntry.value, // The list of indicator rows for this user
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(onPressed: () => _approveReportForUser(report, userEntry.key), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Approve All", style: TextStyle(color: Colors.white))),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _returnReportForUser(report, userEntry.key), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Return All", style: TextStyle(color: Colors.white))),
                    ],
                  ),
                  const Divider(height: 20),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorRowForReview(Report report, ReportEntry entry, String username) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${entry.key}: ", style: const TextStyle(fontWeight: FontWeight.w600)),
              Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 15))),
            ],
          ),
          if (entry.attachments != null && entry.attachments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.attachments!.length,
                  itemBuilder: (context, index) {
                    final attachmentUrl = entry.attachments![index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imagePath: attachmentUrl))),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.network(attachmentUrl, width: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateReportReviewStatus(Report report, String username, String newStatus) async {
    if (report.docRef == null) return;

    // Create a deep copy of the reportEntries map to modify it
    Map<String, dynamic> newReportEntries = report.toFirestore()['reportEntries'];

    if (newReportEntries[username] != null) {
      (newReportEntries[username] as Map<String, dynamic>).forEach((indicatorKey, entryList) {
        for (int i = 0; i < (entryList as List).length; i++) {
          if (entryList[i]['reviewerId'] == selectedFirebaseId) {
            entryList[i]['reviewStatus'] = newStatus;
          }
        }
      });
    }
    await report.docRef!.update({'reportEntries': newReportEntries});
    await _fetchPendingApprovals(); // Refresh the list
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$username's entries have been updated.")));
  }

  Future<void> _approveReportForUser(Report report, String username) async {
    await _updateReportReviewStatus(report, username, 'Approved');
  }

  Future<void> _returnReportForUser(Report report, String username) async {
    await _updateReportReviewStatus(report, username, 'Returned');
  }

  // ===================================================================
  // LEAVE & TIMESHEET LOGIC (Existing code, slightly refactored)
  // ===================================================================


  Future<void> _approveReport(Report report) async {
    Report updatedReport = report;
    updatedReport.reportStatus = 'Approved';
    await _updateReportReviewStatus1(updatedReport);
  }

  Future<void> _returnReport(Report report) async {
    String? feedback = await _showFeedbackDialog(context); // Show dialog to get feedback
    if (feedback != null) {
      Report updatedReport = report;
      updatedReport.reportStatus = 'Rejected'; // or 'Returned' as per your model
      await _updateReportReviewStatus1(updatedReport, feedback: feedback); // Pass feedback to update function
    }
  }

  Future<void> _updateReportReviewStatus1(Report report, {String? feedback}) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot update report status.");
      return;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(report.date!);
      final DocumentReference reportDocRef = FirebaseFirestore.instance
          .collection('Reports')
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(report.reportType); // Assuming reportType is used as document ID

      Map<String, dynamic> reportData = report.toFirestore();
      if (feedback != null) {
        reportData['reportFeedbackComment'] = feedback; // Store feedback comment
      }
      await reportDocRef.set(reportData, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report status updated to ${report.reportStatus}!')));
      setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating report status.')));
      print("Error updating report status in Firestore: $e");
    }
  }

  Future<String?> _showFeedbackDialog(BuildContext context) async {
    TextEditingController feedbackController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Provide Feedback for Return"),
          content: TextField(
            controller: feedbackController,
            decoration: const InputDecoration(hintText: "Enter feedback here"),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: const Text("Return Report"),
              onPressed: () => Navigator.of(context).pop(feedbackController.text),
            ),
          ],
        );
      },
    );
  }
  // --- END OF INTEGRATED REVIEW LIST TAB FUNCTIONS AND WIDGET ---


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Update tab length to 3
      child: Scaffold(
        drawer: drawer2(context),
        appBar: AppBar(
          title: const Text('Pending Approvals', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: appBarGradient),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: "Leaves"),
              Tab(text: "Timesheet"),
              Tab(text: "Reviews"), // New Tab for Reviews
            ],
            onTap: (index) {
              setState(() {
                _tabIndex = index;
              });
            },
          ),
          actions: [

            Container(
              margin: const EdgeInsets.only(top: 15, right: 15, bottom: 15),
              child: Image.asset("assets/image/ccfn_logo.png"),
            )
          ],
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8EEDD), Color(0xFFFAF0E6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: wineColor))
                  : TabBarView(
                physics: const NeverScrollableScrollPhysics(), // Disable swipe between tabs if needed
                children: [
                  // Leaves Tab - Existing Leave Tab Content
                  RefreshIndicator(
                    color: wineColor,
                    onRefresh: _fetchPendingApprovals,
                    child: pendingLeaves.isNotEmpty
                        ? ListView.builder(
                      padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24.0 : 16.0),
                      itemCount: pendingLeaves.length,
                      itemBuilder: (context, index) {
                        return _buildLeaveCard(context, pendingLeaves[index]);
                      },
                    )
                        : Center(
                      child: Text("No pending leave approvals", style: TextStyle(fontSize: constraints.maxWidth > 600 ? 20 : 18, color: Colors.black54)),
                    ),
                  ),
                  // Timesheet Tab - Existing Timesheet Tab Content
                  RefreshIndicator(
                    color: wineColor,
                    onRefresh: _fetchPendingApprovals,
                    child: (selectedBioStaffCategory == "Facility Supervisor" && pendingTimesheetsFacilitySupervisor.isNotEmpty) ||
                        ((selectedBioStaffCategory == "State Office Staff" || selectedBioStaffCategory == "HQ Staff") && pendingTimesheetsCaritasSupervisor.isNotEmpty)
                        ? ListView.builder(
                      padding: EdgeInsets.all(constraints.maxWidth > 600 ? 24.0 : 16.0),
                      itemCount: selectedBioStaffCategory == "Facility Supervisor"
                          ? pendingTimesheetsFacilitySupervisor.length
                          : pendingTimesheetsCaritasSupervisor.length,
                      itemBuilder: (context, index) {
                        final timesheetDoc = selectedBioStaffCategory == "Facility Supervisor"
                            ? pendingTimesheetsFacilitySupervisor[index]
                            : pendingTimesheetsCaritasSupervisor[index];
                        return _buildTimesheetCard(context, timesheetDoc);
                      },
                    )
                        : Center(
                      child: Text("No pending timesheet approvals", style: TextStyle(fontSize: constraints.maxWidth > 600 ? 20 : 18, color: Colors.black54)),
                    ),
                  ),
                  // Reviews Tab - New Review List Tab Content
                  _tabIndex == 2 ? _buildReviewListTab() : const Center(child: Text("Review Tab Content Loading...")), // Conditionally load Review Tab
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({required this.imagePath, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: kIsWeb // Conditional Image widget for FullScreenImage
              ? Image.network(imagePath,
              fit: BoxFit.cover) // Use Image.network for web
              : Image.file(File(imagePath),
              fit: BoxFit.cover), // Use Image.file for non-web
        ),
      ),
    );
  }
}

class FullScreenImageFromMemory extends StatelessWidget {
  final AspectRatio imageData; // Receive AspectRatio with Image.memory

  const FullScreenImageFromMemory({required this.imageData, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: imageData, // Display the Image.memory widget
        ),
      ),
    );
  }
}