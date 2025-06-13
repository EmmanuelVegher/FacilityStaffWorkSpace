import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Assuming these models are in your project and correctly set up
import 'vl_eligible_model.dart';
import 'vl_call_log_model.dart';

class StateLevelReportTab extends StatefulWidget {
  const StateLevelReportTab({super.key});

  @override
  State<StateLevelReportTab> createState() => _StateLevelReportTabState();
}

class _StateLevelReportTabState extends State<StateLevelReportTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State for Filters ---
  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _availableTrackers = [];
  String? _selectedState;
  String? _selectedFacility; // Null means "All Facilities"
  String? _selectedTracker; // Null means "All Trackers"

  String? _userState;



  // --- State for Data & UI ---
  bool _isLoading = false;
  bool _isFilterLoading = true;
  String? _errorMessage;
  String _currentQuarter = '';
  String _currentQuarterDisplay = '';
  String _previousQuarterDisplay = '';
  String _olderSamplesDisplayTitle = '';

  // --- State for Master Data Lists ---
  List<VlEligibleModel> _masterVlSummaries = [];
  List<VlCallLogModel> _masterCallLogs = [];

  // --- State for Aggregated Metrics ---
  int _totalEligibleOverall = 0;
  int _samplesCollectedInQuarter = 0;
  int _resultsReturnedInQuarter = 0;
  int _suppressedInQuarter = 0;
  int _unsuppressedInQuarter = 0;
  // ... (Add all other metric variables from your previous code here)
  int _samplesCollectedPreviousQuarter = 0;
  int _resultsReturnedPreviousQuarter = 0;
  int _suppressedPreviousQuarter = 0;
  int _unsuppressedPreviousQuarter = 0;
  int _samplesCollectedOlder = 0;
  int _resultsReturnedOlder = 0;
  int _suppressedOlder = 0;
  int _unsuppressedOlder = 0;
  int _totalCallsMade = 0;
  int _callsAnswered = 0;
  int _callsNotAnsweredOrFailed = 0;

  // --- State for PaginatedDataTable ---
  _CallLogDataSource? _callLogDataSource;
  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _calculateCurrentAndPreviousQuarters();

    // _loadInitialFilterData();
    _loadUserStateAndData().then((_){
      _initializeUserContext();
    });

  }

  Future<void> _initializeUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = "User not logged in.");
        return;
      }

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final staffData = staffDoc.data();
      final userState = staffData?['state'] as String?;

      if (userState == null) {
        setState(() => _errorMessage = "State not found in staff profile.");
        return;
      }

      _userState = userState;
      _availableFacilities = await _getFacilitiesForState(userState);

      setState(() {
        _isFilterLoading = false;
      });

      await _loadReportData(); // Load data for all facilities initially

    } catch (e) {
      debugPrint("Error initializing user state: $e");
      setState(() {
        _errorMessage = "Failed to load user profile.";
        _isFilterLoading = false;
      });
    }
  }


  void _calculateCurrentAndPreviousQuarters() {
    // This logic remains the same
    final now = DateTime.now();
    int currentMonth = now.month;
    int currentYear = now.year;
    if (currentMonth >= 10) {
      _currentQuarter = 'Q1';
      _currentQuarterDisplay = 'Q1 (FY${(currentYear + 1).toString().substring(2)})';
      _previousQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 7) {
      _currentQuarter = 'Q4';
      _currentQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
      _previousQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 4) {
      _currentQuarter = 'Q3';
      _currentQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
      _previousQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
    } else {
      _currentQuarter = 'Q2';
      _currentQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
      _previousQuarterDisplay = 'Q1 (FY${currentYear.toString().substring(2)})';
    }
    _olderSamplesDisplayTitle = "Older Samples (Collected before $_previousQuarterDisplay)";
  }


  Future<void> _loadInitialFilterData() async {
    try {
      final snapshot = await _firestore.collection('VlReportSummaries').get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = "No states found in 'VlReportSummaries'.";
          _isFilterLoading = false;
        });
        return;
      }
      // The document ID is the state name in your structure
      final states = snapshot.docs.map((doc) => doc.id).toSet().toList();
      states.sort();
      setState(() {
        _availableStates = states;
        _isFilterLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading states: $e";
        _isFilterLoading = false;
      });
    }
  }

  Future<List<String>> _getFacilitiesForState(String state) async {
    try {
      final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint("Error fetching facilities: $e");
      return [];
    }
  }

  Future<void> _loadUserStateAndData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = "User not logged in.");
        return;
      }

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!staffDoc.exists) {
        setState(() => _errorMessage = "User profile not found in Staff collection.");
        return;
      }

      final staffData = staffDoc.data();
      final userState = staffData?['state'] as String?;

      if (userState == null) {
        setState(() => _errorMessage = "User's state not set.");
        return;
      }

      setState(() {
        _selectedState = userState;
        _availableStates = [userState]; // optionally add to dropdown
      });

      await _loadReportData(); // Now load VL summaries and call logs

    } catch (e) {
      debugPrint("Failed to load user state: $e");
      setState(() => _errorMessage = "Failed to load user state: $e");
    }
  }



  Future<void> _loadReportData() async {
    if (_userState == null) return;
    setState(() => _isLoading = true);

    try {
      _masterVlSummaries = [];
      _masterCallLogs = [];

      final facilityList = _selectedFacility != null
          ? [_selectedFacility!] // filter mode
          : await _getFacilitiesForState(_userState!); // default all

      for (final facility in facilityList) {
        final quarterDocRef = _firestore
            .collection('VlReportSummaries')
            .doc(_userState!)
            .collection(facility)
            .doc(_currentQuarterDisplay);

        final quarterSnapshot = await quarterDocRef.get();
        if (!quarterSnapshot.exists) continue;

        _masterVlSummaries.add(
            VlEligibleModel.fromMap(quarterSnapshot.id, quarterSnapshot.data()!)
        );

        final callLogsSnapshot = await quarterDocRef.collection('callLogs').get();
        _masterCallLogs.addAll(
            callLogsSnapshot.docs.map((logDoc) =>
                VlCallLogModel.fromMap(logDoc.id, logDoc.data()))
        );
      }

      _applyFiltersAndCalculate(); // Filter based on UI state

    } catch (e, stack) {
      debugPrint("Error loading report data: $e\n$stack");
      setState(() => _errorMessage = "Failed to load data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }




  void _populateDynamicFilters() {
    if (_masterVlSummaries.isEmpty) return;

    // --- FIX APPLIED HERE ---
    // We can extract facilityName from the document ID path: "state/facilityName/quarterName"
    // Note: This relies on the document ID format.
    // Your VlEligibleModel might need a dedicated `facilityName` field for a cleaner approach.
    final facilities = _masterVlSummaries
        .map((s) {
      // Your old code was `s.id.split('/')[1]`. This assumes a path structure in the ID.
      // If the facility name is a field on the model, use that instead.
      // For example: return s.facilityName;
      // Let's assume `trackerFacility` exists on the model, as it does for call logs.
      return (s as dynamic).trackerFacility; // Assuming this field exists on VlEligibleModel
    })
        .where((f) => f != null)
        .toSet()
        .map((e) => e.toString()) // Ensure all elements are strings
        .toList();

    // The tracker field has the same issue. We map to it, filter out nulls,
    // and then explicitly cast the resulting list to List<String>.
    final trackers = _masterVlSummaries
        .map((s) => (s as dynamic).updatedByFullName)
        .where((t) => t != null)
        .toSet()
        .map((e) => e.toString()) // Ensure all elements are strings
        .toList();


    facilities.sort();
    trackers.sort();

    setState(() {
      // Now both lists are guaranteed to be of type List<String>
      _availableFacilities = facilities;
      _availableTrackers = trackers; // This will no longer cause an error
    });
  }

  void _applyFiltersAndCalculate() {
    List<VlEligibleModel> filteredSummaries = List.from(_masterVlSummaries);
    List<VlCallLogModel> filteredCallLogs = List.from(_masterCallLogs);

    // Apply facility filter
    if (_selectedFacility != null) {
      filteredSummaries = filteredSummaries.where((s) => s.id.contains(_selectedFacility!)).toList();
      filteredCallLogs = filteredCallLogs.where((l) => l.trackerFacility == _selectedFacility).toList();
    }

    // Apply tracker filter
    if (_selectedTracker != null) {
      filteredSummaries = filteredSummaries.where((s) => (s as dynamic).updatedByFullName == _selectedTracker).toList();
      filteredCallLogs = filteredCallLogs.where((l) => l.trackedBy == _selectedTracker).toList();
    }

    _calculateAggregateMetrics(filteredSummaries, filteredCallLogs);
  }


  void _calculateAggregateMetrics(List<VlEligibleModel> summaries, List<VlCallLogModel> callLogs) {
    if (summaries.isEmpty) {
      // Reset all metrics if no data matches filter
      setState(() {
        _totalEligibleOverall = 0;
        _samplesCollectedInQuarter = 0;
        _resultsReturnedInQuarter = 0;
        // ... reset all others
        _callLogDataSource = _CallLogDataSource(data: [], context: context);
      });
      return;
    }

    // Sum up all metrics from the list of summaries
    _totalEligibleOverall = summaries.fold(0, (sum, item) => sum + item.totalEligibleClientsInFilter);
    _samplesCollectedInQuarter = summaries.fold(0, (sum, item) => sum + item.samplesCollected);
    _resultsReturnedInQuarter = summaries.fold(0, (sum, item) => sum + item.resultsReturned);
    _suppressedInQuarter = summaries.fold(0, (sum, item) => sum + item.suppressed);
    _unsuppressedInQuarter = summaries.fold(0, (sum, item) => sum + item.unsuppressed);

    _samplesCollectedPreviousQuarter = summaries.fold(0, (sum, item) => sum + item.samplesCollectedPreviousQuarter);
    _resultsReturnedPreviousQuarter = summaries.fold(0, (sum, item) => sum + item.resultsReturnedPreviousQuarter);
    _suppressedPreviousQuarter = summaries.fold(0, (sum, item) => sum + item.suppressedPreviousQuarter);
    _unsuppressedPreviousQuarter = summaries.fold(0, (sum, item) => sum + item.unsuppressedPreviousQuarter);

    _samplesCollectedOlder = summaries.fold(0, (sum, item) => sum + item.samplesCollectedOlder);
    _resultsReturnedOlder = summaries.fold(0, (sum, item) => sum + item.resultsReturnedOlder);
    _suppressedOlder = summaries.fold(0, (sum, item) => sum + item.suppressedOlder);
    _unsuppressedOlder = summaries.fold(0, (sum, item) => sum + item.unsuppressedOlder);

    // Aggregate call log metrics
    _totalCallsMade = callLogs.length;
    _callsAnswered = callLogs.where((log) => log.callStatus?.toLowerCase() == "answered").length;
    _callsNotAnsweredOrFailed = _totalCallsMade - _callsAnswered;

    // Update call log data source for the table
    _callLogDataSource = _CallLogDataSource(data: callLogs, context: context);

    setState(() {}); // Update the UI with aggregated values
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _callLogDataSource?.sort(columnIndex, ascending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('State Level VL Report'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedState == null
                ? const Center(child: Text('Please select a state to view reports.', style: TextStyle(fontSize: 16)))
                : _buildReportBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Facility',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: _selectedFacility,
              items: [
                DropdownMenuItem(value: null, child: Text('All Facilities', style: TextStyle(fontStyle: FontStyle.italic))),
                ..._availableFacilities.map((f) => DropdownMenuItem(value: f, child: Text(f))),
              ],
              onChanged: (val) => setState(() => _selectedFacility = val),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt),
              label: const Text("Apply Filter"),
              onPressed: () async {
                await _loadReportData(); // reload with selected facility
              },
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: value,
      isExpanded: true,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All ${label}s', style: const TextStyle(fontStyle: FontStyle.italic)),
        ),
        ...items.map((item) => DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        )),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildReportBody() {
    if (_masterVlSummaries.isEmpty && !_isLoading) {
      return const Center(child: Text("No data found for the selected filters.", style: TextStyle(fontSize: 16)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // You can re-add your metric cards and charts here, they will use the aggregated state variables.
          // Example:
          Text('VL Summary ($_currentQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
            children: [
              _buildMetricCard('Total Eligible', _totalEligibleOverall.toString()),
              _buildMetricCard('Samples Collected', _samplesCollectedInQuarter.toString()),
              _buildMetricCard('Results Returned', _resultsReturnedInQuarter.toString()),
              _buildMetricCard('Suppressed', _suppressedInQuarter.toString()),
              _buildMetricCard('Unsuppressed', _unsuppressedInQuarter.toString()),
            ],
          ),
          const SizedBox(height: 20),

          Text('VL Summary ($_previousQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
            children: [
              _buildMetricCard('Samples Collected', _samplesCollectedPreviousQuarter.toString()),
              _buildMetricCard('Results Returned', _resultsReturnedPreviousQuarter.toString()),
              _buildMetricCard('Suppressed', _suppressedPreviousQuarter.toString()),
              _buildMetricCard('Unsuppressed', _unsuppressedPreviousQuarter.toString()),
            ],
          ),
          const SizedBox(height: 20),

          // Call Log Table
          Text('Call Log Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildCallLogTable(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCallLogTable() {
    if (_callLogDataSource == null || _callLogDataSource!.rowCount == 0) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("No call logs match the current filters."),
      ));
    }
    return PaginatedDataTable(
      header: const Text('Call Logs'),
      columns: [
        DataColumn(label: const Text('Date'), onSort: _onSort),
        DataColumn(label: const Text('Client Name'), onSort: _onSort),
        DataColumn(label: const Text('ART ID'), onSort: _onSort),
        DataColumn(label: const Text('Facility'), onSort: _onSort),
        DataColumn(label: const Text('Tracker'), onSort: _onSort),
        DataColumn(label: const Text('Status'), onSort: _onSort),
      ],
      source: _callLogDataSource!,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      rowsPerPage: 10,
    );
  }
}


// --- DATA SOURCE FOR THE PAGINATED TABLE ---

class _CallLogDataSource extends DataTableSource {
  List<VlCallLogModel> _data;
  final BuildContext context;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  _CallLogDataSource({required List<VlCallLogModel> data, required this.context}) : _data = data;

  void sort(int columnIndex, bool ascending) {
    _data.sort((a, b) {
      int compare;
      switch (columnIndex) {
        case 0: compare = (a.callDateTime ?? DateTime(0)).compareTo(b.callDateTime ?? DateTime(0)); break;
        case 1: compare = (a.clientName ?? '').compareTo(b.clientName ?? ''); break;
        case 2: compare = (a.artId ?? '').compareTo(b.artId ?? ''); break;
        case 3: compare = (a.trackerFacility ?? '').compareTo(b.trackerFacility ?? ''); break;
        case 4: compare = (a.trackedBy ?? '').compareTo(b.trackedBy ?? ''); break;
        case 5: compare = (a.callStatus ?? '').compareTo(b.callStatus ?? ''); break;
        default: return 0;
      }
      return ascending ? compare : -compare;
    });
    notifyListeners();
  }

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final log = _data[index];
    return DataRow(cells: [
      DataCell(Text(log.callDateTime != null ? _dateFormat.format(log.callDateTime!) : 'N/A')),
      DataCell(Text(log.clientName ?? 'N/A')),
      DataCell(Text(log.artId ?? 'N/A')),
      DataCell(Text(log.trackerFacility ?? 'N/A')),
      DataCell(Text(log.trackedBy ?? 'N/A')),
      DataCell(
          Text(log.callStatus ?? 'N/A',
            style: TextStyle(color: log.callStatus?.toLowerCase() == 'answered' ? Colors.green : Colors.red),
          )
      ),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}