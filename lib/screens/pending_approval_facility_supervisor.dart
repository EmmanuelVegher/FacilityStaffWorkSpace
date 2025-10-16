import 'package:service_delivery_workspace/screens/timesheet/pending_timesheet_facility_supervisor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/drawer4.dart';

// ===================================================================
// MODELS (You can keep these in a separate file if you prefer)
// ===================================================================

class BioModel {
  String? firstName, lastName, department, state, designation, location, staffCategory, emailAddress, mobile, firebaseAuthId;
  BioModel({this.firstName, this.lastName, this.department, this.state, this.designation, this.location, this.staffCategory, this.emailAddress, this.mobile, this.firebaseAuthId});
  factory BioModel.fromJson(Map<String, dynamic> json) => BioModel(firstName: json['firstName'], lastName: json['lastName'], department: json['department'], state: json['state'], designation: json['designation'], location: json['location'], staffCategory: json['staffCategory'], emailAddress: json['emailAddress'], mobile: json['mobile'], firebaseAuthId: json['firebaseAuthId']);
}

// ===================================================================
// MAIN PAGE WIDGET
// ===================================================================

class PendingFacilitySupervisorApprovalsPage extends StatefulWidget {
  const PendingFacilitySupervisorApprovalsPage({super.key});

  @override
  _PendingFacilitySupervisorApprovalsPageState createState() => _PendingFacilitySupervisorApprovalsPageState();
}

class _PendingFacilitySupervisorApprovalsPageState extends State<PendingFacilitySupervisorApprovalsPage> {
  BioModel? bioData;
  List<Map<String, dynamic>> pendingTimesheets = [];
  bool isLoading = true;
  bool isNavigating = false;

  // Define wine color and gradients
  static const Color wineColor = Color(0xFF722F37);
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient pageBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF8EEDD), Color(0xFFFAF0E6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadBioDataFromFirebase();
    if (mounted && bioData != null) {
      await _fetchPendingTimesheets();
    }
  }

  Future<void> _loadBioDataFromFirebase() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Query by the unique Firebase Auth ID (UID) for reliability
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('Staff')
            .where('id', isEqualTo: user.uid)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var staffData = staffQuery.docs.first.data() as Map<String, dynamic>?;
          if (staffData != null) {
            if (mounted) {
              setState(() {
                bioData = BioModel.fromJson(staffData);
              });
            }
          }
        } else {
          debugPrint("No staff document found for auth UID: ${user.uid}");
        }
      }
    } catch (e) {
      debugPrint("Error loading bio data from Firebase: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPendingTimesheets() async {
    setState(() => isLoading = true);
    if (bioData == null || bioData!.emailAddress == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final userEmailLower = bioData!.emailAddress!.toLowerCase();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allPendingDocs = [];

      // Fetch timesheets pending Facility Supervisor approval
      final facilitySupervisorSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Pending')
          .get();

      allPendingDocs.addAll(facilitySupervisorSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['facilitySupervisorEmail'] as String?;
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }));

      // Fetch timesheets pending CARITAS Supervisor approval
      final caritasSupervisorSnapshot = await FirebaseFirestore.instance
          .collectionGroup('TimeSheets')
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Pending')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved') // Important condition
          .get();

      allPendingDocs.addAll(caritasSupervisorSnapshot.docs.where((doc) {
        final supervisorEmail = doc.data()['caritasSupervisorEmail'] as String?;
        return supervisorEmail?.toLowerCase() == userEmailLower;
      }));

      if (mounted) {
        setState(() {
          // --- THIS IS THE UPDATED PART ---
          pendingTimesheets = allPendingDocs.map((doc) {
            final data = doc.data();
            // Manually add the document ID to the map under the key 'docId'
            data['docId'] = doc.id;
            return data;
          }).toList();
          // --- END OF UPDATE ---
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending timesheets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error fetching timesheets: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ADD THIS HELPER METHOD
  String _formatTimesheetPeriod(String rawPeriod) {
    if (!rawPeriod.contains('_')) return rawPeriod; // Return as-is if not in the expected format

    // Replace underscores with spaces
    String formatted = rawPeriod.replaceAll('_', ' ');

    // Capitalize "part" and wrap in parentheses
    if (formatted.contains('part')) {
      formatted = formatted.replaceFirst('p', 'P'); // Capitalize 'P'
      formatted = formatted.replaceFirstMapped(
          RegExp(r'(Part \d+)'), (match) => '(${match.group(1)})');
    }
    return formatted;
  }

  void _navigateToTimesheetDetails(Map<String, dynamic> doc) async {
    setState(() => isNavigating = true);
    // Navigate to the details screen where the supervisor can approve/reject.
    // The `then` block will execute when returning from the details screen.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimesheetDetailsScreen3(
          timesheetData: doc,
          staffId: doc['staffId'],
        ),
      ),
    ).then((_) {
      // After returning, refresh the list to reflect any changes.
      _fetchPendingTimesheets();
    });

    if (mounted) {
      setState(() => isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer4(context),
      appBar: AppBar(
        title: const Text('Pending Timesheet Approvals', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(12),
            child: Image.asset("assets/image/ccfn_logo.png"),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: pageBackgroundGradient),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: wineColor))
            : RefreshIndicator(
          onRefresh: _fetchPendingTimesheets,
          color: wineColor,
          child: pendingTimesheets.isNotEmpty
              ? _buildTimesheetList()
              : _buildEmptyState(),
        ),
      ),
    );
  }

  Widget _buildTimesheetList() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return ListView.builder(
            padding: EdgeInsets.all(constraints.maxWidth > 600 ? 16.0 : 8.0),
            itemCount: pendingTimesheets.length,
            itemBuilder: (context, index) {
              return _buildTimesheetCard(context, pendingTimesheets[index], constraints);
            },
          );
        }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: wineColor.withOpacity(0.7)),
          const SizedBox(height: 16),
          const Text(
            "No Pending Timesheets",
            style: TextStyle(fontSize: 22, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            "You are all caught up!",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: wineColor,
            ),
            onPressed: _fetchPendingTimesheets,
          )
        ],
      ),
    );
  }

  Widget _buildTimesheetCard(BuildContext context, Map<String, dynamic> doc, BoxConstraints constraints) {
    bool isWideScreen = constraints.maxWidth > 600;

    // Safely get data with fallback values
    final staffName = doc['staffName'] ?? 'N/A';
    final location = doc['location'] ?? 'N/A';

    // --- THIS IS THE UPDATED LINE ---
    // Use the 'docId' we just added. Fallback to 'month' if it exists, otherwise 'N/A'.
    final timesheetPeriod = _formatTimesheetPeriod(doc['docId'] ?? doc['month'] ?? 'N/A');
    // --- END OF UPDATE ---

    final staffDesignation = doc['designation'] ?? 'N/A';
    final state = doc['state'] ?? 'N/A';
    final department = doc['department'] ?? 'N/A';


    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(
          vertical: 8, horizontal: isWideScreen ? constraints.maxWidth * 0.15 : 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staffName,
              style: TextStyle(
                fontSize: isWideScreen ? 22.0 : 20.0,
                fontWeight: FontWeight.bold,
                color: wineColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Timesheet for: $timesheetPeriod",
              style: TextStyle(
                fontSize: isWideScreen ? 16.0 : 14.0,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow("Designation", staffDesignation, isWideScreen),
            _buildDetailRow("Department", department, isWideScreen),
            _buildDetailRow("Location", location, isWideScreen),
            _buildDetailRow("State", state, isWideScreen),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                label: Text("Review & Approve", style: TextStyle(fontSize: isWideScreen ? 16 : 14)),
                icon: isNavigating
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  foregroundColor: Colors.white,
                  backgroundColor: wineColor,
                ),
                onPressed: isNavigating ? null : () => _navigateToTimesheetDetails(doc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, bool isWide) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: isWide ? 16.0 : 14.0,
            color: Colors.black87,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}