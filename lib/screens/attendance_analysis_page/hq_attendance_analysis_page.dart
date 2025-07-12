// A DEDICATED, FEATURE-RICH PAGE FOR HQ ATTENDANCE ANALYSIS
// REWRITTEN FOR HEADQUARTERS TO MONITOR ALL STATES CENTRALLY
// FEATURES: CASCADING FILTERS (STATE -> FACILITY/DESIGNATION -> STAFF) AND SCALABLE QUERIES
// ** VERSION 2: CORRECTED TYPE ASSIGNMENT AND GENERIC TYPE INFERENCE ERRORS **

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
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


import '../../widgets/drawer2.dart';
import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// (AnimatedNumberText widget remains the same)
class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;
  final String suffix;

  const AnimatedNumberText(
      this.value, {
        super.key,
        this.style,
        this.duration = const Duration(milliseconds: 1200),
        this.fractionDigits = 1,
        this.suffix = '',
      });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      builder: (context, animatedValue, child) {
        final isInt = value is int && fractionDigits == 0;
        final textValue = isInt
            ? animatedValue.toInt().toString()
            : animatedValue.toStringAsFixed(fractionDigits);

        return Text(
          '$textValue$suffix',
          style: style,
        );
      },
    );
  }
}

// --- DATA MODELS (Unchanged) ---
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
  final double radius; // in meters

  FacilityDetails({required this.name, required this.coordinates, required this.radius});
}

class AttendanceRecord {
  final String staffId;
  final String staffName;
  final String assignedFacility;
  final DateTime date;
  final double hoursWorked;
  final GeoPoint? clockInLocation;
  final GeoPoint? clockOutLocation;

  AttendanceRecord({
    required this.staffId,
    required this.staffName,
    required this.assignedFacility,
    required this.date,
    required this.hoursWorked,
    this.clockInLocation,
    this.clockOutLocation,
  });
}

class OutlierRecord {
  final String staffName;
  final DateTime date;
  final String type; // 'Clock In' or 'Clock Out'
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

class AggregatedSummary {
  final String name;
  Map<DateTime, double> dailyHours = {};
  double get totalHours => dailyHours.values.fold(0.0, (sum, item) => sum + item);
  AggregatedSummary({required this.name});
}

class _ChartData {
  final String category;
  final double value;
  final Color? color;
  _ChartData(this.category, this.value, [this.color]);
}

// --- MAIN WIDGET: HQAttendanceAnalysisPage ---
class HQAttendanceAnalysisPage extends StatefulWidget {
  const HQAttendanceAnalysisPage({super.key});
  @override
  _HQAttendanceAnalysisPageState createState() => _HQAttendanceAnalysisPageState();
}

class _HQAttendanceAnalysisPageState extends State<HQAttendanceAnalysisPage> {
  // --- Services & State ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScrollController _facilityTableController = ScrollController();
  final ScrollController _designationTableController = ScrollController();

  bool _isPageReady = false;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  // Filter Options Constants
  static const String _allStatesOption = "(All States)";
  static const String _allFacilitiesOption = "(All Facilities)";
  static const String _allDesignationsOption = "(All Designations)";
  static const String _allStaffOption = "(All Staff)";

  // Available options for dropdowns
  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _availableDesignations = [];
  List<StaffInfo> _availableStaff = [];

  // Selected filter values
  List<String> _selectedStates = [];
  List<String> _selectedFacilities = [];
  List<String> _selectedDesignations = [];
  List<String> _selectedStaffIds = [];

  // --- Data & Chart Keys ---
  List<AttendanceRecord> _allRecords = [];
  Map<String, AggregatedSummary> _facilitySummaries = {};
  Map<String, AggregatedSummary> _designationSummaries = {};
  Map<String, Map<String, AggregatedSummary>> _facilityStaffSummaries = {};
  List<DateTime> _dateRangeForTables = [];
  double _totalHoursAll = 0;
  final GlobalKey _barChartKey = GlobalKey();
  final GlobalKey _facilityPieChartKey = GlobalKey();
  final GlobalKey _designationPieChartKey = GlobalKey();
  late TooltipBehavior _tooltipBehavior;

  // --- Map and Outlier State ---
  GoogleMapController? _mapController;
  Set<Marker> _mapMarkers = {};
  Map<String, FacilityDetails> _facilityDetails = {};
  List<OutlierRecord> _outlierRecords = [];
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(9.0820, 8.6753), // Center of Nigeria
    zoom: 5.5,
  );


  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _initializeStateFilter(); // Start by loading the top-level state filter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isPageReady = true);
    });
  }

  @override
  void dispose() {
    _facilityTableController.dispose();
    _designationTableController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --- HQ FILTERING LOGIC ---

  // Fetches data using chunked 'whereIn' queries to overcome Firestore's 30-item limit.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchWithChunkedIn(
      Query<Map<String, dynamic>> baseQuery,
      String field,
      List<String> values
      ) async {
    if (values.isEmpty) return [];

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    // Firestore limits 'whereIn' to 30 values. We chunk the list to handle this.
    for (var i = 0; i < values.length; i += 30) {
      final chunk = values.sublist(i, min(i + 30, values.length));
      final snapshot = await baseQuery.where(field, whereIn: chunk).get();
      allDocs.addAll(snapshot.docs);
    }
    return allDocs;
  }


// Step 1: Update the initialization method
  Future<void> _initializeStateFilter() async {
    // This now only turns the loader ON. It will be turned OFF by the last function in the chain.
    setState(() => _isLoading = true);
    try {
      final facilitiesSnapshot = await _firestore.collection('Facilities').get();
      final Set<String> states = {};
      for (final doc in facilitiesSnapshot.docs) {
        final state = doc.data()['state'] as String?;
        if (state != null && state.isNotEmpty) {
          states.add(state);
        }
      }

      final sortedStates = states.toList()..sort();

      if (mounted) {
        setState(() {
          _availableStates = sortedStates;
          _selectedStates = List.from(sortedStates);
        });

        await _updateFacilityAndDesignationFilters();
        if (!mounted) return;

        setState(() {
          _selectedFacilities = List.from(_availableFacilities);
          _selectedDesignations = List.from(_availableDesignations);
        });

        await _updateStaffFilter();
        if (!mounted) return;

        // The final call will be responsible for turning off the loader.
        await _loadDashboardData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error initializing filters and loading data: $e";
          _isLoading = false; // Turn off loader on error
        });
      }
    }
    // REMOVED the finally block here to prevent premature deactivation of the loader.
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              "Please wait...",
              style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: When states are selected, update the dependent filters.
  Future<void> _onStateSelectionChange(List<String> results) async {
    setState(() {
      _isLoading = true;
      // Handle the "(All States)" selection
      if (results.contains(_allStatesOption)) {
        _selectedStates = List<String>.from(_availableStates);
      } else {
        _selectedStates = results;
      }

      // Reset all child filters
      _selectedFacilities = [];
      _availableFacilities = [];
      _selectedDesignations = [];
      _availableDesignations = [];
      _selectedStaffIds = [];
      _availableStaff = [];
    });

    // Now, fetch the new options for facilities and designations based on selected states.
    await _updateFacilityAndDesignationFilters();

    setState(() => _isLoading = false);
  }

  // Step 3: Fetch available facilities and designations for the selected states.
  Future<void> _updateFacilityAndDesignationFilters() async {
    if (_selectedStates.isEmpty) return;

    try {
      // Fetch facilities
      final facilityDocs = await _fetchWithChunkedIn(
        _firestore.collection('Facilities').where('category', isEqualTo: 'Facility'),
        'state',
        _selectedStates,
      );

      final List<String> facilities = [];
      final Map<String, FacilityDetails> facilityDetailsMap = {};

      for (var doc in facilityDocs) {
        final data = doc.data();
        final name = data['LocationName'] as String?;
        final lat = double.tryParse(data['Latitude']?.toString() ?? '');
        final lon = double.tryParse(data['Longitude']?.toString() ?? '');
        final radius = double.tryParse(data['Radius']?.toString() ?? '');

        if (name != null && lat != null && lon != null && radius != null) {
          facilities.add(name);
          facilityDetailsMap[name] = FacilityDetails(
            name: name,
            coordinates: GeoPoint(lat, lon),
            radius: radius,
          );
        }
      }
      facilities.sort();

      // Fetch designations
      final staffDocs = await _fetchWithChunkedIn(
        _firestore.collection('Staff').where('staffCategory', isEqualTo: "Facility Staff"),
        'state',
        _selectedStates,
      );

      final Set<String> designations = {};
      for (final doc in staffDocs) {
        final value = doc.data()['designation'] as String?;
        if (value != null && value.isNotEmpty) designations.add(value);
      }
      final sortedDesignations = designations.toList()..sort();

      if(mounted) {
        setState(() {
          _availableFacilities = facilities;
          _facilityDetails = facilityDetailsMap;
          _availableDesignations = sortedDesignations;
        });
      }
    } catch(e) {
      if(mounted) setState(() => _errorMessage = "Error updating filters: $e");
    }
  }

  // Step 4: When facilities or designations change, update the staff filter.
  // **REWRITTEN to fix "more than one 'whereIn'" Firestore error.**
  Future<void> _updateStaffFilter() async {
    if (_selectedStates.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Step A: Query by state first, as it's the top-level filter.
      // This uses our one and only allowed 'whereIn' clause for this query.
      final staffDocs = await _fetchWithChunkedIn(
        _firestore.collection('Staff'),
        'state',
        _selectedStates,
      );

      // Step B: Map the raw documents to our StaffInfo model.
      var staffList = staffDocs.map((doc) => StaffInfo(
          id: doc.id,
          name: '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
          location: doc.data()['location'] ?? 'N/A',
          designation: doc.data()['designation'] ?? 'N/A'
      )).toList();

      // Step C: Apply the other filters (designation, facility) client-side.
      // This is less efficient than a server-side filter but is necessary
      // to work around Firestore's limitations.

      // Client-side filter for designations.
      if (_selectedDesignations.isNotEmpty) {
        final designationSet = _selectedDesignations.toSet();
        staffList.retainWhere((staff) => designationSet.contains(staff.designation));
      }

      // Client-side filter for facilities.
      if (_selectedFacilities.isNotEmpty) {
        final facilitySet = _selectedFacilities.toSet();
        staffList.retainWhere((staff) => facilitySet.contains(staff.location));
      }

      staffList.sort((a, b) => a.name.compareTo(b.name));

      if(mounted){
        setState(() {
          _availableStaff = staffList;
          // Ensure any previously selected staff are still valid after filtering.
          final availableStaffIds = _availableStaff.map((s) => s.id).toSet();
          _selectedStaffIds.retainWhere((id) => availableStaffIds.contains(id));
        });
      }
    } catch (e, stack) {
      debugPrint("Error updating staff filter: $e\n$stack");
      if(mounted) setState(() => _errorMessage = "Error updating staff filter: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }


  // --- DATA LOADING & PROCESSING ---

  // Step 2: Update the main data loading function
  Future<void> _loadDashboardData() async {
    if (_selectedStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one state to load data.")));
      return;
    }
    // This just ensures the loader is ON if called by the button.
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      List<StaffInfo> staffToQuery;

      if (_selectedStaffIds.isNotEmpty) {
        staffToQuery = _availableStaff.where((s) => _selectedStaffIds.contains(s.id)).toList();
      } else {
        await _updateStaffFilter();
        staffToQuery = List<StaffInfo>.from(_availableStaff);
      }

      if (staffToQuery.isEmpty) {
        // If there's no staff, process empty data, which will turn off the loader.
        _processAndAggregateData([], []);
        return;
      }

      final filteredStaffIds = staffToQuery.map((s) => s.id).toSet();
      final staffInfoMap = {for (var s in staffToQuery) s.id: s};

      final recordsSnapshot = await _firestore.collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
          .get();

      List<AttendanceRecord> allRecords = [];
      for (final recordDoc in recordsSnapshot.docs) {
        final staffId = recordDoc.reference.parent.parent!.id;
        if (filteredStaffIds.contains(staffId)) {
          final staffInfo = staffInfoMap[staffId]!;
          final data = recordDoc.data();
          allRecords.add(
              AttendanceRecord(
                // ... (rest of the record creation is the same)
                  staffId: staffId,
                  staffName: staffInfo.name,
                  assignedFacility: staffInfo.location,
                  date: (data['timestamp'] as Timestamp).toDate(),
                  hoursWorked: (data['noOfHours'] as num? ?? 0.0).toDouble(),
                  clockInLocation: (data['clockInLatitude'] != null && data['clockInLongitude'] != null) ? GeoPoint((data['clockInLatitude'] as num).toDouble(), (data['clockInLongitude'] as num).toDouble()) : null,
                  clockOutLocation: (data['clockOutLatitude'] != null && data['clockOutLongitude'] != null) ? GeoPoint((data['clockOutLatitude'] as num).toDouble(), (data['clockOutLongitude'] as num).toDouble()) : null
              )
          );
        }
      }

      final dateRange = List.generate(_endDate.difference(_startDate).inDays + 1, (i) => _startDate.add(Duration(days: i)));
      // This function will now turn off the loader.
      _processAndAggregateData(allRecords, dateRange);

    } catch (e, stack) {
      debugPrint("Error loading dashboard data: $e\n$stack");
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred while loading data. Please check Firestore indexes. Error: $e";
          _isLoading = false; // Turn off loader on error
        });
      }
    }
    // REMOVED the finally block here.
  }


  void _processAndAggregateData(List<AttendanceRecord> records, List<DateTime> dateRange) {
    final facilityData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};
    final facilityStaffData = <String, Map<String, AggregatedSummary>>{};

    // ... (rest of the processing logic is the same)
    final staffDetailsFromRecords = <String, StaffInfo>{};
    for(final record in records) {
      if (!staffDetailsFromRecords.containsKey(record.staffId)) {
        final staffInfo = _availableStaff.firstWhere((s) => s.id == record.staffId, orElse: () => StaffInfo(id: record.staffId, name: record.staffName, location: record.assignedFacility, designation: 'Unknown'));
        staffDetailsFromRecords[record.staffId] = staffInfo;
      }
    }

    for(final record in records) {
      final staffInfo = staffDetailsFromRecords[record.staffId];
      if(staffInfo == null) continue;

      final day = DateTime(record.date.year, record.date.month, record.date.day);

      facilityData.putIfAbsent(staffInfo.location, () => AggregatedSummary(name: staffInfo.location));
      facilityData[staffInfo.location]!.dailyHours[day] = (facilityData[staffInfo.location]!.dailyHours[day] ?? 0) + record.hoursWorked;

      designationData.putIfAbsent(staffInfo.designation, () => AggregatedSummary(name: staffInfo.designation));
      designationData[staffInfo.designation]!.dailyHours[day] = (designationData[staffInfo.designation]!.dailyHours[day] ?? 0) + record.hoursWorked;

      facilityStaffData.putIfAbsent(staffInfo.location, () => {});
      facilityStaffData[staffInfo.location]!.putIfAbsent(staffInfo.name, () => AggregatedSummary(name: staffInfo.name));
      facilityStaffData[staffInfo.location]![staffInfo.name]!.dailyHours[day] = (facilityStaffData[staffInfo.location]![staffInfo.name]!.dailyHours[day] ?? 0) + record.hoursWorked;
    }


    _generateMapMarkers(records);
    _findOutliers(records);

    if(mounted){
      // This setState call now updates the data AND turns off the loading indicator simultaneously.
      setState(() {
        _allRecords = records;
        _facilitySummaries = facilityData;
        _designationSummaries = designationData;
        _facilityStaffSummaries = facilityStaffData;
        _dateRangeForTables = dateRange;
        _totalHoursAll = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
        _isLoading = false; // <<< THIS IS THE KEY CHANGE
      });
    }
  }


  // --- WIDGET BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HQ Attendance Analysis Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'csv') _exportToCsv();
                if(value == 'pdf') _exportChartsToPdf();
              },
              enabled: !_isLoading && _allRecords.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text("Export Data (CSV)"))),
                const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text("Export Charts (PDF)"))),
              ],
            )
        ],
      ),
      drawer: drawer3(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                _buildDashboardBody(),
                // MODIFIED: Use the new, more descriptive loading overlay
                if (_isLoading) _buildLoadingOverlay(),
                if (_errorMessage != null)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
              label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),

            // --- NEW: State Filter ---
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              // **FIXED**: Added explicit type <String> and wrapped async call in a void lambda.
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allStatesOption, _allStatesOption),
                  ..._availableStates.map((s) => MultiSelectItem<String>(s, s)),
                ],
                initialValue: _selectedStates,
                title: const Text("Select States"),
                selectedColor: Colors.deepPurple,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.deepPurple, width: 1),
                ),
                buttonIcon: const Icon(Icons.map_outlined, color: Colors.deepPurple),
                buttonText: Text(
                  _selectedStates.length == _availableStates.length && _availableStates.isNotEmpty
                      ? "All States Selected"
                      : _selectedStates.isEmpty
                      ? "State"
                      : "${_selectedStates.length} State${_selectedStates.length == 1 ? '' : 's'} selected",
                  style: TextStyle(color: Colors.deepPurple[800], fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                onConfirm: (results) {
                  _onStateSelectionChange(results);
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),

            // --- Facility Filter (Now dependent on State) ---
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allFacilitiesOption, _allFacilitiesOption),
                  ..._availableFacilities.map((f) => MultiSelectItem<String>(f, f)),
                ],
                initialValue: _selectedFacilities,
                title: const Text("Select Facilities"),
                selectedColor: Colors.teal,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.teal, width: 1),
                ),
                buttonIcon: const Icon(Icons.location_city, color: Colors.teal),
                buttonText: Text(
                  _selectedFacilities.length == _availableFacilities.length && _availableFacilities.isNotEmpty
                      ? "All Facilities Selected"
                      : _selectedFacilities.isEmpty
                      ? "Facility"
                      : "${_selectedFacilities.length} Facilit${_selectedFacilities.length == 1 ? 'y' : 'ies'} selected",
                  style: TextStyle(color: Colors.teal[800], fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                onConfirm: (results) {
                  setState(() {
                    if (results.contains(_allFacilitiesOption)) {
                      _selectedFacilities = List<String>.from(_availableFacilities);
                    } else {
                      _selectedFacilities = results;
                    }
                    _selectedStaffIds = []; // Reset staff selection
                  });
                  _updateStaffFilter(); // Update staff list based on new facility selection
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),

            // --- Designation Filter (Now dependent on State) ---
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allDesignationsOption, _allDesignationsOption),
                  ..._availableDesignations.map((d) => MultiSelectItem<String>(d, d)),
                ],
                initialValue: _selectedDesignations,
                title: const Text("Select Designations"),
                buttonIcon: Icon(Icons.work_outline, color: Colors.grey.shade700),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                buttonText: Text(
                    _selectedDesignations.length == _availableDesignations.length && _availableDesignations.isNotEmpty
                        ? "All Designations Selected"
                        : _selectedDesignations.isEmpty
                        ? "Designation"
                        : "${_selectedDesignations.length} Selected",
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                    overflow: TextOverflow.ellipsis
                ),
                onConfirm: (values) {
                  setState(() {
                    if (values.contains(_allDesignationsOption)) {
                      _selectedDesignations = List<String>.from(_availableDesignations);
                    } else {
                      _selectedDesignations = values;
                    }
                    _selectedStaffIds = []; // Reset staff selection
                  });
                  _updateStaffFilter(); // Update staff list based on new designation selection
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),

            // --- Staff Filter (Dependent on all above) ---
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allStaffOption, "All Staff"),
                  ..._availableStaff.map((s) => MultiSelectItem<String>(s.id, s.name)),
                ],
                initialValue: _selectedStaffIds,
                title: const Text("Select Staff"),
                buttonIcon: Icon(Icons.person_outline, color: Colors.grey.shade700),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                buttonText: Text(
                  _selectedStaffIds.length == _availableStaff.length && _availableStaff.isNotEmpty
                      ? "All Staff Selected"
                      : _selectedStaffIds.isEmpty
                      ? "Staff"
                      : "${_selectedStaffIds.length} Selected",
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                onConfirm: (values) {
                  setState(() {
                    if (values.contains(_allStaffOption)) {
                      _selectedStaffIds = _availableStaff.map((s) => s.id).toList();
                    } else {
                      _selectedStaffIds = values;
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
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // --- All other methods from _showDateRangePicker onwards remain the same ---
  // They are generic and will work correctly with the data loaded by the new
  // HQ-level filtering logic.

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
    final bool hasLoadedData = _allRecords.isNotEmpty || _errorMessage != null;
    final top15Facilities = _facilitySummaries.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    final chartData = top15Facilities.take(15).map((s) => _ChartData(s.name, s.totalHours)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasLoadedData)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: Text(
                  "Please select filters and click 'Load Dashboard' to view analysis.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),

          if (hasLoadedData) ...[
            const SizedBox(height: 24),
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildLocationMapCard(),
            const SizedBox(height: 24),
            _buildOutlierAnalysisSection(),
            const SizedBox(height: 24),
            _buildChartCard("Top 15 Facilities by Hours",
                SfCartesianChart(
                    key: _barChartKey,
                    tooltipBehavior: _tooltipBehavior,
                    primaryXAxis: CategoryAxis(
                      labelRotation: -45,
                      majorGridLines: const MajorGridLines(width: 0),
                      labelIntersectAction: AxisLabelIntersectAction.rotate45,
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                    primaryYAxis: NumericAxis(majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5])),
                    series: <CartesianSeries>[
                      BarSeries<_ChartData, String>(
                          dataSource: chartData,
                          xValueMapper: (d,_) => d.category,
                          yValueMapper: (d,_) => d.value,
                          name: "Hours",
                          dataLabelSettings: const DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
                          color: Colors.teal,
                          borderRadius: const BorderRadius.all(Radius.circular(5))
                      )
                    ]
                )
            ),
            const SizedBox(height: 24),
            _buildFacilitySummaryTable(),
            const SizedBox(height: 24),
            _buildDesignationSummaryTable(),
          ]
        ],
      ),
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
            child: Text("Clock-in & Clock-out Locations", style: Theme.of(context).textTheme.headlineSmall),
          ),
          SizedBox(
            height: 450,
            child: _isPageReady
                ? GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: _initialCameraPosition,
              markers: _mapMarkers,
              mapType: MapType.normal,
            )
                : const Center(child: Text("Initializing Map...")),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlierAnalysisSection() {
    final bool hasLoadedData = _allRecords.isNotEmpty || _errorMessage != null;
    if (!hasLoadedData) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          "Outlier Analysis",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        subtitle: const Text("Clock events outside any recognized facility radius"),
        children: [
          if (_outlierRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(child: Text("No significant outliers found for the selected criteria.", style: TextStyle(fontStyle: FontStyle.italic))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Staff')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Assigned Facility')),
                  DataColumn(label: Text('Distance (meters)')),
                ],
                rows: _outlierRecords.map((outlier) => DataRow(
                  cells: [
                    DataCell(Text(outlier.staffName)),
                    DataCell(Text(DateFormat.yMd().format(outlier.date))),
                    DataCell(Text(outlier.type)),
                    DataCell(Text(outlier.assignedFacility)),
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

  Widget _buildKpiSection(){
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll, Icons.timer_rounded, Colors.blue.shade800, fractionDigits: 1),
        _buildKpiCard("Active Staff", _allRecords.map((r) => r.staffId).toSet().length, Icons.person_4_rounded, Colors.green.shade700),
        _buildKpiCard("Facilities Reporting", _facilitySummaries.keys.length, Icons.location_city_rounded, Colors.purple.shade700),
      ],
    );
  }

  Widget _buildKpiCard(String title, num value, IconData icon, Color color, {int fractionDigits = 0, String suffix = ''}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 250,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
              const SizedBox(height: 16),
              AnimatedNumberText(
                value,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                fractionDigits: fractionDigits,
                suffix: suffix,
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            ],
          ),
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
              SizedBox(height: 350, child: chartWidget),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPieChart(String title, Map<String, AggregatedSummary> summaryMap, {Key? key}) {
    if (summaryMap.isEmpty) return const SizedBox.shrink();
    final sortedList = summaryMap.values.toList()..sort((a,b) => b.totalHours.compareTo(a.totalHours));
    List<_ChartData> chartData = [];
    double othersHours = 0;
    for (int i=0; i < sortedList.length; i++) {
      if (i < 6) { chartData.add(_ChartData(sortedList[i].name, sortedList[i].totalHours)); }
      else { othersHours += sortedList[i].totalHours; }
    }
    if (othersHours > 0) { chartData.add(_ChartData("Others", othersHours)); }
    return _buildChartCard(title,
      SfCircularChart(
          tooltipBehavior: _tooltipBehavior,
          legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            PieSeries<_ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d,_) => d.category,
              yValueMapper: (d,_) => d.value,
              dataLabelMapper: (d,_) => '${d.category}\n${d.value.toStringAsFixed(1)} hrs',
              dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
            )
          ]
      ),
      key: key,
    );
  }

  Widget _buildFacilitySummaryTable() {
    final sortedFacilities = _facilityStaffSummaries.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Facility", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card( clipBehavior: Clip.antiAlias, child: Column( children: [
          SingleChildScrollView( controller: _facilityTableController, scrollDirection: Axis.horizontal, child: DataTable(
            columns: [
              const DataColumn(label: Text('Location / Staff')),
              ..._dateRangeForTables.map((date) => DataColumn(label: Text(DateFormat('EEE\nMMM dd').format(date)), numeric: true)),
              const DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: sortedFacilities.expand((facility) {
              final staffSummaries = _facilityStaffSummaries[facility]!;
              final sortedStaff = staffSummaries.keys.toList()..sort();
              final facilityTotal = staffSummaries.values.fold(0.0, (sum, s) => sum + s.totalHours);
              return [
                DataRow(
                  color: MaterialStateProperty.all(Colors.blue.withOpacity(0.1)),
                  cells: [
                    DataCell(Text(facility, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ..._dateRangeForTables.map((date) {
                      final dailyTotal = staffSummaries.values.fold(0.0, (sum, s) => sum + (s.dailyHours[date] ?? 0.0));
                      return DataCell(Text(dailyTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)));
                    }),
                    DataCell(Text(facilityTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ...sortedStaff.map((staffName) {
                  final summary = staffSummaries[staffName]!;
                  return DataRow(cells: [
                    DataCell(Padding(padding: const EdgeInsets.only(left: 16.0), child: Text(staffName))),
                    ..._dateRangeForTables.map((date) => DataCell(Text((summary.dailyHours[date] ?? 0).toStringAsFixed(2)))),
                    DataCell(Text(summary.totalHours.toStringAsFixed(2))),
                  ]);
                })
              ];
            }).toList(),
          ),
          ),
          Row( mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton( icon: const Icon(Icons.arrow_back), onPressed: () => _facilityTableController.animateTo( _facilityTableController.offset - 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
            IconButton( icon: const Icon(Icons.arrow_forward), onPressed: () => _facilityTableController.animateTo( _facilityTableController.offset + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
          ],
          )
        ],
        ),
        ),
        const SizedBox(height: 16),
        _buildSummaryPieChart("Facility Hours Distribution", _facilitySummaries, key: _facilityPieChartKey),
      ],
    );
  }

  Widget _buildDesignationSummaryTable() {
    final sortedDesignations = _designationSummaries.keys.toList()..sort();
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Attendance by Designation", style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Card( clipBehavior: Clip.antiAlias, child: Column( children: [
        SingleChildScrollView( controller: _designationTableController, scrollDirection: Axis.horizontal, child: DataTable(
          columns: [
            const DataColumn(label: Text('Designation')),
            ..._dateRangeForTables.map((date) => DataColumn(label: Text(DateFormat('EEE\nMMM dd').format(date)), numeric: true)),
            const DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: sortedDesignations.map((designation) {
            final summary = _designationSummaries[designation]!;
            return DataRow(cells: [
              DataCell(Text(summary.name, style: const TextStyle(fontWeight: FontWeight.bold))),
              ..._dateRangeForTables.map((date) => DataCell(Text((summary.dailyHours[date] ?? 0).toStringAsFixed(2)))),
              DataCell(Text(summary.totalHours.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
        ),
        Row( mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton( icon: const Icon(Icons.arrow_back), onPressed: () => _designationTableController.animateTo( _designationTableController.offset - 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
          IconButton( icon: const Icon(Icons.arrow_forward), onPressed: () => _designationTableController.animateTo( _designationTableController.offset + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
        ],
        )
      ],
      ),
      ),
      const SizedBox(height: 16),
      _buildSummaryPieChart("Designation Hours Distribution", _designationSummaries, key: _designationPieChartKey),
    ],
    );
  }

  // --- HELPER METHODS (UNCHANGED) ---
  void _generateMapMarkers(List<AttendanceRecord> records) {
    final Set<Marker> markers = {};
    if (records.isEmpty) {
      if(mounted) setState(() => _mapMarkers = {});
      return;
    }

    for (final record in records) {
      if (record.clockInLocation != null) {
        markers.add(Marker(
          markerId: MarkerId('in-${record.staffId}-${record.date.toIso8601String()}'),
          position: LatLng(record.clockInLocation!.latitude, record.clockInLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '${record.staffName} - Clock In',
            snippet: 'Facility: ${record.assignedFacility} on ${DateFormat.yMd().format(record.date)}',
          ),
        ));
      }
      if (record.clockOutLocation != null) {
        markers.add(Marker(
          markerId: MarkerId('out-${record.staffId}-${record.date.toIso8601String()}'),
          position: LatLng(record.clockOutLocation!.latitude, record.clockOutLocation!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '${record.staffName} - Clock Out',
            snippet: 'Facility: ${record.assignedFacility} on ${DateFormat.yMd().format(record.date)}',
          ),
        ));
      }
    }
    if (mounted) setState(() => _mapMarkers = markers);
  }

  void _findOutliers(List<AttendanceRecord> records) {
    final List<OutlierRecord> outliers = [];
    if (_facilityDetails.isEmpty) return;

    for (final record in records) {
      if (record.clockInLocation != null) {
        bool isWithinAnyFacility = false;
        for (final facility in _facilityDetails.values) {
          final distance = Geolocator.distanceBetween(
            facility.coordinates.latitude,
            facility.coordinates.longitude,
            record.clockInLocation!.latitude,
            record.clockInLocation!.longitude,
          );
          if (distance <= facility.radius) {
            isWithinAnyFacility = true;
            break;
          }
        }

        if (!isWithinAnyFacility) {
          final assignedFacilityDetails = _facilityDetails[record.assignedFacility];
          if (assignedFacilityDetails != null) {
            final distanceToAssigned = Geolocator.distanceBetween(
              assignedFacilityDetails.coordinates.latitude,
              assignedFacilityDetails.coordinates.longitude,
              record.clockInLocation!.latitude,
              record.clockInLocation!.longitude,
            );
            outliers.add(OutlierRecord(
              staffName: record.staffName,
              date: record.date,
              type: 'Clock In',
              assignedFacility: record.assignedFacility,
              distanceInMeters: distanceToAssigned,
            ));
          }
        }
      }

      if (record.clockOutLocation != null) {
        bool isWithinAnyFacility = false;
        for (final facility in _facilityDetails.values) {
          final distance = Geolocator.distanceBetween(
            facility.coordinates.latitude,
            facility.coordinates.longitude,
            record.clockOutLocation!.latitude,
            record.clockOutLocation!.longitude,
          );
          if (distance <= facility.radius) {
            isWithinAnyFacility = true;
            break;
          }
        }

        if (!isWithinAnyFacility) {
          final assignedFacilityDetails = _facilityDetails[record.assignedFacility];
          if (assignedFacilityDetails != null) {
            final distanceToAssigned = Geolocator.distanceBetween(
              assignedFacilityDetails.coordinates.latitude,
              assignedFacilityDetails.coordinates.longitude,
              record.clockOutLocation!.latitude,
              record.clockOutLocation!.longitude,
            );
            outliers.add(OutlierRecord(
              staffName: record.staffName,
              date: record.date,
              type: 'Clock Out',
              assignedFacility: record.assignedFacility,
              distanceInMeters: distanceToAssigned,
            ));
          }
        }
      }
    }
    outliers.sort((a, b) => b.distanceInMeters.compareTo(a.distanceInMeters));
    if (mounted) setState(() => _outlierRecords = outliers);
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    List<List<dynamic>> rows = [];
    rows.add(['Attendance Summary by Facility']);
    rows.add(['Facility', 'Total Hours']);
    _facilitySummaries.forEach((key, value) {
      rows.add([key, value.totalHours.toStringAsFixed(2)]);
    });
    rows.add([]);
    rows.add(['Attendance Summary by Designation']);
    rows.add(['Designation', 'Total Hours']);
    _designationSummaries.forEach((key, value) {
      rows.add([key, value.totalHours.toStringAsFixed(2)]);
    });
    String csvData = const ListToCsvConverter().convert(rows);
    _triggerDownload(utf8.encode(csvData), 'hq_attendance_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    setState(() => _isExporting = false);
  }

  Future<void> _exportChartsToPdf() async {
    setState(() => _isExporting = true);
    try {
      final barChartBytes = await _captureChartPng(_barChartKey);
      final facilityPieBytes = await _captureChartPng(_facilityPieChartKey);
      final designationPieBytes = await _captureChartPng(_designationPieChartKey);
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(text: "HQ Attendance Charts Report"),
        build: (context) => [
          pw.Text("Filters Applied", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text("Date Range: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}"),
          pw.Text("States: ${_selectedStates.length == _availableStates.length ? 'All' : _selectedStates.join(', ')}"),
          pw.Text("Facilities: ${_selectedFacilities.length == _availableFacilities.length ? 'All' : _selectedFacilities.join(', ')}"),
          pw.Text("Designations: ${_selectedDesignations.length == _availableDesignations.length ? 'All' : _selectedDesignations.join(', ')}"),
          pw.Divider(height: 20),
          if (barChartBytes != null) ...[
            pw.Text("Top 15 Facilities by Hours", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(barChartBytes), fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (facilityPieBytes != null) ...[
            pw.Text("Facility Hours Distribution", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(facilityPieBytes), fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (designationPieBytes != null) ...[
            pw.Text("Designation Hours Distribution", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(designationPieBytes), fit: pw.BoxFit.contain, height: 250),
          ],
        ],
      ));
      final pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'hq_attendance_charts_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', 'application/pdf');
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing chart: $e");
      return null;
    }
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