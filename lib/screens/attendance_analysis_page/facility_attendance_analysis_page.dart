// A DEDICATED, FEATURE-RICH PAGE FOR FACILITY-LEVEL ATTENDANCE ANALYSIS
// CREATED BY GEMINI TO AUTOMATICALLY SCOPE DATA TO THE LOGGED-IN USER'S FACILITY

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // COMMENTED OUT - Using OpenStreetMap instead
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/drawer.dart';
// Your custom drawer widget

// --- DATA MODELS (Shared with state-level page) ---
// ADD THIS NEW CLASS WITH THE OTHER DATA MODELS
class RecommendationInfo {
  final String recommenderName;
  final String recommenderDesignation;
  final String notes;
  final int? deductedHours;

  RecommendationInfo({
    required this.recommenderName,
    required this.recommenderDesignation,
    required this.notes,
    this.deductedHours,
  });

  factory RecommendationInfo.fromMap(Map<String, dynamic> map) {
    return RecommendationInfo(
      recommenderName: map['recommenderName'] as String? ?? 'N/A',
      recommenderDesignation: map['recommenderDesignation'] as String? ?? 'N/A',
      notes: map['notes'] as String? ?? '',
      deductedHours: map['deductedHours'] as int?,
    );
  }
}

class StaffInfo {
  final String id;
  final String name;
  final String location;
  final String designation;
  StaffInfo(
      {required this.id,
      required this.name,
      required this.location,
      required this.designation});
}

class FacilityDetails {
  final String name;
  final GeoPoint coordinates;
  final double radius;
  FacilityDetails(
      {required this.name, required this.coordinates, required this.radius});
}

// REPLACE THE EXISTING AttendanceRecord CLASS WITH THIS UPDATED VERSION
class AttendanceRecord {
  final String staffId;
  final String staffName;
  final String assignedFacility;
  final DateTime date;
  final double hoursWorked;
  final GeoPoint? clockInLocation;
  final GeoPoint? clockOutLocation;
  // New fields for recommendations
  final String deductionStatus;
  final RecommendationInfo? recommendation;

  AttendanceRecord({
    required this.staffId,
    required this.staffName,
    required this.assignedFacility,
    required this.date,
    required this.hoursWorked,
    this.clockInLocation,
    this.clockOutLocation,
    // Add new fields to constructor
    this.deductionStatus = 'None',
    this.recommendation,
  });
}

class OutlierRecord {
  final String staffName;
  final DateTime date;
  final String type;
  final String assignedFacility;
  final double distanceInMeters;

  OutlierRecord({
    required this.staffName,
    required this.date,
    required this.type,
    required this.assignedFacility,
    required this.distanceInMeters,
  });
}

// REPLACE the existing AggregatedSummary class with this one.
class AggregatedSummary {
  final String name;

  // For detailed views like the staff table, storing the full record.
  Map<DateTime, AttendanceRecord> dailyRecords = {};

  // For high-level summaries like the designation table.
  Map<DateTime, double> dailyHours = {};

  // The getter can now calculate total hours from either data source.
  double get totalHours {
    if (dailyRecords.isNotEmpty) {
      return dailyRecords.values
          .fold(0.0, (sum, record) => sum + record.hoursWorked);
    }
    return dailyHours.values.fold(0.0, (sum, hours) => sum + hours);
  }

  AggregatedSummary({required this.name});
}

class ChartData {
  final String category;
  final double value;
  ChartData(this.category, this.value);
}

class _RecommendationsDataSource extends DataTableSource {
  final List<AttendanceRecord> records;

  _RecommendationsDataSource(this.records);

  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final record = records[index];
    String statusText = record.deductionStatus;
    Color statusColor = Colors.black;
    final rec = record.recommendation;

    switch (record.deductionStatus) {
      case 'Partial':
        statusText = 'Partial Deduction (${rec?.deductedHours ?? 0} hrs)';
        statusColor = Colors.orange.shade800;
        break;
      case 'Full':
        statusText = 'Full Deduction (8 hrs)';
        statusColor = Colors.red.shade800;
        break;
      case 'ApprovedPartial':
        statusText =
            'Partial Approval (${record.hoursWorked.toInt()} hr${record.hoursWorked == 1 ? '' : 's'})';
        statusColor = Colors.blue.shade800;
        break;
      case 'ApprovedFull':
        statusText = 'Full Approval (8 hrs)';
        statusColor = Colors.indigo.shade800;
        break;
      default:
        statusText = record.deductionStatus;
        break;
    }

    final recommenderText = rec != null
        ? '${rec.recommenderName}\n(${rec.recommenderDesignation})'
        : 'N/A';
    final notesText = rec?.notes ?? 'No notes provided.';

    return DataRow(
      cells: [
        DataCell(Text(record.staffName)),
        DataCell(Text(DateFormat.yMd().format(record.date))),
        DataCell(Text(statusText,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: statusColor))),
        DataCell(Text(recommenderText)),
        DataCell(Text(notesText)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => records.length;

  @override
  int get selectedRowCount => 0;
}

// --- MAIN WIDGET ---
class FacilityAttendanceAnalysisPage extends StatefulWidget {
  const FacilityAttendanceAnalysisPage({super.key});
  @override
  _FacilityAttendanceAnalysisPageState createState() =>
      _FacilityAttendanceAnalysisPageState();
}

class _FacilityAttendanceAnalysisPageState
    extends State<FacilityAttendanceAnalysisPage> {
  // --- Services & State Controllers ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ScrollController _staffTableController = ScrollController();

  // --- UI State ---
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  String? _userFacility; // The facility of the logged-in user
  FacilityDetails? _facilityDetails;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  static const String _allDesignationsOption = "(All Designations)";
  static const String _allStaffOption = "(All Staff)";

  List<String> _availableDesignations = [];
  List<String> _selectedDesignations = [];

  List<StaffInfo> _availableStaff = [];
  List<String> _selectedStaffIds = [];

  // --- Data & Chart State ---
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _recordsWithRecommendations = [];
  Map<String, AggregatedSummary> _staffSummaries = {};
  Map<String, AggregatedSummary> _designationSummaries = {};
  List<DateTime> _dateRangeForTables = [];
  double _totalHoursAll = 0;

  final GlobalKey _designationBarChartKey = GlobalKey();
  final GlobalKey _designationPieChartKey = GlobalKey();
  late TooltipBehavior _tooltipBehavior;

  // --- Map and Outlier State ---
  // GoogleMapController? _mapController; // COMMENTED OUT - Using OpenStreetMap instead
  MapController? _mapController;
  List<Marker> _mapMarkers =
      []; // Changed from Set<Marker> to List<Marker> for flutter_map
  List<OutlierRecord> _outlierRecords = [];
  // CameraPosition _initialCameraPosition = const CameraPosition( // COMMENTED OUT - Using OpenStreetMap instead
  //   target: LatLng(9.0820, 8.6753), // Default center
  //   zoom: 6,
  // );
  latlng.LatLng _initialMapCenter =
      const latlng.LatLng(9.0820, 8.6753); // Default center

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _initializePage();
  }

  @override
  void dispose() {
    _staffTableController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Fetches the user's assigned facility, initializes filters, and then loads the dashboard data.
  Future<void> _initializePage() async {
    // Start the loading indicator for the entire initialization process.
    setState(() => _isLoading = true);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null)
        throw Exception("Authentication error. Please log in again.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!staffDoc.exists || staffDoc.data()?['location'] == null) {
        throw Exception(
            "Your user profile is incomplete or you are not assigned to a facility.");
      }

      _userFacility = staffDoc.data()?['location'] as String;
      if (_userFacility!.isEmpty) {
        throw Exception("Your assigned facility name is invalid.");
      }

      // 1. Await the initialization of filters for the user's facility.
      await _initializeFilters();

      // 2. If filter initialization was successful, automatically load the dashboard data.
      // By default, it will load for all staff/designations in the facility.
      if (_errorMessage == null) {
        await _loadDashboardData();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Initialization Failed: $e");
    } finally {
      // 3. Stop the loading indicator after all startup tasks are complete.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Populates filters with designations and staff from the user's facility.
  Future<void> _initializeFilters() async {
    if (_userFacility == null) return;
    try {
      // Fetch details (like coordinates) for the user's facility for map and outlier logic.
      final facilitySnapshot = await _firestore
          .collection('Facilities')
          .where('LocationName', isEqualTo: _userFacility)
          .limit(1)
          .get();
      if (facilitySnapshot.docs.isEmpty) {
        throw Exception(
            "Details for your facility '$_userFacility' could not be found.");
      }
      final facilityData = facilitySnapshot.docs.first.data();
      final lat = double.tryParse(facilityData['Latitude']?.toString() ?? '');
      final lon = double.tryParse(facilityData['Longitude']?.toString() ?? '');
      final radius = double.tryParse(facilityData['Radius']?.toString() ?? '');

      if (lat != null && lon != null && radius != null) {
        _facilityDetails = FacilityDetails(
            name: _userFacility!,
            coordinates: GeoPoint(lat, lon),
            radius: radius);
        // _initialCameraPosition = CameraPosition(target: LatLng(lat, lon), zoom: 14); // COMMENTED OUT - Using OpenStreetMap instead
        _initialMapCenter = latlng.LatLng(lat, lon);
      } else {
        throw Exception("Facility '$_userFacility' has invalid location data.");
      }

      // Fetch all staff and their designations within this one facility
      final staffSnapshot = await _firestore
          .collection('Staff')
          .where('location', isEqualTo: _userFacility)
          .get();

      final Set<String> designations = {};
      final List<StaffInfo> staffList = [];

      for (final doc in staffSnapshot.docs) {
        final data = doc.data();
        final designation = data['designation'] as String?;
        if (designation != null && designation.isNotEmpty)
          designations.add(designation);

        staffList.add(StaffInfo(
            id: doc.id,
            name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            location: data['location'] ?? 'N/A',
            designation: designation ?? 'N/A'));
      }

      final sortedDesignations = designations.toList()..sort();
      staffList.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _availableDesignations = sortedDesignations;
          _availableStaff = staffList;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() => _errorMessage = "Error initializing filters: $e");
    }
  }

  /// Main data loading logic for the facility.
// REPLACE THE EXISTING _loadDashboardData METHOD
  Future<void> _loadDashboardData() async {
    if (_userFacility == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Cannot load data: User's facility is unknown.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Get the list of staff that match the current filters (already scoped to facility).
      var staffQuery = _firestore
          .collection('Staff')
          .where('location', isEqualTo: _userFacility);

      if (_selectedStaffIds.isNotEmpty) {
        if (_selectedStaffIds.length <= 30) {
          staffQuery = staffQuery.where(FieldPath.documentId,
              whereIn: _selectedStaffIds);
        }
      } else if (_selectedDesignations.isNotEmpty) {
        if (_selectedDesignations.length <= 30) {
          staffQuery =
              staffQuery.where('designation', whereIn: _selectedDesignations);
        }
      }

      final staffSnapshot = await staffQuery.get();
      var staffList = staffSnapshot.docs
          .map((doc) => StaffInfo(
              id: doc.id,
              name:
                  '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'
                      .trim(),
              location: doc.data()['location'] ?? 'N/A',
              designation: doc.data()['designation'] ?? 'N/A'))
          .toList();

      // Client-side filtering for large IN queries not supported by Firestore
      if (_selectedStaffIds.isNotEmpty && _selectedStaffIds.length > 30) {
        staffList.retainWhere((staff) => _selectedStaffIds.contains(staff.id));
      }
      if (_selectedDesignations.isNotEmpty &&
          _selectedDesignations.length > 30) {
        staffList.retainWhere(
            (staff) => _selectedDesignations.contains(staff.designation));
      }

      if (staffList.isEmpty) {
        _processAndAggregateData([], []);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final filteredStaffIds = staffList.map((s) => s.id).toSet();
      final staffInfoMap = {for (var s in staffList) s.id: s};

      // 2. Fetch attendance records using the same efficient collectionGroup query.
      final recordsSnapshot = await _firestore
          .collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp',
              isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
          .get();

      List<AttendanceRecord> allRecords = [];
      for (final recordDoc in recordsSnapshot.docs) {
        final staffId = recordDoc.reference.parent.parent!.id;

        // 3. Filter records to only include those from our filtered staff list.
        if (filteredStaffIds.contains(staffId)) {
          final staffInfo = staffInfoMap[staffId]!;
          final data = recordDoc.data();

          // --- NEW LOGIC TO PARSE RECOMMENDATION ---
          RecommendationInfo? recommendation;
          if (data['recommendation'] != null && data['recommendation'] is Map) {
            recommendation = RecommendationInfo.fromMap(
                data['recommendation'] as Map<String, dynamic>);
          }
          // --- END OF NEW LOGIC ---

          allRecords.add(AttendanceRecord(
            staffId: staffId,
            staffName: staffInfo.name,
            assignedFacility: staffInfo.location,
            date: data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : (data['timestamp'] is String ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now() : DateTime.now()),
            hoursWorked: (data['noOfHours'] as num? ?? 0.0).toDouble(),
            clockInLocation: (data['clockInLatitude'] != null)
                ? GeoPoint(data['clockInLatitude'], data['clockInLongitude'])
                : null,
            clockOutLocation: (data['clockOutLatitude'] != null)
                ? GeoPoint(data['clockOutLatitude'], data['clockOutLongitude'])
                : null,
            // Pass new data to the record
            deductionStatus: data['deductionStatus'] as String? ?? 'None',
            recommendation: recommendation,
          ));
        }
      }

      // 4. Process the fetched data for display.
      final dateRange = List.generate(
          _endDate.difference(_startDate).inDays + 1,
          (i) => _startDate.add(Duration(days: i)));
      _processAndAggregateData(allRecords, dateRange);
    } catch (e, stack) {
      debugPrint("Error loading dashboard data: $e\n$stack");
      if (mounted) {
        setState(() => _errorMessage =
            "An error occurred. A required Firestore index may be missing. Details: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Aggregates raw attendance records into summaries for the facility.
  void _processAndAggregateData(
      List<AttendanceRecord> records, List<DateTime> dateRange) {
    final staffData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};

    for (final record in records) {
      final day =
          DateTime(record.date.year, record.date.month, record.date.day);

      // Find staff info from available list (since it's already filtered)
      final staffInfo =
          _availableStaff.firstWhere((s) => s.id == record.staffId);

      // Aggregate by Staff Member - using the new dailyRecords map
      final staffSummary = staffData.putIfAbsent(
          record.staffName, () => AggregatedSummary(name: record.staffName));
      staffSummary.dailyRecords[day] = record; // Store the entire record

      // Aggregate by Designation - using the existing dailyHours map
      final designationSummary = designationData.putIfAbsent(
          staffInfo.designation,
          () => AggregatedSummary(name: staffInfo.designation));
      designationSummary.dailyHours[day] =
          (designationSummary.dailyHours[day] ?? 0) + record.hoursWorked;
    }

    final recommendations =
        records.where((r) => r.deductionStatus != 'None').toList();
    recommendations.sort((a, b) => b.date.compareTo(a.date));

    _generateMapMarkers(records);
    _findOutliers(records);

    if (mounted) {
      setState(() {
        _allRecords = records;
        _recordsWithRecommendations = recommendations;
        _staffSummaries = staffData;
        _designationSummaries = designationData;
        _dateRangeForTables = dateRange;
        _totalHoursAll = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
      });
    }
  }

  Widget _buildRecommendationsLogSection() {
    if (_recordsWithRecommendations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recommendations Log",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 18),
            ),
            Text(
                "${_recordsWithRecommendations.length} record(s) with an action taken"),
            const SizedBox(height: 16),
            PaginatedDataTable(
              columns: const [
                DataColumn(label: Text('Staff')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Recommendation')),
                DataColumn(label: Text('Recommended By')),
                DataColumn(label: Text('Reason / Notes')),
              ],
              source: _RecommendationsDataSource(_recordsWithRecommendations),
              rowsPerPage: 5,
              showFirstLastButtons: true,
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Facility Analysis: ${_userFacility ?? 'Loading...'}",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF5C1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isExporting)
            const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Data (CSV)",
              onPressed:
                  (_isLoading || _allRecords.isEmpty) ? null : _exportToCsv,
            )
        ],
      ),
      drawer: drawer(context),
      body: SelectionArea(
        child: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                _buildDashboardBody(),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                  ),
                if (_errorMessage != null) _buildErrorOverlay(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                Text("An Error Occurred",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: Text("Close"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                  '${DateFormat("d MMM, yyyy").format(_startDate)} - ${DateFormat("d MMM, yyyy").format(_endDate)}'),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _showFilterDialog(
                  title: "Select Designations",
                  allItems: _availableDesignations,
                  selectedItems: _selectedDesignations,
                  onConfirm: (List<String> newSelection) {
                    setState(() {
                      if (newSelection.isEmpty) {
                        _selectedDesignations = [];
                      } else {
                        _selectedDesignations = newSelection;
                      }
                    });
                  },
                );
              },
              icon: Icon(Icons.work_outline, color: Colors.grey.shade700),
              label: Text(
                _selectedDesignations.isEmpty
                    ? "All Designations"
                    : "${_selectedDesignations.length} Selected",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade800, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _showFilterDialog(
                  title: "Select Staff",
                  allItems: _availableStaff.map((s) => s.name).toList(), // Extract names
                  selectedItems: _selectedStaffIds.map((id) {
                     // CAUTION: Map back to names for display/selection
                     final staff = _availableStaff.firstWhere((s) => s.id == id, orElse: () => StaffInfo(id: '', name: 'Unknown', location: '', designation: ''));
                     return staff.name;
                  }).toList(),
                  onConfirm: (List<String> newSelectionNames) {
                    setState(() {
                        // Map names back to IDs
                        if (newSelectionNames.isEmpty) {
                            _selectedStaffIds = [];
                        } else {
                            _selectedStaffIds = _availableStaff
                                .where((s) => newSelectionNames.contains(s.name))
                                .map((s) => s.id)
                                .toList();
                        }
                    });
                  },
                );
              },
              icon: Icon(Icons.person_outline, color: Colors.grey.shade700),
              label: Text(
                _selectedStaffIds.isEmpty
                    ? "All Staff"
                    : "${_selectedStaffIds.length} Selected",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade800, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded),
              label: Text('Load Dashboard'),
              onPressed: _isLoading ? null : _loadDashboardData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF722F37),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog({
    required String title,
    required List<String> allItems,
    required List<String> selectedItems,
    required Function(List<String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelectedItems = List.from(selectedItems);
        bool isAllSelected = tempSelectedItems.length == allItems.length;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: Text("Select All", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          isAllSelected = value ?? false;
                          if (isAllSelected) {
                            tempSelectedItems = List.from(allItems);
                          } else {
                            tempSelectedItems.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          final isSelected = tempSelectedItems.contains(item);
                          return CheckboxListTile(
                            title: Text(item, style: GoogleFonts.poppins()),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempSelectedItems.add(item);
                                } else {
                                  tempSelectedItems.remove(item);
                                }
                                isAllSelected = tempSelectedItems.length == allItems.length;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    onConfirm(tempSelectedItems);
                    Navigator.pop(context);
                  },
                  child: Text("Confirm", style: GoogleFonts.poppins(color: const Color(0xFF5C1A2E))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Date Range'),
        content: SizedBox(
          width: 350,
          height: 350,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            maxDate: DateTime.now(),
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                setState(() {
                  _startDate = value.startDate ?? _startDate;
                  _endDate = value.endDate ?? value.startDate ?? _endDate;
                });
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

//  _buildDashboardBody METHOD
  Widget _buildDashboardBody() {
    if (_allRecords.isEmpty && _errorMessage == null && !_isLoading) {
      return Center(
        child: Text(
          "Please select filters and click 'Load Dashboard' to view analysis.",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    if (_allRecords.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          "No attendance data found for the selected criteria.",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiSection(),
          const SizedBox(height: 24),
          // ADD THE CALL TO THE NEW WIDGET HERE
          _buildRecommendationsLogSection(),
          const SizedBox(height: 24),
          _buildLocationMapCard(),
          const SizedBox(height: 24),
          _buildOutlierAnalysisSection(),
          const SizedBox(height: 24),
          _buildStaffSummaryTable(),
          const SizedBox(height: 24),
          _buildDesignationCharts(),
        ],
      ),
    );
  }

  Widget _buildKpiSection() {
    final activeStaffCount = _allRecords.map((r) => r.staffId).toSet().length;
    final averageHours =
        activeStaffCount > 0 ? _totalHoursAll / activeStaffCount : 0.0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll, Icons.timer_rounded,
            Colors.blue.shade800,
            fractionDigits: 1),
        _buildKpiCard("Active Staff", activeStaffCount, Icons.person_4_rounded,
            Colors.green.shade700),
        _buildKpiCard("Avg Hours / Staff", averageHours,
            Icons.hourglass_full_rounded, Colors.orange.shade700,
            fractionDigits: 1),
      ],
    );
  }

  Widget _buildLocationMapCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Staff Clock-in Locations",
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          SizedBox(height: 400, child: _buildGoogleMap()),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    try {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialMapCenter,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: _mapMarkers,
          ),
        ],
      );
    } catch (e) {
      // Handle map errors (OpenStreetMap issues, etc.)
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Map temporarily unavailable',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Location data is still available in the detailed records below.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOutlierAnalysisSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text("Outlier Analysis",
            style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text("Clock events outside facility radius"),
        children: [
          if (_outlierRecords.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                  child: Text(
                      "No outliers found. All clock events were within the facility radius.",
                      style: GoogleFonts.poppins(fontStyle: FontStyle.italic))),
            )
          else
            SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Staff')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Distance (m)')),
                ],
                rows: _outlierRecords
                    .map((outlier) => DataRow(
                          cells: [
                            DataCell(Text(outlier.staffName)),
                            DataCell(
                                Text(DateFormat.yMd().format(outlier.date))),
                            DataCell(Text(outlier.type)),
                            DataCell(Text(
                                outlier.distanceInMeters.toStringAsFixed(0),
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red))),
                          ],
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

// REPLACE the existing _buildStaffSummaryTable widget with this new version.
  Widget _buildStaffSummaryTable() {
    final sortedStaff = _staffSummaries.values.toList()
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Staff Attendance Details",
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              SingleChildScrollView(
                  controller: _staffTableController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Staff Member')),
                      ..._dateRangeForTables.map((date) => DataColumn(
                          label: Text(DateFormat('EEE\nMMM dd').format(date)),
                          numeric: true)),
                      const DataColumn(label: Text('Total'), numeric: true),
                    ],
                    rows: sortedStaff.map((summary) {
                      return DataRow(cells: [
                        DataCell(Text(summary.name,
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        ..._dateRangeForTables.map((date) {
                          final recordForDay = summary.dailyRecords[date];

                          // If no record, show default text
                          if (recordForDay == null) {
                            return DataCell(Text('0.0'));
                          }

                          // If a record exists, determine colors, icon, and tooltip
                          final hours = recordForDay.hoursWorked;
                          Color backgroundColor = Colors.transparent;
                          IconData? statusIcon;
                          Color? iconColor;
                          String tooltipMessage =
                              "Hours: ${hours.toStringAsFixed(1)}";

                          switch (recordForDay.deductionStatus) {
                            case 'Partial':
                              backgroundColor = Colors.orange.withOpacity(0.1);
                              statusIcon = Icons.warning_amber_rounded;
                              iconColor = Colors.orange.shade700;
                              break;
                            case 'Full':
                              backgroundColor = Colors.red.withOpacity(0.1);
                              statusIcon = Icons.gpp_bad_rounded;
                              iconColor = Colors.red.shade700;
                              break;
                            case 'ApprovedPartial':
                              backgroundColor = Colors.blue.withOpacity(0.1);
                              statusIcon = Icons.thumb_up_alt_rounded;
                              iconColor = Colors.blue.shade700;
                              break;
                            case 'ApprovedFull':
                              backgroundColor = Colors.green.withOpacity(0.1);
                              statusIcon = Icons.verified_user_rounded;
                              iconColor = Colors.green.shade700;
                              break;
                          }

                          // Build a detailed tooltip message if there's a recommendation
                          if (recordForDay.recommendation != null) {
                            final rec = recordForDay.recommendation!;
                            tooltipMessage +=
                                "\nStatus: ${recordForDay.deductionStatus}";
                            tooltipMessage +=
                                "\nReason: ${rec.notes.isNotEmpty ? rec.notes : 'N/A'}";
                            tooltipMessage += "\nBy: ${rec.recommenderName}";
                          }

                          return DataCell(
                            Tooltip(
                              message: tooltipMessage,
                              child: Container(
                                color: backgroundColor,
                                // Use BoxConstraints.expand() to make the color fill the cell
                                constraints: const BoxConstraints.expand(),
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FutureBuilder<List<String>>(
                                      future: _getVerifiersForStaffAndDate(
                                          recordForDay.staffId, date),
                                      builder: (context, snapshot) {
                                        final verifiers = snapshot.data ?? [];
                                        if (verifiers.isNotEmpty) {
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.verified_user,
                                                    size: 16,
                                                    color: Colors.blue),
                                                onPressed: () =>
                                                    _showVerificationDialog(
                                                        summary.name,
                                                        recordForDay.staffId,
                                                        date),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                tooltip:
                                                    'View verifiers for this day',
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                verifiers.length.toString(),
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.blue,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox(width: 20);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    if (statusIcon != null)
                                      Icon(statusIcon,
                                          size: 16, color: iconColor),
                                    if (statusIcon != null)
                                      const SizedBox(width: 4),
                                    Text(hours.toStringAsFixed(1)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        DataCell(Text(summary.totalHours.toStringAsFixed(1),
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      ]);
                    }).toList(),
                  )),
              const SizedBox(height: 16),
              // Add verification details section
              //  _buildVerificationDetailsSection(),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _staffTableController.animateTo(
                        _staffTableController.offset - 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut)),
                IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _staffTableController.animateTo(
                        _staffTableController.offset + 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut)),
              ])
            ])),
      ],
    );
  }

  Widget _buildVerificationDetailsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getVerificationDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Text('Error loading verification details: ${snapshot.error}'),
          );
        }

        final verificationDetails = snapshot.data ?? [];

        if (verificationDetails.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
                'No verification details available for the selected date range.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Verification Details',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...verificationDetails.map((detail) => Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              detail['staffName'],
                              style:
                                  GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM dd, yyyy').format(detail['date']),
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verified by: ${detail['verifiers'].join(', ')}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        if (detail['verificationCount'] != null)
                          Text(
                            'Total verifications: ${detail['verificationCount']}',
                            style: GoogleFonts.poppins(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getVerificationDetails() async {
    final List<Map<String, dynamic>> verificationDetails = [];

    try {
      // Get all staff IDs that match our filters
      var staffQuery = _firestore
          .collection('Staff')
          .where('location', isEqualTo: _userFacility);

      if (_selectedStaffIds.isNotEmpty) {
        if (_selectedStaffIds.length <= 30) {
          staffQuery = staffQuery.where(FieldPath.documentId,
              whereIn: _selectedStaffIds);
        }
      } else if (_selectedDesignations.isNotEmpty) {
        if (_selectedDesignations.length <= 30) {
          staffQuery =
              staffQuery.where('designation', whereIn: _selectedDesignations);
        }
      }

      final staffSnapshot = await staffQuery.get();
      var staffList = staffSnapshot.docs
          .map((doc) => StaffInfo(
              id: doc.id,
              name:
                  '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'
                      .trim(),
              location: doc.data()['location'] ?? 'N/A',
              designation: doc.data()['designation'] ?? 'N/A'))
          .toList();

      // Client-side filtering for large IN queries
      if (_selectedStaffIds.isNotEmpty && _selectedStaffIds.length > 30) {
        staffList.retainWhere((staff) => _selectedStaffIds.contains(staff.id));
      }
      if (_selectedDesignations.isNotEmpty &&
          _selectedDesignations.length > 30) {
        staffList.retainWhere(
            (staff) => _selectedDesignations.contains(staff.designation));
      }

      final filteredStaffIds = staffList.map((s) => s.id).toSet();

      // Fetch verification details from Record sub-collection
      for (final staff in staffList) {
        final recordQuery = await _firestore
            .collection('Staff')
            .doc(staff.id)
            .collection('Record')
            .where('timestamp', isGreaterThanOrEqualTo: _startDate)
            .where('timestamp',
                isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
            .get();

        for (final recordDoc in recordQuery.docs) {
          final data = recordDoc.data();
          final verifiedByUserNames =
              List<String>.from(data['verifiedByUserNames'] ?? []);
          final verificationCount = data['verificationCount'] as int? ?? 0;

          if (verifiedByUserNames.isNotEmpty) {
            verificationDetails.add({
              'staffId': staff.id,
              'staffName': staff.name,
              'date': data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : (data['timestamp'] is String ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now() : DateTime.now()),
              'verifiers': verifiedByUserNames,
              'verificationCount': verificationCount,
            });
          }
        }
      }

      // Sort by date (most recent first)
      verificationDetails.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    } catch (e) {
      debugPrint("Error fetching verification details: $e");
    }

    return verificationDetails;
  }

  Widget _buildDesignationCharts() {
    if (_designationSummaries.isEmpty) return const SizedBox.shrink();

    final sortedDesignations = _designationSummaries.values.toList()
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));
    final barChartData =
        sortedDesignations.map((d) => ChartData(d.name, d.totalHours)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hours by Designation",
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  _buildChartCard(
                      "Total Hours",
                      SfCartesianChart(
                          key: _designationBarChartKey,
                          tooltipBehavior: _tooltipBehavior,
                          primaryXAxis: CategoryAxis(
                              labelRotation: -45,
                              majorGridLines: const MajorGridLines(width: 0)),
                          series: <CartesianSeries>[
                            BarSeries<ChartData, String>(
                                dataSource: barChartData,
                                xValueMapper: (d, _) => d.category,
                                yValueMapper: (d, _) => d.value,
                                name: "Hours",
                                color: Colors.teal)
                          ])),
                  const SizedBox(height: 16),
                  _buildChartCard(
                      "Distribution",
                      SfCircularChart(
                          key: _designationPieChartKey,
                          tooltipBehavior: _tooltipBehavior,
                          legend: const Legend(
                              isVisible: true,
                              overflowMode: LegendItemOverflowMode.wrap),
                          series: <CircularSeries>[
                            PieSeries<ChartData, String>(
                              dataSource: barChartData,
                              xValueMapper: (d, _) => d.category,
                              yValueMapper: (d, _) => d.value,
                              dataLabelMapper: (d, _) =>
                                  '${d.value.toStringAsFixed(1)} hrs',
                              dataLabelSettings:
                                  const DataLabelSettings(isVisible: true),
                            )
                          ])),
                ],
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildChartCard(
                        "Total Hours",
                        SfCartesianChart(
                            key: _designationBarChartKey,
                            tooltipBehavior: _tooltipBehavior,
                            primaryXAxis: CategoryAxis(
                                labelRotation: -45,
                                majorGridLines: const MajorGridLines(width: 0)),
                            series: <CartesianSeries>[
                              BarSeries<ChartData, String>(
                                  dataSource: barChartData,
                                  xValueMapper: (d, _) => d.category,
                                  yValueMapper: (d, _) => d.value,
                                  name: "Hours",
                                  color: Colors.teal)
                            ])),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildChartCard(
                        "Distribution",
                        SfCircularChart(
                            key: _designationPieChartKey,
                            tooltipBehavior: _tooltipBehavior,
                            legend: const Legend(
                                isVisible: true,
                                overflowMode: LegendItemOverflowMode.wrap),
                            series: <CircularSeries>[
                              PieSeries<ChartData, String>(
                                dataSource: barChartData,
                                xValueMapper: (d, _) => d.category,
                                yValueMapper: (d, _) => d.value,
                                dataLabelMapper: (d, _) =>
                                    '${d.value.toStringAsFixed(1)} hrs',
                                dataLabelSettings:
                                    const DataLabelSettings(isVisible: true),
                              )
                            ])),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // --- HELPER & EXPORT METHODS (Slightly modified for facility context) ---

  Widget _buildKpiCard(String title, num value, IconData icon, Color color,
      {int fractionDigits = 0, String suffix = ''}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 16),
            Text(
              '${value.toStringAsFixed(fractionDigits)}$suffix',
              style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chartWidget, {Key? key}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(height: 300, child: chartWidget),
            ],
          ),
        ),
      ),
    );
  }

  void _generateMapMarkers(List<AttendanceRecord> records) {
    try {
      List<Marker> markers = [];

      // Add a marker for the facility itself
      if (_facilityDetails != null) {
        markers.add(Marker(
          point: latlng.LatLng(_facilityDetails!.coordinates.latitude,
              _facilityDetails!.coordinates.longitude),
          child: Icon(
            Icons.business,
            color: Colors.blue,
            size: 40,
          ),
        ));
      }

      for (final record in records) {
        if (record.clockInLocation != null) {
          markers.add(Marker(
            point: latlng.LatLng(record.clockInLocation!.latitude,
                record.clockInLocation!.longitude),
            child: Icon(
              Icons.location_on,
              color: Colors.green,
              size: 30,
            ),
          ));
        }
      }
      if (mounted) setState(() => _mapMarkers = markers);
    } catch (e) {
      // Handle marker creation errors
      debugPrint("Error generating map markers: $e");
      if (mounted) setState(() => _mapMarkers = []);
    }
  }

  void _findOutliers(List<AttendanceRecord> records) {
    if (_facilityDetails == null) return;

    final List<OutlierRecord> outliers = [];
    final facility = _facilityDetails!;

    for (final record in records) {
      if (record.clockInLocation != null) {
        final distance = Geolocator.distanceBetween(
            facility.coordinates.latitude,
            facility.coordinates.longitude,
            record.clockInLocation!.latitude,
            record.clockInLocation!.longitude);
        if (distance > facility.radius) {
          outliers.add(OutlierRecord(
              staffName: record.staffName,
              date: record.date,
              type: 'Clock In',
              assignedFacility: record.assignedFacility,
              distanceInMeters: distance));
        }
      }
      if (record.clockOutLocation != null) {
        final distance = Geolocator.distanceBetween(
            facility.coordinates.latitude,
            facility.coordinates.longitude,
            record.clockOutLocation!.latitude,
            record.clockOutLocation!.longitude);
        if (distance > facility.radius) {
          outliers.add(OutlierRecord(
              staffName: record.staffName,
              date: record.date,
              type: 'Clock Out',
              assignedFacility: record.assignedFacility,
              distanceInMeters: distance));
        }
      }
    }
    outliers.sort((a, b) => b.distanceInMeters.compareTo(a.distanceInMeters));
    if (mounted) setState(() => _outlierRecords = outliers);
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    List<List<dynamic>> rows = [];
    rows.add(['Facility Attendance Report for $_userFacility']);
    rows.add([
      'Date Range:',
      '${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}'
    ]);
    rows.add([]);

    List<dynamic> header = ['Staff Member'];
    final allDates = _dateRangeForTables
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toList();
    header.addAll(allDates);
    header.add('Total Hours');
    rows.add(header);

    _staffSummaries.forEach((staffName, summary) {
      List<dynamic> row = [staffName];
      for (var date in _dateRangeForTables) {
        row.add(summary.dailyHours[date]?.toStringAsFixed(2) ?? '0.00');
      }
      row.add(summary.totalHours.toStringAsFixed(2));
      rows.add(row);
    });

    String csvData = const ListToCsvConverter().convert(rows);
    final filename =
        'facility_report_${_userFacility?.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    _triggerDownload(utf8.encode(csvData), filename);
    setState(() => _isExporting = false);
  }

  void _triggerDownload(List<int> bytes, String filename,
      [String mimeType = 'text/csv']) {
    final blob = html.Blob([bytes], mimeType);
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

  void _showVerificationDialog(
      String staffName, String staffId, DateTime date) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verifiers for $staffName'),
          content: FutureBuilder<List<String>>(
            future: _getVerifiersForStaffAndDate(staffId, date),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text('Error loading verifiers: ${snapshot.error}');
              }

              final verifiers = snapshot.data ?? [];

              if (verifiers.isEmpty) {
                return Text('No verifications found for this day.');
              }

              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM dd, yyyy').format(date),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verified by:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...verifiers.map((verifier) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(verifier),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _getVerifiersForStaffAndDate(
      String staffId, DateTime date) async {
    try {
      final dateStr = DateFormat('dd-MMMM-yyyy').format(date);

      final recordDoc = await _firestore
          .collection('Staff')
          .doc(staffId)
          .collection('Record')
          .doc(dateStr)
          .get();

      if (recordDoc.exists) {
        final data = recordDoc.data();
        final verifiedByUserNames =
            List<String>.from(data?['verifiedByUserNames'] ?? []);
        return verifiedByUserNames;
      }

      return [];
    } catch (e) {
      debugPrint("Error fetching verifiers: $e");
      return [];
    }
  }
}
