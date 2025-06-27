// HQ CALL TRACKER REPORTS PAGE
// REWRITTEN FOR HEADQUARTERS TO MONITOR ALL STATES WITH CASCADING MULTI-SELECT FILTERS
// ** VERSION 2: CORRECTED FieldPath and Color TYPE ERRORS **

import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../models/contact_tracked.dart'; // Ensure this path is correct
import '../../widgets/drawer2.dart';
import '../../widgets/drawer3.dart';      // Ensure this path is correct

// GlobalKeys to capture chart images for PDF export
final GlobalKey _callStatusChartKey = GlobalKey();
final GlobalKey _artStatusChartKey = GlobalKey();
final GlobalKey _callDurationChartKey = GlobalKey();
final GlobalKey _updateMetricsChartKey = GlobalKey();

class HQCallTrackerReportsPage extends StatefulWidget {
  const HQCallTrackerReportsPage({super.key});

  @override
  _HQCallTrackerReportsPageState createState() => _HQCallTrackerReportsPageState();
}

class _HQCallTrackerReportsPageState extends State<HQCallTrackerReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<ContactTracked> _masterContactList = [];   // Holds all data from Firestore for the selected states/date
  List<ContactTracked> _filteredContactList = []; // The final list displayed after all filters are applied
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  bool _allCellsGloballyUnlocked = false;
  bool _isInitialState = true;

  // --- HQ Filter State ---
  // Available options for dropdowns
  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  List<String> _availableTrackers = [];

  // Selected filter values
  List<String> _selectedStates = [];
  List<String> _selectedFacilities = [];
  List<String> _selectedTrackers = [];

  // Filter Options Constants
  static const String _allStatesOption = "(All States)";
  static const String _allFacilitiesOption = "(All Facilities)";
  static const String _allTrackersOption = "(All Trackers)";

  final ScrollController _logTableController = ScrollController();

  // Chart Data Holders & Calculated Metrics
  List<MapEntry<String, int>> callStatusChartData = [];
  List<_ChartDataPoint> callDurationTrendData = [];
  List<_UpdateChartData> updateMetricsData = [];
  List<MapEntry<String, int>> artStatusChartData = [];
  double _totalCallCost = 0.0;
  final double _costPerSecond = 0.23;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 6);
    endDate = DateTime(now.year, now.month, now.day);
    _initializeStateFilter();
  }

  @override
  void dispose() {
    _logTableController.dispose();
    super.dispose();
  }

  // --- HQ FILTERING & DATA LOADING LOGIC ---

  /// Fetches data using chunked 'whereIn' queries to overcome Firestore's 30-item limit.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchWithChunkedIn(
      Query<Map<String, dynamic>> baseQuery,
      String field,
      List<String> values
      ) async {
    if (values.isEmpty) return [];
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
    for (var i = 0; i < values.length; i += 30) {
      final chunk = values.sublist(i, min(i + 30, values.length));
      final snapshot = await baseQuery.where(field, whereIn: chunk).get();
      allDocs.addAll(snapshot.docs);
    }
    return allDocs;
  }

  /// Step 1: Initialize the list of available states from Firestore.
  Future<void> _initializeStateFilter() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _availableStates = states..sort();
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      final String errorMsg = "Error initializing state filter: $e";
      // --- ADD THESE LINES for CONSOLE LOGGING ---
      debugPrint("HQ_CALL_TRACKER_ERROR: $errorMsg");
      debugPrint("STACK TRACE: $stackTrace");
      // ------------------------------------------
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          isLoading = false;
        });
      }
    }
  }

  /// Step 2: When states are selected, update the dependent facility filter.
  Future<void> _onStateSelectionChange(List<String> results) async {
    setState(() => isLoading = true);

    // Handle "All States" selection
    if (results.contains(_allStatesOption)) {
      _selectedStates = List.from(_availableStates);
    } else {
      _selectedStates = results;
    }

    // Reset child filters
    _selectedFacilities = [];
    _availableFacilities = [];
    _selectedTrackers = [];
    _availableTrackers = [];
    _masterContactList.clear();
    _applyAllFiltersAndRecalculate();

    // Fetch new list of available facilities
    if (_selectedStates.isNotEmpty) {
      try {
        // **FIXED**: Cannot use the helper for FieldPath.documentId.
        // We handle the chunking manually for this specific case.
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> locationDocs = [];
        for (var i = 0; i < _selectedStates.length; i += 30) {
          final chunk = _selectedStates.sublist(i, min(i + 30, _selectedStates.length));
          final snapshot = await _firestore.collection('Location').where(FieldPath.documentId, whereIn: chunk).get();
          locationDocs.addAll(snapshot.docs);
        }

        final Set<String> facilityNames = {};
        for (final doc in locationDocs) {
          final facilitiesSnapshot = await doc.reference.collection(doc.id).get();
          for (final facilityDoc in facilitiesSnapshot.docs) {
            final locationName = facilityDoc.data()['LocationName'] as String?;
            if (locationName != null && locationName.isNotEmpty) {
              facilityNames.add(locationName);
            }
          }
        }
        if(mounted) {
          setState(() {
            _availableFacilities = facilityNames.toList()..sort();
          });
        }
      } catch (e, stackTrace) {
        final String errorMsg = "Error updating facility filter: $e";
        // --- ADD THESE LINES for CONSOLE LOGGING ---
        debugPrint("HQ_CALL_TRACKER_ERROR: $errorMsg");
        debugPrint("STACK TRACE: $stackTrace");
        // ------------------------------------------
        if (mounted) {
          setState(() { // Also ensures the UI updates to show the error
            _errorMessage = errorMsg;
          });
        }
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  /// Step 3: Load the main data from Firestore based on State and Date filters.
  Future<void> _loadReports() async {
    if (_selectedStates.isEmpty) {
      _showSnackBar("Please select at least one state to generate a report.");
      return;
    }
    if (startDate == null || endDate == null) {
      _showSnackBar("Please select a valid date range.");
      return;
    }

    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = null;
      _masterContactList.clear();
      _filteredContactList.clear();
    });

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('CallLogs')
          .where('dateTracked', isGreaterThanOrEqualTo: startDate)
          .where('dateTracked', isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));

      final callLogDocs = await _fetchWithChunkedIn(query, 'trackerFacilityState', _selectedStates);

      final List<ContactTracked> fetchedContacts = callLogDocs.map((doc) {
        return ContactTracked.fromJson(doc.data());
      }).toList();

      fetchedContacts.sort((a,b) => (b.dateTracked ?? DateTime(0)).compareTo(a.dateTracked ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _masterContactList = fetchedContacts;
          // Populate the tracker list from the newly fetched data
          final trackers = _masterContactList
              .map((c) => c.trackedBy)
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .toSet();
          _availableTrackers = trackers.toList()..sort();

          // Reset sub-filters to "All" and apply them
          _selectedFacilities = [];
          _selectedTrackers = [];
          _applyAllFiltersAndRecalculate();
        });
        if (fetchedContacts.isEmpty) {
          _showSnackBar("No call logs found for the selected criteria.");
        }
      }
    } catch (e, stackTrace) {
      final String errorMsg = "An error occurred while loading reports: $e";
      // --- ADD THESE LINES for CONSOLE LOGGING ---
      debugPrint("HQ_CALL_TRACKER_ERROR: $errorMsg");
      debugPrint("STACK TRACE: $stackTrace");
      // ------------------------------------------
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  /// Step 4: Apply client-side filters (Facility, Tracker) and update all UI elements.
  void _applyAllFiltersAndRecalculate() {
    List<ContactTracked> currentlyFiltered = List.from(_masterContactList);

    // Apply facility filter
    if (_selectedFacilities.isNotEmpty) {
      currentlyFiltered.retainWhere((c) => _selectedFacilities.contains(c.trackerFacilityLocation));
    }

    // Apply tracker filter
    if (_selectedTrackers.isNotEmpty) {
      currentlyFiltered.retainWhere((c) => _selectedTrackers.contains(c.trackedBy));
    }

    // Calculate total call cost based on the final filtered list
    int totalDurationInSeconds = currentlyFiltered.fold(0, (sum, contact) => sum + (contact.callDuration ?? 0));
    double calculatedCost = totalDurationInSeconds * _costPerSecond;

    setState(() {
      _filteredContactList = currentlyFiltered;
      _totalCallCost = calculatedCost;
      _prepareChartData(); // Re-run chart calculations
    });
  }

  void _prepareChartData() {
    callStatusChartData = _getCallStatusData();
    callDurationTrendData = _getCallDurationTrendData();
    updateMetricsData = _getUpdateMetricsData();
    artStatusChartData = _getArtStatusData();
  }

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_errorMessage != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    } else {
      bodyContent = _buildDashboardContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HQ Call Tracking Reports', style: TextStyle(color: Colors.white)),
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

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.center,
          children: [
            // 1. State Filter (Multi-select)
            _buildMultiSelectField(
                title: "States",
                buttonText: "State",
                items: _availableStates,
                initialValue: _selectedStates,
                onConfirm: (results){
                  _onStateSelectionChange(results);
                },
                allOption: _allStatesOption
            ),

            // 2. Facility Filter (Multi-select)
            _buildMultiSelectField(
                title: "Facilities",
                buttonText: "Facility",
                items: _availableFacilities,
                initialValue: _selectedFacilities,
                onConfirm: (results) {
                  setState(() {
                    _selectedFacilities = results.contains(_allFacilitiesOption) ? List.from(_availableFacilities) : results;
                  });
                  _applyAllFiltersAndRecalculate();
                },
                allOption: _allFacilitiesOption,
                enabled: _availableFacilities.isNotEmpty
            ),

            // 3. Tracker Filter (Multi-select)
            _buildMultiSelectField(
                title: "Trackers",
                buttonText: "Tracked By",
                items: _availableTrackers,
                initialValue: _selectedTrackers,
                onConfirm: (results) {
                  setState(() {
                    _selectedTrackers = results.contains(_allTrackersOption) ? List.from(_availableTrackers) : results;
                  });
                  _applyAllFiltersAndRecalculate();
                },
                allOption: _allTrackersOption,
                enabled: _availableTrackers.isNotEmpty
            ),

            // 4. Date Range Picker
            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text((startDate != null && endDate != null) ? '${DateFormat.yMd().format(startDate!)} - ${DateFormat.yMd().format(endDate!)}' : 'Select Dates'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),

            // 5. Apply Filter Button
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

  /// Generic builder for multi-select dropdown fields
  Widget _buildMultiSelectField({
    required String title,
    required String buttonText,
    required List<String> items,
    required List<String> initialValue,
    required void Function(List<String>) onConfirm,
    required String allOption,
    bool enabled = true,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: MultiSelectDialogField<String>(
        items: [
          MultiSelectItem<String>(allOption, allOption),
          ...items.map((item) => MultiSelectItem<String>(item, item)),
        ],
        title: Text(title),
        initialValue: initialValue,
        // The package doesn't have a built-in disabled state, so we manually adjust visuals.
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade200,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: Colors.grey.shade600, width: 1),
        ),
        buttonIcon: Icon(Icons.arrow_drop_down, color: enabled ? Colors.grey.shade700 : Colors.grey.shade400),
        buttonText: Text(
            initialValue.isEmpty
                ? buttonText
                : (initialValue.length == items.length && items.isNotEmpty)
                ? "All ${title} Selected"
                : "${initialValue.length} Selected",
            style: TextStyle(color: enabled ? Colors.grey.shade800 : Colors.grey.shade600, fontSize: 16),
            overflow: TextOverflow.ellipsis
        ),
        // ** THE FIX IS HERE **
        // The onConfirm callback itself must not be null.
        // Instead, we pass a function that checks the 'enabled' flag internally.
        // If the widget is disabled, the function does nothing when tapped.
        onConfirm: (results) {
          if (enabled) {
            onConfirm(results);
          }
        },
        searchable: true,
        listType: MultiSelectListType.LIST,
        chipDisplay: MultiSelectChipDisplay.none(),
        itemsTextStyle: const TextStyle(fontSize: 14),
        selectedItemsTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
        selectedColor: Colors.teal.withOpacity(0.1),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        tooltip: _allCellsGloballyUnlocked ? 'Mask Sensitive Data' : 'Unmask Sensitive Data',
        icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: isLoading ? null : _toggleGlobalUnmask,
      ),
      if (_isExporting)
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
        )
      else
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: "Export Options",
          onSelected: (value) async {
            if (value == 'csv') await _exportToCSV();
            else if (value == 'pdf') await _exportToPDF();
          },
          enabled: !isLoading && !_isInitialState && _filteredContactList.isNotEmpty,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.grid_on_outlined, color: Colors.green), title: Text('Export CSV'))),
            const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined, color: Colors.red), title: Text('Export PDF (Charts)'))),
          ],
        ),
    ];
  }

  Widget _buildDashboardContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isInitialState) {
      return Center(child: Text("Please select filters and click 'Apply Filter' to view reports.", style: TextStyle(color: Colors.grey.shade700)));
    }

    if (_masterContactList.isNotEmpty && _filteredContactList.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("No data matches the selected Facility/Tracker filters. Try changing the sub-filters or broadening the date range.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
      ));
    }

    if (_masterContactList.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("No call logs were found for the selected states and date range.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
      ));
    }

    final Map<String, List<ContactTracked>> dailyGroupedReports = _groupContactsByDate();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryInfoCard(),
          Text('Summary Charts', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildChartSection(),
          const SizedBox(height: 30),
          Text('Detailed Logs', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          ..._buildDetailedLogTables(dailyGroupedReports),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _getCallStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in _filteredContactList) {
      String status = contact.callStatus?.trim() ?? 'N/A';
      if (status.isEmpty) status = 'N/A';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, List<ContactTracked>> _groupContactsByDate() {
    final Map<String, List<ContactTracked>> dailyReports = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy');

    for (var contact in _filteredContactList) {
      final dateKey = contact.dateTracked != null ? dateKeyFormat.format(contact.dateTracked!) : 'Unknown Date';
      dailyReports.putIfAbsent(dateKey, () => []).add(contact);
    }
    final sortedKeys = dailyReports.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Date') return 1;
        if (b == 'Unknown Date') return -1;
        return b.compareTo(a);
      });
    return { for (var k in sortedKeys) (k == 'Unknown Date' ? 'Unknown Date' : displayFormat.format(dateKeyFormat.parse(k))) : dailyReports[k]! };
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20)));
  }

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? '${parts[0][0]}. (Hidden)' : 'Hidden';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : phone.replaceAll(RegExp(r'.'), '*');
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
                    onSubmitted: (_) => _performAuth(context, user, passwordController.text, (val) => setState(()=> isAuthenticating = val)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating ? null : () => _performAuth(context, user, passwordController.text, (val) => setState(()=> isAuthenticating = val)),
                child: const Text('Confirm & Unmask'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _performAuth(BuildContext dialogContext, User user, String password, void Function(bool) setLoading) async {
    if (password.isEmpty) {
      _showSnackBar("Password cannot be empty.");
      return;
    }
    setLoading(true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      Navigator.pop(dialogContext, true); // Success
    } catch (e) {
      _showSnackBar('Authentication Error. Please try again.');
      Navigator.pop(dialogContext, false); // Failure
    }
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

  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) {
      proceed = await _promptForPasswordAndReauthenticate();
      if (!proceed) {
        _showSnackBar('Authentication failed. Export will contain masked data.');
      }
    }

    try {
      List<List<dynamic>> rows = [
        [
          'Client Name', 'Client PhoneNo', 'Client ART Status', "Client's Facility",
          'Client State', 'Client ART ID', 'DatimCode', 'Date Tracked', 'Time Tracked',
          'Call Status', 'Duration of Call (s)', 'Tracked By', "Tracker's Designation",
          "Tracker's Facility", "Tracker's Supervisor", "Tracker's Supervisor Email"
        ]
      ];
      for (var contact in _filteredContactList) {
        rows.add([
          _allCellsGloballyUnlocked ? (contact.name ?? 'N/A') : _maskClientName(contact.name),
          _allCellsGloballyUnlocked ? (contact.phoneNumber ?? 'N/A') : _maskPhoneNumber(contact.phoneNumber),
          contact.artStatus ?? 'N/A',
          contact.facilityName ?? 'N/A',
          contact.state ?? 'N/A',
          contact.uniqueID ?? 'N/A',
          contact.datimCode ?? 'N/A',
          contact.dateTracked != null ? DateFormat('yyyy-MM-dd').format(contact.dateTracked!) : 'N/A',
          contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A',
          contact.callStatus ?? 'N/A',
          contact.callDuration ?? 0,
          contact.trackedBy ?? 'N/A',
          contact.designation ?? 'N/A',
          contact.trackerFacilityLocation ?? 'N/A',
          contact.supervisorName ?? 'N/A',
          contact.supervisorEmail ?? 'N/A',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      _triggerDownload(bytes, 'hq_call_tracker_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv', 'text/csv');

      _showSnackBar('CSV download started.');

    } catch (e) {
      _showSnackBar('Error exporting CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final Uint8List? callStatusBytes = await _captureChartPng(_callStatusChartKey);
      final Uint8List? artStatusBytes = await _captureChartPng(_artStatusChartKey);
      final Uint8List? callDurationBytes = await _captureChartPng(_callDurationChartKey);
      final Uint8List? updateMetricsBytes = await _captureChartPng(_updateMetricsChartKey);

      final pw.MemoryImage? callStatusImg = callStatusBytes != null ? pw.MemoryImage(callStatusBytes) : null;
      final pw.MemoryImage? artStatusImg = artStatusBytes != null ? pw.MemoryImage(artStatusBytes) : null;
      final pw.MemoryImage? callDurationImg = callDurationBytes != null ? pw.MemoryImage(callDurationBytes) : null;
      final pw.MemoryImage? updateMetricsImg = updateMetricsBytes != null ? pw.MemoryImage(updateMetricsBytes) : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('HQ Call Tracking Report - ${DateFormat.yMMMMd().format(DateTime.now())}',
                style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey)),
          ),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'Call Tracking Summary Report'),
            pw.Paragraph(
              text: 'Date Range: ${DateFormat.yMd().format(startDate!)} to ${DateFormat.yMd().format(endDate!)}\n'
                  'States: ${_selectedStates.length == _availableStates.length && _availableStates.isNotEmpty ? "All" : _selectedStates.join(", ")}\n'
                  'Facilities: ${_selectedFacilities.isEmpty ? "All (from selected states)" : _selectedFacilities.join(", ")}',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),
            pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: pw.WrapAlignment.spaceEvenly,
                children: [
                  if (callStatusImg != null) _buildPdfChart('Call Status Distribution', callStatusImg),
                  if (artStatusImg != null) _buildPdfChart('ART Status Distribution', artStatusImg),
                  if (callDurationImg != null) _buildPdfChart('Average Call Duration Trend', callDurationImg),
                  if (updateMetricsImg != null) _buildPdfChart('Monthly Update Trends', updateMetricsImg),
                ]
            ),
          ],
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      _triggerDownload(pdfBytes, 'hq_call_tracker_charts_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf', 'application/pdf');
    } catch (e) {
      _showSnackBar('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildPdfChart(String title, pw.MemoryImage image) {
    return pw.Container(width: 350, child: pw.Column(children: [pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Image(image, fit: pw.BoxFit.contain, height: 200)]));
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      _showSnackBar('Error capturing chart image: $e');
      return null;
    }
  }

  void _triggerDownload(List<int> bytes, String filename, String mimeType) {
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

  List<_ChartDataPoint> _getCallDurationTrendData() {
    Map<String, List<int>> dailyDurations = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
    for (var contact in _filteredContactList) {
      if (contact.dateTracked != null && contact.callDuration != null && contact.callDuration! > 0) {
        String dateKey = dateKeyFormat.format(contact.dateTracked!);
        dailyDurations.putIfAbsent(dateKey, () => []).add(contact.callDuration!);
      }
    }
    List<_ChartDataPoint> chartData = [];
    dailyDurations.forEach((date, durations) {
      double averageDuration = durations.reduce((a, b) => a + b) / durations.length;
      chartData.add(_ChartDataPoint(date, averageDuration));
    });
    chartData.sort((a, b) => a.x.compareTo(b.x));
    return chartData;
  }
  List<_UpdateChartData> _getUpdateMetricsData() {
    Map<String, int> phoneUpdates = {};
    Map<String, int> addressUpdates = {};
    Map<String, int> nextVisitUpdates = {};
    final DateFormat monthKeyFormat = DateFormat('yyyy-MM');
    for (var contact in _filteredContactList) {
      if (contact.datePhoneNumberUpdated != null) {
        String monthKey = monthKeyFormat.format(contact.datePhoneNumberUpdated!);
        phoneUpdates[monthKey] = (phoneUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateAddressChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateAddressChanged!);
        addressUpdates[monthKey] = (addressUpdates[monthKey] ?? 0) + 1;
      }
      if (contact.dateNextVisitChanged != null) {
        String monthKey = monthKeyFormat.format(contact.dateNextVisitChanged!);
        nextVisitUpdates[monthKey] = (nextVisitUpdates[monthKey] ?? 0) + 1;
      }
    }
    Set<String> allMonths = {...phoneUpdates.keys, ...addressUpdates.keys, ...nextVisitUpdates.keys};
    List<String> sortedMonths = allMonths.toList()..sort();
    List<_UpdateChartData> chartData = [];
    for (String month in sortedMonths) {
      chartData.add(_UpdateChartData(month, phoneUpdates[month] ?? 0, addressUpdates[month] ?? 0, nextVisitUpdates[month] ?? 0));
    }
    return chartData;
  }
  List<MapEntry<String, int>> _getArtStatusData() {
    Map<String, int> statusCounts = {};
    for (var contact in _filteredContactList) {
      String status = contact.artStatus?.trim() ?? 'Unknown';
      if (status.isEmpty) status = 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  String formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return 'N/A';
    if (totalSeconds == 0) return '0s';
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int remainingSeconds = totalSeconds % 60;

    List<String> parts = [];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (remainingSeconds > 0 || parts.isEmpty) parts.add('${remainingSeconds}s');

    return parts.join(' ');
  }

  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered': case 'completed': return Colors.green.shade700;
      case 'missed': case 'missed call': case 'not answered': case 'call failed': case 'call dropped': return Colors.red.shade700;
      case 'call busy': return Colors.orange.shade700;
      case 'unknown (no log detail)': case 'n/a': case 'unknown': return Colors.grey.shade600;
      default: return Colors.blue.shade700;
    }
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 400,
          height: 450,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (startDate != null && endDate != null)
                ? PickerDateRange(startDate!, endDate!)
                : null,
            showActionButtons: true,
            onSubmit: (Object? value) {
              Navigator.pop(context);
              if (value is PickerDateRange && value.startDate != null) {
                setState(() {
                  startDate = value.startDate;
                  endDate = value.endDate ?? value.startDate;
                });
              }
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryInfoCard() {
    final currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final numberFormatter = NumberFormat.compact();
    final totalDuration = _filteredContactList.fold<int>(0, (sum, item) => sum + (item.callDuration ?? 0));

    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 20.0,
          runSpacing: 16.0,
          children: [
            _buildInfoTile(icon: Icons.call, color: Colors.blue.shade700, label: 'Total Calls Logged', value: numberFormatter.format(_filteredContactList.length)),
            _buildInfoTile(icon: Icons.timer_outlined, color: Colors.purple.shade700, label: 'Total Call Duration', value: formatDuration(totalDuration)),
            _buildInfoTile(icon: Icons.monetization_on_outlined, color: Colors.green.shade700, label: 'Estimated Call Cost', value: currencyFormatter.format(_totalCallCost), subtitle: '(at ₦${_costPerSecond}/sec)'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required Color color, required String label, required String value, String? subtitle}) {
    // **FIXED**: The function now accepts the exact color and uses it directly.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    return Wrap(
      spacing: 20.0,
      runSpacing: 20.0,
      alignment: WrapAlignment.start,
      children: [
        _buildChartCard(title: 'Call Status Distribution', chartKey: _callStatusChartKey, chart: SfCircularChart(
            annotations: (callStatusChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null,
            legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: callStatusChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
        _buildChartCard(title: 'ART Status Distribution', chartKey: _artStatusChartKey, chart: SfCircularChart(
            annotations: (artStatusChartData.isEmpty) ? [const CircularChartAnnotation(widget: Text("No data"))] : null,
            legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[PieSeries<MapEntry<String, int>, String>(dataSource: artStatusChartData, xValueMapper: (d, _) => d.key, yValueMapper: (d, _) => d.value, dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside))])),
        _buildChartCard(isWide: true, title: 'Average Call Duration Trend (Daily)', chartKey: _callDurationChartKey, chart: SfCartesianChart(
            annotations: (callDurationTrendData.isEmpty) ? [const CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')] : null,
            primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Date Tracked')),
            primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Avg. Duration (s)'), numberFormat: NumberFormat.compact()),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries>[LineSeries<_ChartDataPoint, String>(dataSource: callDurationTrendData, xValueMapper: (data, _) => DateFormat('MMM d').format(DateFormat('yyyy-MM-dd').parse(data.x)), yValueMapper: (data, _) => data.y, name: 'Avg Duration', markerSettings: const MarkerSettings(isVisible: true))])),
        _buildChartCard(isWide: true, title: 'Monthly Update Trends', chartKey: _updateMetricsChartKey, chart: SfCartesianChart(
            annotations: (updateMetricsData.isEmpty) ? [const CartesianChartAnnotation(widget: Text("No data"), coordinateUnit: CoordinateUnit.point, region: AnnotationRegion.chart, x: '50%', y: '50%')] : null,
            primaryXAxis: const CategoryAxis(labelRotation: -45, title: AxisTitle(text: 'Month')),
            primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Number of Updates')),
            legend: const Legend(isVisible: true, position: LegendPosition.top, overflowMode: LegendItemOverflowMode.wrap),
            tooltipBehavior: TooltipBehavior(enable: true, shared: true),
            series: <CartesianSeries>[
              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.phoneUpdates, name: 'Phone Updates', markerSettings: const MarkerSettings(isVisible: true)),
              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.addressUpdates, name: 'Address Updates', markerSettings: const MarkerSettings(isVisible: true)),
              LineSeries<_UpdateChartData, String>(dataSource: updateMetricsData, xValueMapper: (d, _) => DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(d.month)), yValueMapper: (d, _) => d.nextVisitUpdates, name: 'Next Visit Updates', markerSettings: const MarkerSettings(isVisible: true)),
            ])),
      ],
    );
  }

  Widget _buildChartCard({required String title, required Widget chart, GlobalKey? chartKey, bool isWide = false}) {
    Widget chartWithBoundary = RepaintBoundary(key: chartKey, child: Container(color: Colors.white, child: chart));
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isWide ? 600 : 400, minWidth: 350),
      child: Card(
        elevation: 2.0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SizedBox(height: 250, child: chartWithBoundary),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailedLogTables(Map<String, List<ContactTracked>> dailyGroupedReports) {
    if (dailyGroupedReports.isEmpty && !_isInitialState) {
      return [const Card(child: SizedBox(height: 100, child: Center(child: Text("No detailed logs match the current filters."))))];
    }
    return dailyGroupedReports.entries.map((entry) {
      final displayDateKey = entry.key;
      final dailyContactList = entry.value;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text(displayDateKey, style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            SingleChildScrollView(
              controller: _logTableController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Client Name')), DataColumn(label: Text('Client PhoneNo')), DataColumn(label: Text('Client ART Status')),
                  DataColumn(label: Text("Client's Facility")), DataColumn(label: Text('Client State')), DataColumn(label: Text('Client ART ID')),
                  DataColumn(label: Text('DatimCode')), DataColumn(label: Text('Time Tracked')), DataColumn(label: Text('Call Status')),
                  DataColumn(label: Text('Duration')), DataColumn(label: Text('Tracked By')), DataColumn(label: Text("Tracker's Designation")),
                  DataColumn(label: Text("Tracker's Facility")), DataColumn(label: Text("Tracker's Supervisor")), DataColumn(label: Text("Tracker's Supervisor Email")),
                ],
                rows: dailyContactList.map((contact) {
                  return DataRow(cells: [
                    DataCell(Text(_maskClientName(contact.name))), DataCell(Text(_maskPhoneNumber(contact.phoneNumber))),
                    DataCell(Text(contact.artStatus ?? 'N/A')), DataCell(Text(contact.facilityName ?? 'N/A')),
                    DataCell(Text(contact.state ?? 'N/A')), DataCell(Text(contact.uniqueID ?? 'N/A')), DataCell(Text(contact.datimCode ?? 'N/A')),
                    DataCell(Text(contact.dateTracked != null ? DateFormat('HH:mm').format(contact.dateTracked!) : 'N/A')),
                    DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _getStatusColor(contact.callStatus ?? '').withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(contact.callStatus ?? 'N/A', style: TextStyle(color: _getStatusColor(contact.callStatus ?? ''))))),
                    DataCell(Text(formatDuration(contact.callDuration ?? 0))), DataCell(Text(contact.trackedBy ?? 'N/A')),
                    DataCell(Text(contact.designation ?? 'N/A')), DataCell(Text(contact.trackerFacilityLocation ?? 'N/A')),
                    DataCell(Text(contact.supervisorName ?? 'N/A')), DataCell(Text(contact.supervisorEmail ?? 'N/A')),
                  ]);
                }).toList(),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _logTableController.animateTo(_logTableController.offset - 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
              IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _logTableController.animateTo(_logTableController.offset + 350, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
            ])
          ],
        ),
      );
    }).toList();
  }
}

// Data point classes remain the same
class _ChartDataPoint {
  final String x;
  final double y;
  _ChartDataPoint(this.x, this.y);
}

class _UpdateChartData {
  final String month;
  final int phoneUpdates;
  final int addressUpdates;
  final int nextVisitUpdates;
  _UpdateChartData(this.month, this.phoneUpdates, this.addressUpdates, this.nextVisitUpdates);
}