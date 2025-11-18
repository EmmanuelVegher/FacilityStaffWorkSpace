// A DEDICATED, FEATURE-RICH PAGE FOR ATTENDANCE ANALYSIS (FINAL OPTIMIZED VERSION)
// FINAL REFACTOR: IMPLEMENTED EFFICIENT collectionGroup QUERY FOR SCALABILITY
// REWRITTEN BY GEMINI WITH INTERACTIVE CHARTS AND ROBUST ERROR HANDLING

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:service_delivery_workspace/screens/attendance_analysis_page/recommendation_info.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // COMMENTED OUT - Using OpenStreetMap instead
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show Blob, Url, document, AnchorElement, window;
import 'package:excel/excel.dart' as xls;

import '../../widgets/drawer2.dart';
import 'daily_record_management_page.dart'; // Assuming a state-level drawer

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

// EXPANDED StaffInfo to include all details for the export
class StaffInfo {
  final String id;
  final String name; // Combined name: "John Doe"
  final String firstName;
  final String lastName;
  final String location; // Assigned Facility
  final String designation;
  final String supervisorEmail;
  final String state;
  final String department;
  final String mobile;
  final String email;
  final String staffCategory;

  StaffInfo({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.location,
    required this.designation,
    required this.supervisorEmail,
    required this.state,
    required this.department,
    required this.mobile,
    required this.email,
    required this.staffCategory,
  });
}

class FacilityDetails {
  final String name;
  final GeoPoint coordinates;
  final double radius; // in meters

  FacilityDetails(
      {required this.name, required this.coordinates, required this.radius});
}

// EXPANDED AttendanceRecord to include string values for the export
class AttendanceRecord {
  final String recordId;
  final String staffId;
  final String staffName;
  final String assignedFacility;
  final DateTime date;
  final double hoursWorked;
  final GeoPoint? clockInLocation;
  final GeoPoint? clockOutLocation;
  final String deductionStatus;
  final RecommendationInfo? recommendation;
  // New fields for detailed export
  final String? clockInTime;
  final String? clockOutTime;
  final String? clockInLocationString;
  final String? clockOutLocationString;
  final String? durationWorked;

  AttendanceRecord({
    required this.recordId,
    required this.staffId,
    required this.staffName,
    required this.assignedFacility,
    required this.date,
    required this.hoursWorked,
    this.clockInLocation,
    this.clockOutLocation,
    this.deductionStatus = 'None',
    this.recommendation,
    // Add new fields to constructor
    this.clockInTime,
    this.clockOutTime,
    this.clockInLocationString,
    this.clockOutLocationString,
    this.durationWorked,
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

  // This map now stores the full AttendanceRecord for a specific day.
  // This is essential for accessing the recordId when the user wants to edit it.
  Map<DateTime, AttendanceRecord> dailyRecords = {};

  // For high-level summaries (like total by designation), we still need to sum hours.
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

class _ChartData {
  final String category;
  final double value;
  final Color? color = null;

  _ChartData(this.category, this.value);
}

// --- MAIN WIDGET ---
class AttendanceAnalysisPage extends StatefulWidget {
  const AttendanceAnalysisPage({super.key});
  @override
  _AttendanceAnalysisPageState createState() => _AttendanceAnalysisPageState();
}

class _AttendanceAnalysisPageState extends State<AttendanceAnalysisPage> {
  // --- Services & State ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _isUpdateBannerVisible = true;
  // This will hold the detailed staff info needed for the export.
  Map<String, StaffInfo> _staffDetailsMap = {};

  final ScrollController _facilityTableController = ScrollController();
  final ScrollController _designationTableController = ScrollController();
  List<AttendanceRecord> _recordsWithRecommendations = [];
  bool _isPageReady = false;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  String? _userState;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  static const String _allFacilitiesOption = "(All Facilities)";
  static const String _allDesignationsOption = "(All Designations)";
  static const String _allStaffOption = "(All Staff)";

  List<String> _availableFacilities = [];
  List<String> _selectedFacilities = [];

  List<String> _availableDesignations = [];
  List<String> _selectedDesignations = [];

  List<StaffInfo> _availableStaff = [];
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

  // *** NEW: TooltipBehavior for interactive charts ***
  late TooltipBehavior _tooltipBehavior;

  // --- Map and Outlier State ---
  // GoogleMapController? _mapController; // COMMENTED OUT - Using OpenStreetMap instead
  MapController? _mapController;
  List<Marker> _mapMarkers =
      []; // Changed from Set<Marker> to List<Marker> for flutter_map
  Map<String, FacilityDetails> _facilityDetails = {};
  List<OutlierRecord> _outlierRecords = [];
  // static const CameraPosition _initialCameraPosition = CameraPosition( // COMMENTED OUT - Using OpenStreetMap instead
  //   target: LatLng(9.0820, 8.6753), // Center of Nigeria
  //   zoom: 5.5,
  // );
  static const latlng.LatLng _initialMapCenter =
      latlng.LatLng(9.0820, 8.6753); // Center of Nigeria
  String? _currentUserEmail;
  Map<String, StaffInfo> _staffInfoByNameMap = {};

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _currentUserEmail = _firebaseAuth.currentUser?.email;
    _initializeFilters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _facilityTableController.dispose();
    _designationTableController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeFilters() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userState = staffDoc.data()?['state'] as String?;
        });

        if (_userState != null) {
          // Fetch available facilities and their details
          final facilitiesSnapshot = await _firestore
              .collection('Facilities')
              .where('state', isEqualTo: _userState)
              .where('category', isEqualTo: 'Facility')
              .get();

          final List<String> facilities = [];
          final Map<String, FacilityDetails> facilityDetailsMap = {};

          for (var doc in facilitiesSnapshot.docs) {
            final data = doc.data();
            final name = data['LocationName'] as String?;
            final latString = data['Latitude'] as String?;
            final lonString = data['Longitude'] as String?;
            final radiusString = data['Radius'] as String?;

            if (name != null &&
                latString != null &&
                lonString != null &&
                radiusString != null) {
              final lat = double.tryParse(latString);
              final lon = double.tryParse(lonString);
              final radius = double.tryParse(radiusString);

              if (lat != null && lon != null && radius != null) {
                facilities.add(name);
                facilityDetailsMap[name] = FacilityDetails(
                  name: name,
                  coordinates: GeoPoint(lat, lon),
                  radius: radius,
                );
              }
            }
          }
          facilities.sort();

          // Fetch available designations
          final designations = await _getUniqueFieldValues('designation');

          if (mounted) {
            // Set the available options and default selections
            setState(() {
              _availableFacilities = facilities;
              _facilityDetails = facilityDetailsMap;
              _availableDesignations = designations;

              // By default, select all facilities and designations for the initial load
              _selectedFacilities = List.from(_availableFacilities);
              _selectedDesignations = List.from(_availableDesignations);
            });

            // --- ADDED THIS LOGIC ---
            // After setting default filters, update the staff list based on them.
            await _updateStaffFilter();
            // Now, automatically load the dashboard data with these default selections.
            await _loadDashboardData();
            // ------------------------
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error initializing filters: $e");
      }
    }
  }

  Future<List<String>> _getUniqueFieldValues(String field) async {
    if (_userState == null) return [];
    final snapshot = await _firestore
        .collection('Staff')
        .where('state', isEqualTo: _userState)
        .where('staffCategory', isEqualTo: "Facility Staff")
        .where('accountStatus', isEqualTo: 'Active')
        .get();
    final Set<String> values = {};
    for (final doc in snapshot.docs) {
      final value = doc.data()[field] as String?;
      if (value != null && value.isNotEmpty) values.add(value);
    }
    final sortedList = values.toList()..sort();
    return sortedList;
  }

  Future<void> _updateStaffFilter() async {
    if (_userState == null) return;
    var query = _firestore
        .collection('Staff')
        .where('state', isEqualTo: _userState)
        .where('accountStatus', isEqualTo: 'Active');

    if (_selectedDesignations.isNotEmpty &&
        _selectedDesignations.length <= 30) {
      query = query.where('designation', whereIn: _selectedDesignations);
    }

    final snapshot = await query.get();
    var staffList = snapshot.docs.map((doc) {
      final data = doc.data();
      final firstName = data['firstName'] as String? ?? '';
      final lastName = data['lastName'] as String? ?? '';
      return StaffInfo(
        id: doc.id,
        name: '$firstName $lastName'.trim(),
        firstName: firstName,
        lastName: lastName,
        location: data['location'] as String? ?? '',
        designation: data['designation'] as String? ?? '',
        supervisorEmail: data['supervisorEmail'] as String? ?? '',
        // Add new fields
        state: data['state'] as String? ?? '',
        department: data['department'] as String? ?? '',
        mobile: data['mobile'] as String? ?? '',
        email: data['emailAddress'] as String? ?? '',
        staffCategory: data['staffCategory'] as String? ?? '',
      );
    }).toList();

    if (_selectedFacilities.isNotEmpty) {
      staffList
          .retainWhere((staff) => _selectedFacilities.contains(staff.location));
    }

    staffList.sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _availableStaff = staffList;
        final availableStaffIds = _availableStaff.map((s) => s.id).toSet();
        _selectedStaffIds.retainWhere((id) => availableStaffIds.contains(id));
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (_userState == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("User state not found.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // --- QUERY MODIFICATION ---
      // Start with the base query, scoped to the user's state and active staff.
      var staffQuery = _firestore
          .collection('Staff')
          .where('state', isEqualTo: _userState)
          .where('accountStatus', isEqualTo: 'Active');

      // Apply optional dropdown filters
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
      // Create the comprehensive list of StaffInfo objects with all new fields
      var staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        return StaffInfo(
          id: doc.id,
          name: '$firstName $lastName'.trim(),
          firstName: firstName,
          lastName: lastName,
          location: data['location'] as String? ?? 'N/A',
          designation: data['designation'] as String? ?? 'N/A',
          supervisorEmail: data['supervisorEmail'] as String? ?? '',
          state: data['state'] as String? ?? 'N/A',
          department: data['department'] as String? ?? 'N/A',
          mobile: data['mobile'] as String? ?? 'N/A',
          email: data['emailAddress'] as String? ?? 'N/A',
          staffCategory: data['staffCategory'] as String? ?? 'N/A',
        );
      }).toList();

      if (_selectedFacilities.isNotEmpty) {
        staffList.retainWhere(
            (staff) => _selectedFacilities.contains(staff.location));
      }

      if (staffList.isEmpty) {
        _processAndAggregateData([], [], [], {});
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Create lookup maps for efficiency
      final staffInfoByNameMap = {
        for (var staff in staffList) staff.name: staff
      };
      final filteredStaffIds = staffList.map((s) => s.id).toSet();
      final staffInfoMap = {for (var s in staffList) s.id: s};

      final recordsSnapshot = await _firestore
          .collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp',
              isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
          .get();

      List<AttendanceRecord> allRecords = [];

      for (final recordDoc in recordsSnapshot.docs) {
        final staffId = recordDoc.reference.parent.parent!.id;

        // Only process records for the staff who passed our initial filters
        if (filteredStaffIds.contains(staffId)) {
          final staffInfo = staffInfoMap[staffId]!;
          final data = recordDoc.data();

          RecommendationInfo? recommendation;
          if (data['recommendation'] != null && data['recommendation'] is Map) {
            recommendation = RecommendationInfo.fromMap(
                data['recommendation'] as Map<String, dynamic>);
          }

          final recordTimestamp = (data['timestamp'] as Timestamp).toDate();
          GeoPoint? clockInPoint;
          final clockInLat = (data['clockInLatitude'] as num?)?.toDouble();
          final clockInLon = (data['clockInLongitude'] as num?)?.toDouble();
          if (clockInLat != null && clockInLon != null) {
            clockInPoint = GeoPoint(clockInLat, clockInLon);
          }

          GeoPoint? clockOutPoint;
          final clockOutLat = (data['clockOutLatitude'] as num?)?.toDouble();
          final clockOutLon = (data['clockOutLongitude'] as num?)?.toDouble();
          if (clockOutLat != null && clockOutLon != null) {
            clockOutPoint = GeoPoint(clockOutLat, clockOutLon);
          }

          allRecords.add(AttendanceRecord(
            recordId: recordDoc.id,
            staffId: staffId,
            staffName: staffInfo.name,
            assignedFacility: staffInfo.location,
            date: recordTimestamp,
            hoursWorked: (data['noOfHours'] as num? ?? 0.0).toDouble(),
            clockInLocation: clockInPoint,
            clockOutLocation: clockOutPoint,
            deductionStatus: data['deductionStatus'] as String? ?? 'None',
            recommendation: recommendation,
            clockInTime: data['clockIn'] as String?,
            clockOutTime: data['clockOut'] as String?,
            clockInLocationString: data['clockInLocation'] as String?,
            clockOutLocationString: data['clockOutLocation'] as String?,
            durationWorked: data['durationWorked'] as String?,
          ));
        }
      }

      final dateRange = List.generate(
          _endDate.difference(_startDate).inDays + 1,
          (i) => _startDate.add(Duration(days: i)));

      _processAndAggregateData(
          allRecords, staffList, dateRange, staffInfoByNameMap);
    } catch (e, stack) {
      debugPrint("Error loading dashboard data: $e\n$stack");
      if (mounted) {
        setState(() => _errorMessage =
            "An error occurred. Check Firestore indexes. Error: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAndAggregateData(
    List<AttendanceRecord> records,
    List<StaffInfo> staff,
    List<DateTime> dateRange,
    Map<String, StaffInfo> staffInfoByNameMap, // <-- ACCEPT THE MAP
  ) {
    final facilityData = <String, AggregatedSummary>{};
    final designationData = <String, AggregatedSummary>{};
    final facilityStaffData = <String, Map<String, AggregatedSummary>>{};
    final staffMap = {for (var s in staff) s.id: s};

    for (final record in records) {
      final staffInfo = staffMap[record.staffId];
      if (staffInfo == null) continue;

      final day =
          DateTime(record.date.year, record.date.month, record.date.day);

      final facilitySummary = facilityData.putIfAbsent(staffInfo.location,
          () => AggregatedSummary(name: staffInfo.location));
      facilitySummary.dailyHours[day] =
          (facilitySummary.dailyHours[day] ?? 0) + record.hoursWorked;

      final designationSummary = designationData.putIfAbsent(
          staffInfo.designation,
          () => AggregatedSummary(name: staffInfo.designation));
      designationSummary.dailyHours[day] =
          (designationSummary.dailyHours[day] ?? 0) + record.hoursWorked;

      final staffMapForFacility =
          facilityStaffData.putIfAbsent(staffInfo.location, () => {});
      final staffSummary = staffMapForFacility.putIfAbsent(
          staffInfo.name, () => AggregatedSummary(name: staffInfo.name));
      staffSummary.dailyRecords[day] = record;
    }

    _generateMapMarkers(records);
    _findOutliers(records);

    final recommendations =
        records.where((r) => r.deductionStatus != 'None').toList();
    recommendations.sort((a, b) => b.date.compareTo(a.date));

    // --- FINAL STATE UPDATE ---
    // This is the single source of truth for rebuilding the UI.
    if (mounted) {
      setState(() {
        _allRecords = records;
        _recordsWithRecommendations = recommendations;
        _facilitySummaries = facilityData;
        _designationSummaries = designationData;
        _facilityStaffSummaries = facilityStaffData;
        _dateRangeForTables = dateRange;
        _totalHoursAll = records.fold(0.0, (sum, r) => sum + r.hoursWorked);
        _staffInfoByNameMap =
            staffInfoByNameMap; // <-- SAVE THE MAP TO STATE HERE
        _staffDetailsMap =
            staffMap; // Make detailed staff data available for export
      });
    }
  }

  // --- NEW METHOD: _exportAttendanceListToCsv ---
  Future<void> _exportAttendanceListToCsv() async {
    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No attendance data to export.")),
      );
      return;
    }

    setState(() => _isExporting = true);
    await Future.delayed(
        const Duration(milliseconds: 100)); // Allow UI to update

    try {
      List<List<dynamic>> rows = [];

      // Header Row
      rows.add([
        'First Name',
        'Last Name',
        'State',
        'Department',
        'Designation',
        'Assigned Facility',
        'Mobile',
        'Email Address',
        'Staff Category',
        'Date',
        'Clock In Time',
        'Clock Out Time',
        'Hours Worked',
        'Duration Worked',
        'Clock In Location',
        'Clock In Latitude',
        'Clock In Longitude',
        'Clock Out Location',
        'Clock Out Latitude',
        'Clock Out Longitude',
        'Deduction Status',
        'Comments/Reason',
        'Recommended By'
      ]);

      // Create a sorted list of records for a clean report
      final sortedRecords = List<AttendanceRecord>.from(_allRecords);
      sortedRecords.sort((a, b) {
        int nameComp = a.staffName.compareTo(b.staffName);
        if (nameComp != 0) return nameComp;
        return a.date.compareTo(b.date);
      });

      for (final record in sortedRecords) {
        final staffInfo = _staffDetailsMap[record.staffId];

        if (staffInfo == null) continue; // Skip if staff details not found

        rows.add([
          staffInfo.firstName,
          staffInfo.lastName,
          staffInfo.state,
          staffInfo.department,
          staffInfo.designation,
          staffInfo.location, // Assigned Facility
          staffInfo.mobile,
          staffInfo.email,
          staffInfo.staffCategory,
          DateFormat('yyyy-MM-dd').format(record.date),
          record.clockInTime ?? 'N/A',
          record.clockOutTime ?? 'N/A',
          record.hoursWorked.toStringAsFixed(2),
          record.durationWorked ?? 'N/A',
          record.clockInLocationString ?? 'N/A',
          record.clockInLocation?.latitude ?? '',
          record.clockInLocation?.longitude ?? '',
          record.clockOutLocationString ?? 'N/A',
          record.clockOutLocation?.latitude ?? '',
          record.clockOutLocation?.longitude ?? '',
          record.deductionStatus,
          record.recommendation?.notes ?? '',
          record.recommendation?.recommenderName ?? ''
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(
        utf8.encode(csvData),
        'attendance_list_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error generating detailed CSV: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAttendanceListToExcel() async {
    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No attendance data to export.")),
      );
      return;
    }

    setState(() => _isExporting = true);
    // Give the UI a moment to show the loading indicator
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // 1. Create a new Excel document
      var excel = xls.Excel.createExcel();

      // ===================================================================
      //  SHEET 1: ATTENDANCE LIST
      // ===================================================================
      xls.Sheet sheetObject = excel['Attendance']; // Create a sheet

      // 2. Define a style for the header row (Bold text)
      var headerStyle = xls.CellStyle(
        bold: true,
        textWrapping: xls.TextWrapping.WrapText,
        verticalAlign: xls.VerticalAlign.Center,
        horizontalAlign: xls.HorizontalAlign.Center,
        // backgroundColorHex: '#FFD3D3D3', // Light grey background
      );

      // 3. Create the list of headers
      List<String> headers = [
        'First Name',
        'Last Name',
        'State',
        'Department',
        'Designation',
        'Assigned Facility',
        'Mobile',
        'Email Address',
        'Staff Category',
        'Date',
        'Clock In Time',
        'Clock Out Time',
        'Hours Worked',
        'Duration Worked',
        'Clock In Location',
        'Clock In Latitude',
        'Clock In Longitude',
        'Clock Out Location',
        'Clock Out Latitude',
        'Clock Out Longitude',
        'Deduction Status',
        'Comments/Reason',
        'Recommended By'
      ];

      // 4. Apply headers and their style to the first row
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // 5. Sort data for a clean report
      final sortedRecords = List<AttendanceRecord>.from(_allRecords);
      sortedRecords.sort((a, b) {
        int nameComp = a.staffName.compareTo(b.staffName);
        if (nameComp != 0) return nameComp;
        return a.date.compareTo(b.date);
      });

      // 6. Populate data rows
      for (int i = 0; i < sortedRecords.length; i++) {
        final record = sortedRecords[i];
        final staffInfo = _staffDetailsMap[record.staffId];
        if (staffInfo == null) continue;

        // Create a list of values for the current row
        List<xls.CellValue> rowData = [
          xls.TextCellValue(staffInfo.firstName),
          xls.TextCellValue(staffInfo.lastName),
          xls.TextCellValue(staffInfo.state),
          xls.TextCellValue(staffInfo.department),
          xls.TextCellValue(staffInfo.designation),
          xls.TextCellValue(staffInfo.location),
          xls.TextCellValue(staffInfo.mobile),
          xls.TextCellValue(staffInfo.email),
          xls.TextCellValue(staffInfo.staffCategory),
          xls.TextCellValue(DateFormat('yyyy-MM-dd').format(record.date)),
          xls.TextCellValue(record.clockInTime ?? 'N/A'),
          xls.TextCellValue(record.clockOutTime ?? 'N/A'),
          xls.DoubleCellValue(
              record.hoursWorked), // Use DoubleCellValue for numbers
          xls.TextCellValue(record.durationWorked ?? 'N/A'),
          xls.TextCellValue(record.clockInLocationString ?? 'N/A'),
          xls.TextCellValue(record.clockInLocation?.latitude.toString() ?? ''),
          xls.TextCellValue(record.clockInLocation?.longitude.toString() ?? ''),
          xls.TextCellValue(record.clockOutLocationString ?? 'N/A'),
          xls.TextCellValue(record.clockOutLocation?.latitude.toString() ?? ''),
          xls.TextCellValue(
              record.clockOutLocation?.longitude.toString() ?? ''),
          xls.TextCellValue(record.deductionStatus),
          xls.TextCellValue(record.recommendation?.notes ?? ''),
          xls.TextCellValue(record.recommendation?.recommenderName ?? '')
        ];

        // Add the row data to the sheet
        sheetObject.insertRowIterables(rowData, i + 1, startingColumn: 0);
      }

      // ===================================================================
      //  NEW --- SHEET 2: GEO-FENCED FACILITIES --- NEW
      // ===================================================================
      xls.Sheet facilitySheet = excel['Geo-Fenced Facilities'];

      // Define headers for the new sheet
      List<String> facilityHeaders = [
        'Facility Name',
        'LGA',
        'State',
        'Latitude',
        'Longitude',
        'Radius (meters)'
      ];

      // Apply headers and style to the first row of the new sheet
      for (var i = 0; i < facilityHeaders.length; i++) {
        var cell = facilitySheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(facilityHeaders[i]);
        cell.cellStyle = headerStyle;
      }

      // Query Firestore for facilities in the user's state
      final facilitiesSnapshot = await _firestore
          .collection('Facilities')
          .where('state', isEqualTo: _userState)
          .get();

      // Populate the facility data rows
      for (int i = 0; i < facilitiesSnapshot.docs.length; i++) {
        final doc = facilitiesSnapshot.docs[i];
        final data = doc.data();

        List<xls.CellValue> rowData = [
          xls.TextCellValue(data['LocationName'] as String? ?? 'N/A'),
          xls.TextCellValue(data['lga'] as String? ?? 'N/A'),
          xls.TextCellValue(data['state'] as String? ?? 'N/A'),
          xls.TextCellValue(data['Latitude'] as String? ?? ''),
          xls.TextCellValue(data['Longitude'] as String? ?? ''),
          xls.TextCellValue(data['Radius'] as String? ?? '0'),
        ];
        facilitySheet.insertRowIterables(rowData, i + 1, startingColumn: 0);
      }

      // Auto-fit columns for the new sheet
      // for (var i = 0; i < facilityHeaders.length; i++) {
      //   facilitySheet.xls.setColAutoFit(i);
      // }

      // 7. Auto-fit all columns
      // for (var i = 0; i < headers.length; i++) {
      //   sheetObject.setColAutoFit(i);
      // }

      // 8. Save the file and trigger the download
      final fileBytes = excel.save();
      if (fileBytes != null) {
        _triggerDownload(
          fileBytes,
          'Attendance_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
          // This is the correct MIME type for modern Excel files
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating Excel file: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // --- RENAMED: _exportToCsv -> _exportSummaryToCsv ---
  Future<void> _exportSummaryToCsv() async {
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
    _triggerDownload(utf8.encode(csvData),
        'attendance_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    setState(() => _isExporting = false);
  }

// --- NEW, FULLY CORRECTED WIDGET ---

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
        subtitle: Text(
            "${_recordsWithRecommendations.length} record(s) with an action taken"),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Staff')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Recommendation')),
                DataColumn(label: Text('Recommended By')), // New column
                DataColumn(label: Text('Reason / Notes')),
              ],
              rows: _recordsWithRecommendations.map((record) {
                String statusText = record.deductionStatus;
                Color statusColor = Colors.black;
                final rec = record.recommendation;

                // Use a switch for clarity
                switch (record.deductionStatus) {
                  case 'Partial':
                    statusText =
                        'Partial Deduction (${rec?.deductedHours ?? 0} hrs)';
                    statusColor = Colors.orange.shade800;
                    break;
                  case 'Full':
                    statusText = 'Full Deduction (8 hrs)';
                    statusColor = Colors.red.shade800;
                    break;
                  case 'ApprovedPartial':
                    // --- THE FIX ---
                    // Read from the main hours field, which is now the source of truth for approved time.
                    statusText =
                        'Partial Approval (${record.hoursWorked.toInt()} hr${record.hoursWorked == 1 ? '' : 's'})';
                    statusColor = Colors.blue.shade800;
                    break;
                  case 'ApprovedFull':
                    statusText = 'Full Approval (8 hrs)';
                    statusColor = Colors.indigo.shade800;
                    break;
                  default:
                    // Fallback for any other status
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: statusColor),
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

  // Add this new method inside the _AttendanceAnalysisPageState class

  Widget _buildUpdateBanner() {
    // Define the expiry date for the notification - extended to show longer
    final DateTime expiryDate = DateTime(2025, 12, 31);

    // Check if the banner should be visible
    if (DateTime.now().isBefore(expiryDate) && _isUpdateBannerVisible) {
      return MaterialBanner(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.blue.shade50,
        surfaceTintColor: Colors.white,
        elevation: 1,
        leading: Icon(Icons.info_outline, color: Colors.blue.shade800),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New Updates! You can now make recommendations for Partial/Full Deductions of filled attendance either due to truancy etc or Partial Approval/Full Approval of attendance attendance for missed days and view staff you directly supervise. Action buttons are enabled only for your team.',
              style: TextStyle(color: Colors.blue.shade900),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // Open YouTube link in new tab
                if (kIsWeb) {
                  html.window.open('https://youtu.be/I_D7rWG3PiQ', 'youtube_tutorial');
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill,
                      color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'View Tutorial',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('DISMISS',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() {
                _isUpdateBannerVisible =
                    false; // Hide the banner for this session
              });
            },
          ),
        ],
      );
    } else {
      // Return an empty widget if the date has passed or banner is dismissed
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Analysis Dashboard",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isExporting)
            const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if (value == 'excel_list') {
                  _exportAttendanceListToExcel(); // Call new Excel method
                }
                if (value == 'csv_list') _exportAttendanceListToCsv();
                if (value == 'csv_summary') _exportSummaryToCsv();
                if (value == 'absent_csv') _downloadAbsentStaffList();
                if (value == 'pdf') _exportChartsToPdf();
              },
              enabled: !_isLoading && _allRecords.isNotEmpty,
              itemBuilder: (context) => [
                // New Menu Item for the native Excel file
                const PopupMenuItem(
                  value: 'excel_list',
                  child: ListTile(
                    leading: Icon(Icons.grid_on_sharp, color: Colors.green),
                    title: Text("Download List (Excel)"),
                  ),
                ),

                const PopupMenuItem(
                  value: 'csv_list',
                  child: ListTile(
                    leading: Icon(Icons.list_alt_rounded),
                    title: Text("Download List (CSV)"),
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv_summary',
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined),
                    title: Text("Download Summary (CSV)"),
                  ),
                ),

                const PopupMenuItem(
                  value: 'absent_csv',
                  child: ListTile(
                    leading: Icon(Icons.person_off_outlined, color: Colors.red),
                    title: Text("Download Absent Staff (CSV)"),
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text("Export Charts (PDF)"),
                  ),
                ),
              ],
            )
        ],
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildUpdateBanner(),
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
                if (_errorMessage != null)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16)),
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
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${DateFormat("MMMM d,yyyy").format(_startDate)} - ${DateFormat("MMMM d,yyyy").format(_endDate)}',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField(
                items: [
                  MultiSelectItem<String>(
                      _allFacilitiesOption, _allFacilitiesOption),
                  ..._availableFacilities
                      .map((f) => MultiSelectItem<String>(f, f)),
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
                  _selectedFacilities.length == _availableFacilities.length &&
                          _availableFacilities.isNotEmpty
                      ? "All Facilities Selected"
                      : _selectedFacilities.isEmpty
                          ? "Facility"
                          : "${_selectedFacilities.length} Facilit${_selectedFacilities.length == 1 ? 'y' : 'ies'} selected",
                  style: TextStyle(color: Colors.teal[800], fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                // In the MultiSelectDialogField for Facilities:
                onConfirm: (results) {
                  setState(() {
                    final castedResults = results.cast<String>();
                    // If "All Facilities" is selected, select everything.
                    if (castedResults.contains(_allFacilitiesOption)) {
                      _selectedFacilities =
                          List<String>.from(_availableFacilities);
                    } else {
                      // Otherwise, just take the specific selections.
                      _selectedFacilities = castedResults;
                    }
                    // After updating facilities, the list of available staff might change.
                    _updateStaffFilter();
                  });
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(
                      _allDesignationsOption, _allDesignationsOption),
                  ..._availableDesignations
                      .map((d) => MultiSelectItem<String>(d, d)),
                ],
                initialValue: _selectedDesignations,
                title: const Text("Select Designations"),
                buttonIcon:
                    Icon(Icons.work_outline, color: Colors.grey.shade700),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                buttonText: Text(
                    _selectedDesignations.length ==
                                _availableDesignations.length &&
                            _availableDesignations.isNotEmpty
                        ? "All Designations Selected"
                        : _selectedDesignations.isEmpty
                            ? "Designation"
                            : "${_selectedDesignations.length} Selected",
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                onConfirm: (values) {
                  setState(() {
                    final castedValues = values.cast<String>();
                    // If "All Designations" is selected, select everything.
                    if (castedValues.contains(_allDesignationsOption)) {
                      _selectedDesignations =
                          List<String>.from(_availableDesignations);
                    } else {
                      // Otherwise, just take the specific selections.
                      _selectedDesignations = castedValues;
                    }
                    _updateStaffFilter();
                  });
                },
                chipDisplay: MultiSelectChipDisplay.none(),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: MultiSelectDialogField<String>(
                items: [
                  MultiSelectItem<String>(_allStaffOption, "All Staff"),
                  ..._availableStaff
                      .map((s) => MultiSelectItem<String>(s.id, s.name)),
                ],
                initialValue: _selectedStaffIds,
                title: const Text("Select Staff"),
                buttonIcon:
                    Icon(Icons.person_outline, color: Colors.grey.shade700),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                buttonText: Text(
                  _selectedStaffIds.length == _availableStaff.length &&
                          _availableStaff.isNotEmpty
                      ? "All Staff Selected"
                      : _selectedStaffIds.isEmpty
                          ? "Staff"
                          : "${_selectedStaffIds.length} Selected",
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                onConfirm: (values) {
                  setState(() {
                    final castedValues = values.cast<String>();
                    // If "All Staff" is selected, select all available staff IDs.
                    if (castedValues.contains(_allStaffOption)) {
                      _selectedStaffIds =
                          _availableStaff.map((s) => s.id).toList();
                    } else {
                      // Otherwise, just take the specific selections.
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
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

  Widget _buildDashboardBody() {
    final bool hasLoadedData = _allRecords.isNotEmpty || _errorMessage != null;
    final top15Facilities = _facilitySummaries.values.toList()
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));
    final chartData = top15Facilities
        .take(15)
        .map((s) => _ChartData(s.name, s.totalHours))
        .toList();

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          if (hasLoadedData) ...[
            const SizedBox(height: 24),
            _buildKpiSection(),
            const SizedBox(height: 24),
            _buildRecommendationsLogSection(),
            const SizedBox(height: 24),
            _buildLocationMapCard(),
            const SizedBox(height: 24),
            _buildOutlierAnalysisSection(),
            const SizedBox(height: 24),
            _buildChartCard(
                "Top 15 Facilities by Hours",
                SfCartesianChart(
                    key: _barChartKey,
                    tooltipBehavior: _tooltipBehavior,
                    primaryXAxis: CategoryAxis(
                      labelRotation: -45,
                      majorGridLines: const MajorGridLines(width: 0),
                      labelIntersectAction: AxisLabelIntersectAction.rotate45,
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                    primaryYAxis: NumericAxis(
                        majorGridLines: const MajorGridLines(
                            width: 0.5, dashArray: [5, 5])),
                    series: <CartesianSeries>[
                      BarSeries<_ChartData, String>(
                          dataSource: chartData,
                          xValueMapper: (d, _) => d.category,
                          yValueMapper: (d, _) => d.value,
                          name: "Hours",
                          dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              labelAlignment: ChartDataLabelAlignment.top),
                          color: Colors.teal,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(5)))
                    ])),
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
            child: Text("Clock-in & Clock-out Locations",
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          SizedBox(
            height: 450,
            child: _isPageReady
                ? _buildGoogleMap()
                : const Center(child: Text("Initializing Map...")),
          ),
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
          initialZoom: 6.0,
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
        subtitle:
            const Text("Clock events outside any recognized facility radius"),
        children: [
          if (_outlierRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                  child: Text(
                      "No significant outliers found for the selected criteria.",
                      style: TextStyle(fontStyle: FontStyle.italic))),
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
                rows: _outlierRecords
                    .map((outlier) => DataRow(
                          cells: [
                            DataCell(Text(outlier.staffName)),
                            DataCell(
                                Text(DateFormat.yMd().format(outlier.date))),
                            DataCell(Text(outlier.type)),
                            DataCell(Text(outlier.assignedFacility)),
                            DataCell(Text(
                                outlier.distanceInMeters.toStringAsFixed(0),
                                style: const TextStyle(
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

  Widget _buildKpiSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Hours Logged", _totalHoursAll, Icons.timer_rounded,
            Colors.blue.shade800,
            fractionDigits: 1),
        _buildKpiCard(
            "Active Staff",
            _allRecords.map((r) => r.staffId).toSet().length,
            Icons.person_4_rounded,
            Colors.green.shade700),
        _buildKpiCard("Facilities Reporting", _facilitySummaries.keys.length,
            Icons.location_city_rounded, Colors.purple.shade700),
      ],
    );
  }

  Widget _buildKpiCard(String title, num value, IconData icon, Color color,
      {int fractionDigits = 0, String suffix = ''}) {
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
              CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, size: 28, color: color)),
              const SizedBox(height: 16),
              AnimatedNumberText(
                value,
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: color),
                fractionDigits: fractionDigits,
                suffix: suffix,
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(height: 350, child: chartWidget),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPieChart(
      String title, Map<String, AggregatedSummary> summaryMap,
      {Key? key}) {
    if (summaryMap.isEmpty) return const SizedBox.shrink();
    final sortedList = summaryMap.values.toList()
      ..sort((a, b) => b.totalHours.compareTo(a.totalHours));
    List<_ChartData> chartData = [];
    double othersHours = 0;
    for (int i = 0; i < sortedList.length; i++) {
      if (i < 6) {
        chartData.add(_ChartData(sortedList[i].name, sortedList[i].totalHours));
      } else {
        othersHours += sortedList[i].totalHours;
      }
    }
    if (othersHours > 0) {
      chartData.add(_ChartData("Others", othersHours));
    }
    return _buildChartCard(
      title,
      SfCircularChart(
          tooltipBehavior: _tooltipBehavior,
          legend: const Legend(
              isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            PieSeries<_ChartData, String>(
              dataSource: chartData,
              xValueMapper: (d, _) => d.category,
              yValueMapper: (d, _) => d.value,
              dataLabelMapper: (d, _) =>
                  '${d.category}\n${d.value.toStringAsFixed(1)} hrs',
              dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelPosition: ChartDataLabelPosition.outside),
            )
          ]),
      key: key,
    );
  }

  Widget _buildFacilitySummaryTable() {
    final sortedFacilities = _facilityStaffSummaries.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Facility",
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _facilityTableController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Location / Staff')),
                    ..._dateRangeForTables.map((date) => DataColumn(
                        label: Text(DateFormat('EEE\nMMM dd').format(date)),
                        numeric: true)),
                    const DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: sortedFacilities.expand((facility) {
                    final staffSummaries = _facilityStaffSummaries[facility]!;
                    final sortedStaff = staffSummaries.keys.toList()..sort();
                    final facilityTotal = staffSummaries.values
                        .fold(0.0, (sum, s) => sum + s.totalHours);

                    return [
                      // Facility Header Row
                      DataRow(
                        color: WidgetStateProperty.all(
                            Colors.blue.withOpacity(0.1)),
                        cells: [
                          DataCell(Text(facility,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          ..._dateRangeForTables.map((date) {
                            final dailyFacilityTotal = staffSummaries.values
                                .fold(
                                    0.0,
                                    (sum, s) =>
                                        sum +
                                        (s.dailyRecords[date]?.hoursWorked ??
                                            0.0));
                            return DataCell(Text(
                                dailyFacilityTotal.toStringAsFixed(2),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)));
                          }),
                          DataCell(Text(facilityTotal.toStringAsFixed(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                        ],
                      ),

                      // Rows for Each Staff Member
                      ...sortedStaff.map((staffName) {
                        final summary = staffSummaries[staffName]!;

                        // --- NEW: PERMISSION CHECK ---
                        final staffDetails = _staffInfoByNameMap[staffName];
                        final bool canEdit =
                            staffDetails?.supervisorEmail == _currentUserEmail;

                        return DataRow(cells: [
                          DataCell(Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(staffName))),
                          ..._dateRangeForTables.map((date) {
                            final recordForDay = summary.dailyRecords[date];

                            // --- RENDER 'ADD' BUTTON (with permission check) ---
                            if (recordForDay == null) {
                              return DataCell(
                                Center(
                                  child: IconButton(
                                    icon: Icon(Icons.add_comment_outlined,
                                        size: 20,
                                        color: canEdit
                                            ? Colors.blue.shade300
                                            : Colors.grey.shade400),
                                    tooltip: canEdit
                                        ? "Create & Approve Record"
                                        : "You are not this staff's supervisor",
                                    onPressed: canEdit
                                        ? () {
                                            Navigator.of(context)
                                                .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    DailyRecordManagementPage(
                                                  staffId: staffDetails!
                                                      .id, // Use reliable ID
                                                  recordId: null,
                                                  date: date,
                                                ),
                                              ),
                                            )
                                                .then((madeChanges) {
                                              if (madeChanges == true) {
                                                _loadDashboardData();
                                              }
                                            });
                                          }
                                        : null, // Disable if no permission
                                  ),
                                ),
                              );
                            }
                            // --- RENDER 'EDIT' BUTTON (with permission check) ---
                            else {
                              // ... (logic to get hours, backgroundColor, statusIcon remains the same)
                              final hours = recordForDay.hoursWorked;
                              Color backgroundColor = Colors.transparent;
                              IconData? statusIcon;
                              Color? iconColor;

                              switch (recordForDay.deductionStatus) {
                                case 'Partial':
                                  backgroundColor =
                                      Colors.orange.withOpacity(0.1);
                                  statusIcon = Icons.warning_amber_rounded;
                                  iconColor = Colors.orange.shade700;
                                  break;
                                case 'Full':
                                  backgroundColor = Colors.red.withOpacity(0.1);
                                  statusIcon = Icons.gpp_bad_rounded;
                                  iconColor = Colors.red.shade700;
                                  break;
                                case 'ApprovedPartial':
                                  backgroundColor =
                                      Colors.blue.withOpacity(0.1);
                                  statusIcon = Icons.thumb_up_alt_rounded;
                                  iconColor = Colors.blue.shade700;
                                  break;
                                case 'ApprovedFull':
                                  backgroundColor =
                                      Colors.green.withOpacity(0.1);
                                  statusIcon = Icons.verified_user_rounded;
                                  iconColor = Colors.green.shade700;
                                  break;
                              }

                              return DataCell(
                                Container(
                                  color: backgroundColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (statusIcon != null)
                                        Icon(statusIcon,
                                            size: 16, color: iconColor),
                                      const SizedBox(width: 4),
                                      Text(hours.toStringAsFixed(2)),
                                      IconButton(
                                        icon: Icon(Icons.edit_note_outlined,
                                            size: 20,
                                            color: canEdit
                                                ? Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                : Colors.grey.shade400),
                                        tooltip: canEdit
                                            ? "Manage Record"
                                            : "You are not this staff's supervisor",
                                        onPressed: canEdit
                                            ? () {
                                                Navigator.of(context)
                                                    .push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DailyRecordManagementPage(
                                                      staffId:
                                                          recordForDay.staffId,
                                                      recordId:
                                                          recordForDay.recordId,
                                                      date: date,
                                                    ),
                                                  ),
                                                )
                                                    .then((madeChanges) {
                                                  if (madeChanges == true) {
                                                    _loadDashboardData();
                                                  }
                                                });
                                              }
                                            : null, // Disable if no permission
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }),
                          DataCell(Text(summary.totalHours.toStringAsFixed(2))),
                        ]);
                      })
                    ];
                  }).toList(),
                ),
              ),
              // Horizontal Scroll Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: "Scroll Left",
                    onPressed: () => _facilityTableController.animateTo(
                        _facilityTableController.offset - 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: "Scroll Right",
                    onPressed: () => _facilityTableController.animateTo(
                        _facilityTableController.offset + 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryPieChart("Facility Hours Distribution", _facilitySummaries,
            key: _facilityPieChartKey),
      ],
    );
  }

  Widget _buildDesignationSummaryTable() {
    final sortedDesignations = _designationSummaries.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance by Designation",
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                controller: _designationTableController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Designation')),
                    ..._dateRangeForTables.map((date) => DataColumn(
                        label: Text(DateFormat('EEE\nMMM dd').format(date)),
                        numeric: true)),
                    const DataColumn(label: Text('Total'), numeric: true),
                  ],
                  rows: sortedDesignations.map((designation) {
                    final summary = _designationSummaries[designation]!;
                    return DataRow(cells: [
                      DataCell(Text(summary.name,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      ..._dateRangeForTables.map((date) => DataCell(Text(
                          (summary.dailyHours[date] ?? 0).toStringAsFixed(2)))),
                      DataCell(Text(summary.totalHours.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _designationTableController.animateTo(
                          _designationTableController.offset - 300,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut)),
                  IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _designationTableController.animateTo(
                          _designationTableController.offset + 300,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryPieChart(
            "Designation Hours Distribution", _designationSummaries,
            key: _designationPieChartKey),
      ],
    );
  }

  // --- HELPER METHODS (UNCHANGED FROM HERE) ---

  void _generateMapMarkers(List<AttendanceRecord> records) {
    try {
      final List<Marker> markers = [];
      if (records.isEmpty) {
        if (mounted) setState(() => _mapMarkers = []);
        return;
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
        if (record.clockOutLocation != null) {
          markers.add(Marker(
            point: latlng.LatLng(record.clockOutLocation!.latitude,
                record.clockOutLocation!.longitude),
            child: Icon(
              Icons.location_on,
              color: Colors.red,
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
          final assignedFacilityDetails =
              _facilityDetails[record.assignedFacility];
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
          final assignedFacilityDetails =
              _facilityDetails[record.assignedFacility];
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
    _triggerDownload(utf8.encode(csvData),
        'attendance_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    setState(() => _isExporting = false);
  }

  Future<void> _exportChartsToPdf() async {
    setState(() => _isExporting = true);
    try {
      final barChartBytes = await _captureChartPng(_barChartKey);
      final facilityPieBytes = await _captureChartPng(_facilityPieChartKey);
      final designationPieBytes =
          await _captureChartPng(_designationPieChartKey);
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(text: "Attendance Charts Report"),
        build: (context) => [
          pw.Text("Filters Applied",
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text(
              "Date Range: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}"),
          pw.Text(
              "Facility: ${_selectedFacilities.length == _availableFacilities.length ? 'All' : _selectedFacilities.join(', ')}"),
          pw.Text(
              "Designation: ${_selectedDesignations.length == _availableDesignations.length ? 'All' : _selectedDesignations.join(', ')}"),
          pw.Divider(height: 20),
          if (barChartBytes != null) ...[
            pw.Text("Top 15 Facilities by Hours",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(barChartBytes),
                fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (facilityPieBytes != null) ...[
            pw.Text("Facility Hours Distribution",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(facilityPieBytes),
                fit: pw.BoxFit.contain, height: 250),
            pw.SizedBox(height: 20),
          ],
          if (designationPieBytes != null) ...[
            pw.Text("Designation Hours Distribution",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Image(pw.MemoryImage(designationPieBytes),
                fit: pw.BoxFit.contain, height: 250),
          ],
        ],
      ));
      final pdfBytes = await pdf.save();
      _triggerDownload(
          pdfBytes,
          'attendance_charts_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          'application/pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadAbsentStaffList() async {
    // Show date picker to select the date
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    setState(() => _isExporting = true);

    try {
      // Fetch all active staff in the user's state
      final staffQuery = _firestore
          .collection('Staff')
          .where('state', isEqualTo: _userState)
          .where('accountStatus', isEqualTo: 'Active');

      final staffSnapshot = await staffQuery.get();
      final allStaffIds = staffSnapshot.docs.map((doc) => doc.id).toSet();
      final staffMap = {for (var doc in staffSnapshot.docs) doc.id: doc.data()};

      // Fetch attendance records for the selected date
      final recordsQuery = _firestore
          .collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: selectedDate)
          .where('timestamp', isLessThan: selectedDate.add(const Duration(days: 1)));

      final recordsSnapshot = await recordsQuery.get();
      final presentStaffIds = recordsSnapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toSet();

      // Determine absent staff
      final absentStaffIds = allStaffIds.difference(presentStaffIds);

      // Generate CSV
      List<List<dynamic>> rows = [];
      rows.add(['First Name', 'Last Name', 'Email', 'Location', 'Designation', 'Department', 'Mobile']);

      for (var id in absentStaffIds) {
        final data = staffMap[id];
        if (data != null) {
          rows.add([
            data['firstName'] ?? '',
            data['lastName'] ?? '',
            data['emailAddress'] ?? '',
            data['location'] ?? '',
            data['designation'] ?? '',
            data['department'] ?? '',
            data['mobile'] ?? '',
          ]);
        }
      }

      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(
        utf8.encode(csvData),
        'absent_staff_${DateFormat('yyyyMMdd').format(selectedDate)}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating absent staff CSV: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing chart: $e");
      return null;
    }
  }

  void _triggerDownload(List<int> bytes, String filename,
      [String mimeType = 'text/csv']) {
    if (kIsWeb) {
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
    } else {
      throw UnsupportedError('Download not supported on this platform');
    }
  }
}
