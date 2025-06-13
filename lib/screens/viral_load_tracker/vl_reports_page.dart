// REWRITTEN FOR FLUTTER WEB
// Removed: dart:io, path_provider, share_plus, printing
// Added: dart:html, dart:convert

import 'dart:convert' show utf8;
import 'dart:html' as html; // NEW: Added for web download functionality
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:attendanceappmailtool/screens/viral_load_tracker/vl_call_log_model.dart';
import 'package:attendanceappmailtool/screens/viral_load_tracker/vl_eligible_model.dart';
import 'package:attendanceappmailtool/screens/viral_load_tracker/vl_form_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart' show PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../../widgets/drawer.dart';

// Define separate keys for RepaintBoundary
final GlobalKey _currentQuarterChartBoundaryKey = GlobalKey();
final GlobalKey _previousQuarterChartBoundaryKey = GlobalKey();
final GlobalKey _olderSamplesChartBoundaryKey = GlobalKey();
final GlobalKey _callOutcomesChartBoundaryKey = GlobalKey();

class ReportVlTab extends StatefulWidget {
  const ReportVlTab({super.key});

  @override
  _ReportVlTabState createState() => _ReportVlTabState();
}

class _ChartData {
  _ChartData(this.x, this.y, [this.color]);
  final String x;
  final double y;
  final Color? color;
}

class _ReportVlTabState extends State<ReportVlTab> {
  // ... (All state variables and initialization methods like initState, _initializeData, etc., remain the same)
  bool _isLoading = true;
  bool _isExporting = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  List<VlEligibleModel> _allEligibleList = [];
  List<VlCallLogModel> _callLogs = [];

  List<VlEligibleModel> _masterVlEligibleList = [];
  List<VlCallLogModel> _masterCallLogs = [];

  DateTime? _startDateFilter;
  DateTime? _endDateFilter;

  bool _allCellsGloballyUnlocked = false;
  bool isLoading = true; // Start loading initially
  bool _isUserBioLoading = true;
  String? _errorMessage;

  // Current Quarter Metrics
  String _currentQuarter = '';
  String _currentQuarterDisplay = '';
  int _totalEligibleOverall = 0;
  int _totalEligibleDueForRefillInQuarter = 0;
  int _totalEligibleDueForRefillOutsideQuarter = 0;
  int _samplesCollectedInQuarter = 0;
  int _resultsReturnedInQuarter = 0;
  int _suppressedInQuarter = 0;
  int _unsuppressedInQuarter = 0;
  int _tatExceeded3MonthsCurrentQuarter = 0;
  int _tatOver3MonthsWithResultCurrentQuarter = 0;

  // Previous Quarter Metrics
  String _previousQuarter = '';
  String _previousQuarterDisplay = '';
  int _samplesCollectedPreviousQuarter = 0;
  int _resultsReturnedPreviousQuarter = 0;
  int _suppressedPreviousQuarter = 0;
  int _unsuppressedPreviousQuarter = 0;
  int _tatExceeded3MonthsPreviousQuarter = 0;
  int _tatOver3MonthsWithResultPreviousQuarter = 0;

  // Older Samples Metrics (collected before previous quarter)
  String _olderSamplesDisplayTitle = '';
  int _samplesCollectedOlder = 0;
  int _resultsReturnedOlder = 0;
  int _suppressedOlder = 0;
  int _unsuppressedOlder = 0;
  int _tatExceeded3MonthsOlder = 0;
  int _tatOver3MonthsWithResultOlder = 0;

  // Call Log Metrics
  int _totalCallsMade = 0;
  int _callsAnswered = 0;
  int _callsNotAnsweredOrFailed = 0;
  double _averageCallDurationSeconds = 0;

  // Overall Percentage Metrics
  double _percentageSampleCollected = 0.0;
  double _percentageResultReceived = 0.0;

  // Overall "Not Active" Client Status Summary
  int _totalNotActive = 0;
  int _totalDeaths = 0;
  int _totalTransferredOut = 0;
  int _totalMissedAppointments = 0;
  int _totalIIT = 0;
  int _totalDiscontinuedCare = 0;

  // Firebase Sync
  final Connectivity _connectivity = Connectivity();
  bool _isSyncingToFirebase = false;
  String? _firebaseAuthId;
  String? _trackerState;
  String? _trackerFacilityLocation;
  String? _trackedBy;

  String? currentUserAuthId;
  String? userFirstName;
  String? userLastName;
  String? userDesignation;
  String? userLocation;
  String? userState;
  String? userSupervisor;
  String? userSupervisorEmail;

  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      await _loadFirebaseUserDetails();
      await _loadAndCalculateReports(applyDateFilter: false);
    } catch (e, stack) {
      debugPrint('❌ Error in _initializeData: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        _showSnackBar('Failed to initialize: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFirebaseUserDetails() async {
    setState(() {
      _isUserBioLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      currentUserAuthId = user.uid;

      final docSnapshot =
      await _firestore.collection('Staff').doc(currentUserAuthId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final String firstName = (data['firstName'] as String?)?.trim() ?? '';
        final String lastName = (data['lastName'] as String?)?.trim() ?? '';
        final String fullName = [firstName, lastName]
            .where((s) => s.isNotEmpty)
            .join(' ');
        setState(() {
          _trackedBy = fullName;
          _firebaseAuthId = currentUserAuthId;
          _trackerFacilityLocation = data['location'] as String?;
          _trackerState = data['state'] as String?;
          _isUserBioLoading = false;
        });
        print("_trackedBy==$_trackedBy");
        print("_firebaseAuthId==$_firebaseAuthId");
        print("_trackerFacilityLocation==$_trackerFacilityLocation");
        print("_trackerState==$_trackerState");
      } else {
        throw Exception(
            "User bio data not found in Firestore 'Staff' collection.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading user details: $e";
          _isUserBioLoading = false;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFirebaseUserDetails1() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _trackedBy = prefs.getString('selected_FullName');
      _firebaseAuthId = prefs.getString('firebaseAuthId');
      _trackerState = prefs.getString('trackerState');
      _trackerFacilityLocation = prefs.getString('trackerFacilityLocation');

      if (_firebaseAuthId == null || _trackerState == null || _trackerFacilityLocation == null) {
        final user = _firebaseAuth.currentUser;
        if (user != null) {
          _firebaseAuthId ??= user.uid;
          final userDoc = await _firestore.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            _trackedBy ??= userData?['fullName'] ?? '${userData?['firstName']} ${userData?['lastName']}'.trim();
            _trackerState ??= userData?['state'];
            _trackerFacilityLocation ??= userData?['facilityLocation'];
            await prefs.setString('selected_FullName', _trackedBy!);
            await prefs.setString('firebaseAuthId', _firebaseAuthId!);
            await prefs.setString('trackerState', _trackerState!);
            await prefs.setString('trackerFacilityLocation', _trackerFacilityLocation!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading Firebase user details in Report tab: $e");
      _showSnackBar("Could not load user profile. Reports may be unavailable.");
    }
  }

  Future<void> _syncReportDataToServer() async {
    if (_isSyncingToFirebase) return;

    try {
      if (mounted) setState(() => _isSyncingToFirebase = true);

      final connectivityResult = await _connectivity.checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.mobile) && !connectivityResult.contains(ConnectivityResult.wifi)) {
        _showSnackBar('No internet connection. Cannot sync.');
        return;
      }

      if (_firebaseAuthId == null || _trackerState == null || _trackerFacilityLocation == null || _currentQuarterDisplay.isEmpty) {
        _showSnackBar('User, facility, or quarter details missing. Cannot sync.');
        return;
      }

      _showSnackBar('Uploading report summary to server...');

      final Map<String, dynamic> vlSummaryData = {
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedByAuthId': _firebaseAuthId,
        'updatedByFullName': _trackedBy,
        'quarterName': _currentQuarterDisplay,
        'totalEligibleClientsInFilter': _totalEligibleOverall,
        'percentageSamplesCollected': _percentageSampleCollected,
        'percentageResultsReceived': _percentageResultReceived,
        'refillsDueInQuarter': _totalEligibleDueForRefillInQuarter,
        'refillsDueOutsideQuarter': _totalEligibleDueForRefillOutsideQuarter,
        'samplesCollected': _samplesCollectedInQuarter,
        'resultsReturned': _resultsReturnedInQuarter,
        'suppressed': _suppressedInQuarter,
        'unsuppressed': _unsuppressedInQuarter,
        'tatPendingOver90Days': _tatExceeded3MonthsCurrentQuarter,
        'tatResultOver90Days': _tatOver3MonthsWithResultCurrentQuarter,
        'totalNotActive': _totalNotActive,
        'totalDeaths': _totalDeaths,
        'totalTransferredOut': _totalTransferredOut,
        'totalMissedAppointments': _totalMissedAppointments,
        'totalIIT': _totalIIT,
        'totalDiscontinuedCare': _totalDiscontinuedCare,
      };

      final DocumentReference quarterDocRef = _firestore
          .collection('VlReportSummaries')
          .doc(_trackerState)
          .collection(_trackerFacilityLocation!)
          .doc(_currentQuarterDisplay);

      await quarterDocRef.set(vlSummaryData, SetOptions(merge: true));

      _showSnackBar('✅ Report summary uploaded successfully!');
    } catch (e, stackTrace) {
      debugPrint('❌ Error during Firebase sync: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showSnackBar('Upload failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSyncingToFirebase = false);
    }
  }

  Future<void> _loadAndCalculateReports({bool applyDateFilter = true}) async {
    try {
      if (mounted && !_isSyncingToFirebase) setState(() => _isLoading = true);

      _calculateCurrentAndPreviousQuarters();

      if (_trackerState == null || _trackerFacilityLocation == null || _currentQuarterDisplay.isEmpty) {
        _showSnackBar("User's state, facility, or current quarter is not set. Cannot load report data.");
        _masterVlEligibleList = [];
        _masterCallLogs = [];
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final DocumentReference quarterSummaryDocRef = _firestore
          .collection('VlReportSummaries')
          .doc(_trackerState!)
          .collection(_trackerFacilityLocation!)
          .doc(_currentQuarterDisplay);

      final summarySnapshot = await quarterSummaryDocRef.get();

      _masterVlEligibleList = [];
      _masterCallLogs = [];

      if (summarySnapshot.exists && summarySnapshot.data() != null) {
        final summaryModel = VlEligibleModel.fromMap(
          summarySnapshot.id,
          summarySnapshot.data() as Map<String, dynamic>,
        );
        _masterVlEligibleList.add(summaryModel);
      }

      _allEligibleList = List.from(_masterVlEligibleList);

      final callLogSnapshot = await quarterSummaryDocRef.collection('callLogs').get();
      _masterCallLogs = callLogSnapshot.docs
          .map((doc) => VlCallLogModel.fromMap(doc.id, doc.data()))
          .toList();

      if (applyDateFilter && _startDateFilter != null && _endDateFilter != null) {
        final adjustedEndDate = DateTime(_endDateFilter!.year, _endDateFilter!.month, _endDateFilter!.day, 23, 59, 59);
        _callLogs = _masterCallLogs.where((log) {
          return log.callDateTime != null && !log.callDateTime!.isBefore(_startDateFilter!) && !log.callDateTime!.isAfter(adjustedEndDate);
        }).toList();
      } else {
        _callLogs = List.from(_masterCallLogs);
      }

      _calculateMetrics();

    } catch (e, stack) {
      debugPrint('❌ Error in _loadAndCalculateReports: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) _showSnackBar('Failed to load reports from server: $e');
      print('Failed to load reports from server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateCurrentAndPreviousQuarters() {
    final now = DateTime.now();
    int currentMonth = now.month;
    int currentYear = now.year;

    if (currentMonth >= 10) {
      _currentQuarter = 'Q1';
      _currentQuarterDisplay = 'Q1 (FY${(currentYear + 1).toString().substring(2)})';
      _previousQuarter = 'Q4';
      _previousQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 7) {
      _currentQuarter = 'Q4';
      _currentQuarterDisplay = 'Q4 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q3';
      _previousQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
    } else if (currentMonth >= 4) {
      _currentQuarter = 'Q3';
      _currentQuarterDisplay = 'Q3 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q2';
      _previousQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
    } else {
      _currentQuarter = 'Q2';
      _currentQuarterDisplay = 'Q2 (FY${currentYear.toString().substring(2)})';
      _previousQuarter = 'Q1';
      _previousQuarterDisplay = 'Q1 (FY${currentYear.toString().substring(2)})';
    }
  }

  bool _isDateInQuarter(DateTime? date, String quarterName, String quarterDisplayName) {
    try {
      if (date == null) return false;
      final match = RegExp(r'\(FY(\d{2,4})\)').firstMatch(quarterDisplayName);
      if (match == null) return false;

      final fiscalYear = int.parse(match.group(1)!.length == 2 ? '20${match.group(1)}' : match.group(1)!);
      final month = date.month;
      final year = date.year;

      switch (quarterName) {
        case 'Q1': return year == fiscalYear - 1 && month >= 10;
        case 'Q2': return year == fiscalYear && month <= 3;
        case 'Q3': return year == fiscalYear && month >= 4 && month <= 6;
        case 'Q4': return year == fiscalYear && month >= 7 && month <= 9;
        default: return false;
      }
    } catch (e) {
      debugPrint('❌ Quarter parsing error: $e');
      return false;
    }
  }

  void _calculateMetrics() {
    setState(() {
      _totalEligibleOverall = 0;
      _percentageSampleCollected = 0.0;
      _percentageResultReceived = 0.0;
      _totalEligibleDueForRefillInQuarter = 0;
      _totalEligibleDueForRefillOutsideQuarter = 0;
      _samplesCollectedInQuarter = 0;
      _resultsReturnedInQuarter = 0;
      _suppressedInQuarter = 0;
      _unsuppressedInQuarter = 0;
      _tatExceeded3MonthsCurrentQuarter = 0;
      _tatOver3MonthsWithResultCurrentQuarter = 0;
      _totalNotActive = 0;
      _totalDeaths = 0;
      _totalTransferredOut = 0;
      _totalMissedAppointments = 0;
      _totalIIT = 0;
      _totalDiscontinuedCare = 0;

      _samplesCollectedPreviousQuarter = 0;
      _resultsReturnedPreviousQuarter = 0;
      _suppressedPreviousQuarter = 0;
      _unsuppressedPreviousQuarter = 0;
      _tatExceeded3MonthsPreviousQuarter = 0;
      _tatOver3MonthsWithResultPreviousQuarter = 0;

      _previousQuarterDisplay = '';
      _olderSamplesDisplayTitle = '';

      _samplesCollectedOlder = 0;
      _resultsReturnedOlder = 0;
      _suppressedOlder = 0;
      _unsuppressedOlder = 0;
      _tatExceeded3MonthsOlder = 0;
      _tatOver3MonthsWithResultOlder = 0;

      _totalCallsMade = 0;
      _callsAnswered = 0;
      _callsNotAnsweredOrFailed = 0;
      _averageCallDurationSeconds = 0.0;
    });

    if (_allEligibleList.isNotEmpty) {
      final summary = _allEligibleList.first;
      setState(() {
        _totalEligibleOverall = summary.totalEligibleClientsInFilter;
        _percentageSampleCollected = summary.percentageSamplesCollected;
        _percentageResultReceived = summary.percentageResultsReceived;
        _totalEligibleDueForRefillInQuarter = summary.refillsDueInQuarter;
        _totalEligibleDueForRefillOutsideQuarter = summary.refillsDueOutsideQuarter;
        _samplesCollectedInQuarter = summary.samplesCollected;
        _resultsReturnedInQuarter = summary.resultsReturned;
        _suppressedInQuarter = summary.suppressed;
        _unsuppressedInQuarter = summary.unsuppressed;
        _tatExceeded3MonthsCurrentQuarter = summary.tatPendingOver90Days;
        _tatOver3MonthsWithResultCurrentQuarter = summary.tatResultOver90Days;
        _totalNotActive = summary.totalNotActive;
        _totalDeaths = summary.totalDeaths;
        _totalTransferredOut = summary.totalTransferredOut;
        _totalMissedAppointments = summary.totalMissedAppointments;
        _totalIIT = summary.totalIIT;
        _totalDiscontinuedCare = summary.totalDiscontinuedCare;

        _previousQuarterDisplay = summary.previousQuarterDisplay ?? _previousQuarterDisplay;
        _samplesCollectedPreviousQuarter = summary.samplesCollectedPreviousQuarter;
        _resultsReturnedPreviousQuarter = summary.resultsReturnedPreviousQuarter;
        _suppressedPreviousQuarter = summary.suppressedPreviousQuarter;
        _unsuppressedPreviousQuarter = summary.unsuppressedPreviousQuarter;
        _tatExceeded3MonthsPreviousQuarter = summary.tatExceeded3MonthsPreviousQuarter;
        _tatOver3MonthsWithResultPreviousQuarter = summary.tatOver3MonthsWithResultPreviousQuarter;

        _olderSamplesDisplayTitle = summary.olderSamplesDisplayTitle ?? "Older Samples";
        _samplesCollectedOlder = summary.samplesCollectedOlder;
        _resultsReturnedOlder = summary.resultsReturnedOlder;
        _suppressedOlder = summary.suppressedOlder;
        _unsuppressedOlder = summary.unsuppressedOlder;
        _tatExceeded3MonthsOlder = summary.tatExceeded3MonthsOlder;
        _tatOver3MonthsWithResultOlder = summary.tatOver3MonthsWithResultOlder;
      });
    }

    if (_callLogs.isNotEmpty) {
      _totalCallsMade = _callLogs.length;
      _callsAnswered = _callLogs.where((log) => log.callStatus?.toLowerCase() == "answered").length;
      _callsNotAnsweredOrFailed = _totalCallsMade - _callsAnswered;
      if (_callsAnswered > 0) {
        var answeredLogs = _callLogs.where((log) => log.callStatus?.toLowerCase() == "answered" && (log.callDurationInSeconds ?? 0) > 0);
        if (answeredLogs.isNotEmpty) {
          _averageCallDurationSeconds = answeredLogs.map((log) => log.callDurationInSeconds!).reduce((a, b) => a + b) / answeredLogs.length;
        }
      }
    }

    if(mounted) setState(() {});
  }


  String _maskClientName(String? name) {
    if (_allCellsGloballyUnlocked || name == null || name.isEmpty) return name ?? 'N/A';
    List<String> parts = name.split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? '${parts[0][0]}. (Hidden)' : 'Hidden';
  }

  String _maskArtId(String? artId) {
    if (_allCellsGloballyUnlocked || artId == null || artId.isEmpty) return artId ?? 'N/A';
    return artId.length > 4 ? '${artId.substring(0, 2)}...${artId.substring(artId.length - 2)}' : artId.replaceAll(RegExp(r'.'), '*');
  }

  String _maskPhoneNumber(String? phone) {
    if (_allCellsGloballyUnlocked || phone == null || phone.isEmpty) return phone ?? 'N/A';
    return phone.length > 4 ? '...${phone.substring(phone.length - 4)}' : phone.replaceAll(RegExp(r'.'), '*');
  }

  Future<bool> _promptForPasswordAndReauthenticate() async {
    final passwordController = TextEditingController();
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      _showSnackBar("Not signed in. Cannot perform action.");
      return false;
    }
    if (user.email == null) {
      _showSnackBar("User email is not available for password authentication.");
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isAuthenticating = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Authentication Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Please enter your password to unmask sensitive data."),
                SizedBox(height: 10),
                if (isAuthenticating)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                        hintText: 'Password',
                        border: OutlineInputBorder()
                    ),
                    onSubmitted: (_) { /* can trigger auth here if desired */ },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating ? null : () async {
                  if(passwordController.text.isEmpty) {
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
                  } on FirebaseAuthException catch (e) {
                    _showSnackBar('Authentication Error: ${e.message ?? "An error occurred."}');
                    Navigator.pop(context, false); // Failure
                  } catch (e) {
                    _showSnackBar('An unexpected error occurred during authentication.');
                    Navigator.pop(context, false); // Failure
                  }
                },
                child: Text('Confirm & Unmask'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _askToUnmask() async {
    final bool isAuthenticated = await _promptForPasswordAndReauthenticate();
    if (!isAuthenticated && mounted) {
      _showSnackBar('Authentication failed. Export cancelled.');
    }
    return isAuthenticated;
  }

  Future<void> _toggleGlobalUnmask() async {
    if (_allCellsGloballyUnlocked) {
      if (mounted) setState(() => _allCellsGloballyUnlocked = false);
      _showSnackBar('All sensitive data re-masked.');
    } else {
      final bool isAuthenticated = await _promptForPasswordAndReauthenticate();
      if (isAuthenticated) {
        if (mounted) setState(() => _allCellsGloballyUnlocked = true);
        _showSnackBar('All sensitive data has been unmasked for this session.');
      } else if (mounted) {
        _showSnackBar('Authentication failed. Data remains masked.');
      }
    }
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Date Range'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.5,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: (_startDateFilter != null && _endDateFilter != null)
                ? PickerDateRange(_startDateFilter!, _endDateFilter!)
                : null,
            showActionButtons: true,
            cancelText: 'Clear Filter',
            confirmText: 'Apply',
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                if (mounted) {
                  setState(() {
                    _startDateFilter = value.startDate;
                    _endDateFilter = value.endDate ?? value.startDate;
                  });
                }
                Navigator.pop(context);
                _loadAndCalculateReports(applyDateFilter: true);
              } else {
                Navigator.pop(context);
              }
            },
            onCancel: () {
              if (mounted) {
                setState(() {
                  _startDateFilter = null;
                  _endDateFilter = null;
                });
              }
              Navigator.pop(context);
              _loadAndCalculateReports(applyDateFilter: false);
            },
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Uint8List?> _captureChartPng(GlobalKey key) async {
    try {
      if (key.currentContext == null) return null;
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (mounted) _showSnackBar('Error capturing chart image: $e');
      return null;
    }
  }

  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) proceed = await _askToUnmask();

    if (!proceed) {
      if (mounted) setState(() => _isExporting = false);
      return;
    }

    try {
      List<List<String>> rows = [
        ['Client Name', 'ART ID', 'Phone Number', 'Call Date & Time', 'Call Status', 'Duration (s)', 'Tracked By', 'Tracker Facility']
      ];
      rows.addAll(_callLogs.map((log) => [
        log.clientName ?? 'N/A',
        log.artId ?? 'N/A',
        log.phoneNumberCalled ?? 'N/A',
        log.callDateTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(log.callDateTime!) : 'N/A',
        log.callStatus ?? 'N/A',
        log.callDurationInSeconds?.toString() ?? 'N/A',
        log.trackedBy ?? 'N/A',
        log.trackerFacility ?? 'N/A',
      ]));

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_call_log_summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('Call Log CSV download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // =========== NEW METHOD FOR SUMMARY CSV EXPORT ============
  Future<void> _exportSummaryToCSV() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    try {
      // Create a list of rows for the CSV in a key-value format
      List<List<dynamic>> rows = [
        ['Metric', 'Value'], // Header
        [], // Blank row for spacing

        // Overall Performance
        ['--- OVERALL PERFORMANCE ---', ''],
        ['% Samples Collected (Overall)', '${_percentageSampleCollected.toStringAsFixed(1)}%'],
        ['% Results Received (Overall)', '${_percentageResultReceived.toStringAsFixed(1)}%'],
        [],

        // Not Active Client Status
        ['--- CLIENTS NOT ON ACTIVE TREATMENT ---', ''],
        ['Total Not Active', _totalNotActive],
        ['Deaths', _totalDeaths],
        ['Transferred Out', _totalTransferredOut],
        ['Missed Appointments', _totalMissedAppointments],
        ['IIT (Interrupted in Treatment)', _totalIIT],
        ['Discontinued Care', _totalDiscontinuedCare],
        [],

        // Current Quarter Summary
        ['--- VL SUMMARY ($_currentQuarterDisplay) ---', ''],
        ['Total Eligible Clients (Filtered)', _totalEligibleOverall],
        ['Due for Refill (In Quarter)', _totalEligibleDueForRefillInQuarter],
        ['Refill Due (Outside Quarter)', _totalEligibleDueForRefillOutsideQuarter],
        ['Samples Collected', _samplesCollectedInQuarter],
        ['Results Returned', _resultsReturnedInQuarter],
        ['Suppressed (<1k)', _suppressedInQuarter],
        ['Unsuppressed (>=1k)', _unsuppressedInQuarter],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsCurrentQuarter],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultCurrentQuarter],
        [],

        // Previous Quarter Summary
        ['--- VL SUMMARY ($_previousQuarterDisplay) ---', ''],
        ['Samples Collected', _samplesCollectedPreviousQuarter],
        ['Results Returned', _resultsReturnedPreviousQuarter],
        ['Suppressed (<1k)', _suppressedPreviousQuarter],
        ['Unsuppressed (>=1k)', _unsuppressedPreviousQuarter],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsPreviousQuarter],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultPreviousQuarter],
        [],

        // Older Samples Summary
        ['--- VL SUMMARY ($_olderSamplesDisplayTitle) ---', ''],
        ['Samples Collected', _samplesCollectedOlder],
        ['Results Returned', _resultsReturnedOlder],
        ['Suppressed (<1k)', _suppressedOlder],
        ['Unsuppressed (>=1k)', _unsuppressedOlder],
        ['TAT: Pending > 90 days', _tatExceeded3MonthsOlder],
        ['TAT: Result Received > 90 days', _tatOver3MonthsWithResultOlder],
        [],

        // Call Log Analysis
        ['--- CALL LOG ANALYSIS ---', ''],
        ['Total Calls Made', _totalCallsMade],
        ['Calls Answered', _callsAnswered],
        ['Calls Not Answered/Failed', _callsNotAnsweredOrFailed],
        ['Average Call Duration (Answered)', '${_averageCallDurationSeconds.toStringAsFixed(1)}s'],
      ];

      String csvData = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_dashboard_summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('Dashboard Summary CSV download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting Summary CSV: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }


  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    if (mounted) setState(() => _isExporting = true);

    bool proceed = _allCellsGloballyUnlocked;
    if (!proceed) proceed = await _askToUnmask();

    if (!proceed) {
      if (mounted) setState(() => _isExporting = false);
      return;
    }

    try {
      final pdf = pw.Document();
      final Uint8List? currentQChartImgBytes = await _captureChartPng(_currentQuarterChartBoundaryKey);
      final Uint8List? prevQChartImgBytes = await _captureChartPng(_previousQuarterChartBoundaryKey);
      final Uint8List? olderSamplesChartImgBytes = await _captureChartPng(_olderSamplesChartBoundaryKey);
      final Uint8List? callOutcomesChartImgBytes = await _captureChartPng(_callOutcomesChartBoundaryKey);

      final pw.MemoryImage? currentQPdfImg = currentQChartImgBytes != null ? pw.MemoryImage(currentQChartImgBytes) : null;
      final pw.MemoryImage? prevQPdfImg = prevQChartImgBytes != null ? pw.MemoryImage(prevQChartImgBytes) : null;
      final pw.MemoryImage? olderSamplesPdfImg = olderSamplesChartImgBytes != null ? pw.MemoryImage(olderSamplesChartImgBytes) : null;
      final pw.MemoryImage? callOutcomesPdfImg = callOutcomesChartImgBytes != null ? pw.MemoryImage(callOutcomesChartImgBytes) : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.all(20),
          header: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('VL Report - ${DateFormat.yMMMMd().format(DateTime.now())}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey))),
          footer: (pw.Context context) => pw.Container(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.Theme.of(context).defaultTextStyle.copyWith(color: PdfColors.grey))),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'Viral Load Report Summary', textStyle: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (_startDateFilter != null && _endDateFilter != null)
              pw.Paragraph(text: 'Data filtered from: ${DateFormat.yMd().format(_startDateFilter!)} to ${DateFormat.yMd().format(_endDateFilter!)}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 10),

            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Overall Performance:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text('% Samples Collected (Overall): ${_percentageSampleCollected.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11)),
                        pw.Text('% Results Received (Overall): ${_percentageResultReceived.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11)),
                      ]),
                  pw.SizedBox(width: 20),
                  pw.Text('Total Eligible Clients (Filtered): $_totalEligibleOverall', style: pw.TextStyle(fontSize: 11)),
                ]),
            pw.SizedBox(height: 15),

            pw.Header(level: 1, text: 'Summary Charts', textStyle: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Wrap(
              spacing: 10, runSpacing: 10,
              children: [
                if (currentQPdfImg != null && _samplesCollectedInQuarter > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('$_currentQuarterDisplay: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(currentQPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (prevQPdfImg != null && _samplesCollectedPreviousQuarter > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('$_previousQuarterDisplay: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(prevQPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (olderSamplesPdfImg != null && _samplesCollectedOlder > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('Older Samples: VL Status & TAT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(olderSamplesPdfImg, fit: pw.BoxFit.contain, height: 150)])),
                if (callOutcomesPdfImg != null && _totalCallsMade > 0)
                  pw.Container(width: 250, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text('Call Outcomes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), pw.SizedBox(height:3), pw.Image(callOutcomesPdfImg, fit: pw.BoxFit.contain, height: 150)])),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Paragraph(text: "Note: Detailed call logs are available in the CSV export.", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final filename = 'vl_report_summary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;

      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) _showSnackBar('PDF download started.');

    } catch (e) {
      if (mounted) _showSnackBar('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildMetricCard(String title, String value, {String? subtitle, double? width, Color? valueColor}) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
              SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
              if (subtitle != null) ...[
                SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis,maxLines: 2,),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoughnutChart(String title, List<_ChartData> data, {GlobalKey? boundaryKey}) {
    List<_ChartData> filteredData = data.where((d) => d.y > 0).toList();
    if (filteredData.isEmpty) return SizedBox.shrink();

    Widget chartWidget = SfCircularChart(
      title: ChartTitle(text: title, textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, position: LegendPosition.bottom),
      tooltipBehavior: _tooltipBehavior,
      series: <CircularSeries<_ChartData, String>>[
        DoughnutSeries<_ChartData, String>(
          dataSource: filteredData,
          xValueMapper: (_ChartData data, _) => data.x,
          yValueMapper: (_ChartData data, _) => data.y,
          pointColorMapper: (_ChartData data, _) => data.color,
          dataLabelSettings: DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
          dataLabelMapper: (_ChartData data, _) => '${data.x}\n${data.y.toInt()}',
          innerRadius: '50%',
        )
      ],
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: boundaryKey != null
            ? RepaintBoundary(key: boundaryKey, child: chartWidget)
            : chartWidget,
      ),
    );
  }

  Map<String, List<VlCallLogModel>> _groupCallLogsByDate() {
    final Map<String, List<VlCallLogModel>> dailyLogs = {};
    final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');

    for (var log in _callLogs) {
      final dateKey = log.callDateTime != null ? dateKeyFormat.format(log.callDateTime!) : 'Unknown Date';
      dailyLogs.putIfAbsent(dateKey, () => []).add(log);
    }

    final sortedKeys = dailyLogs.keys.toList()
      ..sort((a, b) {
        if (a == 'Unknown Date') return 1; if (b == 'Unknown Date') return -1;
        try { return DateTime.parse(b).compareTo(DateTime.parse(a)); } catch (e) { return a.compareTo(b); }
      });

    return { for (var k in sortedKeys) k : dailyLogs[k]! };
  }

  Widget _buildCallLogSummaryTable() {
    if (_callLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text(_startDateFilter == null && _endDateFilter == null ? 'No call logs available.' : 'No call logs for selected period.')),
      );
    }

    final Map<String, List<VlCallLogModel>> groupedLogs = _groupCallLogsByDate();
    final DateFormat displayDateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Detailed Call Logs by Date", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        if (groupedLogs.isEmpty && !_isLoading)
          Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No call logs match the current filter.", style: TextStyle(fontSize: 16)))),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: groupedLogs.keys.length,
          itemBuilder: (context, index) {
            final dateKey = groupedLogs.keys.elementAt(index);
            final dailyLogs = groupedLogs[dateKey]!;
            final String displayDate = dateKey == 'Unknown Date' ? 'Unknown Date' : displayDateFormat.format(DateTime.parse(dateKey));

            dailyLogs.sort((a,b) => (b.callDateTime ?? DateTime(1900)).compareTo(a.callDateTime ?? DateTime(1900)));

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
              child: ExpansionTile(
                key: PageStorageKey<String>(dateKey),
                title: Text('$displayDate (${dailyLogs.length} calls)', style: TextStyle(fontWeight: FontWeight.w600)),
                initiallyExpanded: index == 0,
                children: dailyLogs.map((log) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      log.callStatus?.toLowerCase() == 'answered' ? Icons.call_received : Icons.call_missed_outgoing,
                      color: log.callStatus?.toLowerCase() == 'answered' ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    title: Text(_maskClientName(log.clientName), style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ART ID: ${_maskArtId(log.artId)} | Phone: ${_maskPhoneNumber(log.phoneNumberCalled)}'),
                        Text('Time: ${log.callDateTime != null ? DateFormat('HH:mm:ss').format(log.callDateTime!) : 'N/A'}'),
                        Text('Status: ${log.callStatus ?? 'N/A'} | Duration: ${log.callDurationInSeconds ?? 0}s'),
                        if (log.trackedBy != null && log.trackedBy!.isNotEmpty)
                          Text('Tracker: ${log.trackedBy}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                    isThreeLine: true,
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(

          appBar: AppBar(
            title: const Text("Viral Load Tracker", style: TextStyle(color: Colors.white, fontSize: 20)),
            backgroundColor: const Color(0xFF722F37),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawer: drawer(context),
         // appBar: AppBar(title: Text('VL Reports Dashboard')),
          body: Center(child: CircularProgressIndicator())
      );
    }

    // ... (Chart data setup and layout widgets remain the same)

    final List<_ChartData> currentQuarterChartData = [
      _ChartData('Samples Coll.', _samplesCollectedInQuarter.toDouble(), Colors.orange.shade300),
      _ChartData('Results Rcvd', _resultsReturnedInQuarter.toDouble(), Colors.teal.shade300),
      _ChartData('Suppressed', _suppressedInQuarter.toDouble(), Colors.green.shade400),
      _ChartData('Unsuppressed', _unsuppressedInQuarter.toDouble(), Colors.red.shade400),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsCurrentQuarter.toDouble(), Colors.purple.shade300),
      _ChartData('Result TAT >3m', _tatOver3MonthsWithResultCurrentQuarter.toDouble(), Colors.deepOrange.shade300),
    ];

    final List<_ChartData> previousQuarterChartData = [
      _ChartData('Samples Coll.', _samplesCollectedPreviousQuarter.toDouble(), Colors.orange.shade200),
      _ChartData('Results Rcvd', _resultsReturnedPreviousQuarter.toDouble(), Colors.teal.shade200),
      _ChartData('Suppressed', _suppressedPreviousQuarter.toDouble(), Colors.green.shade300),
      _ChartData('Unsuppressed', _unsuppressedPreviousQuarter.toDouble(), Colors.red.shade300),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsPreviousQuarter.toDouble(), Colors.purple.shade200),
      _ChartData('Result TAT >3m', _tatOver3MonthsWithResultPreviousQuarter.toDouble(), Colors.deepOrange.shade200),
    ];

    final List<_ChartData> olderSamplesChartData = [
      _ChartData('Samples Coll.', _samplesCollectedOlder.toDouble(), Colors.blueGrey.shade200),
      _ChartData('Results Rcvd', _resultsReturnedOlder.toDouble(), Colors.cyan.shade200),
      _ChartData('Suppressed', _suppressedOlder.toDouble(), Colors.lightGreen.shade300),
      _ChartData('Unsuppressed', _unsuppressedOlder.toDouble(), Colors.orange.shade300),
      _ChartData('TAT >3m No Result', _tatExceeded3MonthsOlder.toDouble(), Colors.grey.shade400),
      _ChartData('TAT: Result TAT >3m', _tatOver3MonthsWithResultOlder.toDouble(), Colors.brown.shade200),
    ];

    final List<_ChartData> callStatusData = [
      _ChartData('Answered', _callsAnswered.toDouble(), Colors.greenAccent.shade400),
      _ChartData('Not Answered/\nFailed/Error', _callsNotAnsweredOrFailed.toDouble(), Colors.pinkAccent.shade100),
    ];

    final double reportCardWidth = MediaQuery.of(context).size.width > 900
        ? (MediaQuery.of(context).size.width / 4.5) - 12
        : (MediaQuery.of(context).size.width / 2.3) - 12;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('VL Reports Dashboard'),
        actions: [
          IconButton(
            icon: Icon(_allCellsGloballyUnlocked ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: _allCellsGloballyUnlocked ? 'Mask All Data' : 'Unmask All Data',
            onPressed: _toggleGlobalUnmask,
          ),
          if (_isSyncingToFirebase)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: "More Options",
              onSelected: (value) {
                switch (value) {
                  case 'dateFilter': _showDateRangePicker(); break;
                  case 'refreshData': _loadAndCalculateReports(applyDateFilter: _startDateFilter != null); break;
                  case 'syncToServer': _syncReportDataToServer(); break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'dateFilter',
                  child: ListTile(leading: Icon(Icons.date_range_outlined), title: Text('Filter by Date'), dense: true),
                ),
                const PopupMenuItem<String>(
                  value: 'refreshData',
                  child: ListTile(leading: Icon(Icons.refresh_outlined), title: Text('Refresh Data'), dense: true),
                ),
                const PopupMenuItem<String>(
                  value: 'syncToServer',
                  child: ListTile(leading: Icon(Icons.cloud_upload_outlined, color: Colors.blue), title: Text('Upload Report Summary'), dense: true),
                ),
              ],
            ),
          if (_isExporting)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            )
          else
          // =========== MODIFIED EXPORT MENU ============
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "Export Options",
              onSelected: (value) async {
                switch (value) {
                  case 'csv_call_log':
                    await _exportToCSV();
                    break;
                  case 'csv_summary': // NEW
                    await _exportSummaryToCSV();
                    break;
                  case 'pdf':
                    await _exportToPDF();
                    break;
                }
              },
              itemBuilder: (context) => [
                // NEW: Added item for summary CSV
                PopupMenuItem(
                    value: 'csv_summary',
                    child: Row(children: [Icon(Icons.summarize_outlined, color: Colors.blue[700]), const SizedBox(width: 8), const Text('Export CSV (Summaries)')])
                ),
                // MODIFIED: Renamed value for clarity
                PopupMenuItem(
                    value: 'csv_call_log',
                    child: Row(children: [Icon(Icons.grid_on_outlined, color: Colors.green[700]), const SizedBox(width: 8), const Text('Export CSV (Call Log)')])
                ),
                PopupMenuItem(
                    value: 'pdf',
                    child: Row(children: [Icon(Icons.picture_as_pdf_outlined, color: Colors.red[700]), const SizedBox(width: 8), const Text('Export PDF (Charts)')])
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _masterVlEligibleList.isEmpty && _masterCallLogs.isEmpty && !_isLoading
          ? Center(child: Text("No data available for your facility to generate reports.", style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center,))
          : SingleChildScrollView(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_startDateFilter != null && _endDateFilter != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Displaying data from ${DateFormat.yMMMMd().format(_startDateFilter!)} to ${DateFormat.yMMMMd().format(_endDateFilter!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.spaceEvenly,
                children: [
                  _buildMetricCard('% Samples Collected', '${_percentageSampleCollected.toStringAsFixed(1)}%', subtitle: 'Overall (Latest VL Date)', width: reportCardWidth, valueColor: Colors.indigoAccent),
                  _buildMetricCard('% Results Received', '${_percentageResultReceived.toStringAsFixed(1)}%', subtitle: 'Overall (Latest VL Date)', width: reportCardWidth, valueColor: Colors.teal),
                ],
              ),
            ),
            SizedBox(height: 10),

            Text('Clients Not on Active Treatment', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
              children: [
                _buildMetricCard('Total Not Active', _totalNotActive.toString(), width: reportCardWidth, subtitle: '(Across Filtered List)', valueColor: Colors.red.shade800),
                _buildMetricCard('Deaths', _totalDeaths.toString(), width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.black),
                _buildMetricCard('Transferred Out', _totalTransferredOut.toString(), width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.blueGrey),
                _buildMetricCard('Missed Appt.', _totalMissedAppointments.toString(), width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.orange),
                _buildMetricCard('IIT', _totalIIT.toString(), width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.red.shade700),
                _buildMetricCard('Discontinued Care', _totalDiscontinuedCare.toString(), width: reportCardWidth, subtitle: 'Overall', valueColor: Colors.purple),
              ],
            ),
            SizedBox(height: 20),

            Text('VL Summary ($_currentQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
              children: [
                _buildMetricCard('Total Eligible Clients', _totalEligibleOverall.toString(), width: reportCardWidth, subtitle: "(Filtered List)"),
                _buildMetricCard('Due for Refill', _totalEligibleDueForRefillInQuarter.toString(), width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay'),
                _buildMetricCard('Refill (Outside Qtr)', _totalEligibleDueForRefillOutsideQuarter.toString(), width: reportCardWidth),
                _buildMetricCard('Samples Collected', _samplesCollectedInQuarter.toString(), width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay'),
                _buildMetricCard('Results Returned', _resultsReturnedInQuarter.toString(), width: reportCardWidth, subtitle: 'For samples in $_currentQuarterDisplay'),
                _buildMetricCard('Suppressed', _suppressedInQuarter.toString(), width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay (<1k)'),
                _buildMetricCard('Unsuppressed', _unsuppressedInQuarter.toString(), width: reportCardWidth, subtitle: 'In $_currentQuarterDisplay (>=1k)'),
                _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsCurrentQuarter.toString(), width: reportCardWidth, subtitle: 'Samples from $_currentQuarterDisplay'),
                _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultCurrentQuarter.toString(), width: reportCardWidth, subtitle: 'Samples from $_currentQuarterDisplay'),
              ],
            ),
            if (_samplesCollectedInQuarter > 0)
              _buildDoughnutChart('$_currentQuarterDisplay: VL Status & TAT', currentQuarterChartData, boundaryKey: _currentQuarterChartBoundaryKey),

            SizedBox(height: 20),
            Text('VL Summary ($_previousQuarterDisplay)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
              children: [
                _buildMetricCard('Samples Collected', _samplesCollectedPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay'),
                _buildMetricCard('Results Returned', _resultsReturnedPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'For samples in $_previousQuarterDisplay'),
                _buildMetricCard('Suppressed', _suppressedPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay (<1k)'),
                _buildMetricCard('Unsuppressed', _unsuppressedPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'In $_previousQuarterDisplay (>=1k)'),
                _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'Samples from $_previousQuarterDisplay'),
                _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultPreviousQuarter.toString(), width: reportCardWidth, subtitle: 'Samples from $_previousQuarterDisplay'),
              ],
            ),
            if (_samplesCollectedPreviousQuarter > 0)
              _buildDoughnutChart('$_previousQuarterDisplay: VL Status & TAT', previousQuarterChartData, boundaryKey: _previousQuarterChartBoundaryKey),

            SizedBox(height: 20),
            Text(_olderSamplesDisplayTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
              children: [
                _buildMetricCard('Samples Collected', _samplesCollectedOlder.toString(), width: reportCardWidth, subtitle: 'Collected before $_previousQuarterDisplay'),
                _buildMetricCard('Results Returned', _resultsReturnedOlder.toString(), width: reportCardWidth, subtitle: 'For older samples'),
                _buildMetricCard('Suppressed', _suppressedOlder.toString(), width: reportCardWidth, subtitle: 'Older samples (<1k)'),
                _buildMetricCard('Unsuppressed', _unsuppressedOlder.toString(), width: reportCardWidth, subtitle: 'Older samples (>=1k)'),
                _buildMetricCard('TAT: No Result >3m', _tatExceeded3MonthsOlder.toString(), width: reportCardWidth, subtitle: 'Older samples'),
                _buildMetricCard('TAT: Result TAT >3m', _tatOver3MonthsWithResultOlder.toString(), width: reportCardWidth, subtitle: 'Older samples'),
              ],
            ),
            if (_samplesCollectedOlder > 0)
              _buildDoughnutChart('Older Samples: VL Status & TAT', olderSamplesChartData, boundaryKey: _olderSamplesChartBoundaryKey),

            SizedBox(height: 20),
            Text('Call Log Analysis', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.start,
              children: [
                _buildMetricCard('Total Calls Made', _totalCallsMade.toString(), width: reportCardWidth),
                _buildMetricCard('Calls Answered', _callsAnswered.toString(), width: reportCardWidth),
                _buildMetricCard('Not Answered/Failed', _callsNotAnsweredOrFailed.toString(), width: reportCardWidth),
                _buildMetricCard('Avg. Call Duration', '${_averageCallDurationSeconds.toStringAsFixed(1)}s', width: reportCardWidth, subtitle: "(Answered)"),
              ],
            ),
            if (_totalCallsMade > 0)
              _buildDoughnutChart('Call Outcomes', callStatusData, boundaryKey: _callOutcomesChartBoundaryKey),

            _buildCallLogSummaryTable(),
          ],
        ),
      ),
    );
  }
}