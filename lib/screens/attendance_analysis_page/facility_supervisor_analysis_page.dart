// A DEDICATED, FEATURE-RICH PAGE FOR FACILITY-LEVEL ATTENDANCE ANALYSIS
// CREATED BY GEMINI TO AUTOMATICALLY SCOPE DATA TO THE LOGGED-IN USER'S FACILITY
// UPDATED TO INCLUDE RECOMMENDATION LOGS AND DETAILED STAFF ATTENDANCE VIEW

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../widgets/drawer.dart';
import '../../widgets/drawer2.dart';
import '../../widgets/drawer4.dart'; // Your custom drawer widget

// --- DATA MODELS (Shared with state-level page) ---
class StaffInfo {
  final String id;
  final String name;
  final String location;
  final String designation;
  StaffInfo({required this.id, required this.name, required this.location, required this.designation});
}

class FacilityDetails {
  final String name;
  final GeoPoint coordinates;
  final double radius;
  FacilityDetails({required this.name, required this.coordinates, required this.radius});
}

// --- NEW: RecommendationInfo Model ---
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

// --- UPDATED: AttendanceRecord Model ---
class AttendanceRecord {
  final String staffId;
  final String staffName;
  final String assignedFacility;
  final DateTime date;
  final double hoursWorked;
  final GeoPoint? clockInLocation;
  final GeoPoint? clockOutLocation;
  // New fields
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
    // Add to constructor
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

// --- UPDATED: AggregatedSummary Model ---
class AggregatedSummary {
  final String name;

  // For detailed views like the staff table, storing the full record.
  Map<DateTime, AttendanceRecord> dailyRecords = {};

  // For high-level summaries like the designation table.
  Map<DateTime, double> dailyHours = {};

  // The getter can now calculate total hours from either data source.
  double get totalHours {
    if (dailyRecords.isNotEmpty) {
      return dailyRecords.values.fold(0.0, (sum, record) => sum + record.hoursWorked);
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

// --- MAIN WIDGET ---
class FacilitySupervisorAttendanceAnalysisPage extends StatefulWidget {
  const FacilitySupervisorAttendanceAnalysisPage({super.key});
  @override
  _FacilitySupervisorAttendanceAnalysisPageState createState() => _FacilitySupervisorAttendanceAnalysisPageState();
}

class _FacilitySupervisorAttendanceAnalysisPageState extends State<FacilitySupervisorAttendanceAnalysisPage> {
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
  // --- NEW: State variable for recommendations ---
  List<AttendanceRecord> _recordsWithRecommendations = [];
  Map<String, AggregatedSummary> _staffSummaries = {};
  Map<String, AggregatedSummary> _designationSummaries = {};
  List<DateTime> _dateRangeForTables = [];
  double _totalHoursAll = 0;

  final GlobalKey _designationBarChartKey = GlobalKey();
  final GlobalKey _designationPieChartKey = GlobalKey();
  late TooltipBehavior _tooltipBehavior;

  // --- Map and Outlier State ---
  GoogleMapController? _mapController;
  Set<Marker> _mapMarkers = {};
  List<OutlierRecord> _outlierRecords = [];
  CameraPosition _initialCameraPosition = const CameraPosition(
    target: LatLng(9.0820, 8.6753), // Default center
    zoom: 6,
  );

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
      if (user == null) throw Exception("Authentication error. Please log in again.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!staffDoc.exists || staffDoc.data()?['location'] == null) {
        throw Exception("Your user profile is incomplete or you are not assigned to a facility.");
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
      final facilitySnapshot = await _firestore.collection('Facilities').where('LocationName', isEqualTo: _userFacility).limit(1).get();
      if (facilitySnapshot.docs.isEmpty) {
        throw Exception("Details for your facility '$_userFacility' could not be found.");
      }
      final facilityData = facilitySnapshot.docs.first.data();
      final lat = double.tryParse(facilityData['Latitude']?.toString() ?? '');
      final lon = double.tryParse(facilityData['Longitude']?.toString() ?? '');
      final radius = double.tryParse(facilityData['Radius']?.toString() ?? '');

      if (lat != null && lon != null && radius != null) {
        _facilityDetails = FacilityDetails(name: _userFacility!, coordinates: GeoPoint(lat, lon), radius: radius);
        _initialCameraPosition = CameraPosition(target: LatLng(lat, lon), zoom: 14);
      } else {
        throw Exception("Facility '$_userFacility' has invalid location data.");
      }

      // Fetch all staff and their designations within this one facility
      final staffSnapshot = await _firestore.collection('Staff').where('location', isEqualTo: _userFacility).get();

      final Set<String> designations = {};
      final List<StaffInfo> staffList = [];

      for (final doc in staffSnapshot.docs) {
        final data = doc.data();
        final designation = data['designation'] as String?;
        if (designation != null && designation.isNotEmpty) designations.add(designation);

        staffList.add(StaffInfo(
            id: doc.id,
            name: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            location: data['location'] ?? 'N/A',
            designation: designation ?? 'N/A'
        ));
      }

      final sortedDesignations = designations.toList()..sort();
      staffList.sort((a,b) => a.name.compareTo(b.name));

      if(mounted) {
        setState(() {
          _availableDesignations = sortedDesignations;
          _availableStaff = staffList;
        });
      }
    } catch(e) {
      if(mounted) setState(() => _errorMessage = "Error initializing filters: $e");
    }
  }

  /// Main data loading logic for the facility.
  Future<void> _loadDashboardData() async {
    if (_userFacility == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot load data: User's facility is unknown.")));
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // 1. Get the list of staff that match the current filters (already scoped to facility).
      var staffQuery = _firestore.collection('Staff').where('location', isEqualTo: _userFacility);

      if (_selectedStaffIds.isNotEmpty) {
        if (_selectedStaffIds.length <= 30) {
          staffQuery = staffQuery.where(FieldPath.documentId, whereIn: _selectedStaffIds);
        }
      } else if (_selectedDesignations.isNotEmpty) {
        if (_selectedDesignations.length <= 30) {
          staffQuery = staffQuery.where('designation', whereIn: _selectedDesignations);
        }
      }

      final staffSnapshot = await staffQuery.get();
      var staffList = staffSnapshot.docs.map((doc) => StaffInfo(
          id: doc.id,
          name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
          location: doc.data()['location'] ?? 'N/A',
          designation: doc.data()['designation'] ?? 'N/A'
      )).toList();

      // Client-side filtering for large IN queries not supported by Firestore
      if (_selectedStaffIds.isNotEmpty && _selectedStaffIds.length > 30) {
        staffList.retainWhere((staff) => _selectedStaffIds.contains(staff.id));
      }
      if (_selectedDesignations.isNotEmpty && _selectedDesignations.length > 30) {
        staffList.retainWhere((staff) => _selectedDesignations.contains(staff.designation));
      }

      if (staffList.isEmpty) {
        _processAndAggregateData([], []);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final filteredStaffIds = staffList.map((s) => s.id).toSet();
      final staffInfoMap = {for (var s in staffList) s.id: s};

      // 2. Fetch attendance records using the same efficient collectionGroup query.
      final recordsSnapshot = await _firestore.collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
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
            recommendation = RecommendationInfo.fromMap(data['recommendation'] as Map<String, dynamic>);
          }

          allRecords.add(
              AttendanceRecord(
                  staffId: staffId,
                  staffName: staffInfo.name,
                  assignedFacility: staffInfo.location,
                  date: (data['timestamp'] as Timestamp).toDate(),
                  hoursWorked: (data['noOfHours']as num? ?? 0.0).toDouble(),
                  clockInLocation: (data['clockInLatitude'] != null) ? GeoPoint(data['clockInLatitude'], data['clockInLongitude']) : null,
                  clockOutLocation: (data['clockOutLatitude'] != null) ? GeoPoint(data['clockOutLatitude'], data['clockOutLongitude']) : null,
                  // Pass new data to the record
                  deductionStatus: data['deductionStatus'] as String? ?? 'None',
                  recommendation: recommendation
              )
          );
        }
      }

      // 4. Process the fetched data for display.
      final dateRange = List.generate(_endDate.difference(_startDate).inDays + 1, (i) => _startDate.add(Duration(days: i)));
      _processAndAggregateData(allRecords, dateRange);

    } catch (e, stack) {
      debugPrint("Error loading dashboard data: $e\n$stack");
      if (mounted) {
        setState(() => _errorMessage = "An error occurred. A required Firestore index may be missing. Details: $e");
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  /// Aggregates raw attendance records into summaries for the facility.
  void _processAndAggregateData(List<AttendanceRecord> records, List<DateTime> dateRange){
    final staffData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};

    for(final record in records) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);

      // Find staff info from available list (since it's already filtered)
      final staffInfo = _availableStaff.firstWhere((s) => s.id == record.staffId);

      // Aggregate by Staff Member - using the new dailyRecords map
      final staffSummary = staffData.putIfAbsent(record.staffName, () => AggregatedSummary(name: record.staffName));
      staffSummary.dailyRecords[day] = record; // Store the entire record

      // Aggregate by Designation - using the existing dailyHours map
      final designationSummary = designationData.putIfAbsent(staffInfo.designation, () => AggregatedSummary(name: staffInfo.designation));
      designationSummary.dailyHours[day] = (designationSummary.dailyHours[day] ?? 0) + record.hoursWorked;
    }

    // --- NEW LOGIC TO POPULATE RECOMMENDATIONS LIST ---
    final recommendations = records.where((r) => r.deductionStatus != 'None').toList();
    recommendations.sort((a, b) => b.date.compareTo(a.date));

    _generateMapMarkers(records);
    _findOutliers(records);

    if(mounted){
      setState(() {
        _allRecords = records;
        _recordsWithRecommendations = recommendations; // Set the new state variable
        _staffSummaries = staffData;
        _designationSummaries = designationData;
        _dateRangeForTables = dateRange;
        _totalHoursAll = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
      });
    }
  }


  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Facility Analysis: ${_userFacility ?? 'Loading...'}", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Data (CSV)",
              onPressed: (_isLoading || _allRecords.isEmpty) ? null : _exportToCsv,
            )
        ],
      ),
      drawer: drawer4(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                _buildDashboardBody(),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                if (_errorMessage != null)
                  _buildErrorOverlay(),
              ],
            ),
          ),
        ],
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
                Text("An Error Occurred", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center,),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text("Close"),
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
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat("d MMM, yyyy").format(_startDate)} - ${DateFormat("d MMM, yyyy").format(_endDate)}'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allDesignationsOption, _allDesignationsOption),
                  ..._availableDesignations.map((d) => MultiSelectItem<String>(d, d)),
                ],
                initialValue: _selectedDesignations,
                title: const Text("Select Designations"),
                buttonIcon: Icon(Icons.work_outline, color: Colors.grey.shade700),
                buttonText: Text(
                  _selectedDesignations.isEmpty ? "All Designations" : "${_selectedDesignations.length} Selected",
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                ),
                onConfirm: (values) {
                  setState(() {
                    final castedValues = values.cast<String>();
                    if (castedValues.contains(_allDesignationsOption) || castedValues.isEmpty) {
                      _selectedDesignations = [];
                    } else {
                      _selectedDesignations = castedValues;
                    }
                  });
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allStaffOption, "All Staff"),
                  ..._availableStaff.map((s) => MultiSelectItem<String>(s.id, s.name)),
                ],
                initialValue: _selectedStaffIds,
                title: const Text("Select Staff"),
                buttonIcon: Icon(Icons.person_outline, color: Colors.grey.shade700),
                buttonText: Text(
                  _selectedStaffIds.isEmpty ? "All Staff" : "${_selectedStaffIds.length} Selected",
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                ),
                onConfirm: (values) {
                  setState(() {
                    final castedValues = values.cast<String>();
                    if (castedValues.contains(_allStaffOption) || castedValues.isEmpty) {
                      _selectedStaffIds = [];
                    } else {
                      _selectedStaffIds = castedValues;
                    }
                  });
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('Load Dashboard'),
              onPressed: _isLoading ? null : _loadDashboardData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF722F37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 350, height: 350,
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

  Widget _buildDashboardBody() {
    if (_allRecords.isEmpty && _errorMessage == null && !_isLoading) {
      return Center(
        child: Text(
          "Please select filters and click 'Load Dashboard' to view analysis.",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
        ),
      );
    }

    if (_allRecords.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          "No attendance data found for the selected criteria.",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
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
          _buildRecommendationsLogSection(), // ADDED CALL
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

  // --- NEW: Recommendation Log Widget ---
  Widget _buildRecommendationsLogSection() {
    if (_recordsWithRecommendations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.playlist_add_check_circle_rounded),
        title: Text(
          "Recommendations Log",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        subtitle: Text("${_recordsWithRecommendations.length} record(s) with an action taken"),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Staff')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Recommendation')),
                DataColumn(label: Text('Recommended By')),
                DataColumn(label: Text('Reason / Notes')),
              ],
              rows: _recordsWithRecommendations.map((record) {
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
                    statusText = 'Partial Approval (${record.hoursWorked.toInt()} hr${record.hoursWorked == 1 ? '' : 's'})';
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
                    DataCell(Text(
                      statusText,
                      style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                    )),
                    DataCell(Text(recommenderText)),
                    DataCell(Text(notesText)),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }


  Widget _buildKpiSection(){
    final activeStaffCount = _allRecords.map((r) => r.staffId).toSet().length;
    final averageHours = activeStaffCount > 0 ? _totalHoursAll / activeStaffCount : 0.0;

    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll, Icons.timer_rounded, Colors.blue.shade800, fractionDigits: 1),
        _buildKpiCard("Active Staff", activeStaffCount, Icons.person_4_rounded, Colors.green.shade700),
        _buildKpiCard("Avg Hours / Staff", averageHours, Icons.hourglass_full_rounded, Colors.orange.shade700, fractionDigits: 1),
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
            child: Text("Staff Clock-in Locations", style: Theme.of(context).textTheme.headlineSmall),
          ),
          SizedBox(
              height: 400,
              child: _buildGoogleMap()
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    try {
      return GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: _initialCameraPosition,
        markers: _mapMarkers,
      );
    } catch (e) {
      // Handle Google Maps errors (billing issues, deprecated API, etc.)
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Map temporarily unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Location data is still available in the detailed records below.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (e.toString().contains('BillingNotEnabledMapError')) ...[
              const SizedBox(height: 16),
              Text(
                'Note: Google Maps billing needs to be enabled for map display.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
                textAlign: TextAlign.center,
              ),
            ],
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
        title: Text("Outlier Analysis", style: Theme.of(context).textTheme.titleLarge),
        subtitle: const Text("Clock events outside facility radius"),
        children: [
          if (_outlierRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(child: Text("No outliers found. All clock events were within the facility radius.", style: TextStyle(fontStyle: FontStyle.italic))),
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
                rows: _outlierRecords.map((outlier) => DataRow(
                  cells: [
                    DataCell(Text(outlier.staffName)),
                    DataCell(Text(DateFormat.yMd().format(outlier.date))),
                    DataCell(Text(outlier.type)),
                    DataCell(Text(outlier.distanceInMeters.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  ],
                )).toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- REPLACED: Staff Summary Table with Colors and Tooltips ---
  Widget _buildStaffSummaryTable() {
    final sortedStaff = _staffSummaries.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Staff Attendance Details", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card( clipBehavior: Clip.antiAlias, child: Column( children: [
          SingleChildScrollView( controller: _staffTableController, scrollDirection: Axis.horizontal, child: DataTable(
            columns: [
              const DataColumn(label: Text('Staff Member')),
              ..._dateRangeForTables.map((date) => DataColumn(label: Text(DateFormat('EEE\nMMM dd').format(date)), numeric: true)),
              const DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: sortedStaff.map((summary) {
              return DataRow(cells: [
                DataCell(Text(summary.name, style: const TextStyle(fontWeight: FontWeight.bold))),

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
                  String tooltipMessage = "Hours: ${hours.toStringAsFixed(1)}";

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
                    tooltipMessage += "\nStatus: ${recordForDay.deductionStatus}";
                    tooltipMessage += "\nReason: ${rec.notes.isNotEmpty ? rec.notes : 'N/A'}";
                    tooltipMessage += "\nBy: ${rec.recommenderName}";
                  }

                  return DataCell(
                    Tooltip(
                      message: tooltipMessage,
                      child: Container(
                        color: backgroundColor,
                        constraints: const BoxConstraints.expand(),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (statusIcon != null) Icon(statusIcon, size: 16, color: iconColor),
                            if (statusIcon != null) const SizedBox(width: 4),
                            Text(hours.toStringAsFixed(1)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                DataCell(Text(summary.totalHours.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]);
            }).toList(),
          )),
          Row( mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton( icon: const Icon(Icons.arrow_back), onPressed: () => _staffTableController.animateTo( _staffTableController.offset - 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
            IconButton( icon: const Icon(Icons.arrow_forward), onPressed: () => _staffTableController.animateTo( _staffTableController.offset + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
          ])
        ])),
      ],
    );
  }

  Widget _buildDesignationCharts() {
    if (_designationSummaries.isEmpty) return const SizedBox.shrink();

    final sortedDesignations = _designationSummaries.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    final barChartData = sortedDesignations.map((d) => ChartData(d.name, d.totalHours)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hours by Designation", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildChartCard("Total Hours",
                  SfCartesianChart(
                      key: _designationBarChartKey,
                      tooltipBehavior: _tooltipBehavior,
                      primaryXAxis: CategoryAxis(labelRotation: -45, majorGridLines: const MajorGridLines(width: 0)),
                      series: <CartesianSeries>[
                        BarSeries<ChartData, String>(
                            dataSource: barChartData,
                            xValueMapper: (d,_) => d.category,
                            yValueMapper: (d,_) => d.value,
                            name: "Hours",
                            color: Colors.teal
                        )
                      ]
                  )
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _buildChartCard("Distribution",
                  SfCircularChart(
                      key: _designationPieChartKey,
                      tooltipBehavior: _tooltipBehavior,
                      legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
                      series: <CircularSeries>[
                        PieSeries<ChartData, String>(
                          dataSource: barChartData,
                          xValueMapper: (d,_) => d.category,
                          yValueMapper: (d,_) => d.value,
                          dataLabelMapper: (d,_) => '${d.value.toStringAsFixed(1)} hrs',
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                        )
                      ]
                  )
              ),
            ),
          ],
        )
      ],
    );
  }

  // --- HELPER & EXPORT METHODS (Slightly modified for facility context) ---

  Widget _buildKpiCard(String title, num value, IconData icon, Color color, {int fractionDigits = 0, String suffix = ''}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 16),
            Text(
              '${value.toStringAsFixed(fractionDigits)}$suffix',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      Set<Marker> markers = {};

      // Add a marker for the facility itself
      if (_facilityDetails != null) {
        markers.add(Marker(
          markerId: MarkerId('facility_${_facilityDetails!.name}'),
          position: LatLng(_facilityDetails!.coordinates.latitude, _facilityDetails!.coordinates.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: _facilityDetails!.name, snippet: 'Facility Location'),
        ));
      }

      for (final record in records) {
        if (record.clockInLocation != null) {
          markers.add(Marker(
            markerId: MarkerId('in-${record.staffId}-${record.date.toIso8601String()}'),
            position: LatLng(record.clockInLocation!.latitude, record.clockInLocation!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: '${record.staffName} - Clock In',
              snippet: 'On ${DateFormat.yMd().add_jm().format(record.date)}',
            ),
          ));
        }
      }
      if (mounted) setState(() => _mapMarkers = markers);
    } catch (e) {
      // Handle marker creation errors (deprecated API, etc.)
      debugPrint("Error generating map markers: $e");
      if (mounted) setState(() => _mapMarkers = {});
    }
  }

  void _findOutliers(List<AttendanceRecord> records) {
    if (_facilityDetails == null) return;

    final List<OutlierRecord> outliers = [];
    final facility = _facilityDetails!;

    for (final record in records) {
      if (record.clockInLocation != null) {
        final distance = Geolocator.distanceBetween(facility.coordinates.latitude, facility.coordinates.longitude, record.clockInLocation!.latitude, record.clockInLocation!.longitude);
        if (distance > facility.radius) {
          outliers.add(OutlierRecord(staffName: record.staffName, date: record.date, type: 'Clock In', assignedFacility: record.assignedFacility, distanceInMeters: distance));
        }
      }
      if (record.clockOutLocation != null) {
        final distance = Geolocator.distanceBetween(facility.coordinates.latitude, facility.coordinates.longitude, record.clockOutLocation!.latitude, record.clockOutLocation!.longitude);
        if (distance > facility.radius) {
          outliers.add(OutlierRecord(staffName: record.staffName, date: record.date, type: 'Clock Out', assignedFacility: record.assignedFacility, distanceInMeters: distance));
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
    rows.add(['Date Range:', '${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}']);
    rows.add([]);

    List<dynamic> header = ['Staff Member'];
    final allDates = _dateRangeForTables.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    header.addAll(allDates);
    header.add('Total Hours');
    rows.add(header);

    _staffSummaries.forEach((staffName, summary) {
      List<dynamic> row = [staffName];
      for (var date in _dateRangeForTables) {
        // Use dailyRecords for staff export
        row.add(summary.dailyRecords[date]?.hoursWorked.toStringAsFixed(2) ?? '0.00');
      }
      row.add(summary.totalHours.toStringAsFixed(2));
      rows.add(row);
    });

    String csvData = const ListToCsvConverter().convert(rows);
    final filename = 'facility_report_${_userFacility?.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    _triggerDownload(utf8.encode(csvData), filename);
    setState(() => _isExporting = false);
  }

  void _triggerDownload(List<int> bytes, String filename, [String mimeType = 'text/csv']) {
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
}