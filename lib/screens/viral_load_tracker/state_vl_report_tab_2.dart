// lib/pages/reports/facility_vl_tracking_page.dart

// FACILITY-CENTRIC VIRAL LOAD (VL) TRACKING REPORTS PAGE - REWRITTEN WITH PASSWORD-PROTECTED MASKING
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';

import '../../widgets/drawer2.dart';

// --- DATA MODELS ---
class VlCallLog {
  final String? artId,
      callStatus,
      clientName,
      firebaseAuthId,
      phoneNumberCalled;
  final String? trackedBy,
      trackerDesignation,
      trackerFacility,
      trackerState,
      uuid;
  final DateTime? callDateTime, syncedAt;
  final int? callDurationInSeconds, vlEligibleRecordId;

  VlCallLog({
    this.artId,
    this.callDateTime,
    this.callDurationInSeconds,
    this.callStatus,
    this.clientName,
    this.firebaseAuthId,
    this.phoneNumberCalled,
    this.syncedAt,
    this.trackedBy,
    this.trackerDesignation,
    this.trackerFacility,
    this.trackerState,
    this.uuid,
    this.vlEligibleRecordId,
  });

  factory VlCallLog.fromJson(Map<String, dynamic> data) {
    return VlCallLog(
      artId: data['artId'] as String?,
      callDateTime: (data['callDateTime'] as Timestamp?)?.toDate(),
      callDurationInSeconds: data['callDurationInSeconds'] as int?,
      callStatus: data['callStatus'] as String?,
      clientName: data['clientName'] as String?,
      firebaseAuthId: data['firebaseAuthId'] as String?,
      phoneNumberCalled: data['phoneNumberCalled'] as String?,
      syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
      trackedBy: data['trackedBy'] as String?,
      trackerDesignation: data['trackerDesignation'] as String?,
      trackerFacility: data['trackerFacility'] as String?,
      trackerState: data['trackerState'] as String?,
      uuid: data['uuid'] as String?,
      vlEligibleRecordId: data['vlEligibleRecordId'] as int?,
    );
  }
}

class VlReportSummary {
  final double percentageResultsReceived, percentageSamplesCollected;
  final int refillsDueInQuarter, resultsReturned, samplesCollected;
  final int suppressed, unsuppressed, totalEligibleClientsInFilter;

  VlReportSummary({
    required this.percentageResultsReceived,
    required this.percentageSamplesCollected,
    required this.refillsDueInQuarter,
    required this.resultsReturned,
    required this.samplesCollected,
    required this.suppressed,
    required this.unsuppressed,
    required this.totalEligibleClientsInFilter,
  });

  factory VlReportSummary.fromJson(Map<String, dynamic> data) {
    return VlReportSummary(
      percentageResultsReceived:
          (data['percentageResultsReceived'] as num?)?.toDouble() ?? 0.0,
      percentageSamplesCollected:
          (data['percentageSamplesCollected'] as num?)?.toDouble() ?? 0.0,
      refillsDueInQuarter: data['refillsDueInQuarter'] as int? ?? 0,
      resultsReturned: data['resultsReturned'] as int? ?? 0,
      samplesCollected: data['samplesCollected'] as int? ?? 0,
      suppressed: data['suppressed'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      totalEligibleClientsInFilter:
          data['totalEligibleClientsInFilter'] as int? ?? 0,
    );
  }
}

// --- GlobalKeys for chart export ---
final GlobalKey _callOutcomesChartKey = GlobalKey();

class StateVlTrackingPageWeb extends StatefulWidget {
  const StateVlTrackingPageWeb({super.key});
  @override
  _StateVlTrackingPageWebState createState() => _StateVlTrackingPageWebState();
}

class _StateVlTrackingPageWebState extends State<StateVlTrackingPageWeb> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<VlCallLog> _masterLogList = [];
  List<VlReportSummary> _summaries = [];
  DateTime? startDate, endDate;
  bool isLoading = false,
      _isInitialState = true,
      _isFilterLoading = true,
      _isFacilitiesLoading = false;
  String? _errorMessage, _summaryErrorMessage;
  bool _isExporting = false;
  List<ScrollController> _logTableControllers = [];
  int _currentlyExpandedDateIndex = -1;

  // State variable for managing data visibility
  bool _allCellsGloballyUnlocked = false;

  // Filter State
  String? _currentUserState;
  final List<String> _availableFacilities = ['All Facilities'];
  List<String> _selectedFacilities = ['All Facilities'];
  List<String> _availableQuarters = [];
  String? _selectedQuarter;

  // Chart Data
  List<MapEntry<String, int>> callOutcomesChartData = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day - 6);
    endDate = now;
    _initializePage();
  }

  @override
  void dispose() {
    for (final controller in _logTableControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializePage() async {
    setState(() {
      isLoading = true;
      _isFilterLoading = true;
    });
    try {
      _generateQuarterList();
      await _loadCurrentUserBio();
      if (mounted && _currentUserState != null) {
        await _loadFacilitiesForState(_currentUserState!);
      } else if (mounted) {
        setState(() {
          isLoading = false;
          _isFilterLoading = false;
        });
        return;
      }
      if (mounted) setState(() => _isFilterLoading = false);
      if (mounted) await _loadReports();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred during page initialization: $e";
          isLoading = false;
          _isFilterLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentUserBio() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final docSnapshot =
          await _firestore.collection('Staff').doc(user.uid).get();
      if (docSnapshot.exists && mounted) {
        final state = docSnapshot.data()?['state'] as String?;
        if (state == null || state.isEmpty) {
          throw Exception("Your profile is missing a 'state' field.");
        }
        setState(() => _currentUserState = state);
      } else {
        throw Exception("Your user profile was not found.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Could not load user profile: $e");
      }
    }
  }

  Future<void> _loadFacilitiesForState(String state) async {
    setState(() => _isFacilitiesLoading = true);
    try {
      final snapshot = await _firestore
          .collection('Location')
          .doc(state)
          .collection(state)
          .get();
      final facilities = snapshot.docs
          .map((doc) => doc['LocationName'] as String)
          .where((name) => name.isNotEmpty)
          .toList()
        ..sort();
      if (mounted) setState(() => _availableFacilities.addAll(facilities));
    } catch (e) {
      if (mounted) _showSnackBar("Error fetching facility list for $state.");
    } finally {
      if (mounted) setState(() => _isFacilitiesLoading = false);
    }
  }

  void _generateQuarterList() {
    List<String> quarters = [];
    DateTime date = DateTime.now();
    for (int i = 0; i < 8; i++) {
      int year = date.year;
      int month = date.month;
      int fiscalYear = (month >= 10) ? year + 1 : year;
      String quarter;
      if (month >= 10) {
        quarter = 'Q1';
      } else if (month >= 7)
        quarter = 'Q4';
      else if (month >= 4)
        quarter = 'Q3';
      else
        quarter = 'Q2';
      quarters.add('FY${fiscalYear.toString().substring(2)} $quarter');
      date = DateTime(date.year, date.month - 3, 1);
    }
    setState(() {
      _availableQuarters = quarters.toSet().toList();
      _selectedQuarter = _availableQuarters.first;
    });
  }

  Future<void> _loadReports() async {
    if (_currentUserState == null || _selectedQuarter == null) {
      _showSnackBar("Cannot load reports: State or Quarter is not selected.");
      return;
    }
    setState(() {
      isLoading = true;
      _isInitialState = false;
      _errorMessage = _summaryErrorMessage = null;
      _masterLogList.clear();
      _summaries.clear();
    });
    try {
      await Future.wait([_fetchCallLogs(), _fetchSummaries()]);
      if (mounted) {
        _applyAllFiltersAndRecalculate();
        if (_masterLogList.isEmpty && _summaries.isEmpty) {
          _showSnackBar("No VL data found for the selected criteria.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = "An error occurred while loading reports: $e");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCallLogs() async {
    Query query = _firestore
        .collection('VlCallLogs')
        .where('trackerState', isEqualTo: _currentUserState)
        .where('callDateTime', isGreaterThanOrEqualTo: startDate)
        .where('callDateTime',
            isLessThanOrEqualTo: endDate!.add(const Duration(days: 1)));
    if (!_selectedFacilities.contains('All Facilities')) {
      query = query.where('trackerFacility', whereIn: _selectedFacilities);
    }
    final querySnapshot =
        await query.orderBy('callDateTime', descending: true).get();
    if (mounted) {
      _masterLogList = querySnapshot.docs
          .map((doc) => VlCallLog.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _fetchSummaries() async {
    final List<String> facilitiesToQuery =
        _selectedFacilities.contains('All Facilities')
            ? _availableFacilities.where((f) => f != 'All Facilities').toList()
            : _selectedFacilities;
    if (facilitiesToQuery.isEmpty) {
      if (mounted) setState(() => _summaries = []);
      return;
    }
    List<Future<DocumentSnapshot>> summaryFutures =
        facilitiesToQuery.map((facility) {
      final path =
          'VlReportSummaries/$_currentUserState/$facility/$_selectedQuarter';
      return _firestore.doc(path).get();
    }).toList();
    try {
      final List<DocumentSnapshot> results = await Future.wait(summaryFutures);
      final List<VlReportSummary> summaries = [];
      for (var doc in results) {
        if (doc.exists) {
          summaries.add(
              VlReportSummary.fromJson(doc.data() as Map<String, dynamic>));
        }
      }
      if (mounted) setState(() => _summaries = summaries);
    } catch (e) {
      if (mounted) {
        setState(
            () => _summaryErrorMessage = "Failed to load some VL summaries.");
      }
    }
  }

  void _applyAllFiltersAndRecalculate() {
    setState(() {
      _prepareChartData();
      for (final controller in _logTableControllers) {
        controller.dispose();
      }
      final dateGroups = _groupLogsByDate();
      _logTableControllers =
          List.generate(dateGroups.length, (_) => ScrollController());
      _currentlyExpandedDateIndex = _masterLogList.isNotEmpty ? 0 : -1;
    });
  }

  void _prepareChartData() {
    callOutcomesChartData = _getCallOutcomesChartData();
  }

  // --- AUTHENTICATION AND MASKING LOGIC ---

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showSnackBar(
          "Cannot authenticate: User or user email is not available.");
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isAuthenticating = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void performReauth() async {
              if (passwordController.text.isEmpty) {
                _showSnackBar("Password cannot be empty.");
                return;
              }
              setStateDialog(() => isAuthenticating = true);
              try {
                final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text.trim());
                await user.reauthenticateWithCredential(credential);
                if (mounted) Navigator.pop(context, true);
              } on FirebaseAuthException catch (e) {
                _showSnackBar(
                    'Authentication Error: ${e.message ?? "An unknown error occurred."}');
                if (mounted) Navigator.pop(context, false);
              } catch (e) {
                _showSnackBar(
                    'An unexpected error occurred during authentication.');
                if (mounted) Navigator.pop(context, false);
              }
            }

            return AlertDialog(
              title: const Text('Authentication Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Please enter your password to unmask sensitive data."),
                  const SizedBox(height: 10),
                  if (isAuthenticating)
                    const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()))
                  else
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: 'Password', border: OutlineInputBorder()),
                      onSubmitted: (_) => performReauth(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isAuthenticating ? null : performReauth,
                  child: const Text('Confirm & Unmask'),
                ),
              ],
            );
          },
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

  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) {
      return name ?? 'N/A';
    }
    List<String> parts = name.split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return '${parts[0][0]}. (Hidden)';
    }
    return 'Hidden';
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) {
      return phone ?? 'N/A';
    }
    return phone.length > 4
        ? '...${phone.substring(phone.length - 4)}'
        : '****';
  }

  String _maskArtId(String? artId) {
    if (_allCellsGloballyUnlocked || artId == null || artId.isEmpty) {
      return artId ?? 'N/A';
    }
    return artId.length > 4
        ? '...${artId.substring(artId.length - 4)}'
        : '****';
  }

  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'answered':
      case 'incoming answered':
      case 'completed':
        return Colors.green.shade700;
      case 'outgoing failed/not answered':
      case 'unknown (no outgoing log detail)':
      case 'missed':
      case 'missed call':
      case 'call failed':
      case 'call dropped':
      case 'unknown (no log detail)':
        return Colors.red.shade700;
      case 'call busy':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusCell(String? status) {
    if (status == null || status.isEmpty) return const Text('N/A');
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1)),
      child: Text(status,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
    );
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_isFilterLoading) {
      bodyContent = const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading User Profile...")
        ],
      ));
    } else if (isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bodyContent = Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center)));
    } else {
      bodyContent = _buildDashboardContent();
    }
    String appBarTitle = _currentUserState != null
        ? 'VL Reports for $_currentUserState'
        : 'Facility VL Reports';
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _buildAppBarActions(),
      ),
      drawer: drawer2(context),
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
        tooltip: _allCellsGloballyUnlocked
            ? 'Mask Sensitive Data'
            : 'Unmask Sensitive Data',
        icon: Icon(_allCellsGloballyUnlocked
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        onPressed: _toggleGlobalUnmask,
      ),
      if (_isExporting)
        const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white)))
      else
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: "Export Options",
          onSelected: (value) async {
            if (value == 'csv') await _exportToCSV();
          },
          enabled: !isLoading &&
              !_isInitialState &&
              (_masterLogList.isNotEmpty || _summaries.isNotEmpty),
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'csv',
                child: ListTile(
                    leading: Icon(Icons.grid_on_outlined, color: Colors.green),
                    title: Text('Export CSV'))),
          ],
        ),
    ];
  }

  Widget _buildFilterBar() {
    if (_isFilterLoading || _currentUserState == null) {
      return const SizedBox.shrink();
    }
    String facilityButtonText = _selectedFacilities.contains('All Facilities')
        ? 'All Facilities'
        : _selectedFacilities.length == 1
            ? _selectedFacilities.first
            : '${_selectedFacilities.length} Facilities';
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.start,
          children: [
            _buildFilterChip(
                "Facility", facilityButtonText, Icons.business_center, () {
              _showMultiSelectDialog(
                context: context,
                title: 'Select Facilities',
                allOptions: _availableFacilities,
                selectedOptions: _selectedFacilities,
                allKeyword: 'All Facilities',
                onConfirm: (results) =>
                    setState(() => _selectedFacilities = results),
              );
            }, disabled: _isFacilitiesLoading),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedQuarter,
                hint: const Text('Select Quarter'),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Quarter',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                items: _availableQuarters
                    .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedQuarter = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text((startDate != null && endDate != null)
                  ? '${_formatDateWithSuffix(startDate!)} - ${_formatDateWithSuffix(endDate!)}'
                  : 'Select Dates'),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: isLoading ? null : _loadReports,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isInitialState && !isLoading) {
      return Center(
          child: Text("Select facilities and apply filters to view VL reports.",
              style: TextStyle(color: Colors.grey.shade700)));
    }
    if (_masterLogList.isEmpty && _summaries.isEmpty && !isLoading) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("No VL data found for the selected criteria.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700))));
    }
    final Map<String, List<VlCallLog>> dailyGroupedReports = _groupLogsByDate();
    final dailyGroupedKeys = dailyGroupedReports.keys.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_summaries.isNotEmpty || _summaryErrorMessage != null) ...[
            _buildVlSummarySection(),
            const SizedBox(height: 24),
          ],
          if (_masterLogList.isNotEmpty) ...[
            Text('Call Log Analysis',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildCallLogChartSection(),
            const SizedBox(height: 30),
            Text('Detailed Call Logs',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _buildDetailedLogSection(dailyGroupedKeys, dailyGroupedReports),
          ]
        ],
      ),
    );
  }

  Widget _buildVlSummarySection() {
    if (_summaryErrorMessage != null) {
      return Card(
          color: Colors.red.shade50,
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                    child: Text("Summary Error: $_summaryErrorMessage",
                        style: TextStyle(color: Colors.red.shade800)))
              ])));
    }
    if (_summaries.isEmpty) return const SizedBox.shrink();
    final int totalEligible =
        _summaries.fold(0, (p, s) => p + s.totalEligibleClientsInFilter);
    final int totalSamples =
        _summaries.fold(0, (p, s) => p + s.samplesCollected);
    final int totalResults =
        _summaries.fold(0, (p, s) => p + s.resultsReturned);
    final int totalSuppressed = _summaries.fold(0, (p, s) => p + s.suppressed);
    final int totalUnsuppressed =
        _summaries.fold(0, (p, s) => p + s.unsuppressed);
    final double avgSampleCollectionRate =
        totalEligible > 0 ? (totalSamples / totalEligible) * 100 : 0.0;
    final double avgResultReturnRate =
        totalSamples > 0 ? (totalResults / totalSamples) * 100 : 0.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aggregated VL Summary for $_selectedQuarter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade800)),
            const SizedBox(height: 4),
            Text(
                'For ${_selectedFacilities.contains("All Facilities") ? "All Facilities" : "${_selectedFacilities.length} Facilitie(s)"} in $_currentUserState',
                style: TextStyle(color: Colors.blueGrey.shade600)),
            const Divider(height: 24),
            Wrap(
              spacing: 20.0,
              runSpacing: 20.0,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildInfoTile(
                    iconWidget: Icon(Icons.people_alt_outlined,
                        size: 36, color: Colors.blue.shade700),
                    label: 'Total Eligible Clients',
                    value: totalEligible.toString()),
                _buildInfoTile(
                    iconWidget: Icon(Icons.bloodtype_outlined,
                        size: 36, color: Colors.red.shade700),
                    label: 'Samples Collected',
                    value: totalSamples.toString(),
                    subtitle:
                        '${avgSampleCollectionRate.toStringAsFixed(1)}% of eligible'),
                _buildInfoTile(
                    iconWidget: Icon(Icons.assignment_turned_in_outlined,
                        size: 36, color: Colors.green.shade700),
                    label: 'Results Returned',
                    value: totalResults.toString(),
                    subtitle:
                        '${avgResultReturnRate.toStringAsFixed(1)}% of samples'),
                _buildInfoTile(
                    iconWidget: Icon(Icons.check_circle_outline,
                        size: 36, color: Colors.green.shade900),
                    label: 'Suppressed',
                    value: totalSuppressed.toString()),
                _buildInfoTile(
                    iconWidget: Icon(Icons.warning_amber_rounded,
                        size: 36, color: Colors.orange.shade900),
                    label: 'Unsuppressed',
                    value: totalUnsuppressed.toString()),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCallLogChartSection() {
    return Wrap(
      spacing: 20.0,
      runSpacing: 20.0,
      alignment: WrapAlignment.start,
      children: [
        _buildChartCard(
            title: 'Call Outcome Distribution',
            chartKey: _callOutcomesChartKey,
            chart: SfCircularChart(
                annotations: (callOutcomesChartData.isEmpty)
                    ? [const CircularChartAnnotation(widget: Text("No data"))]
                    : null,
                legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap),
                series: <CircularSeries>[
                  PieSeries<MapEntry<String, int>, String>(
                      dataSource: callOutcomesChartData,
                      xValueMapper: (d, _) => d.key,
                      yValueMapper: (d, _) => d.value,
                      dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          labelPosition: ChartDataLabelPosition.outside))
                ])),
      ],
    );
  }

  Widget _buildDetailedLogSection(List<String> dailyGroupedKeys,
      Map<String, List<VlCallLog>> dailyGroupedReports) {
    if (dailyGroupedKeys.isEmpty) {
      return const Card(
          child: SizedBox(
              height: 100,
              child: Center(
                  child: Text("No call logs match the current filters."))));
    }
    return ExpansionPanelList(
      expansionCallback: (int index, bool isExpanded) => setState(() =>
          _currentlyExpandedDateIndex =
              _currentlyExpandedDateIndex == index ? -1 : index),
      animationDuration: const Duration(milliseconds: 300),
      children: dailyGroupedKeys.map<ExpansionPanel>((String dateKey) {
        final index = dailyGroupedKeys.indexOf(dateKey);
        final dailyLogList = dailyGroupedReports[dateKey]!;
        final bool isExpanded = _currentlyExpandedDateIndex == index;
        return ExpansionPanel(
          isExpanded: isExpanded,
          canTapOnHeader: true,
          headerBuilder: (BuildContext context, bool isExpanded) => ListTile(
              title: Text(dateKey,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          body: SingleChildScrollView(
            controller: _logTableControllers.length > index
                ? _logTableControllers[index]
                : ScrollController(),
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Client Name')),
                  DataColumn(label: Text('ART ID')),
                  DataColumn(label: Text('Phone No.')),
                  DataColumn(label: Text("Facility")),
                  DataColumn(label: Text('Call Status')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Duration')),
                  DataColumn(label: Text('Tracked By'))
                ],
                rows: dailyLogList
                    .map((log) => DataRow(cells: [
                          DataCell(Text(_maskClientName(log.clientName))),
                          DataCell(Text(_maskArtId(log.artId))),
                          DataCell(
                              Text(_maskPhoneNumber(log.phoneNumberCalled))),
                          DataCell(Text(log.trackerFacility ?? 'N/A')),
                          DataCell(_buildStatusCell(log.callStatus)),
                          DataCell(Text(log.callDateTime != null
                              ? DateFormat('HH:mm').format(log.callDateTime!)
                              : 'N/A')),
                          DataCell(Text(
                              formatDuration(log.callDurationInSeconds ?? 0))),
                          DataCell(Text(log.trackedBy ?? 'N/A')),
                        ]))
                    .toList(),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);
    bool proceed = _allCellsGloballyUnlocked;
    if (!_allCellsGloballyUnlocked) {
      proceed = await _promptForPasswordAndReauthenticate();
      if (!proceed) {
        _showSnackBar(
            'Authentication failed. Export will contain masked data.');
      }
    }
    try {
      List<List<dynamic>> rows = [];
      rows.add(['VIRAL LOAD REPORT SUMMARY']);
      rows.add([
        'State:',
        _currentUserState ?? 'N/A',
        'Quarter:',
        _selectedQuarter ?? 'N/A',
        'Facilities:',
        _selectedFacilities.join(", ")
      ]);
      rows.add([]);
      rows.add(['Metric', 'Value']);
      final int totalEligible =
          _summaries.fold(0, (p, s) => p + s.totalEligibleClientsInFilter);
      final int totalSamples =
          _summaries.fold(0, (p, s) => p + s.samplesCollected);
      final int totalResults =
          _summaries.fold(0, (p, s) => p + s.resultsReturned);
      rows.add(['Total Eligible Clients', totalEligible]);
      rows.add(['Samples Collected', totalSamples]);
      rows.add(['Results Returned', totalResults]);
      rows.add([]);
      rows.add(['DETAILED CALL LOGS']);
      rows.add([
        'Call Status',
        'Client Name',
        'ART ID',
        'Phone No',
        'Facility',
        'Date',
        'Time',
        'Duration(s)',
        'Tracked By'
      ]);
      for (var log in _masterLogList) {
        rows.add([
          log.callStatus,
          _maskClientName(log.clientName),
          _maskArtId(log.artId),
          _maskPhoneNumber(log.phoneNumberCalled),
          log.trackerFacility,
          log.callDateTime != null
              ? DateFormat('yyyy-MM-dd').format(log.callDateTime!)
              : 'N/A',
          log.callDateTime != null
              ? DateFormat('HH:mm').format(log.callDateTime!)
              : 'N/A',
          log.callDurationInSeconds,
          log.trackedBy
        ]);
      }
      String csvData = const ListToCsvConverter().convert(rows);
      final filename =
          'facility_vl_tracking_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      _triggerDownload(utf8.encode(csvData), filename, 'text/csv');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _triggerDownload(List<int> bytes, String filename, String mimeType) {
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
      // Mobile platform - show message that download is not supported
      _showSnackBar('CSV download is only supported on web platform');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20)));
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
                    onCancel: () => Navigator.pop(context)))));
  }

  String _formatDateWithSuffix(DateTime date) {
    String day = DateFormat('d').format(date);
    String suffix;
    switch (int.parse(day) % 10) {
      case 1:
        suffix = (day.endsWith('11')) ? 'th' : 'st';
        break;
      case 2:
        suffix = (day.endsWith('12')) ? 'th' : 'nd';
        break;
      case 3:
        suffix = (day.endsWith('13')) ? 'th' : 'rd';
        break;
      default:
        suffix = 'th';
    }
    return DateFormat("d'$suffix' MMMM yyyy").format(date);
  }

  List<MapEntry<String, int>> _getCallOutcomesChartData() {
    Map<String, int> statusCounts = {};
    for (var log in _masterLogList) {
      String status = log.callStatus?.trim() ?? 'N/A';
      if (status.isEmpty) status = 'N/A';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    return statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    List<String> parts = [];
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    return parts.join(' ');
  }

  Map<String, List<VlCallLog>> _groupLogsByDate() {
    final Map<String, List<VlCallLog>> dailyReports = {};
    final DateFormat displayFormat = DateFormat('EEEE, MMMM d, yyyy');
    for (var log in _masterLogList) {
      final dateKey = log.callDateTime != null
          ? displayFormat.format(log.callDateTime!)
          : 'Unknown Date';
      dailyReports.putIfAbsent(dateKey, () => []).add(log);
    }
    return dailyReports;
  }

  Widget _buildFilterChip(
      String label, String value, IconData icon, VoidCallback onPressed,
      {bool disabled = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      InputChip(
        avatar: _isFacilitiesLoading && label == "Facility"
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(value, overflow: TextOverflow.ellipsis),
        onPressed: disabled ? null : onPressed,
        showCheckmark: false,
        side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.7)),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      )
    ]);
  }

  Widget _buildInfoTile(
      {required Widget iconWidget,
      required String label,
      required String value,
      String? subtitle}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600))
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(
      {required String title,
      required Widget chart,
      GlobalKey? chartKey,
      bool isWide = false}) {
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
              SizedBox(
                  height: 250,
                  child: RepaintBoundary(
                      key: chartKey,
                      child: Container(color: Colors.white, child: chart)))
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMultiSelectDialog({
    required BuildContext context,
    required String title,
    required List<String> allOptions,
    required List<String> selectedOptions,
    required String allKeyword,
    required Function(List<String>) onConfirm,
  }) async {
    final tempSelected = List<String>.from(selectedOptions);
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(builder: (bldContext, setStateDialog) {
            return AlertDialog(
                title: Text(title),
                content: SizedBox(
                    width: 350,
                    child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allOptions.length,
                        itemBuilder: (context, index) {
                          final option = allOptions[index];
                          final isAllOption = option == allKeyword;
                          return CheckboxListTile(
                            title: Text(option,
                                style: TextStyle(
                                    fontWeight: isAllOption
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            value: tempSelected.contains(option),
                            onChanged: (bool? value) {
                              setStateDialog(() {
                                if (value == true) {
                                  if (isAllOption) {
                                    tempSelected
                                      ..clear()
                                      ..add(allKeyword);
                                  } else {
                                    tempSelected.remove(allKeyword);
                                    tempSelected.add(option);
                                  }
                                } else {
                                  tempSelected.remove(option);
                                  if (tempSelected.isEmpty &&
                                      allOptions.contains(allKeyword)) {
                                    tempSelected.add(allKeyword);
                                  }
                                }
                              });
                            },
                          );
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        onConfirm(tempSelected);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Apply'))
                ]);
          });
        });
  }
}
