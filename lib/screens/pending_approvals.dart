import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/drawer2.dart';
// Note: This import might be unnecessary if not used, but kept for context
import 'activity_monitoring/activity_monitoring_page.dart';


// ===================================================================
// MODELS (Copied for context, no changes made here)
// ===================================================================

class BioModel {
  String? firstName, lastName, department, state, designation, location, staffCategory, emailAddress, mobile, firebaseAuthId;
  BioModel({this.firstName, this.lastName, this.department, this.state, this.designation, this.location, this.staffCategory, this.emailAddress, this.mobile, this.firebaseAuthId});
  factory BioModel.fromJson(Map<String, dynamic> json) => BioModel(firstName: json['firstName'], lastName: json['lastName'], department: json['department'], state: json['state'], designation: json['designation'], location: json['location'], staffCategory: json['staffCategory'], emailAddress: json['emailAddress'], mobile: json['mobile'], firebaseAuthId: json['firebaseAuthId']);
}

// Note: Report and ReportEntry models are no longer used on this page
// but are kept here as they were part of the original file.
class ReportEntry {
  // ... (Model code remains the same)
}
class Report {
  // ... (Model code remains the same)
}


class PendingApprovalsPage extends StatefulWidget {
  const PendingApprovalsPage({super.key});

  @override
  _PendingApprovalsPageState createState() => _PendingApprovalsPageState();
}

// MODIFIED: Removed 'with SingleTickerProviderStateMixin' as it's no longer needed
class _PendingApprovalsPageState extends State<PendingApprovalsPage> {

  // MODIFIED: Main build method simplified to remove tabs
  @override
  Widget build(BuildContext context) {
    // REMOVED: DefaultTabController is no longer necessary
    return Scaffold(
      drawer: drawer2(context),
      appBar: AppBar(
        title: const Text('Pending Timesheets', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
        // REMOVED: The 'bottom' property containing the TabBar is gone
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
            // MODIFIED: No TabBarView, the Timesheet list is now the direct body
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: wineColor))
                : RefreshIndicator(
              color: wineColor,
              onRefresh: fetchPendingApprovals,
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
                  return buildTimesheetCard(context, timesheetDoc);
                },
              )
                  : const Center(
                child: Text("No pending timesheet approvals", style: TextStyle(fontSize: 18, color: Colors.black54)),
              ),
            ),
          );
        },
      ),
    );
  }

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

  // MODIFIED: State variables for leaves and reviews are removed
  List<Map<String, dynamic>> pendingTimesheets = [];
  List<Map<String, dynamic>> pendingTimesheetsFacilitySupervisor = [];
  List<Map<String, dynamic>> pendingTimesheetsCaritasSupervisor = [];

  bool isLoading = true;
  bool isApproveLoading = false;
  final TextEditingController _rejectReasonController = TextEditingController();

  // REMOVED: _tabIndex and FirestoreService instance are no longer needed

  // ===================================================================
  // MAIN DATA FETCHING METHODS
  // ===================================================================

  // MODIFIED: Simplified to fetch only timesheets
  Future<void> fetchPendingApprovals() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || bioData == null || bioData!.emailAddress == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final userEmailLower = bioData!.emailAddress!.toLowerCase();

      // Fetch pending timesheets and filter by supervisor email
      Query timesheetsQuery = FirebaseFirestore.instance
          .collectionGroup('Timesheet')
          .where('status', isEqualTo: 'Pending')
          .where('selectedSupervisorEmail', isEqualTo: userEmailLower);

      if (bioData?.state?.isNotEmpty == true) {
        timesheetsQuery = timesheetsQuery.where('state', isEqualTo: bioData!.state);
      }

      final timesheetsSnapshot = await timesheetsQuery.get();
      final timesheetsData = timesheetsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Separate timesheets based on staff category
      final facilitySupervisorTimesheets = <Map<String, dynamic>>[];
      final caritasSupervisorTimesheets = <Map<String, dynamic>>[];

      for (var timesheet in timesheetsData) {
        if (timesheet['staffId'] != null) {
          final staffDoc = await FirebaseFirestore.instance.collection('Staff').doc(timesheet['staffId']).get();

          if (staffDoc.exists) {
            final staffData = staffDoc.data() as Map<String, dynamic>;
            final staffCategory = staffData['staffCategory'] as String?;

            if (staffCategory == "Facility Supervisor") {
              facilitySupervisorTimesheets.add(timesheet);
            } else if (staffCategory == "State Office Staff" || staffCategory == "HQ Staff") {
              caritasSupervisorTimesheets.add(timesheet);
            }
          }
        }
      }

      setState(() {
        pendingTimesheets = timesheetsData;
        pendingTimesheetsFacilitySupervisor = facilitySupervisorTimesheets;
        pendingTimesheetsCaritasSupervisor = caritasSupervisorTimesheets;
      });

      print('Fetched Data:');
      print('- Pending Timesheets: ${pendingTimesheets.length}');

    } catch (e) {
      print("Error fetching pending approvals: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadBioDataFromFirebase() async {
    setState(() {
      isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userEmail = user.email!;
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('Staff')
            .where('emailAddress', isEqualTo: userEmail)
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
          }
        }
      }
    } catch (e) {
      print("Error loading bio data from Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ===================================================================
  // UI BUILD METHODS
  // ===================================================================

  // REMOVED: buildLeaveCard method is gone.

  Widget buildTimesheetCard(BuildContext context, Map<String, dynamic> timesheetData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timesheet for ${timesheetData['reportingPeriod'] ?? 'Unknown Period'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: wineColor),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Staff Name', '${timesheetData['staffFirstName'] ?? ''} ${timesheetData['staffLastName'] ?? ''}', 14, 14),
            _buildDetailRow('Total Hours', timesheetData['totalHours']?.toString() ?? 'N/A', 14, 14),
            _buildDetailRow('Status', timesheetData['status'] ?? 'N/A', 14, 14),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _approveTimesheet(timesheetData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showRejectDialog(timesheetData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // REMOVED: buildReviewListTab method is gone.

  // ===================================================================
  // ACTION METHODS
  // ===================================================================

  // REMOVED: _approveLeave method is gone.

  Future<void> _approveTimesheet(Map<String, dynamic> timesheetData) async {
    setState(() => isApproveLoading = true);
    try {
      await FirebaseFirestore.instance
          .collectionGroup('Timesheet')
          .where('id', isEqualTo: timesheetData['id'])
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'status': 'Approved'});
        }
      });

      await fetchPendingApprovals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timesheet approved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving timesheet: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isApproveLoading = false);
    }
  }

  // REMOVED: _approveReview method is gone.

  void _showRejectDialog(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter rejection reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _rejectReasonController.text.trim();
              if (reason.isNotEmpty) {
                _rejectItem(item, reason);
                _rejectReasonController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // MODIFIED: Simplified to only handle timesheets
  Future<void> _rejectItem(dynamic item, String reason) async {
    setState(() => isApproveLoading = true);
    try {
      if (item is Map<String, dynamic>) {
        String collectionName = 'Timesheet';
        String docId = item['id'];
        Map<String, dynamic> updateData = {'status': 'Rejected', 'rejectionReason': reason};

        await FirebaseFirestore.instance
            .collectionGroup(collectionName)
            .where('id', isEqualTo: docId)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update(updateData);
          }
        });
      }

      await fetchPendingApprovals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item rejected successfully'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting item: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isApproveLoading = false);
    }
  }

  // ===================================================================
  // HELPER METHODS
  // ===================================================================

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

  static const Color wineColor = Color(0xFF722F37);
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // Other gradients can remain if used elsewhere

  @override
  void initState() {
    super.initState();
    _loadBioDataFromFirebase().then((_) {
      fetchPendingApprovals();
    });
  }

  // REMOVED: _loadBioDataFromFirebase1 was a duplicate and is removed.

  // Kept as it might be used by buildTimesheetCard if data format requires it
  String _formatTimesheetPeriod(String rawPeriod) {
    if (!rawPeriod.contains('_')) return rawPeriod;
    String formatted = rawPeriod.replaceAll('_', ' ');
    if (formatted.contains('part')) {
      formatted = formatted.replaceFirst('p', 'P');
      formatted = formatted.replaceFirstMapped(
          RegExp(r'(Part \d+)'), (match) => '(${match.group(1)})');
    }
    return formatted;
  }
}