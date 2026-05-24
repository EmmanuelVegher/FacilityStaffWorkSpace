// A ROBUST PAGE FOR REVIEWING STAFF TIMESHEETS STATE-WIDE (FINAL ADVANCED VERSION)

import 'dart:convert';

import 'package:flutter/material.dart';
// For TextSpan ambiguity
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../../widgets/global_multi_select_dropdown.dart';
import '../../widgets/drawer2.dart'; // State-level drawer
import '../admin/payment_schedule_page.dart';
import 'hq_timesheet_review_page.dart'; // NEW: Import for the payment schedule page
import 'hq_timesheet_review_page.dart' as hq; // NEW: Import for the payment schedule page

// // --- DATA MODELS (Adapted from HQ Version) ---
// class TimesheetEntry {
//   final String date;
//   final String durationWorked;
//   final num noOfHours;
//   final bool isOffDay;
//   final String projectName;
//
//   TimesheetEntry({
//     required this.date,
//     required this.durationWorked,
//     required this.noOfHours,
//     required this.isOffDay,
//     required this.projectName,
//   });
//
//   factory TimesheetEntry.fromMap(Map<String, dynamic> map) {
//     return TimesheetEntry(
//       date: map['date'] as String? ?? 'N/A',
//       durationWorked: map['durationWorked'] as String? ?? 'N/A',
//       noOfHours: map['noOfHours'] as num? ?? 0,
//       isOffDay: map['offDay'] as bool? ?? false,
//       projectName: map['projectName'] as String? ?? 'N/A',
//     );
//   }
// }
//
// // MODIFIED: Replaced with the more robust model from HQ, using DateTime for timestamps.
// class TimesheetModel {
//   final String staffId;
//   final String staffName;
//   final String staffEmail;
//   final String designation;
//   final String department;
//   final String location;
//   final String state;
//   final String? staffSignature;
//   final String? staffSignatureDate;
//   final DateTime? staffSignatureDateTime; // MODIFIED
//   final String? projectName;
//   final String facilitySupervisor;
//   final String? facilitySupervisorEmail;
//   final String facilitySupervisorSignatureStatus;
//   final String? facilitySupervisorSignature;
//   final String? facilitySupervisorSignatureDate;
//   final DateTime? facilitySupervisorTimesheetSubmissionDateTime; // MODIFIED
//   final String caritasSupervisor;
//   final String? caritasSupervisorEmail;
//   final String caritasSupervisorSignatureStatus;
//   final String? caritasSupervisorSignature;
//   final String? caritasSupervisorSignatureDate;
//   final DateTime? caritasSupervisorTimesheetSubmissionDateTime; // MODIFIED
//   final List<TimesheetEntry> entries;
//   final double totalHours;
//
//   TimesheetModel({
//     required this.staffId,
//     required this.staffName,
//     required this.staffEmail,
//     required this.designation,
//     required this.department,
//     required this.location,
//     required this.state,
//     this.staffSignature,
//     this.staffSignatureDate,
//     this.staffSignatureDateTime,
//     this.projectName,
//     required this.facilitySupervisor,
//     this.facilitySupervisorEmail,
//     required this.facilitySupervisorSignatureStatus,
//     this.facilitySupervisorSignature,
//     this.facilitySupervisorSignatureDate,
//     this.facilitySupervisorTimesheetSubmissionDateTime,
//     required this.caritasSupervisor,
//     this.caritasSupervisorEmail,
//     required this.caritasSupervisorSignatureStatus,
//     this.caritasSupervisorSignature,
//     this.caritasSupervisorSignatureDate,
//     this.caritasSupervisorTimesheetSubmissionDateTime,
//     required this.entries,
//   }) : totalHours = _calculateCappedTotalHours(entries);
//
//   static double _calculateCappedTotalHours(List<TimesheetEntry> entries) {
//     if (entries.isEmpty) return 0.0;
//     final Map<String, double> dailyHours = {};
//     for (final entry in entries) {
//       dailyHours.update(
//         entry.date,
//             (value) => value + entry.noOfHours.toDouble(),
//         ifAbsent: () => entry.noOfHours.toDouble(),
//       );
//     }
//     double cappedTotal = 0.0;
//     for (final hours in dailyHours.values) {
//       cappedTotal += (hours > 8.0) ? 8.0 : hours;
//     }
//     return cappedTotal;
//   }
//
//   // ADDED: Robust helper to parse Firestore Timestamps OR date Strings
//   static DateTime? _parseTimestamp(dynamic value) {
//     if (value is Timestamp) {
//       return value.toDate();
//     }
//     if (value is String) {
//       return DateTime.tryParse(value);
//     }
//     return null;
//   }
//
//   factory TimesheetModel.fromMap(Map<String, dynamic> map, String id) {
//     var entriesData = (map['timesheetEntries'] as List<dynamic>?)
//         ?.map((e) => TimesheetEntry.fromMap(e as Map<String, dynamic>))
//         .toList() ?? [];
//
//     return TimesheetModel(
//       staffId: map['staffId'] as String? ?? id,
//       staffName: map['staffName'] as String? ?? 'N/A',
//       staffEmail: map['staffEmail'] as String? ?? 'N/A',
//       designation: map['designation'] as String? ?? 'N/A',
//       department: map['department'] as String? ?? 'N/A',
//       location: map['location'] as String? ?? 'N/A',
//       state: map['state'] as String? ?? 'N/A',
//       staffSignature: map['staffSignature'] as String?,
//       staffSignatureDate: map['staffSignatureDate'] as String?,
//       staffSignatureDateTime: _parseTimestamp(map['staffSignatureTimestamp']), // MODIFIED
//       projectName: map['projectName'] as String?,
//       facilitySupervisor: map['facilitySupervisor'] as String? ?? 'N/A',
//       facilitySupervisorEmail: map['facilitySupervisorEmail'] as String?,
//       facilitySupervisorSignatureStatus: map['facilitySupervisorSignatureStatus'] as String? ?? 'Pending',
//       facilitySupervisorSignature: map['facilitySupervisorSignature'] as String?,
//       facilitySupervisorSignatureDate: map['facilitySupervisorSignatureDate'] as String?,
//       facilitySupervisorTimesheetSubmissionDateTime: _parseTimestamp(map['facilitySupervisorTimesheetSubmissionTimestamp']), // MODIFIED
//       caritasSupervisor: map['caritasSupervisor'] as String? ?? 'N/A',
//       caritasSupervisorEmail: map['caritasSupervisorEmail'] as String?,
//       caritasSupervisorSignatureStatus: map['caritasSupervisorSignatureStatus'] as String? ?? 'Pending',
//       caritasSupervisorSignature: map['caritasSupervisorSignature'] as String?,
//       caritasSupervisorSignatureDate: map['caritasSupervisorSignatureDate'] as String?,
//       caritasSupervisorTimesheetSubmissionDateTime: _parseTimestamp(map['caritasSupervisorTimesheetSubmissionTimestamp']), // MODIFIED
//       entries: entriesData,
//     );
//   }
// }

class TimesheetMetrics {
  int totalExpected = 0;
  int totalSubmitted = 0;
  int yetToSubmit = 0;
  int pendingFacilityApproval = 0;
  int pendingCaritasApproval = 0;
  int fullyApproved = 0;
  double totalHoursLogged = 0;
  double percentFullyApproved = 0.0;
}

class FacilityMetrics {
  int totalExpected = 0;
  int totalSubmitted = 0;
  int yetToSubmit = 0;
  int approvedByFacility = 0;
  int approvedByCaritas = 0;

  int get pendingFacility => totalSubmitted - approvedByFacility;
  int get pendingCaritas => totalSubmitted - approvedByCaritas;
}

// --- MAIN WIDGET ---
class TimesheetReviewPage extends StatefulWidget {
  const TimesheetReviewPage({super.key});

  @override
  _TimesheetReviewPageState createState() => _TimesheetReviewPageState();
}

class _TimesheetReviewPageState extends State<TimesheetReviewPage> with SingleTickerProviderStateMixin  {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // --- NEW State Variables for September Tabs ---
  TabController? _tabController;
  int _selectedSeptemberPart = 1; // Default to Part 1


  // --- State Variables ---
  bool _isFilterLoading = true;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _canSeePaymentButton = false;
  String? _errorMessage;

  // Filter & User Context
  String? _userState;
  late int _selectedYear;
  late int _selectedMonth;
  List<String> _availableFacilities = [];
  List<String> _selectedFacilities = [];
  List<String> _selectedStaffIds = [];

  String _selectedStatusFilter = 'All Submitted';
  final List<String> _statusFilters = [
    'All Submitted',
    'Yet to Submit',
    'Awaiting Facility Approval',
    'Awaiting Caritas Approval'
  ];

  // Data Stores
  List<Map<String, dynamic>> _allExpectedStaffMaster = [];
  List<TimesheetModel> _allTimesheetsMaster = [];
  List<Map<String, dynamic>> _nonSubmittedStaff = [];
  List<dynamic> _displayedItems = [];
  TimesheetMetrics _metrics = TimesheetMetrics();
  Map<String, FacilityMetrics> _facilitySummary = {};

  final ScrollController _summaryTableScrollController = ScrollController();
  bool _isSummaryExpanded = false;
  bool _isNonSubmittedExpanded = false;
  bool _isSubmittedExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    // Set up the controller based on the initial month
    _updateTabControllerState();

    _initializeUserContext();
  }

  @override
  void dispose() {
    // Always clean up the controller when the page is destroyed.
    _tabController?.dispose();
    _summaryTableScrollController.dispose();
    super.dispose();
  }

  // NEW HELPER METHOD: The single source of truth for managing the TabController
  void _updateTabControllerState() {
    final bool isSeptember = (_selectedMonth == 9);

    if (isSeptember) {
      // If it's September and the controller doesn't exist yet, create it.
      _tabController ??= TabController(length: 2, vsync: this, initialIndex: _selectedSeptemberPart - 1);
    } else {
      // If it's NOT September but the controller still exists, destroy it.
      if (_tabController != null) {
        // We don't need to call dispose() here because the logic in onChanged will handle it.
        // But we must set it to null so the UI rebuilds correctly.
        _tabController?.dispose(); // It's safer to dispose it here.
        _tabController = null;
        _selectedSeptemberPart = 1; // Reset to part 1 for the next time
      }
    }
  }

  // // NEW: Creates or disposes the TabController based on the selected month.
  // void _updateTabController() {
  //   // If the selected month is September and the controller doesn't exist yet
  //   if (_selectedMonth == 9 && _tabController == null) {
  //     _tabController = TabController(length: 2, vsync: this, initialIndex: _selectedSeptemberPart - 1);
  //     _tabController!.addListener(_onTabChanged);
  //     // We call setState to ensure the UI rebuilds and shows the TabBar
  //     setState(() {});
  //   }
  //   // If the month is not September but the controller still exists
  //   else if (_selectedMonth != 9 && _tabController != null) {
  //     _tabController?.removeListener(_onTabChanged);
  //     _tabController?.dispose();
  //     _tabController = null;
  //     // Reset part selection when leaving September
  //     if (_selectedSeptemberPart != 1) {
  //       _selectedSeptemberPart = 1;
  //     }
  //     // We call setState to ensure the UI rebuilds and hides the TabBar
  //     setState(() {});
  //   }
  // }

  // NEW: Handles logic when a tab is tapped.
// NEW: Handles logic when a tab is tapped. (If you don't have this, add it)
//   void _onTabChanged() {
//     // Check if the tab index has actually changed to avoid redundant calls
//     if (_tabController != null && !_tabController!.indexIsChanging) {
//       final newPart = _tabController!.index + 1;
//       if (_selectedSeptemberPart != newPart) {
//         setState(() {
//           _selectedSeptemberPart = newPart;
//         });
//         _loadTimesheets(); // Reload data for the newly selected part
//       }
//     }
//   }

  // NEW: Handles tab selection via the onTap callback, which is safer.
// Handles tab selection via the onTap callback, which is safer.
  void _onTabTapped(int index) {
    // The index is 0 for Part 1, 1 for Part 2.
    final newPart = index + 1;
    if (_selectedSeptemberPart != newPart) {
      setState(() {
        _selectedSeptemberPart = newPart;
      });
      // Reload the data for the newly selected part
      _loadTimesheets();
    }
  }

  Future<void> _initializeUserContext() async {
    setState(() => _isFilterLoading = true);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final data = staffDoc.data();
      final userState = data?['state'] as String?;
      if (userState == null || userState.isEmpty) throw Exception("State not found for user.");

      // Compute access for Payment Schedule button:
      final dept = (data?['department'] as String? ?? '').trim().toLowerCase();
      final desig = (data?['designation'] as String? ?? '').trim().toLowerCase();
      final canSeePayment = dept == 'program management' &&
          (desig == 'senior program manager' || desig == 'program manager');

      _userState = userState;
      final facilityNames = await _getFacilitiesForState(userState);

      if (mounted) {
        setState(() {
          _availableFacilities = facilityNames;
          _selectedFacilities = [];
          _canSeePaymentButton = canSeePayment;
        });
        await _loadTimesheets();
      }
    } catch (e) {
      if(mounted) setState(() => _errorMessage = "Failed to load page context: $e");
    } finally {
      if(mounted) setState(() => _isFilterLoading = false);
    }
  }

  Future<List<String>> _getFacilitiesForState(String state) async {
    final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
    final facilityNames = snapshot.docs
        .map((doc) => doc.data()['LocationName'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toList();
    facilityNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return facilityNames;
  }

  // --- NEW: Method to navigate to the Payment Schedule Page ---
  void _navigateToPaymentSchedule() {
    final List<TimesheetModel> submittedTimesheets = _allTimesheetsMaster;

    if (submittedTimesheets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No submitted timesheets available to generate a payment schedule.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSchedulePage(
          timesheets: submittedTimesheets,
          year: _selectedYear,
          month: _selectedMonth,
        ),
      ),
    );
  }

// In _TimesheetReviewPageState

  Future<void> _loadTimesheets() async {
    if (_userState == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User state not found. Cannot load data.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allTimesheetsMaster = [];
      _nonSubmittedStaff = [];
      _displayedItems = [];
      _selectedStaffIds.clear();
      _facilitySummary.clear();
    });

    try {
      List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
          ? _availableFacilities.where((f) => f != 'All Facilities').toList()
          : _selectedFacilities;

      Query staffQuery = _firestore.collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .where('state', isEqualTo: _userState);

      if (facilitiesToQuery.isNotEmpty) {
        staffQuery = staffQuery.where('location', whereIn: facilitiesToQuery);
      }
      final staffSnapshot = await staffQuery.get();
      _allExpectedStaffMaster = staffSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['accountStatus'] == 'Active';
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'staffId': doc.id,
          'staffName': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim().isNotEmpty
              ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim()
              : 'N/A',
          'location': data['location'] ?? 'N/A',
          'state': data['state'] ?? 'N/A',
          'email': data['emailAddress'] ?? 'Not Available',
          'mobile': data['mobile'] ?? 'Not Available',
        };

      }).toList();

      Query timesheetQuery = _firestore.collectionGroup('TimeSheets').where('state', isEqualTo: _userState);

      if (facilitiesToQuery.isNotEmpty) {
        timesheetQuery = timesheetQuery.where('location', whereIn: facilitiesToQuery);
      }
      final timesheetSnapshot = await timesheetQuery.get();

      final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
      final bool isSeptember = _selectedMonth == 9;
      final String timesheetDocId = isSeptember
          ? '${monthName}_${_selectedYear}_part$_selectedSeptemberPart'
          : '${monthName}_$_selectedYear';

      final List<TimesheetModel> fetchedTimesheets = [];
      final Set<String> submittedStaffIds = {};

      for (final doc in timesheetSnapshot.docs) {
        if (doc.id == timesheetDocId) {
          // <<<--- FIX: Call the correct fromFirestore factory ---<<<
          final timesheet = TimesheetModel.fromFirestore(doc);
          fetchedTimesheets.add(timesheet);
          submittedStaffIds.add(timesheet.staffId);
        }
      }

      final List<Map<String, dynamic>> nonSubmitters = [];
      for (final staff in _allExpectedStaffMaster) {
        if (!submittedStaffIds.contains(staff['staffId'])) {
          nonSubmitters.add(staff);
        }
      }

      _allTimesheetsMaster = fetchedTimesheets..sort((a, b) => a.staffName.compareTo(b.staffName));
      _nonSubmittedStaff = nonSubmitters..sort((a, b) => (a['staffName'] as String).compareTo(b['staffName'] as String));

      _calculateFacilitySummary();
      _applyFiltersAndCalculateMetrics();

    } catch (e, stack) {
      debugPrint('Error loading timesheets: $e\n$stack');
      if (mounted) {
        _errorMessage = e is FirebaseException && e.code == 'failed-precondition'
            ? 'Firestore Index Required: Please check debug console.'
            : 'Failed to load timesheets: $e';
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<TimesheetModel?> _fetchTimesheetFromFirestore(String staffId, String timesheetDocId) async {
    try {
      final querySnapshot = await _firestore.collectionGroup('TimeSheets').where('staffId', isEqualTo: staffId).get();
      final docs = querySnapshot.docs.where((doc) => doc.id == timesheetDocId).toList();
      if (docs.isNotEmpty) {
        final doc = docs.first;
        // <<<--- FIX: Call the correct fromFirestore factory ---<<<
        return TimesheetModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching single timesheet for PDF: $e");
      return null;
    }
  }

  void _applyFiltersAndCalculateMetrics() {
    List<dynamic> filteredList;

    switch (_selectedStatusFilter) {
      case 'Yet to Submit':
        filteredList = _nonSubmittedStaff;
        break;
      case 'Awaiting Facility Approval':
        filteredList = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus != 'Approved').toList();
        break;
      case 'Awaiting Caritas Approval':
        filteredList = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus != 'Approved').toList();
        break;
      case 'All Submitted':
      default:
        filteredList = _allTimesheetsMaster;
        break;
    }

    if (_selectedStaffIds.isNotEmpty) {
      final selectionSet = _selectedStaffIds.toSet();
      filteredList = filteredList.where((item) {
        if (item is TimesheetModel) return selectionSet.contains(item.staffId);
        if (item is Map) return selectionSet.contains(item['staffId']);
        return false;
      }).toList();
    }

    final newMetrics = TimesheetMetrics();
    newMetrics.totalExpected = _allTimesheetsMaster.length + _nonSubmittedStaff.length;
    newMetrics.totalSubmitted = _allTimesheetsMaster.length;
    newMetrics.yetToSubmit = _nonSubmittedStaff.length;
    newMetrics.fullyApproved = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus == 'Approved').length;
    newMetrics.pendingCaritasApproval = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus == 'Approved' && ts.caritasSupervisorSignatureStatus != 'Approved').length;
    newMetrics.pendingFacilityApproval = _allTimesheetsMaster.where((ts) => ts.facilitySupervisorSignatureStatus != 'Approved').length;
    newMetrics.totalHoursLogged = _allTimesheetsMaster.fold(0.0, (sum, item) => sum + item.totalHours);

    if (newMetrics.totalExpected > 0) {
      newMetrics.percentFullyApproved = (newMetrics.fullyApproved / newMetrics.totalExpected) * 100;
    }

    setState(() {
      _displayedItems = filteredList;
      _metrics = newMetrics;
    });
  }

  void _calculateFacilitySummary() {
    final summary = <String, FacilityMetrics>{};
    for (final ts in _allTimesheetsMaster) {
      final facility = ts.location;
      summary.putIfAbsent(facility, () => FacilityMetrics());
      final metrics = summary[facility]!;
      metrics.totalExpected++;
      metrics.totalSubmitted++;
      if (ts.facilitySupervisorSignatureStatus == 'Approved') metrics.approvedByFacility++;
      if (ts.caritasSupervisorSignatureStatus == 'Approved') metrics.approvedByCaritas++;
    }
    for (final staff in _nonSubmittedStaff) {
      final facility = staff['location'] as String? ?? 'Unknown Facility';
      summary.putIfAbsent(facility, () => FacilityMetrics());
      final metrics = summary[facility]!;
      metrics.totalExpected++;
      metrics.yetToSubmit++;
    }
    setState(() {
      _facilitySummary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$_userState Timesheet Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5C1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'bulk_pdf') _downloadBulkPdf();
                if(value == 'summary_csv') _downloadSummaryAsCsv();
                if(value == 'summary_excel') _downloadSummaryAsExcel();
                if(value == 'missing_staff_excel') _downloadMissingStaffAsExcel();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'bulk_pdf',
                    enabled: !_isLoading && _allTimesheetsMaster.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.picture_as_pdf), title: Text("Download Details (PDF)"))
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'summary_csv',
                    enabled: !_isLoading && _facilitySummary.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.description), title: Text("Download Summary (CSV)"))
                ),
                PopupMenuItem(
                    value: 'summary_excel',
                    enabled: !_isLoading && _facilitySummary.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.table_chart), title: Text("Download Summary (Excel)"))
                ),
                PopupMenuItem(
                    value: 'missing_staff_excel',
                    enabled: !_isLoading && _nonSubmittedStaff.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.person_off), title: Text("Download Missing Staff (Excel)"))
                ),
              ],
            )
        ],
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
        SelectionArea(child: _buildResponsiveFilterBar()),
          // This condition will now work correctly
          // This condition will now work perfectly every time.
          // This is the complete and corrected block
          if (_tabController != null)
            Container(
              color: Theme.of(context).canvasColor,
              child: TabBar(
                controller: _tabController,
                onTap: _onTabTapped, // Your handler for tab clicks
                labelColor: const Color(0xFF5C1A2E),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: const Color(0xFFD4A03C),
                // THIS IS THE REQUIRED 'tabs' PARAMETER THAT WAS MISSING
                tabs: [
                  Tab(child: Text('Part 1', style: GoogleFonts.poppins())),
                  Tab(child: Text('Part 2', style: GoogleFonts.poppins())),
                ],
              ),
            ),
          if (_errorMessage != null)
            Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))),
          Expanded(
            child: SelectionArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsDashboard(),
                    const SizedBox(height: 24),
                    if (_facilitySummary.isNotEmpty)
                      _buildFacilitySummaryTable(),
                    const SizedBox(height: 24),
                    if (_nonSubmittedStaff.isNotEmpty)
                      _buildNonSubmittedStaffList(),
                    const SizedBox(height: 24),
                    if (_allTimesheetsMaster.isNotEmpty)
                      _buildSubmittedStaffList(),
                    const SizedBox(height: 24),
                    if (_displayedItems.isNotEmpty) ...[
                      Text("Detailed View: $_selectedStatusFilter", style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge)),
                      const Divider(),
                      const SizedBox(height: 8),
                      ..._displayedItems.map((item) {
                        if (item is TimesheetModel) return _buildTimesheetCard(item);
                        if (item is Map) return _buildNonSubmittedCard(item as Map<String, dynamic>);
                        return const SizedBox.shrink();
                      }),
                    ] else if (!_isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text("No data found for the current filters.", style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MODIFIED: Fully responsive filter bar with adaptive layouts
  Widget _buildResponsiveFilterBar() {
    final years = List.generate(5, (index) => DateTime.now().year - index);
    final months = List.generate(12, (index) => index + 1);

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine layout based on screen width
            final bool isVerySmall = constraints.maxWidth < 600;
            final bool isSmall = constraints.maxWidth < 950;
            final bool isMedium = constraints.maxWidth < 1200;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter items section
                if (_isFilterLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Loading filters..."),
                    ),
                  )
                else if (isVerySmall)
                  // Very small screens: Stack vertically
                  Column(
                    children: [
                      GlobalMultiSelectDropdown<String>(
                        items: _availableFacilities,
                        selectedItems: _selectedFacilities,
                        title: "Select Facilities",
                        labelBuilder: (val) => val,
                        onChanged: (results) {
                          setState(() => _selectedFacilities = results);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedMonth,
                        decoration: InputDecoration(
                          labelText: 'Month',
                          border: const OutlineInputBorder(),
                          labelStyle: GoogleFonts.poppins(),
                        ),
                        items: months
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    DateFormat('MMMM').format(DateTime(0, m)),
                                    style: GoogleFonts.poppins(),
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedMonth = value;
                            _updateTabControllerState();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedYear,
                        decoration: InputDecoration(
                          labelText: 'Year',
                          border: const OutlineInputBorder(),
                          labelStyle: GoogleFonts.poppins(),
                        ),
                        items: years
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(y.toString(), style: GoogleFonts.poppins()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedYear = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatusFilter,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: const OutlineInputBorder(),
                          labelStyle: GoogleFonts.poppins(),
                        ),
                        items: _statusFilters
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: GoogleFonts.poppins()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedStatusFilter = value);
                            _applyFiltersAndCalculateMetrics();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      GlobalMultiSelectDropdown<String>(
                        items: _allTimesheetsMaster.map((ts) => ts.staffName).toSet().toList() +
                            _nonSubmittedStaff.map((s) => s['staffName'] as String).toSet().toList(),
                        selectedItems: _selectedStaffIds.map((id) {
                          final ts = _allTimesheetsMaster.firstWhere(
                            (element) => element.staffId == id,
                            orElse: () => TimesheetModel(
                              staffId: '',
                              staffName: 'N/A',
                              staffEmail: '',
                              designation: '',
                              department: '',
                              location: '',
                              state: '',
                              caritasSupervisor: '',
                              caritasSupervisorSignatureStatus: '',
                              facilitySupervisor: '',
                              facilitySupervisorSignatureStatus: '',
                              entries: [],
                            ),
                          );
                          if (ts.staffId != '') return ts.staffName;
                          final staff = _nonSubmittedStaff.firstWhere(
                            (element) => element['staffId'] == id,
                            orElse: () => {},
                          );
                          return staff['staffName'] as String? ?? 'N/A';
                        }).toList(),
                        title: "Select Staff",
                        labelBuilder: (val) => val,
                        onChanged: (results) {
                          setState(() {
                            _selectedStaffIds = results.map((name) {
                              final ts = _allTimesheetsMaster.firstWhere(
                                (element) => element.staffName == name,
                                orElse: () => TimesheetModel(
                                  staffId: '',
                                  staffName: 'N/A',
                                  staffEmail: '',
                                  designation: '',
                                  department: '',
                                  location: '',
                                  state: '',
                                  caritasSupervisor: '',
                                  caritasSupervisorSignatureStatus: '',
                                  facilitySupervisor: '',
                                  facilitySupervisorSignatureStatus: '',
                                  entries: [],
                                ),
                              );
                              if (ts.staffId != '') return ts.staffId;
                              final staff = _nonSubmittedStaff.firstWhere(
                                (element) => element['staffName'] == name,
                                orElse: () => {},
                              );
                              return staff['staffId'] as String? ?? '';
                            }).where((id) => id != '').toList();
                            _applyFiltersAndCalculateMetrics();
                          });
                        },
                      ),
                    ],
                  )
                else if (isSmall)
                  // Small screens: 2-column grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth - 36) / 2,
                        child: GlobalMultiSelectDropdown<String>(
                          items: _availableFacilities,
                          selectedItems: _selectedFacilities,
                          title: "Select Facilities",
                          labelBuilder: (val) => val,
                          onChanged: (results) {
                            setState(() => _selectedFacilities = results);
                          },
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 36) / 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: months
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMMM').format(DateTime(0, m)),
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedMonth = value;
                              _updateTabControllerState();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 36) / 2,
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: years
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y.toString(), style: GoogleFonts.poppins()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedYear = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 36) / 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatusFilter,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: _statusFilters
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: GoogleFonts.poppins()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedStatusFilter = value);
                              _applyFiltersAndCalculateMetrics();
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth - 24,
                        child: GlobalMultiSelectDropdown<String>(
                          items: _allTimesheetsMaster.map((ts) => ts.staffName).toSet().toList() +
                              _nonSubmittedStaff.map((s) => s['staffName'] as String).toSet().toList(),
                          selectedItems: _selectedStaffIds.map((id) {
                            final ts = _allTimesheetsMaster.firstWhere(
                              (element) => element.staffId == id,
                              orElse: () => TimesheetModel(
                                staffId: '',
                                staffName: 'N/A',
                                staffEmail: '',
                                designation: '',
                                department: '',
                                location: '',
                                state: '',
                                caritasSupervisor: '',
                                caritasSupervisorSignatureStatus: '',
                                facilitySupervisor: '',
                                facilitySupervisorSignatureStatus: '',
                                entries: [],
                              ),
                            );
                            if (ts.staffId != '') return ts.staffName;
                            final staff = _nonSubmittedStaff.firstWhere(
                              (element) => element['staffId'] == id,
                              orElse: () => {},
                            );
                            return staff['staffName'] as String? ?? 'N/A';
                          }).toList(),
                          title: "Select Staff",
                          labelBuilder: (val) => val,
                          onChanged: (results) {
                            setState(() {
                              _selectedStaffIds = results.map((name) {
                                final ts = _allTimesheetsMaster.firstWhere(
                                  (element) => element.staffName == name,
                                  orElse: () => TimesheetModel(
                                    staffId: '',
                                    staffName: 'N/A',
                                    staffEmail: '',
                                    designation: '',
                                    department: '',
                                    location: '',
                                    state: '',
                                    caritasSupervisor: '',
                                    caritasSupervisorSignatureStatus: '',
                                    facilitySupervisor: '',
                                    facilitySupervisorSignatureStatus: '',
                                    entries: [],
                                  ),
                                );
                                if (ts.staffId != '') return ts.staffId;
                                final staff = _nonSubmittedStaff.firstWhere(
                                  (element) => element['staffName'] == name,
                                  orElse: () => {},
                                );
                                return staff['staffId'] as String? ?? '';
                              }).where((id) => id != '').toList();
                              _applyFiltersAndCalculateMetrics();
                            });
                          },
                        ),
                      ),
                    ],
                  )
                else
                  // Large screens: Horizontal wrap layout
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMedium ? 180 : 220,
                          maxWidth: isMedium ? 220 : 280,
                        ),
                        child: GlobalMultiSelectDropdown<String>(
                          items: _availableFacilities,
                          selectedItems: _selectedFacilities,
                          title: "Select Facilities",
                          labelBuilder: (val) => val,
                          onChanged: (results) {
                            setState(() => _selectedFacilities = results);
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMedium ? 120 : 150,
                          maxWidth: isMedium ? 150 : 180,
                        ),
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: months
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      DateFormat('MMMM').format(DateTime(0, m)),
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedMonth = value;
                              _updateTabControllerState();
                            });
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMedium ? 100 : 120,
                          maxWidth: isMedium ? 120 : 140,
                        ),
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: years
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y.toString(), style: GoogleFonts.poppins()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedYear = value);
                            }
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMedium ? 200 : 250,
                          maxWidth: isMedium ? 250 : 300,
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatusFilter,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: const OutlineInputBorder(),
                            labelStyle: GoogleFonts.poppins(),
                          ),
                          items: _statusFilters
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: GoogleFonts.poppins()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedStatusFilter = value);
                              _applyFiltersAndCalculateMetrics();
                            }
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMedium ? 180 : 220,
                          maxWidth: isMedium ? 220 : 280,
                        ),
                        child: GlobalMultiSelectDropdown<String>(
                          items: _allTimesheetsMaster.map((ts) => ts.staffName).toSet().toList() +
                              _nonSubmittedStaff.map((s) => s['staffName'] as String).toSet().toList(),
                          selectedItems: _selectedStaffIds.map((id) {
                            final ts = _allTimesheetsMaster.firstWhere(
                              (element) => element.staffId == id,
                              orElse: () => TimesheetModel(
                                staffId: '',
                                staffName: 'N/A',
                                staffEmail: '',
                                designation: '',
                                department: '',
                                location: '',
                                state: '',
                                caritasSupervisor: '',
                                caritasSupervisorSignatureStatus: '',
                                facilitySupervisor: '',
                                facilitySupervisorSignatureStatus: '',
                                entries: [],
                              ),
                            );
                            if (ts.staffId != '') return ts.staffName;
                            final staff = _nonSubmittedStaff.firstWhere(
                              (element) => element['staffId'] == id,
                              orElse: () => {},
                            );
                            return staff['staffName'] as String? ?? 'N/A';
                          }).toList(),
                          title: "Select Staff",
                          labelBuilder: (val) => val,
                          onChanged: (results) {
                            setState(() {
                              _selectedStaffIds = results.map((name) {
                                final ts = _allTimesheetsMaster.firstWhere(
                                  (element) => element.staffName == name,
                                  orElse: () => TimesheetModel(
                                    staffId: '',
                                    staffName: 'N/A',
                                    staffEmail: '',
                                    designation: '',
                                    department: '',
                                    location: '',
                                    state: '',
                                    caritasSupervisor: '',
                                    caritasSupervisorSignatureStatus: '',
                                    facilitySupervisor: '',
                                    facilitySupervisorSignatureStatus: '',
                                    entries: [],
                                  ),
                                );
                                if (ts.staffId != '') return ts.staffId;
                                final staff = _nonSubmittedStaff.firstWhere(
                                  (element) => element['staffName'] == name,
                                  orElse: () => {},
                                );
                                return staff['staffId'] as String? ?? '';
                              }).where((id) => id != '').toList();
                              _applyFiltersAndCalculateMetrics();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                
                // Buttons section
                const SizedBox(height: 16),
                if (!_isFilterLoading)
                  if (isVerySmall)
                    // Very small screens: Stack buttons vertically
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Apply Filter'),
                          onPressed: _isLoading || _isFilterLoading ? null : _loadTimesheets,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            minimumSize: const Size(0, 50),
                          ),
                        ),
                        if (_canSeePaymentButton) const SizedBox(height: 12),
                        if (_canSeePaymentButton)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Payment Schedule'),
                            onPressed: _isLoading || _isFilterLoading ? null : _navigateToPaymentSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              minimumSize: const Size(0, 50),
                            ),
                          ),
                      ],
                    )
                  else
                    // Larger screens: Buttons side by side
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Apply Filter'),
                            onPressed: _isLoading || _isFilterLoading ? null : _loadTimesheets,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              minimumSize: const Size(0, 50),
                            ),
                          ),
                        ),
                        if (_canSeePaymentButton) const SizedBox(width: 16),
                        if (_canSeePaymentButton)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Payment Schedule'),
                              onPressed: _isLoading || _isFilterLoading ? null : _navigateToPaymentSchedule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                minimumSize: const Size(0, 50),
                              ),
                            ),
                          ),
                      ],
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Expected", _metrics.totalExpected.toString(), Icons.people_alt_rounded, Colors.indigo),
        _buildKpiCard("Submitted", _metrics.totalSubmitted.toString(), Icons.file_present_rounded, Colors.blueGrey),
        _buildKpiCard("Yet to Submit", _metrics.yetToSubmit.toString(), Icons.person_off, const Color(0xFFC62828)),
        _buildKpiCard("Awaiting Facility", _metrics.pendingFacilityApproval.toString(), Icons.hourglass_top_rounded, Colors.orange),
        _buildKpiCard("Awaiting CARITAS", _metrics.pendingCaritasApproval.toString(), Icons.hourglass_bottom_rounded, Colors.deepPurple),
        _buildKpiCard("Fully Approved", _metrics.fullyApproved.toString(), Icons.check_circle_rounded, Colors.green),
        _buildKpiCard("% Fully Approved", "${_metrics.percentFullyApproved.toStringAsFixed(1)}%", Icons.pie_chart, Colors.pink),
      ],
    );
  }

  Widget _buildFacilitySummaryTable() {
    final sortedFacilities = _facilitySummary.keys.toList()..sort();
    const double scrollAmount = 250.0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _isSummaryExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isSummaryExpanded = isExpanded),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Summary by Facility', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark))),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                final newOffset = _summaryTableScrollController.offset - scrollAmount;
                _summaryTableScrollController.animateTo(newOffset < 0 ? 0 : newOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              tooltip: 'Scroll Left',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                final maxScroll = _summaryTableScrollController.position.maxScrollExtent;
                final newOffset = _summaryTableScrollController.offset + scrollAmount;
                _summaryTableScrollController.animateTo(newOffset > maxScroll ? maxScroll : newOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              tooltip: 'Scroll Right',
            ),
          ],
        ),
        subtitle: Text(
          _isSummaryExpanded ? 'Detailed breakdown of timesheet submission and approval status.' : '(Tap to expand for a detailed breakdown)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children: [
          SingleChildScrollView(
            controller: _summaryTableScrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Facility')),
                DataColumn(label: Text('Expected'), numeric: true),
                DataColumn(label: Text('Submitted'), numeric: true),
                DataColumn(label: Text('Yet to Submit'), numeric: true),
                DataColumn(label: Text('Facility Approved'), numeric: true),
                DataColumn(label: Text('Facility Pending'), numeric: true),
                DataColumn(label: Text('CARITAS Approved'), numeric: true),
                DataColumn(label: Text('CARITAS Pending'), numeric: true),
              ],
              rows: sortedFacilities.map((facility) {
                final metrics = _facilitySummary[facility]!;
                return DataRow(cells: [
                  DataCell(Text(facility, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(metrics.totalExpected.toString())),
                  DataCell(Text(metrics.totalSubmitted.toString())),
                  DataCell(Text(metrics.yetToSubmit.toString())),
                  DataCell(Text(metrics.approvedByFacility.toString())),
                  DataCell(Text(metrics.pendingFacility.toString())),
                  DataCell(Text(metrics.approvedByCaritas.toString())),
                  DataCell(Text(metrics.pendingCaritas.toString())),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonSubmittedStaffList() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _isNonSubmittedExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isNonSubmittedExpanded = isExpanded),
        title: Text(
          'Staff Yet to Submit (${_nonSubmittedStaff.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
        ),
        subtitle: Text(
          _isNonSubmittedExpanded ? 'Contact details for staff with outstanding timesheets.' : '(Tap to see details)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        leading: Icon(Icons.person_off, color: Theme.of(context).colorScheme.error),
        children: ListTile.divideTiles(
          context: context,
          tiles: _nonSubmittedStaff.map((staff) {
            return ListTile(
              title: Text(staff['staffName'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Facility: ${staff['location']}'),
                  Text('Email: ${staff['email']}'),
                  Text('Mobile: ${staff['mobile']}'),
                ],
              ),
              isThreeLine: true,
            );
          }),
        ).toList(),
      ),
    );
  }

  Widget _buildSubmittedStaffList() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _isSubmittedExpanded,
        onExpansionChanged: (isExpanded) => setState(() => _isSubmittedExpanded = isExpanded),
        title: Text(
          'Staff Who Have Submitted (${_allTimesheetsMaster.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
        ),
        subtitle: Text(
          _isSubmittedExpanded ? 'List of staff with submitted timesheets and their status.' : '(Tap to see details)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        leading: Icon(Icons.check_circle_outline, color: Colors.green.shade800),
        children: ListTile.divideTiles(
          context: context,
          tiles: _allTimesheetsMaster.map((timesheet) {
            return ListTile(
              title: Text(timesheet.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Facility: ${timesheet.location}'),
              trailing: _buildStatusChip(
                  timesheet.facilitySupervisorSignatureStatus,
                  timesheet.caritasSupervisorSignatureStatus
              ),
            );
          }),
        ).toList(),
      ),
    );
  }

  List<List<dynamic>> _generateFacilitySummaryData() {
    final List<List<dynamic>> rows = [];
    const List<String> headers = [
      'Facility', 'Total Expected', 'Total Submitted', 'Yet to Submit',
      'Approved by Facility Supervisor', 'Pending Facility Supervisor',
      'Approved by CARITAS Staff', 'Pending CARITAS Staff'
    ];
    rows.add(headers);

    final sortedFacilities = _facilitySummary.keys.toList()..sort();
    for (var facility in sortedFacilities) {
      final metrics = _facilitySummary[facility]!;
      rows.add([
        facility,
        metrics.totalExpected,
        metrics.totalSubmitted,
        metrics.yetToSubmit,
        metrics.approvedByFacility,
        metrics.pendingFacility,
        metrics.approvedByCaritas,
        metrics.pendingCaritas,
      ]);
    }
    return rows;
  }

  List<List<dynamic>> _generateSubmittedSummaryData() {
    final List<List<dynamic>> rows = [];
    const List<String> headers = [
      'State', 'Name', 'Location', 'Phone Number', 'Email',
      'Submission Status', 'Facility Supervisor', 'Facility Supervisor Email',
      'CARITAS Supervisor', 'CARITAS Supervisor Email', 'Total Expected Hours',
      'No of Hours Worked', 'Percentage of Hours Worked (%)'
    ];
    rows.add(headers);

    final startDate = DateTime(_selectedYear, _selectedMonth - 1, 20);
    final endDate = DateTime(_selectedYear, _selectedMonth, 19);
    final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));
    final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
    final double totalExpectedHours = (workingDays * 8.0);

    final staffDetailsMap = { for (var staff in _allExpectedStaffMaster) staff['staffId']: staff };

    for (final timesheet in _allTimesheetsMaster) {
      final staffInfo = staffDetailsMap[timesheet.staffId];
      final phone = staffInfo?['mobile'] ?? 'N/A';
      final email = timesheet.staffEmail != 'N/A' ? timesheet.staffEmail : (staffInfo?['email'] ?? 'N/A');
      final workedHours = timesheet.totalHours;
      final percentage = totalExpectedHours > 0 ? (workedHours / totalExpectedHours * 100) : 0.0;

      String submissionStatus;
      if (timesheet.facilitySupervisorSignatureStatus != 'Approved') {
        submissionStatus = 'Awaiting Project Cordinators Signature';
      } else if (timesheet.caritasSupervisorSignatureStatus != 'Approved') {
        submissionStatus = 'Awaiting CARITAS Staff Signature';
      } else {
        submissionStatus = 'Fully Approved';
      }

      rows.add([
        timesheet.state,
        timesheet.staffName,
        timesheet.location,
        phone,
        email,
        submissionStatus,
        timesheet.facilitySupervisor,
        timesheet.facilitySupervisorEmail ?? 'N/A',
        timesheet.caritasSupervisor,
        timesheet.caritasSupervisorEmail ?? 'N/A',
        totalExpectedHours,
        workedHours,
        double.parse(percentage.toStringAsFixed(2)),
      ]);
    }
    return rows;
  }

  Future<void> _downloadSummaryAsCsv() async {
    setState(() => _isExporting = true);
    try {
      final List<List<dynamic>> rows = [];
      rows.add(['Summary by Facility']);
      rows.addAll(_generateFacilitySummaryData());
      rows.add([]);

      if (_allTimesheetsMaster.isNotEmpty) {
        rows.add(['Submitted Timesheet Summary']);
        rows.addAll(_generateSubmittedSummaryData());
        rows.add([]);
      }

      if (_nonSubmittedStaff.isNotEmpty) {
        rows.add(['Staff Who Have Not Submitted']);
        rows.add(['Staff Name', 'Facility', 'Email', 'Mobile']);
        for (final staff in _nonSubmittedStaff) {
          rows.add([
            staff['staffName'],
            staff['location'],
            staff['email'],
            staff['mobile'],
          ]);
        }
      }

      final String csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);
      _triggerDownload(Uint8List.fromList(bytes), 'Timesheet_Summary_${_userState}_${_selectedMonth}_$_selectedYear.csv');
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating CSV: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadSummaryAsExcel() async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();

      final Sheet facilitySummarySheet = excel['Summary by Facility'];
      final List<List<dynamic>> summaryRows = _generateFacilitySummaryData();
      for (var row in summaryRows) {
        facilitySummarySheet.appendRow(row.map((e) => e is num ? DoubleCellValue(e.toDouble()) : TextCellValue(e.toString())).toList());
      }

      if (_allTimesheetsMaster.isNotEmpty) {
        final Sheet submittedSheet = excel['Submitted Summary'];
        final submittedRows = _generateSubmittedSummaryData();
        for (var row in submittedRows) {
          submittedSheet.appendRow(row.map((e) {
            if (e is num) return DoubleCellValue(e.toDouble());
            return TextCellValue(e.toString());
          }).toList());
        }
      }

      if (_nonSubmittedStaff.isNotEmpty) {
        final Sheet nonSubmitterSheet = excel['Non-Submitters'];
        nonSubmitterSheet.appendRow([
          TextCellValue('Staff Name'),
          TextCellValue('Facility'),
          TextCellValue('Email'),
          TextCellValue('Mobile'),
        ]);
        for (final staff in _nonSubmittedStaff) {
          nonSubmitterSheet.appendRow([
            TextCellValue(staff['staffName'] ?? ''),
            TextCellValue(staff['location'] ?? ''),
            TextCellValue(staff['email'] ?? ''),
            TextCellValue(staff['mobile'] ?? ''),
          ]);
        }
      }

      final fileBytes = excel.save();
      if(fileBytes != null) {
        _triggerDownload(Uint8List.fromList(fileBytes), 'Timesheet_Summary_${_userState}_${_selectedMonth}_$_selectedYear.xlsx');
      }

    } catch(e, stack) {
      debugPrint("Error generating Excel: $e\n$stack");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating Excel: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadMissingStaffAsExcel() async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      
      final Sheet nonSubmitterSheet = excel['Missing Staff'];
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      nonSubmitterSheet.appendRow([
        TextCellValue('Staff Name'),
        TextCellValue('Facility'),
        TextCellValue('State'),
        TextCellValue('Phone Number'),
        TextCellValue('Email Address'),
      ]);
      
      for (final staff in _nonSubmittedStaff) {
        nonSubmitterSheet.appendRow([
          TextCellValue(staff['staffName'] ?? ''),
          TextCellValue(staff['location'] ?? ''),
          TextCellValue(staff['state'] ?? ''),
          TextCellValue(staff['mobile'] ?? ''),
          TextCellValue(staff['email'] ?? ''),
        ]);
      }

      final fileBytes = excel.save();
      if(fileBytes != null) {
        _triggerDownload(Uint8List.fromList(fileBytes), 'Missing_Timesheet_Staff_${_selectedMonth}_$_selectedYear.xlsx');
      }
    } catch (e, stack) {
      debugPrint("Error generating Missing Staff Excel: $e\n$stack");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export missing staff: $e')));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  // --- UI & EXPORT HELPER WIDGETS AND FUNCTIONS ---
  // (These are largely unchanged from the provided code, so they are included for completeness)

  void _triggerDownload(Uint8List data, String filename) {
    final blob = html.Blob([data]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Future<Uint8List?> _networkImageToByte(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') return null;
    try {
      final response = await Dio().get<List<int>>(imageUrl, options: Options(responseType: ResponseType.bytes));
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        return Uint8List.fromList(response.data!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching image for PDF: $e');
      return null;
    }
  }

  Widget _buildTimesheetCard(TimesheetModel timesheet) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timesheet.staffName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Text(timesheet.location, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            _buildStatusChip(timesheet.facilitySupervisorSignatureStatus, timesheet.caritasSupervisorSignatureStatus),
            const SizedBox(width: 8),
            Text("${timesheet.totalHours.toStringAsFixed(2)} hrs", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: "Download PDF",
              onPressed: () => _downloadSinglePdf(timesheet.staffId),
            )
          ],
        ),
        children: [_buildExpansionDetails(timesheet)],
      ),
    );
  }

  Widget _buildNonSubmittedCard(Map<String, dynamic> staffInfo) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.red.withOpacity(0.05),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828)),
        title: Text(staffInfo['staffName'] ?? 'N/A', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Text(staffInfo['location'] ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12)),
        trailing: Chip(
          label: Text('Not Submitted', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  void _showMultiSelectFacilityDialog() async {
    List<String> tempSelected = List.from(_selectedFacilities);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final facilitiesOnly = _availableFacilities.where((f) => f != 'All Facilities').toList();
            bool isAllSelected = tempSelected.contains('All Facilities') || tempSelected.length == facilitiesOnly.length;

            return AlertDialog(
              title: const Text('Select Facilities'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All Facilities', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelected.clear();
                          if (value == true) {
                            tempSelected.add('All Facilities');
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: facilitiesOnly.length,
                        itemBuilder: (context, index) {
                          final facility = facilitiesOnly[index];
                          return CheckboxListTile(
                            title: Text(facility),
                            value: tempSelected.contains(facility),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                tempSelected.remove('All Facilities');
                                if (value == true) {
                                  tempSelected.add(facility);
                                } else {
                                  tempSelected.remove(facility);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedFacilities = tempSelected.isEmpty ? ['All Facilities'] : tempSelected);
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMultiSelectFacilityDropdown() {
    String getButtonText() {
      final facilitiesOnlyCount = _availableFacilities.where((f) => f != 'All Facilities').length;
      if (_selectedFacilities.contains('All Facilities') || _selectedFacilities.length == facilitiesOnlyCount) {
        return 'All Facilities';
      }
      if (_selectedFacilities.length == 1) return _selectedFacilities.first;
      if (_selectedFacilities.isEmpty) return 'Select Facility';
      return '${_selectedFacilities.length} Facilities Selected';
    }

    return InkWell(
      onTap: _showMultiSelectFacilityDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Facility',
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(getButtonText(), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> get _staffListForFilter {
    final combinedList = [
      ..._allTimesheetsMaster.map((ts) => {'id': ts.staffId, 'name': ts.staffName}),
      ..._nonSubmittedStaff.map((s) => {'id': s['staffId'] as String, 'name': s['staffName'] as String})
    ];
    final uniqueStaff = {for (var staff in combinedList) staff['id']: staff['name']};
    final sortedList = uniqueStaff.entries
        .where((entry) => entry.key != null && entry.value != null)
        .map((entry) => {'id': entry.key!, 'name': entry.value!})
        .toList();
    sortedList.sort((a, b) => (a['name']!).compareTo(b['name']!));
    return sortedList;
  }

  Widget _buildMultiSelectStaffDropdown() {
    final staffList = _staffListForFilter;
    String getButtonText() {
      if (_selectedStaffIds.isEmpty) return 'All Staff';
      if (_selectedStaffIds.length == 1) {
        final staffMember = staffList.firstWhere((s) => s['id'] == _selectedStaffIds.first, orElse: () => {'name': 'N/A'});
        return staffMember['name']!;
      }
      return '${_selectedStaffIds.length} Staff Selected';
    }

    return InkWell(
      onTap: staffList.isEmpty ? null : () => _showMultiSelectStaffDialog(staffList),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Staff Member',
          border: const OutlineInputBorder(),
          filled: staffList.isEmpty,
          fillColor: Colors.grey.shade200,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(child: Text(getButtonText(), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectStaffDialog(List<Map<String, String>> staffList) async {
    List<String> tempSelectedIds = List.from(_selectedStaffIds);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected = tempSelectedIds.length == staffList.length;
            return AlertDialog(
              title: const Text('Select Staff'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelectedIds.clear();
                          if (value == true) {
                            tempSelectedIds.addAll(staffList.map((s) => s['id']!));
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: staffList.length,
                        itemBuilder: (context, index) {
                          final staff = staffList[index];
                          return CheckboxListTile(
                            title: Text(staff['name']!),
                            value: tempSelectedIds.contains(staff['id']),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelectedIds.add(staff['id']!);
                                } else {
                                  tempSelectedIds.remove(staff['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    if (tempSelectedIds.length == staffList.length) {
                      _selectedStaffIds.clear();
                    } else {
                      _selectedStaffIds = tempSelectedIds;
                    }
                    _applyFiltersAndCalculateMetrics();
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 240,
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(title, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String facilityStatus, String caritasStatus) {
    String text; Color color;
    if (facilityStatus == 'Approved' && caritasStatus == 'Approved') {
      text = 'Fully Approved'; color = Colors.green;
    } else if (facilityStatus == 'Approved' && caritasStatus != 'Approved') {
      text = 'Awaiting CARITAS Signature'; color = Colors.deepPurple;
    } else {
      text = 'Awaiting Project Coordinator Signature'; color = Colors.orange;
    }
    return Chip(
      label: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildExpansionDetails(TimesheetModel timesheet) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSupervisorInfo("Facility Supervisor", timesheet.facilitySupervisor, timesheet.facilitySupervisorSignatureStatus, timesheet.facilitySupervisorSignatureDate, timesheet.facilitySupervisorSignature)),
              Expanded(child: _buildSupervisorInfo("CARITAS Supervisor", timesheet.caritasSupervisor, timesheet.caritasSupervisorSignatureStatus, timesheet.caritasSupervisorSignatureDate, timesheet.caritasSupervisorSignature)),
            ],
          ),
          const Divider(height: 24),
          Text("Daily Entries Summary", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildEntriesTable(timesheet.entries),
        ],
      ),
    );
  }

  Widget _buildSupervisorInfo(String title, String name, String status, String? date, String? signatureUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(name),
        Text("Status: $status"),
        if (date != null) Text("Date: $date"),
        if (signatureUrl != null && signatureUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Image.network(signatureUrl, height: 40, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red)),
        ]
      ],
    );
  }

  Widget _buildEntriesTable(List<hq.TimesheetEntry> entries) {
    final Map<String, Map<String, dynamic>> dailySummary = {};
    for (final entry in entries) {
      dailySummary.update(
        entry.date,
            (value) {
          value['hours'] = value['hours']! + entry.noOfHours.toDouble();
          if (entry.isOffDay) value['isOffDay'] = true;
          return value;
        },
        ifAbsent: () => {'hours': entry.noOfHours.toDouble(), 'isOffDay': entry.isOffDay},
      );
    }
    final sortedDates = dailySummary.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [DataColumn(label: Text("Date")), DataColumn(label: Text("Total Hours"), numeric: true)],
        rows: sortedDates.map((date) {
          final summary = dailySummary[date]!;
          final double dailyHours = summary['hours']!;
          final double cappedHours = dailyHours > 8.0 ? 8.0 : dailyHours;
          final bool isOffDay = summary['isOffDay']!;
          return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((s) => isOffDay ? Colors.blue.withOpacity(0.05) : null),
              cells: [DataCell(Text(date)), DataCell(Text(cappedHours.toStringAsFixed(2)))]
          );
        }).toList(),
      ),
    );
  }

  // Future<TimesheetModel?> _fetchTimesheetFromFirestore1(String staffId, String timesheetDocId) async {
  //   try {
  //     final querySnapshot = await _firestore.collectionGroup('TimeSheets').where('staffId', isEqualTo: staffId).get();
  //     final docs = querySnapshot.docs.where((doc) => doc.id == timesheetDocId).toList();
  //     if (docs.isNotEmpty) {
  //       final doc = docs.first;
  //       final data = doc.data();
  //       if (data is Map<String, dynamic>) {
  //         return TimesheetModel.fromMap(data, staffId);
  //       }
  //     }
  //     return null;
  //   } catch (e) {
  //     debugPrint("Error fetching single timesheet for PDF: $e");
  //     return null;
  //   }
  // }

  // In _TimesheetReviewPageHqState class

  // <<<--- CORRECTED METHOD ---<<<
  Future<TimesheetModel?> _fetchTimesheetFromFirestore2(String staffId, String timesheetDocId) async {
    try {
      final querySnapshot = await _firestore.collectionGroup('TimeSheets').where('staffId', isEqualTo: staffId).get();

      // Also check for the split September timesheet IDs
      final part1DocId = '${timesheetDocId}_part1';
      final part2DocId = '${timesheetDocId}_part2';

      final docs = querySnapshot.docs.where((doc) =>
      doc.id == timesheetDocId ||
          doc.id == part1DocId ||
          doc.id == part2DocId
      ).toList();

      if (docs.isNotEmpty) {
        // It's possible for a staff member to have two timesheets in September.
        // For a single PDF download, we'll just grab the first one found.
        final doc = docs.first;

        // FIX: Call the correct factory 'fromFirestore' which takes the DocumentSnapshot
        return TimesheetModel.fromFirestore(doc);
      }

      return null; // Return null if no matching timesheet is found
    } catch (e) {
      debugPrint("Error fetching single timesheet for PDF: $e");
      return null;
    }
  }


  Future<void> _downloadSinglePdf(String staffId) async {
    setState(() => _isExporting = true);
    final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
    // MODIFIED: Handle document naming for September parts
    final bool isSeptember = _selectedMonth == 9;
    final String timesheetDocId = isSeptember
        ? '${monthName}_${_selectedYear}_part$_selectedSeptemberPart'
        : '${monthName}_$_selectedYear';
    final timesheet = await _fetchTimesheetFromFirestore(staffId, timesheetDocId);
    if (timesheet == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not find timesheet for $staffId to download.')));
      setState(() => _isExporting = false);
      return;
    }
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
    final ttf = pw.Font.ttf(font);
    final ttfBold = pw.Font.ttf(boldFont);
    final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());
    pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));
    final pdfBytes = await pdf.save();
    _triggerDownload(pdfBytes, 'Timesheet_${timesheet.staffName.replaceAll(' ','_')}_${_selectedMonth}_$_selectedYear.pdf');
    setState(() => _isExporting = false);
  }

  Future<void> _downloadBulkPdf() async {
    setState(() => _isExporting = true);
    try {
      if (_allTimesheetsMaster.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No submitted timesheets to generate a bulk PDF.')));
        setState(() => _isExporting = false);
        return;
      }

      final timesheetsToPrint = List<TimesheetModel>.from(_allTimesheetsMaster);

      if (_selectedStaffIds.isNotEmpty) {
        final selectionSet = _selectedStaffIds.toSet();
        timesheetsToPrint.retainWhere((ts) => selectionSet.contains(ts.staffId));
      }

      if (timesheetsToPrint.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching timesheets for the selected staff.')));
        setState(() => _isExporting = false);
        return;
      }

      timesheetsToPrint.sort((a,b) => a.staffName.compareTo(b.staffName));

      final pdf = pw.Document();
      final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
      final boldFont = await rootBundle.load("assets/fonts/OpenSans-Bold.ttf");
      final ttf = pw.Font.ttf(font);
      final ttfBold = pw.Font.ttf(boldFont);
      final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());

      for(final timesheet in timesheetsToPrint) {
        pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));
      }

      final pdfBytes = await pdf.save();
      String selectionName = 'Statewide';
      if (!_selectedFacilities.contains('All Facilities')) {
        selectionName = _selectedFacilities.join('_').replaceAll(' ', '_');
      }
      _triggerDownload(pdfBytes, 'Bulk_Timesheets_${_userState}_${selectionName}_${_selectedMonth}_$_selectedYear.pdf');

    } catch (e, stack) {
      debugPrint("Error generating bulk PDF: $e\n$stack");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred during bulk PDF generation: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<pw.Page> _createSingleTimesheetPage(TimesheetModel timesheet, pw.ImageProvider logoImage, pw.Font ttf, pw.Font ttfBold) async {
    final monthName = DateFormat('MMMM, yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final startDate = DateTime(_selectedYear, _selectedMonth - 1, 20);
    final endDate = DateTime(_selectedYear, _selectedMonth, 19);
    final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));
    final tableHeaders = ['Project Name', ...daysInRange.map((date) => DateFormat('dd').format(date)), 'Total Hours', '%'];
    final mainProjectName = timesheet.projectName ?? "Access Project";
    final List<String> categories = [ mainProjectName, 'Annual leave', 'Holiday', 'Maternity', ];
    Map<String, List<double>> dailyHoursByCategory = { for (var category in categories) category: List.filled(daysInRange.length, 0.0) };

    for (int i = 0; i < daysInRange.length; i++) {
      final date = daysInRange[i];
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      double dailyTotalForCap = 0;
      for (final entry in timesheet.entries) {
        if (entry.date == dateString) {
          double hours = entry.noOfHours.toDouble();
          if (dailyTotalForCap + hours > 8.0) { hours = 8.0 - dailyTotalForCap; }
          if (hours < 0) hours = 0;
          dailyTotalForCap += hours;
          if (entry.isOffDay) {
            if (dailyHoursByCategory.containsKey(entry.durationWorked)) { dailyHoursByCategory[entry.durationWorked]![i] += hours; }
          } else { dailyHoursByCategory[mainProjectName]![i] += hours; }
        }
      }
    }
    final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
    final double maxHours = (workingDays * 8.0);
    List<List<String>> tableBodyRows = [];
    for (var category in categories) {
      final hours = dailyHoursByCategory[category]!;
      final totalCategoryHours = hours.reduce((a, b) => a + b);
      final percentCategory = maxHours > 0 ? (totalCategoryHours / maxHours * 100) : 0;
      tableBodyRows.add([ category, ...hours.map((h) => h.round().toString()), totalCategoryHours.round().toString(), '${percentCategory.round()}%' ]);
    }
    List<String> totalRowStrings = ['Total'];
    for (int i = 0; i < daysInRange.length; i++) {
      double dayTotal = 0;
      for (var category in categories) { dayTotal += dailyHoursByCategory[category]![i]; }
      totalRowStrings.add(dayTotal.round().toString());
    }
    final double grandTotalHours = totalRowStrings.sublist(1).fold(0.0, (sum, item) => sum + (double.tryParse(item) ?? 0.0));
    final double grandPercent = maxHours > 0 ? (grandTotalHours / maxHours * 100) : 0.0;
    totalRowStrings.add(grandTotalHours.round().toString());
    totalRowStrings.add('${grandPercent.round()}%');
    tableBodyRows.add(totalRowStrings);

    final staffSigBytes = await _networkImageToByte(timesheet.staffSignature);
    final facilitySigBytes = await _networkImageToByte(timesheet.facilitySupervisorSignature);
    final caritasSigBytes = await _networkImageToByte(timesheet.caritasSupervisorSignature);

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Name: ${timesheet.staffName}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Department: ${timesheet.department}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Designation: ${timesheet.designation}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Location: ${timesheet.location}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('State: ${timesheet.state}', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                pw.Column(children: [
                  pw.Text("CARITAS NIGERIA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                  pw.SizedBox(height: 5),
                  pw.Text("Monthly Time Report ($monthName)", style: const pw.TextStyle(fontSize: 14))
                ]),
                pw.Image(logoImage, width: 70, height: 70),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                for (int i = 1; i <= daysInRange.length; i++) i: const pw.FlexColumnWidth(0.8),
                daysInRange.length + 1: const pw.FlexColumnWidth(1.2),
                daysInRange.length + 2: const pw.FlexColumnWidth(0.8),
              },
              children: [
                pw.TableRow(
                  children: tableHeaders.asMap().entries.map((entry) {
                    final i = entry.key;
                    final headerText = entry.value;
                    bool isWeekendHeader = i > 0 && i <= daysInRange.length && (daysInRange[i - 1].weekday == 6 || daysInRange[i - 1].weekday == 7);
                    return pw.Container(
                        color: isWeekendHeader ? PdfColors.black : PdfColors.grey300,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        child: pw.Text(headerText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: isWeekendHeader ? PdfColors.white : PdfColors.black)));
                  }).toList(),
                ),
                ...tableBodyRows.map((row) {
                  final isTotalRow = row.first == 'Total';
                  final style = isTotalRow ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9) : const pw.TextStyle(fontSize: 8);
                  return pw.TableRow(
                    decoration: isTotalRow ? const pw.BoxDecoration(color: PdfColors.grey300) : null,
                    children: row.asMap().entries.map((entry) {
                      final i = entry.key;
                      final data = entry.value;
                      final isWeekend = i > 0 && i <= daysInRange.length && (daysInRange[i - 1].weekday == 6 || daysInRange[i - 1].weekday == 7);
                      return pw.Container(
                        color: isWeekend ? PdfColors.black : null,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        child: pw.Text(isWeekend ? '' : data, style: style),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
            pw.Spacer(),
            pw.Text('Signature & Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Divider(height: 1),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildPdfSignatureColumn('Name of Staff', timesheet.staffName, staffSigBytes, timesheet.staffSignatureDate),
                _buildPdfSignatureColumn('Name of Project Coordinator', timesheet.facilitySupervisor, facilitySigBytes, timesheet.facilitySupervisorSignatureDate),
                _buildPdfSignatureColumn('Name of Caritas Supervisor', timesheet.caritasSupervisor, caritasSigBytes, timesheet.caritasSupervisorSignatureDate),
              ],
            ),
          ],
        );
      },
    );
  }

  pw.Widget _buildPdfSignatureColumn(String title, String name, Uint8List? imageBytes, String? date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Text(name.toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 2),
        pw.Container(
            height: 35, width: 100,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
            child: imageBytes != null && imageBytes.isNotEmpty
                ? pw.Image(pw.MemoryImage(imageBytes))
                : pw.Center(child: pw.Text('Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)))
        ),
        pw.SizedBox(height: 2),
        pw.Text("Date: ${date ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }
}