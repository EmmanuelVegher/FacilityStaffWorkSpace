// lib/pages/reports/state_eac_reports_page.dart

// STATE-WIDE EAC & CALLS TRACKER REPORTS PAGE - REWRITTEN WITH UNMASKING FEATURE
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';

import '../../widgets/drawer3.dart';

// --- DATA MODELS ---
class EacCallLog {
  final String? clientName, phoneNumber, artStatus, facilityName, state, artId, datimCode;
  final DateTime? dateTracked;
  final String? trackingOutcome, trackedBy, designation, trackerFacilityLocation, supervisorName, supervisorEmail, eacSessionType;
  final int? callDuration;

  EacCallLog({
    this.clientName, this.phoneNumber, this.artStatus, this.facilityName, this.state,
    this.artId, this.datimCode, this.dateTracked, this.trackingOutcome, this.callDuration,
    this.trackedBy, this.designation, this.trackerFacilityLocation, this.supervisorName,
    this.supervisorEmail, this.eacSessionType,
  });

  factory EacCallLog.fromJson(Map<String, dynamic> data) {
    return EacCallLog(
      clientName: data['clientName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      artStatus: data['artStatus'] as String?,
      facilityName: data['facilityName'] as String?,
      state: data['trackerState'] as String?,
      artId: data['artId'] as String?,
      datimCode: data['datimCode'] as String?,
      dateTracked: (data['dateTracked'] as Timestamp?)?.toDate(),
      trackingOutcome: data['trackingOutcome'] as String?,
      callDuration: data['callDuration'] as int?,
      trackedBy: data['trackedBy'] as String?,
      designation: data['designation'] as String?,
      trackerFacilityLocation: data['trackerFacilityLocation'] as String?,
      supervisorName: data['supervisorName'] as String?,
      supervisorEmail: data['supervisorEmail'] as String?,
      eacSessionType: data['eacSessionType'] as String?,
    );
  }
}

class EacSummary {
  final String reportId, facility, trackerName;
  final DateTime reportDate;
  final int totalUniqueClients;
  final EacSessionsSummary eacSessions;
  final TatSummary tat;
  final VlSummary vlSummary;

  EacSummary({
    required this.reportId, required this.facility, required this.reportDate,
    required this.totalUniqueClients, required this.trackerName, required this.eacSessions,
    required this.tat, required this.vlSummary,
  });

  factory EacSummary.fromJson(Map<String, dynamic> data) {
    DateTime parsedDate;
    try {
      if (data['reportDate'] is Timestamp) parsedDate = (data['reportDate'] as Timestamp).toDate();
      else if (data['reportDate'] is String) parsedDate = DateFormat('yyyy-MM-dd').parse(data['reportDate']);
      else parsedDate = (data['lastUpdated'] as Timestamp).toDate();
    } catch (e) { parsedDate = DateTime.now(); }

    return EacSummary(
      reportId: data['reportId'] as String? ?? 'N/A',
      facility: data['facility'] as String? ?? 'N/A',
      reportDate: parsedDate,
      totalUniqueClients: data['totalUniqueClients'] as int? ?? 0,
      trackerName: data['trackerName'] as String? ?? 'N/A',
      eacSessions: EacSessionsSummary.fromJson(data['eacSessions'] as Map<String, dynamic>? ?? {}),
      tat: TatSummary.fromJson(data['tat'] as Map<String, dynamic>? ?? {}),
      vlSummary: VlSummary.fromJson(data['vlSummary'] as Map<String, dynamic>? ?? {}),
    );
  }
}
class EacSessionsSummary {
  final int withAtLeast3Sessions, without3Sessions;
  EacSessionsSummary({required this.withAtLeast3Sessions, required this.without3Sessions});
  factory EacSessionsSummary.fromJson(Map<String, dynamic> data) => EacSessionsSummary(
      withAtLeast3Sessions: data['withAtLeast3Sessions'] as int? ?? 0,
      without3Sessions: data['without3Sessions'] as int? ?? 0);
}
class TatSummary {
  final int lessThan90Days, between90and150Days, moreThan150Days;
  TatSummary({required this.lessThan90Days, required this.between90and150Days, required this.moreThan150Days});
  factory TatSummary.fromJson(Map<String, dynamic> data) => TatSummary(
      lessThan90Days: data['lessThan90Days'] as int? ?? 0,
      between90and150Days: data['between90and150Days'] as int? ?? 0,
      moreThan150Days: data['moreThan150Days'] as int? ?? 0);
}
class VlSummary {
  final int suppressedLessThan50, suppressedLessThan1000, unsuppressed, withRepeatVl, switchReviewCount;
  VlSummary({required this.suppressedLessThan50, required this.suppressedLessThan1000, required this.unsuppressed, required this.withRepeatVl, required this.switchReviewCount});
  factory VlSummary.fromJson(Map<String, dynamic> data) => VlSummary(
      suppressedLessThan50: data['suppressedLessThan50'] as int? ?? 0,
      suppressedLessThan1000: data['suppressedLessThan1000'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      withRepeatVl: data['withRepeatVl'] as int? ?? 0,
      switchReviewCount: data['switchReviewCount'] as int? ?? 0);
}

// --- GlobalKeys for chart export ---
final GlobalKey _outcomeChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _sessionTypeChartKey = GlobalKey();
final GlobalKey _callDurationChartKey = GlobalKey();

class HqEacReportsPageWeb extends StatefulWidget {
  const HqEacReportsPageWeb({super.key});
  @override
  _HqEacReportsPageWebState createState() => _HqEacReportsPageWebState();
}

class _HqEacReportsPageWebState extends State<HqEacReportsPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<EacCallLog> _masterLogList = [];
  List<EacCallLog> _filteredLogList = [];
  List<EacSummary> _eacSummaries = [];
  DateTime? startDate, endDate;
  bool isLoading = false, _isInitialState = true, _isFilterLoading = true, _isFacilitiesLoading = false;
  String? _errorMessage, _summaryErrorMessage;

  // --- State variables for masking and exporting ---
  bool _allCellsGloballyUnlocked = false;
  bool _isExporting = false;

  // --- UI State for Expandable Sections ---
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;
  bool _isClientSummaryExpanded = false, _isAnalysisExpanded = true;
  final ScrollController _clientSummaryScrollController = ScrollController();

  // --- Filter State ---
  List<String> _availableStates = ['All States'];
  List<String> _availableFacilities = ['All Facilities'];
  List<String> _selectedStates = ['All States'];
  List<String> _selectedFacilities = ['All Facilities'];

  // --- Call Costs & Chart Data ---
  double _totalCallCost = 0.0, _costPerSecond = 0.25;
  List<MapEntry<String, int>> outcomeChartData = [], artStatusChartData = [], sessionTypeChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month, now.day);
    _initializeFilters();
  }

  @override
  void dispose() {
    for (final controller in _logTableControllers) { controller.dispose(); }
    _clientSummaryScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeFilters() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      final states = snapshot.docs.map((doc) => doc.id).toList()..sort();

      if (!mounted) return;

      setState(() {
        _availableStates.addAll(states);
        _isFilterLoading = false;
      });

      await _loadReports();

    } catch (e, s) {
      debugPrint("Error during initial page load: $e\n$s");
      if (mounted) {
        setState(() {
          _errorMessage = "Error during initial page load: $e";
          isLoading = false;
          _isFilterLoading = false;
        });
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = _summaryErrorMessage = null;
      _masterLogList.clear();
      _filteredLogList.clear();
      _eacSummaries.clear();
    });

    try {
      await Future.wait([_fetchCallLogs(), _fetchEacSummaries()]);
      if (mounted) {
        _applyAllFiltersAndRecalculate();
        if (_masterLogList.isEmpty && _eacSummaries.isEmpty) {
          _showSnackBar("No EAC data found for the selected criteria.");
        }
      }
    } catch (e, s) {
      debugPrint("Error loading reports: $e\n$s");
      if (mounted) setState(() => _errorMessage = "An error occurred while loading reports: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- MASKING AND AUTHENTICATION METHODS ---

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return '${parts[0][0]}. (Hidden)';
    }
    return 'Hidden';
  }

  String _maskArtId(String? id) {
    if (_allCellsGloballyUnlocked || id == null || id.isEmpty) return id ?? 'N/A';
    return id.length > 4 ? '...${id.substring(id.length - 4)}' : '****';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : '****';
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      _showSnackBar("Cannot authenticate: User or user email is not available.");
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isAuthenticating = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Authentication Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please enter your password to unmask sensitive data."),
                const SizedBox(height: 10),
                if (isAuthenticating)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: 'Password',
                        border: OutlineInputBorder()
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating ? null : () async {
                  if (passwordController.text.isEmpty) {
                    _showSnackBar("Password cannot be empty.");
                    return;
                  }
                  setState(() => isAuthenticating = true);
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text.trim(),
                    );
                    await user.reauthenticateWithCredential(credential);
                    Navigator.pop(context, true); // Success
                  } catch (e) {
                    _showSnackBar('Authentication Error. Please try again.');
                    Navigator.pop(context, false); // Failure
                  }
                },
                child: const Text('Confirm & Unmask'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      if (mounted) setState(() => _allCellsGloballyUnlocked = false);
      _showSnackBar('All sensitive data re-masked.');
    } else {
      final bool isAuthenticated = await _promptForPasswordAndReauthenticate();
      if (isAuthenticated) {
        if (mounted) setState(() => _allCellsGloballyUnlocked = true);
        _showSnackBar('All sensitive data has been unmasked.');
      } else if (mounted) {
        _showSnackBar('Authentication failed. Data remains masked.');
      }
    }
  }


  // --- DATA FETCHING & FILTERING ---

  Future<void> _onStatesChanged(List<String> newStates) async {
    setState(() {
      _selectedStates = newStates;
      _isFacilitiesLoading = true;
      _availableFacilities = ['All Facilities'];
      _selectedFacilities = ['All Facilities'];
    });

    List<String> statesToFetchFacilitiesFor = newStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : newStates;

    if (statesToFetchFacilitiesFor.isEmpty) {
      setState(() => _isFacilitiesLoading = false);
      return;
    }

    try {
      List<String> facilities = [];
      List<Future<QuerySnapshot>> facilityFutures = [];

      for (String state in statesToFetchFacilitiesFor) {
        facilityFutures.add(_firestore.collection('Location').doc(state).collection(state).get());
      }

      final List<QuerySnapshot> results = await Future.wait(facilityFutures);
      for(var snapshot in results) {
        final stateFacilities = snapshot.docs.map((doc) => doc['LocationName'] as String).where((name) => name.isNotEmpty);
        facilities.addAll(stateFacilities);
      }

      if (mounted) {
        setState(() => _availableFacilities.addAll(facilities.toSet().toList()..sort()));
      }
    } catch (e, s) {
      debugPrint("Error fetching facilities: $e\n$s");
      _showSnackBar("Error fetching facility lists.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  Future<void> _fetchCallLogs() async {
    final List<String> statesToQuery = _selectedStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : _selectedStates;

    final List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
        ? _availableFacilities.where((f) => f != 'All Facilities').toList()
        : _selectedFacilities;

    Query baseQuery = _firestore.collection('EacCallLogs')
        .where('dateTracked', isGreaterThanOrEqualTo: startDate)
        .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

    List<Future<QuerySnapshot>> futures = [];

    if (statesToQuery.isNotEmpty) {
      for (final state in statesToQuery) {
        Query stateQuery = baseQuery.where('trackerState', isEqualTo: state);
        if (facilitiesToQuery.isNotEmpty && !_selectedFacilities.contains('All Facilities')) {
          stateQuery = stateQuery.where('trackerFacilityLocation', whereIn: facilitiesToQuery);
        }
        futures.add(stateQuery.get());
      }
    } else {
      futures.add(baseQuery.get());
    }

    final List<QuerySnapshot> results = await Future.wait(futures);
    final List<EacCallLog> allLogs = [];
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        allLogs.add(EacCallLog.fromJson(doc.data() as Map<String, dynamic>));
      }
    }

    if (mounted) {
      _masterLogList = allLogs;
      _masterLogList.sort((a, b) => (b.dateTracked ?? DateTime(0)).compareTo(a.dateTracked ?? DateTime(0)));
    }
  }

  Future<void> _fetchEacSummaries() async {
    List<String> facilitiesToQuery = _selectedFacilities.contains('All Facilities')
        ? _availableFacilities.where((f) => f != 'All Facilities').toList()
        : List.from(_selectedFacilities);

    if (facilitiesToQuery.isEmpty) {
      if(mounted) setState(() => _eacSummaries = []);
      return;
    }

    List<Future<QuerySnapshot>> futures = [];
    for (String facility in facilitiesToQuery) {
      final locationPrefix = facility.replaceAll(' ', '_');
      futures.add(_firestore.collection('EacSummaries')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: locationPrefix)
          .where(FieldPath.documentId, isLessThan: '$locationPrefix\uf8ff')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get());
    }

    try {
      final List<QuerySnapshot> results = await Future.wait(futures);
      final List<EacSummary> summaries = [];
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          if (doc.exists) {
            summaries.add(EacSummary.fromJson(doc.data() as Map<String, dynamic>));
          }
        }
      }
      if(mounted) setState(() {
        _eacSummaries = summaries;
        _summaryErrorMessage = null;
      });
    } catch (e, s) {
      debugPrint("Error fetching summaries: $e\n$s");
      if(mounted) setState(() => _summaryErrorMessage = "Failed to load EAC summaries.");
    }
  }

  void _applyAllFiltersAndRecalculate() {
    setState(() {
      _filteredLogList = _masterLogList;
      _totalCallCost = _filteredLogList.fold(0.0, (sum, c) => sum + (c.callDuration ?? 0)) * _costPerSecond;
      _prepareChartData();
      for (final controller in _logTableControllers) { controller.dispose(); }
      final dateGroups = _groupLogsByDate();
      _logTableControllers = List.generate(dateGroups.length, (_) => ScrollController());
      _currentlyExpandedDateIndex = _filteredLogList.isNotEmpty ? 0 : -1;
    });
  }

  void _prepareChartData() {
    outcomeChartData = _getOutcomeData();
    artStatusChartData = _getArtStatusData();
    sessionTypeChartData = _getSessionTypeData();
    callDurationTrendData = _getCallDurationTrendData();
  }

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
    } else {
      bodyContent = _buildDashboardContent();
    }

    String appBarTitle = 'State-wide EAC Reports';
    if(!_isInitialState) {
      if (_selectedStates.contains("All States")) {
        appBarTitle = 'National EAC Report';
      } else if (_selectedStates.length == 1) {
        appBarTitle = 'EAC Report for ${_selectedStates.first}';
      } else {
        appBarTitle = 'EAC Report for ${_selectedStates.length} States';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _buildAppBarActions(),
      ),
      drawer: drawer3(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
        icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: (isLoading || _isInitialState) ? null : _toggleGlobalUnmask,
      ),
      if (_isExporting)
        const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
      else
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: "Export Options",
          onSelected: (value) async { if (value == 'csv') await _exportToCSV(); },
          enabled: !isLoading && !_isInitialState && (_filteredLogList.isNotEmpty || _eacSummaries.isNotEmpty),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.grid_on_outlined, color: Colors.green), title: Text('Export CSV'))),
          ],
        ),
    ];
  }

  Widget _buildFilterBar() {
    String stateButtonText = _selectedStates.contains('All States') ? 'All States' : _selectedStates.length == 1 ? _selectedStates.first : '${_selectedStates.length} States';
    String facilityButtonText = _selectedFacilities.contains('All Facilities') ? 'All Facilities' : _selectedFacilities.length == 1 ? _selectedFacilities.first : '${_selectedFacilities.length} Facilities';
    bool isAllStatesSelected = _selectedStates.contains('All States');

    return Card(
      margin: const EdgeInsets.all(8.0), elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isFilterLoading
            ? const Center(child: Text("Loading filters..."))
            : Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0, runSpacing: 12.0, alignment: WrapAlignment.start,
          children: [
            _buildFilterChip("State", stateButtonText, Icons.map_outlined, () {
              _showMultiSelectDialog(
                context: context, title: 'Select States', allOptions: _availableStates,
                selectedOptions: _selectedStates, allKeyword: 'All States',
                onConfirm: (results) => _onStatesChanged(results),
              );
            }),
            _buildFilterChip("Facility", facilityButtonText, Icons.business_center, () {
              _showMultiSelectDialog(
                context: context, title: 'Select Facilities', allOptions: _availableFacilities,
                selectedOptions: _selectedFacilities, allKeyword: 'All Facilities',
                onConfirm: (results) => setState(() => _selectedFacilities = results),
              );
            }, disabled: isAllStatesSelected || _isFacilitiesLoading),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text((startDate != null && endDate != null) ? '${_formatDateWithSuffix(startDate!)} - ${_formatDateWithSuffix(endDate!)}' : 'Select Dates'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: isLoading ? null : _loadReports,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isInitialState && !isLoading) {
      return Center(child: Text("Select state(s) and apply filters to view EAC reports.", style: TextStyle(color: Colors.grey.shade700)));
    }
    if (_filteredLogList.isEmpty && _eacSummaries.isEmpty && !isLoading) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No EAC data found for the selected criteria.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))));
    }

    final Map<String, List<EacCallLog>> dailyGroupedReports = _groupLogsByDate();
    final Map<String, _ClientCallSummary> clientSummaryMap = _generateClientCallSummary();
    final dailyGroupedKeys = dailyGroupedReports.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryInfoCard(),
          const SizedBox(height: 24),
          if (_eacSummaries.isNotEmpty || _summaryErrorMessage != null) ...[
            _buildEacAnalysisSection(),
            const SizedBox(height: 24),
          ],
          if(_filteredLogList.isNotEmpty)...[
            Text('Call Log Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildChartSection(),
            const SizedBox(height: 30),
            if (clientSummaryMap.isNotEmpty) ...[
              _buildClientSummarySection(clientSummaryMap),
              const SizedBox(height: 30),
            ],
            Text('Detailed EAC Logs', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _buildDetailedLogSection(dailyGroupedKeys, dailyGroupedReports),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailedLogSection(List<String> dailyGroupedKeys, Map<String, List<EacCallLog>> dailyGroupedReports) {
    if (dailyGroupedKeys.isEmpty) { return const Card(child: SizedBox(height: 100, child: Center(child: Text("No detailed logs match the current filters.")))); }
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) => setState(() => _currentlyExpandedDateIndex = _currentlyExpandedDateIndex == index ? -1 : index),
      animationDuration: const Duration(milliseconds: 300),
      children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
        final index = dailyGroupedKeys.indexOf(dateKey);
        final dailyLogList = dailyGroupedReports[dateKey]!;
        final bool isExpanded = _currentlyExpandedDateIndex == index;
        return ExpansionPanel(
          isExpanded: isExpanded, canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Visibility(
                visible: isExpanded, maintainSize: true, maintainAnimation: true, maintainState: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Scroll Left', onPressed: () => _logTableControllers[index].animateTo(_logTableControllers[index].offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                    IconButton(icon: const Icon(Icons.arrow_forward), tooltip: 'Scroll Right', onPressed: () => _logTableControllers[index].animateTo(_logTableControllers[index].offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                  ],
                ),
              ),
            );
          },
          body: SingleChildScrollView(
            controller: _logTableControllers[index], scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [DataColumn(label: Text('Client Name')), DataColumn(label: Text('PhoneNo')), DataColumn(label: Text('ART Status')), DataColumn(label: Text("Facility")), DataColumn(label: Text('State')), DataColumn(label: Text('ART ID')), DataColumn(label: Text('DatimCode')), DataColumn(label: Text('Time')), DataColumn(label: Text('EAC Session')), DataColumn(label: Text('Outcome')), DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By'))],
                rows: dailyLogList.map((log) => DataRow(cells: [
                  DataCell(Text(_maskClientName(log.clientName))),
                  DataCell(Text(_maskPhoneNumber(log.phoneNumber))),
                  DataCell(Text(log.artStatus ?? 'N/A')),
                  DataCell(Text(log.facilityName ?? 'N/A')),
                  DataCell(Text(log.state ?? 'N/A')),
                  DataCell(Text(_maskArtId(log.artId))),
                  DataCell(Text(log.datimCode ?? 'N/A')),
                  DataCell(Text(log.dateTracked != null ? DateFormat('HH:mm').format(log.dateTracked!) : 'N/A')),
                  DataCell(Text(log.eacSessionType ?? 'N/A')),
                  DataCell(_buildStatusCell(log.trackingOutcome)),
                  DataCell(Text(formatDuration(log.callDuration ?? 0))),
                  DataCell(Text(log.trackedBy ?? 'N/A')),
                ])).toList(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- EXPORTING METHODS ---

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) {
      proceed = await _promptForPasswordAndReauthenticate();
      if (!proceed) {
        _showSnackBar('Authentication failed. Export will contain masked data.');
      }
    }

    try {
      List<List<dynamic>> rows = [['Client Name', 'PhoneNo', 'ART Status', 'Facility', 'State', 'ART ID', 'DatimCode', 'Date Tracked', 'EAC Session', 'Outcome', 'Duration(s)', 'Tracked By']];
      for (var log in _filteredLogList) {
        rows.add([
          proceed ? (log.clientName ?? 'N/A') : _maskClientName(log.clientName),
          proceed ? (log.phoneNumber ?? 'N/A') : _maskPhoneNumber(log.phoneNumber),
          log.artStatus ?? 'N/A',
          log.facilityName ?? 'N/A',
          log.state ?? 'N/A',
          proceed ? (log.artId ?? 'N/A') : _maskArtId(log.artId),
          log.datimCode ?? 'N/A',
          log.dateTracked != null ? DateFormat('yyyy-MM-dd HH:mm').format(log.dateTracked!) : 'N/A',
          log.eacSessionType ?? 'N/A',
          log.trackingOutcome ?? 'N/A',
          log.callDuration ?? 0,
          log.trackedBy ?? 'N/A'
        ]);
      }
      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(utf8.encode(csvData), 'state_eac_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', 'text/csv');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _triggerDownload(List<int> bytes, String filename, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement..href = url..style.display = 'none'..download = filename;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }


  // --- HELPER & UTILITY METHODS ---

  void _showSnackBar(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20))); }

  void _showDateRangePicker() { showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Select Date Range'), content: SizedBox(width: 400, height: 450, child: SfDateRangePicker(selectionMode: DateRangePickerSelectionMode.range, initialSelectedRange: (startDate != null && endDate != null) ? PickerDateRange(startDate!, endDate!) : null, showActionButtons: true, onSubmit: (Object? value) { Navigator.pop(context); if (value is PickerDateRange && value.startDate != null) { setState(() { startDate = value.startDate; endDate = value.endDate ?? value.startDate; }); } }, onCancel: () => Navigator.pop(context))))); }

  String _formatDateWithSuffix(DateTime date) { String day = DateFormat('d').format(date); String suffix = 'th'; int dayInt = int.parse(day); if (dayInt >= 11 && dayInt <= 13) { suffix = 'th'; } else { switch (dayInt % 10) { case 1: suffix = 'st'; break; case 2: suffix = 'nd'; break; case 3: suffix = 'rd'; break; default: suffix = 'th'; } } return DateFormat("d'$suffix'-MMMM-y").format(date); }

  Color _getStatusColor(String status) { String lowerStatus = status.toLowerCase(); switch (lowerStatus) { case 'answered': case 'incoming answered': case 'completed': return Colors.green.shade700; case 'outgoing failed/not answered': case 'unknown (no outgoing log detail)': case 'missed': case 'missed call': case 'call failed': case 'call dropped': case 'unknown (no log detail)': return Colors.red.shade700; case 'call busy': return Colors.orange.shade700; default: return Colors.grey.shade600; } }

  Widget _buildStatusCell(String? status) { if (status == null || status.isEmpty) { return const Text('N/A'); } final color = _getStatusColor(status); return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4), width: 1)), child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w500), textAlign: TextAlign.center)); }

  List<MapEntry<String, int>> _getOutcomeData() { Map<String, int> statusCounts = {}; for (var log in _filteredLogList) { String status = log.trackingOutcome?.trim() ?? 'N/A'; if (status.isEmpty) status = 'N/A'; statusCounts[status] = (statusCounts[status] ?? 0) + 1; } return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); }
  List<MapEntry<String, int>> _getSessionTypeData() { Map<String, int> sessionCounts = {}; for (var log in _filteredLogList) { String session = log.eacSessionType?.trim() ?? 'Unknown'; if (session.isEmpty) session = 'Unknown'; sessionCounts[session] = (sessionCounts[session] ?? 0) + 1; } return sessionCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)); }
  List<MapEntry<String, int>> _getArtStatusData() { Map<String, int> statusCounts = {}; for (var log in _filteredLogList) { String status = log.artStatus?.trim() ?? 'Unknown'; if (status.isEmpty) status = 'Unknown'; statusCounts[status] = (statusCounts[status] ?? 0) + 1; } return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)); }
  List<_ChartDataPoint> _getCallDurationTrendData() { Map<String, List<int>> dailyDurations = {}; final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd'); for (var log in _filteredLogList) { if (log.dateTracked != null && log.callDuration != null && log.callDuration! > 0) { String dateKey = dateKeyFormat.format(log.dateTracked!); dailyDurations.putIfAbsent(dateKey, () => []).add(log.callDuration!); } } List<_ChartDataPoint> chartData = []; dailyDurations.forEach((date, durations) { double averageDuration = durations.reduce((a, b) => a + b) / durations.length; chartData.add(_ChartDataPoint(date, averageDuration)); }); chartData.sort((a, b) => a.x.compareTo(b.x)); return chartData; }
  String formatDuration(int totalSeconds) { if (totalSeconds <= 0) return '0s'; final int hours = totalSeconds ~/ 3600; final int minutes = (totalSeconds % 3600) ~/ 60; final int seconds = totalSeconds % 60; List<String> parts = []; if (hours > 0) parts.add('${hours}h'); if (minutes > 0) parts.add('${minutes}m'); if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s'); return parts.join(' '); }
  Map<String, List<EacCallLog>> _groupLogsByDate() { final Map<String, List<EacCallLog>> dailyReports = {}; final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy'); for (var log in _filteredLogList) { final dateKey = log.dateTracked != null ? displayFormat.format(log.dateTracked!) : 'Unknown Date'; dailyReports.putIfAbsent(dateKey, () => []).add(log); } final sortedKeys = dailyReports.keys.toList()..sort((a, b) { if (a == 'Unknown Date') return 1; if (b == 'Unknown Date') return -1; return displayFormat.parse(b).compareTo(displayFormat.parse(a)); }); return { for (var k in sortedKeys) k: dailyReports[k]! }; }
  Map<String, _ClientCallSummary> _generateClientCallSummary() { final Map<String, _ClientCallSummary> summaryMap = {}; for (var log in _filteredLogList) { final clientId = log.artId ?? 'Unknown ID'; final clientName = log.clientName ?? 'Unknown Name'; if (!summaryMap.containsKey(clientId)) { summaryMap[clientId] = _ClientCallSummary(clientId: clientId, clientName: clientName); } summaryMap[clientId]!.totalCalls += 1; final status = log.trackingOutcome?.toLowerCase() ?? 'unknown'; summaryMap[clientId]!.statusCounts[status] = (summaryMap[clientId]!.statusCounts[status] ?? 0) + 1; } return summaryMap; }

  Widget _buildFilterChip(String label, String value, IconData icon, VoidCallback onPressed, {bool disabled = false}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), InputChip(avatar: _isFacilitiesLoading && label=="Facility" ? const SizedBox(height:18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18), label: Text(value, overflow: TextOverflow.ellipsis), onPressed: disabled ? null : onPressed, showCheckmark: false, side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.7)), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),)]);}
  Widget _buildInfoTile({required Widget iconWidget, required String label, required String value, String? subtitle}) { return Row(mainAxisSize: MainAxisSize.min, children: [ iconWidget, const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))], ],), ],); }
  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) { return ConstrainedBox(constraints: BoxConstraints(maxWidth: isWide ? 600 : 400, minWidth: 350), child: Card(elevation: 2.0, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), SizedBox(height: 250, child: RepaintBoundary(key: chartKey, child: Container(color: Colors.white, child: chart)))],),),),); }
  Widget _buildSummaryInfoCard() { final numberFormatter = NumberFormat.compact(); final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦'); final totalDuration = _filteredLogList.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0)); final uniqueClients = _filteredLogList.map((log) => log.artId).toSet().length; final int facilityCount; if(_selectedStates.contains("All States")){ facilityCount = 0; } else if (_selectedFacilities.contains('All Facilities')) { facilityCount = _availableFacilities.length > 1 ? _availableFacilities.length - 1 : 0; } else { facilityCount = _selectedFacilities.length; } return Card(margin: const EdgeInsets.only(bottom: 0), elevation: 2.0, child: Padding(padding: const EdgeInsets.all(16.0), child: Wrap(alignment: WrapAlignment.spaceAround, spacing: 20.0, runSpacing: 16.0, children: [ if(!_selectedStates.contains("All States")) _buildInfoTile(iconWidget: Icon(Icons.location_city, color: Colors.blueGrey, size: 36), label: 'Selected Facilities', value: facilityCount.toString()), _buildInfoTile(iconWidget: Icon(Icons.group, color: Colors.teal.shade700, size: 36), label: 'Unique Clients in Logs', value: numberFormatter.format(uniqueClients)), _buildInfoTile(iconWidget: Icon(Icons.call, color: Colors.blue.shade700, size: 36), label: 'Total EAC Calls Logged', value: numberFormatter.format(_filteredLogList.length)), _buildInfoTile(iconWidget: Icon(Icons.timer_outlined, color: Colors.purple.shade700, size: 36), label: 'Total Call Duration', value: formatDuration(totalDuration)), _buildInfoTile(iconWidget: Text('₦', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange.shade800)), label: 'Estimated Call Cost', value: currencyFormatter.format(_totalCallCost), subtitle: '(at ₦${_costPerSecond.toStringAsFixed(2)}/sec)') ],),),); }
  Widget _buildChartSection() { return Wrap(spacing: 20.0, runSpacing: 20.0, alignment: WrapAlignment.start, children: [ _buildChartCard(title: 'Call Outcome Distribution', chartKey: _outcomeChartKey, chart: SfCircularChart(annotations: (outcomeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: outcomeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])), _buildChartCard(title: 'EAC Session Distribution', chartKey: _sessionTypeChartKey, chart: SfCircularChart(annotations: (sessionTypeChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: sessionTypeChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])), _buildChartCard(title: 'ART Status Distribution', chartKey: _artStatusChartKey, chart: SfCircularChart(annotations: (artStatusChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null, legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: artStatusChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])), _buildChartCard(isWide: true, title: 'Average Call Duration Trend (Daily)', chartKey: _callDurationChartKey, chart: SfCartesianChart(annotations: (callDurationTrendData.isEmpty) ? [const CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')] : null, primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked')), primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (s)'), numberFormat: NumberFormat.compact()), tooltipBehavior: TooltipBehavior(enable: true), series: <CartesianSeries>[LineSeries<_ChartDataPoint, String>(dataSource: callDurationTrendData, xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)), yValueMapper: (data, _) => data.y, name: 'Avg Duration', markerSettings: const MarkerSettings(isVisible: true))])), ],); }
  Widget _buildClientSummarySection(Map<String, _ClientCallSummary> clientSummaryMap) { return Card(clipBehavior: Clip.antiAlias, elevation: 2, margin: const EdgeInsets.symmetric(vertical: 8.0), child: ExpansionTile(title: Row(children: [Expanded(child: Text('Summary of Calls per Client', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))), Visibility(visible: _isClientSummaryExpanded, maintainSize: true, maintainAnimation: true, maintainState: true, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Scroll Left', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)), IconButton(icon: const Icon(Icons.arrow_forward), tooltip: 'Scroll Right', onPressed: () => _clientSummaryScrollController.animateTo(_clientSummaryScrollController.offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut))]))]), initiallyExpanded: _isClientSummaryExpanded, onExpansionChanged: (isExpanded) => setState(() => _isClientSummaryExpanded = isExpanded), children: [SingleChildScrollView(controller: _clientSummaryScrollController, scrollDirection: Axis.horizontal, child: Padding(padding: const EdgeInsets.all(8.0), child: DataTable(columnSpacing: 15.0, headingRowColor: MaterialStateProperty.all(Colors.grey.shade200), columns: const [DataColumn(label: Text('Client ART ID')), DataColumn(label: Text('Client Name')), DataColumn(label: Text('Total Calls')), DataColumn(label: Text('Call Outcome Summary'))], rows: clientSummaryMap.values.map((summary) { final statusSummary = summary.statusCounts.entries.map((e) => '${e.key}: ${e.value}').join(', '); return DataRow(cells: [DataCell(Text(_maskArtId(summary.clientId))), DataCell(Text(_maskClientName(summary.clientName))), DataCell(Text(summary.totalCalls.toString())), DataCell(Text(statusSummary))]); }).toList())))])); }
  Widget _buildEacAnalysisSection() { if (_summaryErrorMessage != null) { return Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text("Analysis Error: $_summaryErrorMessage", style: TextStyle(color: Colors.red.shade800)))]))); } if (_eacSummaries.isEmpty) return const SizedBox.shrink(); final EacSessionsSummary totalSessions = _eacSummaries.fold(EacSessionsSummary(withAtLeast3Sessions: 0, without3Sessions: 0), (p, s) => EacSessionsSummary(withAtLeast3Sessions: p.withAtLeast3Sessions + s.eacSessions.withAtLeast3Sessions, without3Sessions: p.without3Sessions + s.eacSessions.without3Sessions)); final int totalClients = _eacSummaries.fold(0, (p, s) => p + s.totalUniqueClients); final TatSummary totalTat = _eacSummaries.fold(TatSummary(lessThan90Days: 0, between90and150Days: 0, moreThan150Days: 0), (p, s) => TatSummary(lessThan90Days: p.lessThan90Days + s.tat.lessThan90Days, between90and150Days: p.between90and150Days + s.tat.between90and150Days, moreThan150Days: p.moreThan150Days + s.tat.moreThan150Days)); final VlSummary totalVl = _eacSummaries.fold(VlSummary(suppressedLessThan50: 0, suppressedLessThan1000: 0, unsuppressed: 0, withRepeatVl: 0, switchReviewCount: 0), (p, s) => VlSummary(suppressedLessThan50: p.suppressedLessThan50 + s.vlSummary.suppressedLessThan50, suppressedLessThan1000: p.suppressedLessThan1000 + s.vlSummary.suppressedLessThan1000, unsuppressed: p.unsuppressed + s.vlSummary.unsuppressed, withRepeatVl: p.withRepeatVl + s.vlSummary.withRepeatVl, switchReviewCount: p.switchReviewCount + s.vlSummary.switchReviewCount)); String subtitle = 'For ${_selectedFacilities.contains("All Facilities") ? "All Facilities" : "${_selectedFacilities.length} Facilitie(s)"} in ${_selectedStates.length == 1 ? _selectedStates.first : "${_selectedStates.length} States"}'; return Card( clipBehavior: Clip.antiAlias, elevation: 2, child: ExpansionTile( initiallyExpanded: _isAnalysisExpanded, onExpansionChanged: (isExpanded) => setState(() => _isAnalysisExpanded = isExpanded), backgroundColor: Colors.blueGrey.shade50.withOpacity(0.5), title: Text('Aggregated Programmatic EAC Analysis', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800)), subtitle: Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600)), children: [ Padding( padding: const EdgeInsets.all(16.0), child: Wrap( spacing: 40.0, runSpacing: 24.0, children: [ _buildAnalysisCategory(title: 'EAC Session Adherence', icon: Icons.checklist_rtl_outlined, iconColor: Colors.teal, metrics: {'Total Unique Clients on EAC': totalClients.toString(), 'Completed 3+ Sessions': totalSessions.withAtLeast3Sessions.toString(), 'Incomplete (< 3 Sessions)': totalSessions.without3Sessions.toString()}), _buildAnalysisCategory(title: 'Viral Load (VL) Summary', icon: Icons.science_outlined, iconColor: Colors.deepPurple, metrics: {'Suppressed (< 50 c/ml)': totalVl.suppressedLessThan50.toString(), 'Suppressed (< 1000 c/ml)': totalVl.suppressedLessThan1000.toString(), 'Unsuppressed (≥ 1000 c/ml)': totalVl.unsuppressed.toString(), 'Clients with Repeat VL': totalVl.withRepeatVl.toString(), 'Clients for Switch Review': totalVl.switchReviewCount.toString()}), _buildAnalysisCategory(title: 'Turn-Around Time (TAT) for VL', icon: Icons.hourglass_top_outlined, iconColor: Colors.amber.shade800, metrics: {'Less than 90 Days': totalTat.lessThan90Days.toString(), '90 - 150 Days': totalTat.between90and150Days.toString(), 'More than 150 Days': totalTat.moreThan150Days.toString()}), ], ), ) ], ), ); }
  Widget _buildAnalysisCategory({required String title, required IconData icon, required Color iconColor, required Map<String, String> metrics}) { return ConstrainedBox( constraints: const BoxConstraints(minWidth: 300, maxWidth: 450), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: iconColor), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]), const Divider(height: 12), ...metrics.entries.map((entry) => Padding( padding: const EdgeInsets.only(bottom: 6.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(entry.key, style: Theme.of(context).textTheme.bodyMedium), Text(entry.value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)), ],), )), ], ), ); }
  Future<void> _showMultiSelectDialog({ required BuildContext context, required String title, required List<String> allOptions, required List<String> selectedOptions, required String allKeyword, required Function(List<String>) onConfirm, }) async { final tempSelected = List<String>.from(selectedOptions); await showDialog(context: context, builder: (dialogContext) { return StatefulBuilder(builder: (bldContext, setStateDialog) { return AlertDialog(title: Text(title), content: SizedBox(width: 350, child: ListView.builder( shrinkWrap: true, itemCount: allOptions.length, itemBuilder: (context, index) { final option = allOptions[index]; final isAllOption = option == allKeyword; return CheckboxListTile( title: Text(option, style: TextStyle(fontWeight: isAllOption ? FontWeight.bold : FontWeight.normal)), value: tempSelected.contains(option), onChanged: (bool? value) { setStateDialog(() { if (value == true) { if (isAllOption) { tempSelected.clear(); tempSelected.add(allKeyword); } else { tempSelected.remove(allKeyword); tempSelected.add(option); } } else { tempSelected.remove(option); if (tempSelected.isEmpty && allOptions.contains(allKeyword)) { tempSelected.add(allKeyword); } } }); }, ); } )), actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), ElevatedButton( onPressed: () { onConfirm(tempSelected); Navigator.pop(dialogContext); }, child: const Text('Apply') ) ]); }); }); }
}

// --- Helper classes ---
class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _ClientCallSummary {
  final String clientId, clientName;
  int totalCalls = 0;
  Map<String, int> statusCounts = {};
  _ClientCallSummary({required this.clientId, required this.clientName});
}