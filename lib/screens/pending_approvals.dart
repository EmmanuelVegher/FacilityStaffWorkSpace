import 'dart:developer';

import 'package:attendanceappmailtool/screens/staff_timesheet.dart';
import 'package:attendanceappmailtool/screens/timesheet/approval_timesheetpage.dart';
import 'package:attendanceappmailtool/screens/timesheet/pending_timesheet_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/drawer.dart';
import '../widgets/drawer2.dart';

// Bio Model (Assuming this is your BioModel class definition)
class BioModel {
  String? firstName;
  String? lastName;
  String? department;
  String? state;
  String? designation;
  String? location;
  String? staffCategory;
  String? emailAddress;
  String? mobile;
  String? firebaseAuthId;

  BioModel({
    this.firstName,
    this.lastName,
    this.department,
    this.state,
    this.designation,
    this.location,
    this.staffCategory,
    this.emailAddress,
    this.mobile,
    this.firebaseAuthId,
  });

  // Add factory constructor to create BioModel from JSON if needed
  factory BioModel.fromJson(Map<String, dynamic> json) {
    return BioModel(
      firstName: json['firstName'],
      lastName: json['lastName'],
      department: json['department'],
      state: json['state'],
      designation: json['designation'],
      location: json['location'],
      staffCategory: json['staffCategory'],
      emailAddress: json['emailAddress'],
      mobile: json['mobile'],
      firebaseAuthId: json['firebaseAuthId'],
    );
  }
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
  bool isLoading = true;
  final TextEditingController _rejectReasonController = TextEditingController();

  // Define wine color and gradients
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

  Future<void> _loadBioDataFromFirebase() async {
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


  Future<void> _fetchPendingApprovals() async {
    print("_fetchPendingApprovals");
    setState(() {
      isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || bioData == null) {
        print("User not logged in or bio data not loaded.");
        setState(() {
          isLoading = false;
        });
        return;
      }

      final userEmail = bioData!.emailAddress;

      // Fetch pending leaves
      final leavesSnapshot = await FirebaseFirestore.instance
          .collectionGroup('Leave Request')
          .where('selectedSupervisorEmail', isEqualTo: userEmail)
          .where('status', isEqualTo: 'Pending')
          .get();

      // Fetch pending timesheets for Caritas Supervisor
      final caritasSupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('caritasSupervisorEmail', isEqualTo: userEmail)
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved')
          .get();

      // Fetch pending timesheets for Facility Supervisor
      final facilitySupervisorTimesheetsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('facilitySupervisorEmail', isEqualTo: userEmail)
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
          .get();


      setState(() {
        pendingLeaves = leavesSnapshot.docs.map((doc) => doc.data()).toList();
        pendingTimesheetsFacilitySupervisor = facilitySupervisorTimesheetsSnapshot.docs.map((doc) => doc.data()).toList();
        pendingTimesheetsCaritasSupervisor = caritasSupervisorTimesheetsSnapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching pending approvals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching pending approvals: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
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
          title: const Text("Reject Leave Request", style: TextStyle(color: wineColor, fontWeight: FontWeight.bold)),
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
                  label: const Text("Reject", style: TextStyle(color: Colors.white)),
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
                if (selectedBioStaffCategory == "State Office Staff" || selectedBioStaffCategory == "HQ Staff")
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
                ElevatedButton.icon(
                  label: const Text("Approve Timesheet", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.forward, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    backgroundColor: wineColor,
                  ),
                  onPressed: () {
                    log("doc['staffId'] ==${doc['staffId']}");
                    log("doc['staffId'] ==${doc}");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TimesheetDetailsScreen2(
                          timesheetData: doc,
                          staffId: doc['staffId'],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
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


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: drawer2(context), // No IsarService needed now
        appBar: AppBar(
          title: const Text('Pending Approvals', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white), // Makes the drawer icon white
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: appBarGradient),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Leaves"),
              Tab(text: "Timesheet"),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Container(
              decoration: const BoxDecoration( // Optional background gradient for the body
                gradient: LinearGradient(
                  colors: [Color(0xFFF8EEDD), Color(0xFFFAF0E6)], // Very light background
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: wineColor))
                  : TabBarView(
                children: [
                  // Leaves Tab
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
                  // Timesheet Tab
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}