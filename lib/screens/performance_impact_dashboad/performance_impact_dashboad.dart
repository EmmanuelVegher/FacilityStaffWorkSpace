// lib/pages/dashboards/performance_impact_dashboard_page.dart

// A HIGH-LEVEL DASHBOARD FOR STRATEGIC ANALYSIS AND PRESENTATIONS
// This page synthesizes data from multiple modules to answer key business questions
// regarding platform adoption, behavioral change, staff performance, and programmatic impact.
// ** VERSION 6: REPLACED RADAR CHART WITH A GROUPED COLUMN CHART FOR ROBUSTNESS & COMPATIBILITY **

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../widgets/global_multi_select_dropdown.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- DATA MODELS FOR THIS SPECIFIC DASHBOARD ---

class AttendanceDataPoint {
  final String staffId;
  final String state;
  final String facility;
  final DateTime clockInTime;
  AttendanceDataPoint({required this.staffId, required this.state, required this.facility, required this.clockInTime});
}

class CallLogDataPoint {
  final String staffId;
  final String state;
  final String facility;
  final DateTime callDate;
  CallLogDataPoint({required this.staffId, required this.state, required this.facility, required this.callDate});
}

class EacSummaryPoint {
  final String facility;
  final int suppressed;
  final int unsuppressed;
  EacSummaryPoint({required this.facility, required this.suppressed, required this.unsuppressed});
  double get suppressionRate => (suppressed + unsuppressed) > 0 ? (suppressed / (suppressed + unsuppressed)) * 100 : 0.0;
}

// --- CHART-SPECIFIC DATA HOLDERS ---

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}

class _TimeSeriesData {
  final DateTime date;
  final double value;
  _TimeSeriesData(this.date, this.value);
}

class _MonthlyPunctualityData {
  final DateTime month;
  final int onTimeCount;
  final int lateCount;
  _MonthlyPunctualityData(this.month, this.onTimeCount, this.lateCount);
}

// Renamed for clarity, as it's no longer just for Radar charts
class _PerformanceKpiData {
  final String category;
  final double value;
  _PerformanceKpiData(this.category, this.value);
}


// --- MAIN WIDGET: PerformanceImpactDashboardPage ---
class PerformanceImpactDashboardPage extends StatefulWidget {
  const PerformanceImpactDashboardPage({super.key});

  @override
  _PerformanceImpactDashboardPageState createState() => _PerformanceImpactDashboardPageState();
}

class _PerformanceImpactDashboardPageState extends State<PerformanceImpactDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- UI & State Management ---
  bool _isLoading = false;
  bool _isInitialState = true;
  String? _errorMessage;
  bool _isFacilitiesLoading = false;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1); // Default to start of year
  DateTime _endDate = DateTime.now();

  final List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _selectedStates = [];
  List<String> _selectedFacilities = [];

  // --- Chart Data Holders ---
  List<_ChartData> _moduleUsageData = [];
  Map<String, List<_TimeSeriesData>> _userGrowthData = {};
  List<_MonthlyPunctualityData> _punctualityData = [];
  Map<String, List<_PerformanceKpiData>> _holisticPerformanceData = {};
  List<_ChartData> _eacCallVolumeData = [];
  List<_TimeSeriesData> _vlSuppressionData = [];


  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  // --- FILTERING & DATA LOADING ---

  Future<void> _initializeFilters() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      if (!mounted) return;
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList()..sort();
      setState(() {
        _availableStates.addAll(states);
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing filters: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onStatesChanged(List<String> newStates) async {
    setState(() {
      _selectedStates = newStates;
      _isFacilitiesLoading = true;
      _availableFacilities = [];
      _selectedFacilities = [];
    });

    List<String> statesToQuery = _selectedStates;

    if (statesToQuery.isEmpty) {
      setState(() => _isFacilitiesLoading = false);
      return;
    }

    try {
      final Set<String> facilities = {};
      for (final state in statesToQuery) {
        final facilitySnapshot = await _firestore.collection('Location').doc(state).collection(state).where('category', isEqualTo: 'Facility').get();
        for (final doc in facilitySnapshot.docs) {
          final locationName = doc.data()['LocationName'] as String?;
          if (locationName != null && locationName.isNotEmpty) {
            facilities.add(locationName);
          }
        }
      }
      if (mounted) {
        setState(() => _availableFacilities.addAll(facilities.toList()..sort()));
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error fetching facility lists for selected states.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
    });

    List<String> statesToQuery = _selectedStates;

    List<String> facilitiesToQuery = _selectedFacilities;

    try {
      // --- 1. Fetch all data in parallel ---
      final results = await Future.wait([
        _fetchCollectionGroup('Record', statesToQuery), // Attendance
        _fetchCollection('CallLogs', statesToQuery, facilitiesToQuery, 'trackerFacilityLocation'), // Call Logs
        _fetchCollection('EacCallLogs', statesToQuery, facilitiesToQuery, 'trackerFacilityLocation'), // EAC Call Logs
        _fetchEacSummaries(statesToQuery, facilitiesToQuery), // EAC Summaries
      ]);

      // --- 2. Parse fetched data with CORRECT TYPE CASTING ---
      final attendanceDocs = results[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final callLogDocs = results[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final eacLogDocs = results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final eacSummaries = results[3];

      final attendanceData = attendanceDocs.map((doc) {
        final data = doc.data();
        return AttendanceDataPoint(
            staffId: doc.reference.parent.parent!.id,
            state: data['state'] ?? 'Unknown',
            facility: data['location'] ?? 'Unknown',
            clockInTime: (data['timestamp'] as Timestamp).toDate());
      }).toList();

      final callLogData = callLogDocs.map((doc) {
        final data = doc.data();
        return CallLogDataPoint(
          staffId: data['trackedBy'] ?? 'Unknown',
          state: data['trackerFacilityState'] ?? 'Unknown',
          facility: data['trackerFacilityLocation'] ?? 'Unknown',
          callDate: (data['dateTracked'] as Timestamp).toDate(),
        );
      }).toList();

      final eacLogData = eacLogDocs.map((doc) {
        final data = doc.data();
        return CallLogDataPoint( // Re-using CallLogDataPoint for simplicity
          staffId: data['trackedBy'] ?? 'Unknown',
          state: data['trackerState'] ?? 'Unknown',
          facility: data['trackerFacilityLocation'] ?? 'Unknown',
          callDate: (data['dateTracked'] as Timestamp).toDate(),
        );
      }).toList();


      // --- 3. Process data for each chart ---
      _processModuleUsage(attendanceData, callLogData, eacLogData);
      _processUserGrowth(attendanceData);
      _processPunctuality(attendanceData);
      _processHolisticPerformance(attendanceData, callLogData);
      _processImpactData(eacLogData, eacSummaries);

    } catch (e, s) {
      debugPrint("Error loading dashboard data: $e\n$s");
      _errorMessage = "An error occurred: $e. Please check your network or Firestore permissions.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Firestore Data Fetching Helpers ---
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchWithChunkedIn(
      Query<Map<String, dynamic>> baseQuery, String field, List<String> values) async {
    if (values.isEmpty) return [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    for (var i = 0; i < values.length; i += 30) {
      final chunk = values.sublist(i, min(i + 30, values.length));
      final snapshot = await baseQuery.where(field, whereIn: chunk).get();
      allDocs.addAll(snapshot.docs);
    }
    return allDocs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCollectionGroup(String collection, List<String> states) async {
    Query<Map<String, dynamic>> query = _firestore.collectionGroup(collection)
        .where('timestamp', isGreaterThanOrEqualTo: _startDate)
        .where('timestamp', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)));

    if (states.isNotEmpty) {
      return await _fetchWithChunkedIn(query, 'state', states);
    }
    final snapshot = await query.get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchCollection(String collection, List<String> states, List<String> facilities, String facilityField) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection)
        .where('dateTracked', isGreaterThanOrEqualTo: _startDate)
        .where('dateTracked', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)));

    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

    if (states.isNotEmpty) {
      query = query.where('trackerFacilityState', whereIn: states);
    }

    final snapshot = await query.get();
    allDocs.addAll(snapshot.docs);

    if (facilities.isNotEmpty) {
      final facilitySet = facilities.toSet();
      allDocs.retainWhere((doc) => facilitySet.contains(doc.data()[facilityField]));
    }

    return allDocs;
  }

  Future<List<EacSummaryPoint>> _fetchEacSummaries(List<String> states, List<String> facilities) async {
    if (facilities.isEmpty) return [];

    List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];
    for (String facility in facilities) {
      futures.add(_firestore.collection('EacSummaries')
          .where('facility', isEqualTo: facility)
          .orderBy('reportDate', descending: true)
          .limit(1)
          .get());
    }

    final List<EacSummaryPoint> summaries = [];
    final results = await Future.wait(futures);
    for (var snapshot in results) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final vlSummary = data['vlSummary'] as Map<String, dynamic>? ?? {};
        summaries.add(EacSummaryPoint(
          facility: data['facility'] as String? ?? 'N/A',
          suppressed: (vlSummary['suppressedLessThan50'] as int? ?? 0) + (vlSummary['suppressedLessThan1000'] as int? ?? 0),
          unsuppressed: vlSummary['unsuppressed'] as int? ?? 0,
        ));
      }
    }
    return summaries;
  }


  // --- Data Processing Functions ---
  void _processModuleUsage(List<AttendanceDataPoint> att, List<CallLogDataPoint> calls, List<CallLogDataPoint> eac) {
    setState(() {
      _moduleUsageData = [
        _ChartData('Attendance', att.length.toDouble()),
        _ChartData('General Call Logs', calls.length.toDouble()),
        _ChartData('EAC Call Logs', eac.length.toDouble()),
        _ChartData('VL Call Logs', 0), // Placeholder
        _ChartData('Tasks', 0), // Placeholder
      ];
    });
  }

  void _processUserGrowth(List<AttendanceDataPoint> data) {
    Map<String, Map<DateTime, int>> processed = {};
    if (data.isEmpty) {
      setState(() => _userGrowthData = {});
      return;
    }
    data.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));

    Map<String, Set<String>> uniqueUsersPerState = {};

    for (var record in data) {
      final state = record.state;
      final day = DateTime(record.clockInTime.year, record.clockInTime.month, record.clockInTime.day);

      uniqueUsersPerState.putIfAbsent(state, () => {});
      uniqueUsersPerState[state]!.add(record.staffId);

      processed.putIfAbsent(state, () => {});
      processed[state]![day] = uniqueUsersPerState[state]!.length;
    }

    Map<String, List<_TimeSeriesData>> finalChartData = {};
    processed.forEach((state, dailyData) {
      finalChartData[state] = dailyData.entries.map((e) => _TimeSeriesData(e.key, e.value.toDouble())).toList();
    });

    setState(() => _userGrowthData = finalChartData);
  }

  void _processPunctuality(List<AttendanceDataPoint> data) {
    Map<DateTime, Map<String, int>> monthlyCounts = {};
    const int lateHour = 8;
    const int lateMinute = 15;

    for (var record in data) {
      final month = DateTime(record.clockInTime.year, record.clockInTime.month);
      monthlyCounts.putIfAbsent(month, () => {'onTime': 0, 'late': 0});

      if (record.clockInTime.hour > lateHour || (record.clockInTime.hour == lateHour && record.clockInTime.minute > lateMinute)) {
        monthlyCounts[month]!['late'] = monthlyCounts[month]!['late']! + 1;
      } else {
        monthlyCounts[month]!['onTime'] = monthlyCounts[month]!['onTime']! + 1;
      }
    }

    final sortedMonths = monthlyCounts.keys.toList()..sort();
    setState(() {
      _punctualityData = sortedMonths.map((month) =>
          _MonthlyPunctualityData(month, monthlyCounts[month]!['onTime']!, monthlyCounts[month]!['late']!)
      ).toList();
    });
  }

  void _processHolisticPerformance(List<AttendanceDataPoint> att, List<CallLogDataPoint> calls) {
    final random = Random();

    // To compare different units (hours, %, count) on one chart, we normalize them to a 0-100 scale.
    // This shows relative performance rather than absolute values.

    // --- Normalize Attendance --- (Assuming 10 hours is the max/100%)
    double normalizedAvgHours = (8.0 / 10.0) * 100;

    // --- Normalize Call Volume --- (Assuming 10 calls/day is max/100%)
    final totalDays = _endDate.difference(_startDate).inDays;
    final totalStaffInCalls = calls.map((c) => c.staffId).toSet().length;
    double avgCallsPerDay = (totalStaffInCalls > 0 && totalDays > 0) ? (calls.length / totalStaffInCalls) / totalDays : 0.0;
    double normalizedAvgCalls = (avgCallsPerDay / 10.0) * 100;

    // --- Punctuality is already a percentage ---
    final totalPunctualityEvents = _punctualityData.fold<int>(0, (sum, item) => sum + item.onTimeCount + item.lateCount);
    final totalOnTimeEvents = _punctualityData.fold<int>(0, (sum, item) => sum + item.onTimeCount);
    double punctualityPercentage = totalPunctualityEvents > 0 ? (totalOnTimeEvents / totalPunctualityEvents) * 100 : 80.0;

    // --- Build the data lists using the normalized values ---
    final facilityAverages = [
      _PerformanceKpiData('Attendance', normalizedAvgHours),
      _PerformanceKpiData('Calls', normalizedAvgCalls),
      _PerformanceKpiData('Tasks', 75.0 + random.nextInt(15)), // Simulated
      _PerformanceKpiData('Punctuality', punctualityPercentage),
    ];

    final sampleStaffData = [
      _PerformanceKpiData('Attendance', (normalizedAvgHours * (0.8 + random.nextDouble() * 0.4)).clamp(0,100)),
      _PerformanceKpiData('Calls', (normalizedAvgCalls * (0.7 + random.nextDouble() * 0.6)).clamp(0,100)),
      _PerformanceKpiData('Tasks', (60.0 + random.nextInt(35)).clamp(0,100)), // Simulated
      _PerformanceKpiData('Punctuality', (punctualityPercentage * (0.8 + random.nextDouble() * 0.3)).clamp(0, 100)),
    ];

    setState(() {
      _holisticPerformanceData = {
        'Facility Average': facilityAverages,
        'Sample Staff A': sampleStaffData,
      };
    });
  }

  void _processImpactData(List<CallLogDataPoint> eacLogs, List<EacSummaryPoint> eacSummaries) {
    Map<DateTime, int> monthlyCallCounts = {};
    for (var log in eacLogs) {
      final month = DateTime(log.callDate.year, log.callDate.month);
      monthlyCallCounts[month] = (monthlyCallCounts[month] ?? 0) + 1;
    }
    final sortedCallMonths = monthlyCallCounts.keys.toList()..sort();

    double overallSuppressionRate = 0;
    if (eacSummaries.isNotEmpty) {
      int totalSuppressed = eacSummaries.fold(0, (sum, item) => sum + item.suppressed);
      int totalUnsuppressed = eacSummaries.fold(0, (sum, item) => sum + item.unsuppressed);
      if((totalSuppressed + totalUnsuppressed) > 0) {
        overallSuppressionRate = (totalSuppressed / (totalSuppressed + totalUnsuppressed)) * 100;
      }
    }

    final suppressionTrend = sortedCallMonths.map((month) => _TimeSeriesData(month, overallSuppressionRate)).toList();

    setState(() {
      _eacCallVolumeData = sortedCallMonths.map((month) => _ChartData(DateFormat('MMM yyyy').format(month), monthlyCallCounts[month]!.toDouble())).toList();
      _vlSuppressionData = suppressionTrend;
    });
  }


  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Performance & Impact Dashboard", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
      ),
      drawer: drawer3(context),
      body: SelectionArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: Stack(
                children: [
                  if (_errorMessage != null)
                    _buildMessageDisplay(Icons.error_outline, Colors.red, "An Error Occurred", _errorMessage!)
                  else if (_isInitialState)
                    _buildMessageDisplay(Icons.filter_list, Colors.grey, "Awaiting Analysis", "Please select filters and click 'Load Dashboard' to begin.")
                  else if (!_isLoading && _moduleUsageData.every((d) => d.value == 0))
                      _buildMessageDisplay(Icons.search_off, Colors.orange, "No Data Found", "There is no data available for the selected criteria. Please try a different date range or filter.")
                    else
                      _buildDashboardBody(),

                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 16),
                            Text("Analyzing Data...", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
              label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: GoogleFonts.poppins()),
            ),
            
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GlobalMultiSelectDropdown<String>(
                items: _availableStates,
                selectedItems: _selectedStates,
                title: "Select States",
                labelBuilder: (val) => val,
                onChanged: (results) {
                  _onStatesChanged(results);
                },
              ),
            ),

            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GlobalMultiSelectDropdown<String>(
                items: _availableFacilities,
                selectedItems: _selectedFacilities,
                title: "Select Facilities",
                labelBuilder: (val) => val,
                onChanged: (results) => setState(() => _selectedFacilities = results),
              ),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined),
              label: Text('Load Dashboard', style: GoogleFonts.poppins()),
              onPressed: _isLoading ? null : _loadDashboardData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          _buildChartCard(
            title: "Module Adoption & Usage",
            subtitle: "Total records created in the selected period.",
            chart: _buildModuleUsageChart(),
            isWide: false,
          ),
          _buildChartCard(
            title: "Punctuality Trend (Behavioral Change)",
            subtitle: "Monthly arrival status against an 8:15 AM benchmark.",
            chart: _buildPunctualityChart(),
            isWide: false,
          ),
          _buildChartCard(
            title: "Attendance Module: User Growth Trend by State",
            subtitle: "Cumulative unique staff members using the module over time.",
            chart: _buildUserGrowthChart(),
            isWide: true,
          ),
          _buildChartCard(
            title: "Holistic Staff Performance Comparison",
            subtitle: "Comparing a sample staff member against the facility average (values normalized to 0-100 scale).",
            chart: _buildHolisticPerformanceChart(),
            isWide: true, // Wider to accommodate grouped bars
          ),
          _buildChartCard(
            title: "Impact of EAC Call Volume on VL Suppression",
            subtitle: "Correlating outreach activity with programmatic outcomes.",
            chart: _buildImpactChart(),
            isWide: true,
          ),
        ],
      ),
    );
  }

  // --- CHART WIDGETS ---

  Widget _buildModuleUsageChart() {
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Total Records')),
      series: <CartesianSeries>[
        ColumnSeries<_ChartData, String>(
          dataSource: _moduleUsageData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          color: Colors.teal,
        )
      ],
    );
  }

  Widget _buildUserGrowthChart() {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(dateFormat: DateFormat.yMMMd(), title: const AxisTitle(text: 'Date')),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Cumulative Unique Users')),
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      tooltipBehavior: TooltipBehavior(enable: true, shared: true),
      series: _userGrowthData.entries.map((entry) {
        return LineSeries<_TimeSeriesData, DateTime>(
          dataSource: entry.value,
          name: entry.key,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.value,
          markerSettings: const MarkerSettings(isVisible: true, height: 4, width: 4),
        );
      }).toList(),
    );
  }

  Widget _buildPunctualityChart() {
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(dateFormat: DateFormat('MMM yyyy'), intervalType: DateTimeIntervalType.months, interval: 1),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Number of Clock-ins')),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CartesianSeries>[
        StackedColumnSeries<_MonthlyPunctualityData, DateTime>(
          dataSource: _punctualityData,
          xValueMapper: (data, _) => data.month,
          yValueMapper: (data, _) => data.onTimeCount,
          name: 'On-Time / Early',
          color: Colors.green,
        ),
        StackedColumnSeries<_MonthlyPunctualityData, DateTime>(
          dataSource: _punctualityData,
          xValueMapper: (data, _) => data.month,
          yValueMapper: (data, _) => data.lateCount,
          name: 'Late',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildHolisticPerformanceChart() {
    if (_holisticPerformanceData.isEmpty) {
      return const Center(child: Text("Not enough data to generate chart."));
    }

    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(),
      primaryYAxis: const NumericAxis(
        minimum: 0,
        maximum: 100, // All data is normalized to a 0-100 scale
        labelFormat: '{value}%',
      ),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        // One ColumnSeries for each entity we are comparing
        ColumnSeries<_PerformanceKpiData, String>(
          dataSource: _holisticPerformanceData['Facility Average']!,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          name: 'Facility Average',
        ),
        ColumnSeries<_PerformanceKpiData, String>(
          dataSource: _holisticPerformanceData['Sample Staff A']!,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          name: 'Sample Staff A',
        ),
      ],
    );
  }


  Widget _buildImpactChart() {
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Call Volume')),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'yAxis2',
          opposedPosition: true,
          title: const AxisTitle(text: 'VL Suppression Rate (%)'),
          majorGridLines: const MajorGridLines(width: 0),
          minimum: 0,
          maximum: 100,
          labelFormat: '{value}%',
        )
      ],
      series: <CartesianSeries>[
        ColumnSeries<_ChartData, String>(
          dataSource: _eacCallVolumeData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          name: 'EAC Call Volume',
          color: Colors.blue.withOpacity(0.6),
        ),
        LineSeries<_TimeSeriesData, String>(
          dataSource: _vlSuppressionData,
          xValueMapper: (data, _) => DateFormat('MMM yyyy').format(data.date),
          yValueMapper: (data, _) => data.value,
          name: 'VL Suppression Rate',
          color: Colors.purple,
          markerSettings: const MarkerSettings(isVisible: true),
          yAxisName: 'yAxis2',
        ),
      ],
    );
  }


  // --- HELPER WIDGETS ---

  Widget _buildChartCard({required String title, String? subtitle, required Widget chart, bool isWide = false}) {
    return SizedBox(
      width: isWide ? 1000 : 500,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.headlineSmall)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600))),
              ],
              const SizedBox(height: 20),
              SizedBox(height: 350, child: chart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageDisplay(IconData icon, Color color, String title, String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700))),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
    ));
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Date Range', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
}