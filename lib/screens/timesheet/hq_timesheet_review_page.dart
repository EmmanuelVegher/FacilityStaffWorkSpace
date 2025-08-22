// A NATIONWIDE PAGE FOR REVIEWING STAFF TIMESHEETS (DASHBOARD VERSION V3.5 - ROBUST TIMESTAMP PARSING)

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../widgets/drawer3.dart';

// --- DATA MODELS ---
class TimesheetEntry {
  final String date;
  final String durationWorked;
  final num noOfHours;
  final bool isOffDay;
  final String projectName;

  TimesheetEntry({
    required this.date,
    required this.durationWorked,
    required this.noOfHours,
    required this.isOffDay,
    required this.projectName,
  });

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) {
    return TimesheetEntry(
      date: map['date'] as String? ?? 'N/A',
      durationWorked: map['durationWorked'] as String? ?? 'N/A',
      noOfHours: map['noOfHours'] as num? ?? 0,
      isOffDay: map['offDay'] as bool? ?? false,
      projectName: map['projectName'] as String? ?? 'N/A',
    );
  }
}

// MODIFIED: Changed Timestamp fields to DateTime and added a robust parser
class TimesheetModel {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String designation;
  final String department;
  final String location;
  final String state;
  final String? staffSignature;
  final String? staffSignatureDate;
  final DateTime? staffSignatureDateTime; // MODIFIED
  final String? projectName;
  final String facilitySupervisor;
  final String? facilitySupervisorEmail;
  final String facilitySupervisorSignatureStatus;
  final String? facilitySupervisorSignature;
  final String? facilitySupervisorSignatureDate;
  final DateTime? facilitySupervisorTimesheetSubmissionDateTime; // MODIFIED
  final String caritasSupervisor;
  final String? caritasSupervisorEmail;
  final String caritasSupervisorSignatureStatus;
  final String? caritasSupervisorSignature;
  final String? caritasSupervisorSignatureDate;
  final DateTime? caritasSupervisorTimesheetSubmissionDateTime; // MODIFIED
  final List<TimesheetEntry> entries;
  final double totalHours;

  TimesheetModel({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.designation,
    required this.department,
    required this.location,
    required this.state,
    this.staffSignature,
    this.staffSignatureDate,
    this.staffSignatureDateTime,
    this.projectName,
    required this.facilitySupervisor,
    this.facilitySupervisorEmail,
    required this.facilitySupervisorSignatureStatus,
    this.facilitySupervisorSignature,
    this.facilitySupervisorSignatureDate,
    this.facilitySupervisorTimesheetSubmissionDateTime,
    required this.caritasSupervisor,
    this.caritasSupervisorEmail,
    required this.caritasSupervisorSignatureStatus,
    this.caritasSupervisorSignature,
    this.caritasSupervisorSignatureDate,
    this.caritasSupervisorTimesheetSubmissionDateTime,
    required this.entries,
  }) : totalHours = _calculateCappedTotalHours(entries);

  static double _calculateCappedTotalHours(List<TimesheetEntry> entries) {
    if (entries.isEmpty) return 0.0;
    final Map<String, double> dailyHours = {};
    for (final entry in entries) {
      dailyHours.update(
        entry.date,
            (value) => value + entry.noOfHours.toDouble(),
        ifAbsent: () => entry.noOfHours.toDouble(),
      );
    }
    double cappedTotal = 0.0;
    for (final hours in dailyHours.values) {
      cappedTotal += (hours > 8.0) ? 8.0 : hours;
    }
    return cappedTotal;
  }

  // ADDED: Robust helper to parse Firestore Timestamps OR date Strings
  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory TimesheetModel.fromMap(Map<String, dynamic> map, String id) {
    var entriesData = (map['timesheetEntries'] as List<dynamic>?)
        ?.map((e) => TimesheetEntry.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];

    return TimesheetModel(
      staffId: map['staffId'] as String? ?? id,
      staffName: map['staffName'] as String? ?? 'N/A',
      staffEmail: map['staffEmail'] as String? ?? 'N/A',
      designation: map['designation'] as String? ?? 'N/A',
      department: map['department'] as String? ?? 'N/A',
      location: map['location'] as String? ?? 'N/A',
      state: map['state'] as String? ?? 'N/A',
      staffSignature: map['staffSignature'] as String?,
      staffSignatureDate: map['staffSignatureDate'] as String?,
      staffSignatureDateTime: _parseTimestamp(map['staffSignatureTimestamp']), // MODIFIED
      projectName: map['projectName'] as String?,
      facilitySupervisor: map['facilitySupervisor'] as String? ?? 'N/A',
      facilitySupervisorEmail: map['facilitySupervisorEmail'] as String?,
      facilitySupervisorSignatureStatus: map['facilitySupervisorSignatureStatus'] as String? ?? 'Pending',
      facilitySupervisorSignature: map['facilitySupervisorSignature'] as String?,
      facilitySupervisorSignatureDate: map['facilitySupervisorSignatureDate'] as String?,
      facilitySupervisorTimesheetSubmissionDateTime: _parseTimestamp(map['facilitySupervisorTimesheetSubmissionTimestamp']), // MODIFIED
      caritasSupervisor: map['caritasSupervisor'] as String? ?? 'N/A',
      caritasSupervisorEmail: map['caritasSupervisorEmail'] as String?,
      caritasSupervisorSignatureStatus: map['caritasSupervisorSignatureStatus'] as String? ?? 'Pending',
      caritasSupervisorSignature: map['caritasSupervisorSignature'] as String?,
      caritasSupervisorSignatureDate: map['caritasSupervisorSignatureDate'] as String?,
      caritasSupervisorTimesheetSubmissionDateTime: _parseTimestamp(map['caritasSupervisorTimesheetSubmissionTimestamp']), // MODIFIED
      entries: entriesData,
    );
  }
}
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

class TurnaroundTimeMetrics {
  final double avgStaffToFacilityDays;
  final double avgFacilityToCaritasDays;
  final int facilityApprovedCount;
  final int caritasApprovedCount;

  TurnaroundTimeMetrics({
    required this.avgStaffToFacilityDays,
    required this.avgFacilityToCaritasDays,
    required this.facilityApprovedCount,
    required this.caritasApprovedCount,
  });
}


// --- MAIN WIDGET ---
class TimesheetReviewPageHq extends StatefulWidget {
  const TimesheetReviewPageHq({super.key});

  @override
  _TimesheetReviewPageHqState createState() => _TimesheetReviewPageHqState();
}

class _TimesheetReviewPageHqState extends State<TimesheetReviewPageHq> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State Variables ---
  bool _isFilterLoading = true;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Filter selections
  late int _selectedYear;
  late int _selectedMonth;
  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _selectedStates = [];
  List<String> _selectedFacilities = [];
  List<String> _selectedStaffIds = [];

  String _selectedStatusFilter = 'All Submitted';
  final List<String> _statusFilters = [
    'All Submitted',
    'Yet to Submit',
    'Awaiting Facility Approval',
    'Awaiting Caritas Approval'
  ];

  // Data stores
  List<Map<String, dynamic>> _allExpectedStaffMaster = [];
  List<TimesheetModel> _allTimesheetsMaster = [];
  List<Map<String, dynamic>> _nonSubmittedStaff = [];
  List<dynamic> _displayedItems = [];
  TimesheetMetrics _metrics = TimesheetMetrics();
  Map<String, Map<String, FacilityMetrics>> _stateFacilitySummary = {};
  Map<String, TurnaroundTimeMetrics> _turnaroundTimeSummary = {};

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
    _initializeFilters();
  }

  @override
  void dispose() {
    _summaryTableScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeFilters() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _availableStates = ['All States', ...states..sort()];
          _selectedStates = ['All States'];
        });

        await _onStateSelectionChange(_selectedStates);
        if (!mounted) return;
        await _loadTimesheets();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing page: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFilterLoading = false;
        });
      }
    }
  }

  Future<void> _onStateSelectionChange(List<String> selected) async {
    setState(() {
      _selectedStates = selected;
      _isFilterLoading = true;
      _selectedFacilities = ['All Facilities'];
      _availableFacilities = ['All Facilities'];
      _allTimesheetsMaster.clear();
      _displayedItems.clear();
    });

    List<String> statesToQuery = _selectedStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : _selectedStates;

    if (statesToQuery.isNotEmpty) {
      try {
        final Set<String> facilityNames = {};
        for (var i = 0; i < statesToQuery.length; i += 30) {
          final chunk = statesToQuery.sublist(i, min(i + 30, statesToQuery.length));
          final locationDocs = await _firestore.collection('Location').where(FieldPath.documentId, whereIn: chunk).get();
          for (final doc in locationDocs.docs) {
            final facilitiesSnapshot = await doc.reference.collection(doc.id).get();
            for (final facilityDoc in facilitiesSnapshot.docs) {
              final locationName = facilityDoc.data()['LocationName'] as String?;
              if (locationName != null && locationName.isNotEmpty) {
                facilityNames.add(locationName);
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _availableFacilities.addAll(facilityNames.toList()..sort());
          });
        }
      } catch (e) {
        if (mounted) setState(() => _errorMessage = "Error updating facility filter: $e");
      }
    }
    if (mounted) setState(() => _isFilterLoading = false);
  }

  Future<void> _loadTimesheets() async {
    if (_selectedStates.isEmpty || (_selectedStates.contains('All States') && _availableStates.length <= 1)) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one state.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allTimesheetsMaster = [];
      _nonSubmittedStaff = [];
      _displayedItems = [];
      _selectedStaffIds.clear();
      _stateFacilitySummary.clear();
      _turnaroundTimeSummary = {};
    });

    try {
      List<String> statesToQuery = _selectedStates.contains('All States')
          ? _availableStates.where((s) => s != 'All States').toList()
          : _selectedStates;

      List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
          ? _availableFacilities.where((f) => f != 'All Facilities').toList()
          : _selectedFacilities;

      Query staffQuery = _firestore.collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .where('state', whereIn: statesToQuery);

      if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
        staffQuery = staffQuery.where('location', whereIn: facilitiesToQuery);
      }
      final staffSnapshot = await staffQuery.get();
      _allExpectedStaffMaster = staffSnapshot.docs.map((doc) {
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

      Query timesheetQuery = _firestore.collectionGroup('TimeSheets').where('state', whereIn: statesToQuery);

      if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
        timesheetQuery = timesheetQuery.where('location', whereIn: facilitiesToQuery);
      }
      final timesheetSnapshot = await timesheetQuery.get();

      final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
      final timesheetDocId = '${monthName}_$_selectedYear';

      final List<TimesheetModel> fetchedTimesheets = [];
      final Set<String> submittedStaffIds = {};

      for (final doc in timesheetSnapshot.docs) {
        if (doc.id == timesheetDocId) {
          final data = doc.data();
          if (data is Map<String, dynamic>) {
            final staffId = data['staffId'] as String? ?? doc.reference.parent.parent!.id;
            fetchedTimesheets.add(TimesheetModel.fromMap(data, staffId));
            submittedStaffIds.add(staffId);
          }
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

      _calculateStateFacilitySummary();
      _applyFiltersAndCalculateMetrics();
      _calculateTurnaroundTimes();

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
    } else {
      newMetrics.percentFullyApproved = 0.0;
    }

    setState(() {
      _displayedItems = filteredList;
      _metrics = newMetrics;
    });
  }

  void _calculateStateFacilitySummary() {
    final summary = <String, Map<String, FacilityMetrics>>{};
    for (final ts in _allTimesheetsMaster) {
      final state = ts.state;
      final facility = ts.location;
      summary.putIfAbsent(state, () => {});
      summary[state]!.putIfAbsent(facility, () => FacilityMetrics());

      final metrics = summary[state]![facility]!;
      metrics.totalExpected++;
      metrics.totalSubmitted++;
      if (ts.facilitySupervisorSignatureStatus == 'Approved') {
        metrics.approvedByFacility++;
      }
      if (ts.caritasSupervisorSignatureStatus == 'Approved') {
        metrics.approvedByCaritas++;
      }
    }

    for (final staff in _nonSubmittedStaff) {
      final state = staff['state'] as String? ?? 'Unknown State';
      final facility = staff['location'] as String? ?? 'Unknown Facility';
      summary.putIfAbsent(state, () => {});
      summary[state]!.putIfAbsent(facility, () => FacilityMetrics());

      final metrics = summary[state]![facility]!;
      metrics.totalExpected++;
      metrics.yetToSubmit++;
    }

    setState(() {
      _stateFacilitySummary = summary;
    });
  }

  void _calculateTurnaroundTimes() {
    final staffToFacilityTimes = <String, List<double>>{};
    final facilityToCaritasTimes = <String, List<double>>{};

    for (final timesheet in _allTimesheetsMaster) {
      final state = timesheet.state;
      // MODIFIED: Use the new DateTime fields directly
      final staffDate = timesheet.staffSignatureDateTime;
      final facilityDate = timesheet.facilitySupervisorTimesheetSubmissionDateTime;
      final caritasDate = timesheet.caritasSupervisorTimesheetSubmissionDateTime;

      if (staffDate != null && facilityDate != null) {
        final duration = facilityDate.difference(staffDate).inMilliseconds / (1000 * 60 * 60 * 24);
        staffToFacilityTimes.putIfAbsent(state, () => []).add(duration > 0 ? duration : 0);
      }

      if (facilityDate != null && caritasDate != null) {
        final duration = caritasDate.difference(facilityDate).inMilliseconds / (1000 * 60 * 60 * 24);
        facilityToCaritasTimes.putIfAbsent(state, () => []).add(duration > 0 ? duration : 0);
      }
    }

    final summary = <String, TurnaroundTimeMetrics>{};
    final allStates = {...staffToFacilityTimes.keys, ...facilityToCaritasTimes.keys};

    for (final state in allStates) {
      final s2fList = staffToFacilityTimes[state] ?? [];
      final f2cList = facilityToCaritasTimes[state] ?? [];

      final avgS2F = s2fList.isNotEmpty ? s2fList.reduce((a, b) => a + b) / s2fList.length : 0.0;
      final avgF2C = f2cList.isNotEmpty ? f2cList.reduce((a, b) => a + b) / f2cList.length : 0.0;

      summary[state] = TurnaroundTimeMetrics(
        avgStaffToFacilityDays: avgS2F,
        avgFacilityToCaritasDays: avgF2C,
        facilityApprovedCount: s2fList.length,
        caritasApprovedCount: f2cList.length,
      );
    }

    setState(() {
      _turnaroundTimeSummary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Timesheet Review Dashboard", style: TextStyle(color: Colors.white)),
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
                if(value == 'bulk_pdf') _downloadBulkPdf();
                if(value == 'summary_csv') _downloadSummaryAsCsv();
                if(value == 'summary_excel') _downloadSummaryAsExcel();
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
                    enabled: !_isLoading && _stateFacilitySummary.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.description), title: Text("Download Summary (CSV)"))
                ),
                PopupMenuItem(
                    value: 'summary_excel',
                    enabled: !_isLoading && _stateFacilitySummary.isNotEmpty,
                    child: const ListTile(leading: Icon(Icons.table_chart), title: Text("Download Summary (Excel)"))
                ),
              ],
            )
        ],
      ),
      drawer: drawer3(context),
      body: Column(
        children: [
          _buildResponsiveFilterBar(),
          if (_errorMessage != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
                )
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricsDashboard(),
                  // const SizedBox(height: 24),
                  // if (_turnaroundTimeSummary.isNotEmpty)
                  //   _buildTurnaroundTimeCharts(),
                  const SizedBox(height: 24),
                  if (_stateFacilitySummary.isNotEmpty)
                    _buildStateFacilitySummaryTable(),
                  const SizedBox(height: 24),
                  if (_nonSubmittedStaff.isNotEmpty)
                    _buildNonSubmittedStaffList(),
                  const SizedBox(height: 24),
                  if (_allTimesheetsMaster.isNotEmpty)
                    _buildSubmittedStaffList(),
                  const SizedBox(height: 24),
                  if (_displayedItems.isNotEmpty) ...[
                    Text(
                      "Detailed View: $_selectedStatusFilter",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    ..._displayedItems.map((item) {
                      if (item is TimesheetModel) {
                        return _buildTimesheetCard(item);
                      } else if (item is Map) {
                        return _buildNonSubmittedCard(item as Map<String, dynamic>);
                      }
                      return const SizedBox.shrink();
                    }).toList(),
                  ] else if (!_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          "No data found for the current filters.",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFilterBar() {
    final years = List.generate(5, (index) => DateTime.now().year - index);
    final months = List.generate(12, (index) => index + 1);

    final List<Widget> filterItems = [
      if (_isFilterLoading)
        const Center(child: Text("Loading filters..."))
      else ...[
        SizedBox(width: 220, child: _buildMultiSelectStateDropdown()),
        SizedBox(width: 220, child: _buildMultiSelectFacilityDropdown()),
      ],
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<int>(
          value: _selectedMonth,
          decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
          items: months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM').format(DateTime(0, m)))))
              .toList(),
          onChanged: (value) => setState(() => _selectedMonth = value!),
        ),
      ),
      SizedBox(
        width: 120,
        child: DropdownButtonFormField<int>(
          value: _selectedYear,
          decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
              .toList(),
          onChanged: (value) => setState(() => _selectedYear = value!),
        ),
      ),
      SizedBox(
        width: 250,
        child: DropdownButtonFormField<String>(
          value: _selectedStatusFilter,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
          items: _statusFilters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedStatusFilter = value);
              _applyFiltersAndCalculateMetrics();
            }
          },
        ),
      ),
      SizedBox(width: 220, child: _buildMultiSelectStaffDropdown()),
    ];

    final applyButton = ElevatedButton.icon(
      icon: const Icon(Icons.filter_list),
      label: const Text('Apply Filter'),
      onPressed: _isLoading || _isFilterLoading ? null : _loadTimesheets,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(0, 50),
      ),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 750) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    childAspectRatio: 3.0,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: filterItems,
                  ),
                  const SizedBox(height: 16),
                  applyButton,
                ],
              );
            } else {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...filterItems,
                      applyButton
                    ],
                  ),
                ),
              );
            }
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

  Widget _buildTurnaroundTimeCharts() {
    final sortedStates = _turnaroundTimeSummary.keys.toList()..sort();
    if (sortedStates.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Average Approval Turnaround Time (in Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColorDark)),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      _buildSingleBarChart(
                        title: 'Staff Submission to Facility Approval',
                        data: _turnaroundTimeSummary,
                        sortedStates: sortedStates,
                        dataSelector: (metrics) => metrics.avgStaffToFacilityDays,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 40),
                      _buildSingleBarChart(
                        title: 'Facility Approval to CARITAS Approval',
                        data: _turnaroundTimeSummary,
                        sortedStates: sortedStates,
                        dataSelector: (metrics) => metrics.avgFacilityToCaritasDays,
                        color: Colors.deepPurple,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildSingleBarChart(
                        title: 'Staff Submission to Facility Approval',
                        data: _turnaroundTimeSummary,
                        sortedStates: sortedStates,
                        dataSelector: (metrics) => metrics.avgStaffToFacilityDays,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSingleBarChart(
                        title: 'Facility Approval to CARITAS Approval',
                        data: _turnaroundTimeSummary,
                        sortedStates: sortedStates,
                        dataSelector: (metrics) => metrics.avgFacilityToCaritasDays,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleBarChart({
    required String title,
    required Map<String, TurnaroundTimeMetrics> data,
    required List<String> sortedStates,
    required double Function(TurnaroundTimeMetrics) dataSelector,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: sortedStates.asMap().entries.map((entry) {
                final index = entry.key;
                final state = entry.value;
                final metrics = data[state]!;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: dataSelector(metrics),
                      color: color,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedStates.length) return const SizedBox.shrink();
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(sortedStates[index], style: const TextStyle(fontSize: 10)),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(value.round().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                 // tooltipBgColor: Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final state = sortedStates[group.x];
                    return BarTooltipItem(
                      '$state\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: <material.TextSpan>[
                        material.TextSpan(
                          text: '${rod.toY.toStringAsFixed(1)} days',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _downloadBulkPdf() async {
    setState(() => _isExporting = true);
    try {
      if (_allTimesheetsMaster.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No submitted timesheets found to generate a bulk PDF.')));
        return;
      }
      final timesheetsToPrint = List<TimesheetModel>.from(_allTimesheetsMaster);
      if (_selectedStaffIds.isNotEmpty) {
        final selectionSet = _selectedStaffIds.toSet();
        timesheetsToPrint.retainWhere((ts) => selectionSet.contains(ts.staffId));
      }

      if (timesheetsToPrint.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching timesheets found for the selected staff.')));
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
      String selectionName = 'Nationwide';
      if (!_selectedStates.contains('All States')) {
        selectionName = _selectedStates.join('_').replaceAll(' ', '_');
      }
      _triggerDownload(pdfBytes, 'Bulk_Timesheets_${selectionName}_${_selectedMonth}_${_selectedYear}.pdf');

    } catch (e, stack) {
      debugPrint("Error generating bulk PDF: $e\n$stack");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred while generating the bulk PDF: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

  Widget _buildStateFacilitySummaryTable() {
    final sortedStates = _stateFacilitySummary.keys.toList()..sort();
    const double scrollAmount = 250.0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _isSummaryExpanded,
        onExpansionChanged: (isExpanded) {
          setState(() {
            _isSummaryExpanded = isExpanded;
          });
        },
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Summary by State and Facility',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                final newOffset = _summaryTableScrollController.offset - scrollAmount;
                _summaryTableScrollController.animateTo(
                  newOffset < 0 ? 0 : newOffset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: 'Scroll Left',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                final maxScroll = _summaryTableScrollController.position.maxScrollExtent;
                final newOffset = _summaryTableScrollController.offset + scrollAmount;
                _summaryTableScrollController.animateTo(
                  newOffset > maxScroll ? maxScroll : newOffset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: 'Scroll Right',
            ),
          ],
        ),
        subtitle: Text(
          _isSummaryExpanded
              ? 'Detailed breakdown of timesheet submission and approval status. Scroll to see other information'
              : '(Tap to expand for a detailed breakdown)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children: [
          SingleChildScrollView(
            controller: _summaryTableScrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Facility')),
                DataColumn(label: Text('Expected'), numeric: true),
                DataColumn(label: Text('Submitted'), numeric: true),
                DataColumn(label: Text('Yet to Submit'), numeric: true),
                DataColumn(label: Text('Facility Approved'), numeric: true),
                DataColumn(label: Text('Facility Pending'), numeric: true),
                DataColumn(label: Text('CARITAS Approved'), numeric: true),
                DataColumn(label: Text('CARITAS Pending'), numeric: true),
              ],
              rows: [
                for (var state in sortedStates)
                  ...(_stateFacilitySummary[state]!.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key)))
                      .map((entry) {
                    final facility = entry.key;
                    final metrics = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(Text(state, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(facility)),
                        DataCell(Text(metrics.totalExpected.toString())),
                        DataCell(Text(metrics.totalSubmitted.toString())),
                        DataCell(Text(metrics.yetToSubmit.toString())),
                        DataCell(Text(metrics.approvedByFacility.toString())),
                        DataCell(Text(metrics.pendingFacility.toString())),
                        DataCell(Text(metrics.approvedByCaritas.toString())),
                        DataCell(Text(metrics.pendingCaritas.toString())),
                      ],
                    );
                  }).toList(),
              ],
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
                  Text('Facility: ${staff['location']} | State: ${staff['state']}'),
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

  // --- EXPORT HELPER FUNCTIONS ---

  List<List<dynamic>> _generateFacilitySummaryData() {
    final List<List<dynamic>> rows = [];
    const List<String> headers = [
      'State', 'Facility', 'Total Expected', 'Total Submitted', 'Yet to Submit',
      'Approved by Facility Supervisor', 'Pending Facility Supervisor',
      'Approved by CARITAS Staff', 'Pending CARITAS Staff'
    ];
    rows.add(headers);

    final sortedStates = _stateFacilitySummary.keys.toList()..sort();
    for (var state in sortedStates) {
      final sortedFacilities = _stateFacilitySummary[state]!.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (var entry in sortedFacilities) {
        final facility = entry.key;
        final metrics = entry.value;
        rows.add([
          state,
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
        rows.add(['Staff Name', 'Facility', 'State', 'Phone Number', 'Email Address']);
        for (final staff in _nonSubmittedStaff) {
          rows.add([
            staff['staffName'],
            staff['location'],
            staff['state'],
            staff['mobile'],
            staff['email'],
          ]);
        }
      }

      final String csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);
      _triggerDownload(Uint8List.fromList(bytes), 'Timesheet_Summary_${_selectedMonth}_${_selectedYear}.csv');
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
      }

      final fileBytes = excel.save();
      if(fileBytes != null) {
        _triggerDownload(Uint8List.fromList(fileBytes), 'Timesheet_Summary_${_selectedMonth}_${_selectedYear}.xlsx');
      }

    } catch(e, stack) {
      debugPrint("Error generating Excel: $e\n$stack");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating Excel: $e")));
    } finally {
      if(mounted) setState(() => _isExporting = false);
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
                  Text(timesheet.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${timesheet.location} - ${timesheet.state}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            _buildStatusChip(timesheet.facilitySupervisorSignatureStatus, timesheet.caritasSupervisorSignatureStatus),
            const SizedBox(width: 8),
            Text("${timesheet.totalHours.toStringAsFixed(2)} hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(staffInfo['staffName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${staffInfo['location']} - ${staffInfo['state']}', style: const TextStyle(fontSize: 12)),
        trailing: const Chip(
          label: Text('Not Submitted', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  void _showMultiSelectStateDialog() async {
    List<String> tempSelected = List.from(_selectedStates);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected = tempSelected.length == _availableStates.length -1 || tempSelected.contains('All States');
            return AlertDialog(
              title: const Text('Select States'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('All States', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          tempSelected.clear();
                          if (value == true) {
                            tempSelected.add('All States');
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableStates.where((s) => s != 'All States').length,
                        itemBuilder: (context, index) {
                          final option = _availableStates.where((s) => s != 'All States').toList()[index];
                          return CheckboxListTile(
                            title: Text(option),
                            value: tempSelected.contains(option),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                tempSelected.remove('All States');
                                if (value == true) {
                                  tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (tempSelected.isEmpty) tempSelected.add('All States');
                    _onStateSelectionChange(tempSelected);
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

  Widget _buildMultiSelectStateDropdown() {
    String getButtonText() {
      if (_selectedStates.isEmpty) return 'Select State';
      if (_selectedStates.contains('All States')) return 'All States';
      if (_selectedStates.length == 1) return _selectedStates.first;
      return '${_selectedStates.length} States Selected';
    }

    return InkWell(
      onTap: _showMultiSelectStateDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'State',
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

  Widget _buildMultiSelectFacilityDropdown() {
    String getButtonText() {
      if (_selectedFacilities.isEmpty) return 'Select Facility';
      if (_selectedFacilities.contains('All Facilities')) return 'All Facilities';
      if (_selectedFacilities.length == 1) return _selectedFacilities.first;
      return '${_selectedFacilities.length} Facilities Selected';
    }

    return InkWell(
      onTap: _availableFacilities.length <= 1 ? null : _showMultiSelectFacilityDialog,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Facility',
          border: const OutlineInputBorder(),
          filled: _availableFacilities.length <= 1,
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

  void _showMultiSelectFacilityDialog() async {
    List<String> tempSelected = List.from(_selectedFacilities);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAllSelected = tempSelected.contains('All Facilities') || tempSelected.length == _availableFacilities.length - 1;
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
                        itemCount: _availableFacilities.where((f) => f != 'All Facilities').length,
                        itemBuilder: (context, index) {
                          final option = _availableFacilities.where((f) => f != 'All Facilities').toList()[index];
                          return CheckboxListTile(
                            title: Text(option),
                            value: tempSelected.contains(option),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                tempSelected.remove('All Facilities');
                                if (value == true) {
                                  tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: () {
                    if (tempSelected.isEmpty) tempSelected.add('All Facilities');
                    setState(() => _selectedFacilities = tempSelected);
                    Navigator.pop(context);
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis, maxLines: 1,),
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
      label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
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

  Widget _buildEntriesTable(List<TimesheetEntry> entries) {
    final Map<String, Map<String, dynamic>> dailySummary = {};
    for (final entry in entries) {
      dailySummary.update(
        entry.date,
            (value) {
          value['hours'] = value['hours']! + entry.noOfHours.toDouble();
          if (entry.isOffDay) value['isOffDay'] = true;
          return value;
        },
        ifAbsent: () => {
          'hours': entry.noOfHours.toDouble(),
          'isOffDay': entry.isOffDay,
        },
      );
    }
    final sortedDates = dailySummary.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Date")),
          DataColumn(label: Text("Total Hours"), numeric: true)
        ],
        rows: sortedDates.map((date) {
          final summary = dailySummary[date]!;
          final double dailyHours = summary['hours']!;
          final double cappedHours = dailyHours > 8.0 ? 8.0 : dailyHours;
          final bool isOffDay = summary['isOffDay']!;

          return DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                      (s) => isOffDay ? Colors.blue.withOpacity(0.05) : null),
              cells: [
                DataCell(Text(date)),
                DataCell(Text(cappedHours.toStringAsFixed(2))),
              ]
          );
        }).toList(),
      ),
    );
  }

  Future<TimesheetModel?> _fetchTimesheetFromFirestore(String staffId, String timesheetDocId) async {
    try {
      final querySnapshot = await _firestore.collectionGroup('TimeSheets').where('staffId', isEqualTo: staffId).get();
      final docs = querySnapshot.docs.where((doc) => doc.id == timesheetDocId).toList();
      if (docs.isNotEmpty) {
        final doc = docs.first;
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          return TimesheetModel.fromMap(data, staffId);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching single timesheet for PDF: $e");
      return null;
    }
  }

  Future<void> _downloadSinglePdf(String staffId) async {
    setState(() => _isExporting = true);
    final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
    final timesheetDocId = '${monthName}_$_selectedYear';
    final timesheet = await _fetchTimesheetFromFirestore(staffId, timesheetDocId);
    if (timesheet == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not find the latest timesheet for staff ID $staffId to download.')));
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
    _triggerDownload(pdfBytes, 'Timesheet_${timesheet.staffName.replaceAll(' ','_')}_${_selectedMonth}_${_selectedYear}.pdf');
    setState(() => _isExporting = false);
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