// lib/pages/admin/payment_schedule_page.dart

import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls hide TextSpan;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../models/payment_schedule_model.dart';
import '../timesheet/hq_timesheet_review_page.dart';
import 'salary_scale_page.dart';

// Model to hold all data for one row in the payment table
// Add this to lib/models/payment_schedule_model.dart

class Recommendation {
  final double? deductedHours;
  final String? notes;

  Recommendation({this.deductedHours, this.notes});

  factory Recommendation.fromMap(Map<String, dynamic> map) {
    return Recommendation(
      deductedHours: (map['deductedHours'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class TimesheetEntry {
  final Recommendation? recommendation;

  TimesheetEntry({this.recommendation});

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) {
    return TimesheetEntry(
      recommendation: map['recommendation'] != null
          ? Recommendation.fromMap(map['recommendation'])
          : null,
    );
  }
}

// 1. Add a new data model for Staff Bank Info (No change here)
class StaffBankInfo {
  final String bankName;
  final String accountNumber;
  final String sortCode;
  StaffBankInfo({this.bankName = '', this.accountNumber = '', this.sortCode = ''});
}

// 2. Add toJson/fromJson to PaymentScheduleItem (as done in Step 1)
// In lib/pages/admin/payment_schedule_page.dart

class PaymentScheduleItem {
  // Core data
  final TimesheetModel timesheet;
  final SalaryScale baseSalary;
  final double expectedHours;
  final String? srt;

  // Calculated fields based on the new logic
  double actualHoursWorked;
  double percentageWorked;
  double payeFromGrossBase;
  double totalDeductedHoursFromTimesheet;
  double otherDeductionsAmount;
  double grossAfterDeductions;
  double proratedNet;

  // Fields for manual adjustments
  bool isEdited = false;
  double additionAmount = 0.0;
  String? additionReason;
  double deductionAmount = 0.0;
  String? deductionReason;
  String comments = '';

  PaymentScheduleItem({ required this.timesheet, required this.baseSalary, required this.expectedHours, this.srt,})
       : actualHoursWorked = 0, percentageWorked = 0, payeFromGrossBase = 0,
         totalDeductedHoursFromTimesheet = 0, otherDeductionsAmount = 0,
         grossAfterDeductions = 0, proratedNet = 0 {
    actualHoursWorked = timesheet.totalHours;
    calculateProratedSalary();
  }

  void calculateProratedSalary() {
    double hoursUsedForCalc = (actualHoursWorked > expectedHours) ? expectedHours : actualHoursWorked;
    double rawPercentage = (expectedHours > 0) ? (hoursUsedForCalc / expectedHours * 100) : 0.0;
    percentageWorked = rawPercentage > 100.0 ? 100.0 : rawPercentage;
    final ratio = percentageWorked / 100.0;

    // --- CHANGE: Updated from 2% (0.02) to 5% (0.05) ---
    payeFromGrossBase = baseSalary.grossPay * 0.05;

    totalDeductedHoursFromTimesheet = 0;

    for (var entry in timesheet.entries) {
      if (entry.recommendation?.deductedHours != null) {
        totalDeductedHoursFromTimesheet += entry.recommendation!.deductedHours!;
      }
    }

    double hourlyGrossRate = (expectedHours > 0) ? (baseSalary.grossPay / expectedHours) : 0;
    otherDeductionsAmount = totalDeductedHoursFromTimesheet * hourlyGrossRate;

    grossAfterDeductions = baseSalary.grossPay - payeFromGrossBase - otherDeductionsAmount;
    if (grossAfterDeductions < 0) grossAfterDeductions = 0;

    if (totalDeductedHoursFromTimesheet > 0 && expectedHours > 0) {
      double deductedPercentage = (totalDeductedHoursFromTimesheet / expectedHours) * 100;
      comments = "${totalDeductedHoursFromTimesheet.toStringAsFixed(1)} hours recommended for deduction (${deductedPercentage.toStringAsFixed(1)}%).";
    } else {
      comments = "";
    }

    if (!isEdited) {
      proratedNet = (grossAfterDeductions * ratio) + additionAmount - deductionAmount;
    }

    if (proratedNet < 0) proratedNet = 0;
  }


// In lib/pages/admin/payment_schedule_page.dart -> class PaymentScheduleItem

  factory PaymentScheduleItem.fromJson(Map<String, dynamic> json, Map<String, SalaryScale> salaryScales) {
    final salary = salaryScales[json['designation']];
    if (salary == null) throw Exception("Salary scale not found for designation: ${json['designation']}");

    // Create a temporary TimesheetModel. The error was in this constructor call.
    final partialTimesheet = TimesheetModel(
      staffId: json['staffId'],
      staffName: json['staffName'],
      designation: json['designation'],
      state: json['state'],
      location: json['location'],
      // <<<--- FIX: The 'totalHours' parameter is removed from here ---<<<
      staffEmail: '',
      department: '',
      caritasSupervisor: '',
      caritasSupervisorSignatureStatus: '',
      entries: [], // We pass an empty list because the real hours are in the JSON
      facilitySupervisor: '',
      facilitySupervisorSignatureStatus: '',
    );

    // The rest of the logic is correct and remains the same.
    final item = PaymentScheduleItem(
      timesheet: partialTimesheet,
      baseSalary: salary,
      expectedHours: (json['expectedHours'] as num).toDouble(),
      srt: json['srt'],
    );

    // We overwrite the initial calculated values with the ones saved in the JSON.
    item.actualHoursWorked = (json['actualHoursWorked'] as num).toDouble();
    item.isEdited = json['isEdited'] ?? false;
    item.deductionAmount = (json['deductionAmount'] as num?)?.toDouble() ?? 0.0;
    item.deductionReason = json['deductionReason'];
    item.additionAmount = (json['additionAmount'] as num?)?.toDouble() ?? 0.0;
    item.additionReason = json['additionReason'];

    // The final calculation uses the correct, restored values.
    item.calculateProratedSalary();
    return item;
  }

  Map<String, dynamic> toJson() {
    // ... no changes needed here
    return {
      'staffId': timesheet.staffId, 'staffName': timesheet.staffName, 'designation': timesheet.designation,
      'state': timesheet.state, 'location': timesheet.location, 'actualHoursWorked': actualHoursWorked,
      'baseSalaryGross': baseSalary.grossPay, 'baseSalaryNet': baseSalary.netPay, 'expectedHours': expectedHours,
      'isEdited': isEdited, 'deductionAmount': deductionAmount, 'deductionReason': deductionReason,
      'additionAmount': additionAmount, 'additionReason': additionReason, 'proratedNet': proratedNet,
      'srt': srt,
    };
  }
}

class PaymentSchedulePage extends StatefulWidget {
  // --- MODIFIED CONSTRUCTOR ---
  final List<TimesheetModel>? timesheets; // Nullable for review mode
  final int? year; // Nullable for review mode
  final int? month; // Nullable for review mode
  final PaymentScheduleModel? scheduleModel; // New parameter for review mode

  const PaymentSchedulePage({
    super.key,
    this.timesheets,
    this.year,
    this.month,
    this.scheduleModel,
  })  : assert(timesheets != null || scheduleModel != null, "Either timesheets or a scheduleModel must be provided");

  @override
  _PaymentSchedulePageState createState() => _PaymentSchedulePageState();
}


class _PaymentSchedulePageState extends State<PaymentSchedulePage> {
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isFiltering = false;
  bool _isSubmitting = false;

  // Data stores
  List<PaymentScheduleItem> _masterPaymentList = [];
  List<PaymentScheduleItem> _filteredPaymentList = [];
  final Map<String, StaffBankInfo> _staffBankDetailsCache = {};
  
  // September Part 2 data cache
  final Map<String, Map<String, dynamic>> _septPart2DataCache = {};

  // Filter options
  final List<String> _availableStates = ['All States'];
  final List<String> _availableDesignations = ['All Designations'];
  List<String> _selectedStates = ['All States'];
  List<String> _selectedDesignations = ['All Designations'];
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  // --- NEW: Pagination State ---
  static const int _rowsPerPage = 50;
  int _currentPage = 0;
  List<PaymentScheduleItem> _paginatedList = [];

  // --- NEW WORKFLOW STATE ---
  late bool _isReviewMode;
  Map<String, String>? _selectedApprover;
  List<Map<String, String>> _approverList = [];
  bool _approversLoading = false;
  bool _isCombinedView = false;

  @override
  void initState() {
    super.initState();
    _isReviewMode = widget.scheduleModel != null;
    if (_isReviewMode) {
      _loadDataFromModel();
    } else {
      _preparePaymentData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }



  // --- NEW: Pagination Logic ---
  void _paginateData() {
    final startIndex = _currentPage * _rowsPerPage;
    // Ensure endIndex does not exceed the list length
    final endIndex = min(startIndex + _rowsPerPage, _filteredPaymentList.length);

    setState(() {
      _paginatedList = _filteredPaymentList.sublist(startIndex, endIndex);
    });
  }

  // --- NEW: Load data from existing model ---
  Future<void> _loadDataFromModel() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("=== LOADING DATA FROM MODEL ===");
      debugPrint("Schedule model month: ${widget.scheduleModel?.month}");
      debugPrint("Schedule model year: ${widget.scheduleModel?.year}");
      debugPrint("Schedule model state: ${widget.scheduleModel?.state}");
      
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

      // Fetch SRT Assignments
      final srtSnapshot = await FirebaseFirestore.instance.collection('SRTAssignments').get();
      final Map<String, String> srtMap = {};
      for (var doc in srtSnapshot.docs) {
        final data = doc.data();
        final key = '${data['state']}-${data['location']}';
        srtMap[key] = data['srt'] ?? 'N/A';
      }

      final List<dynamic> jsonData = jsonDecode(widget.scheduleModel!.scheduleDataJson);
      final List<PaymentScheduleItem> items = jsonData.map((itemJson) {
        return PaymentScheduleItem.fromJson(itemJson as Map<String, dynamic>, salaryScales);
      }).toList();

      final List<String> staffIds = items.map((item) => item.timesheet.staffId).toList();
      await _fetchStaffBankDetails(staffIds);
      _setupFilters(items);

      debugPrint("Loaded ${items.length} items from model");
      setState(() {
        _masterPaymentList = items;
        _filteredPaymentList = items;
        _isLoading = false;
      });
      debugPrint("Set master payment list with ${_masterPaymentList.length} items from model");
      debugPrint("Review mode schedule month: ${widget.scheduleModel!.month}");

      // Fetch September Part 2 data if this is October and in review mode
      if (widget.scheduleModel!.month == 10) {
        debugPrint("Review mode October schedule detected, calling _fetchSeptPart2DataForAllStaff()");
        await _fetchSeptPart2DataForAllStaff();
        debugPrint("Review mode September Part 2 cache size after fetch: ${_septPart2DataCache.length}");

        // If no data was found, try comprehensive search for review mode too
        if (_septPart2DataCache.isEmpty) {
          debugPrint("No data found in review mode. Trying comprehensive search...");
          await _comprehensiveSeptPart2Search(staffIds, widget.scheduleModel!.year);

          // If still no data, try state collection approach for review mode
          if (_septPart2DataCache.isEmpty) {
            debugPrint("No data found in comprehensive search for review mode. Trying state collection...");
            await _fetchSeptPart2FromStateCollection(staffIds, widget.scheduleModel!.year);
          }
        }
      }

      _paginateData(); // --- NEW: Paginate initial data
      _getApproversForCurrentStep();
    } catch (e) {
      debugPrint("Error loading from model: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading schedule: $e")));
      setState(() => _isLoading = false);
    }
  }

// In _PaymentSchedulePageState

  // In _PaymentSchedulePageState
  Future<void> _preparePaymentData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("=== PREPARING PAYMENT DATA ===");
      debugPrint("Is review mode: $_isReviewMode");
      debugPrint("Widget month: ${widget.month}");
      debugPrint("Widget year: ${widget.year}");
      debugPrint("Widget timesheets length: ${widget.timesheets?.length}");
      
      // 1. Fetch Salary Scales
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

      // Fetch SRT Assignments
      final srtSnapshot = await FirebaseFirestore.instance.collection('SRTAssignments').get();
      final Map<String, String> srtMap = {};
      for (var doc in srtSnapshot.docs) {
        final data = doc.data();
        final key = '${data['state']}-${data['location']}';
        srtMap[key] = data['srt'] ?? 'N/A';
      }

      // 2. Calculate Expected Hours for the Month
      DateTime startDate;
      DateTime endDate;
      double totalExpectedHours;
      SalaryScale adjustedSalary;

      if (widget.month == 9) { // September: 20th to 30th
        startDate = DateTime(widget.year!, 9, 20);
        endDate = DateTime(widget.year!, 9, 30);
      } else if (widget.month == 10) { // October: 1st to 19th
        startDate = DateTime(widget.year!, 10, 1);
        endDate = DateTime(widget.year!, 10, 19);
      } else { // Other months: 20th of previous to 19th of current
        startDate = DateTime(widget.year!, widget.month! - 1, 20);
        endDate = DateTime(widget.year!, widget.month!, 19);
      }
      final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));

      // Calculate working days to determine total expected hours.
      final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
      final double baseExpectedHours = (workingDays * 8.0);

      final List<PaymentScheduleItem> items = [];

      // 3. Loop through timesheets to build payment items
      for (final timesheet in widget.timesheets!) {
        final salary = salaryScales[timesheet.designation.trim()];
        if (salary != null) {
          SalaryScale effectiveSalary = salary;
          double effectiveExpectedHours = baseExpectedHours;

          if (widget.month == 9 || widget.month == 10) {
            // Full period: Sep 20 to Oct 19
            DateTime fullStart = DateTime(widget.year!, 9, 20);
            DateTime fullEnd = DateTime(widget.year!, 10, 19);
            List<DateTime> fullDays = List.generate(fullEnd.difference(fullStart).inDays + 1, (i) => fullStart.add(Duration(days: i)));
            int fullWorkingDays = fullDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

            double dailyGross = salary.grossPay / fullWorkingDays;

            if (widget.month == 9) {
              // Sep 20-30
              DateTime sepStart = DateTime(widget.year!, 9, 20);
              DateTime sepEnd = DateTime(widget.year!, 9, 30);
              List<DateTime> sepDays = List.generate(sepEnd.difference(sepStart).inDays + 1, (i) => sepStart.add(Duration(days: i)));
              int sepWorkingDays = sepDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
              double effectiveGross = dailyGross * sepWorkingDays;
              effectiveSalary = SalaryScale(
                id: salary.id,
                designation: salary.designation,
                basic: salary.basic,
                housing: salary.housing,
                transport: salary.transport,
                meal: salary.meal,
                utility: salary.utility,
                paye: salary.paye,
                grossPay: effectiveGross,
                netPay: effectiveGross * 0.98,
              );
              effectiveExpectedHours = sepWorkingDays * 8.0;
            } else if (widget.month == 10) {
              // Oct 1-19
              DateTime octStart = DateTime(widget.year!, 10, 1);
              DateTime octEnd = DateTime(widget.year!, 10, 19);
              List<DateTime> octDays = List.generate(octEnd.difference(octStart).inDays + 1, (i) => octStart.add(Duration(days: i)));
              int octWorkingDays = octDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
              double effectiveGross = dailyGross * octWorkingDays;
              effectiveSalary = SalaryScale(
                id: salary.id,
                designation: salary.designation,
                basic: salary.basic,
                housing: salary.housing,
                transport: salary.transport,
                meal: salary.meal,
                utility: salary.utility,
                paye: salary.paye,
                grossPay: effectiveGross,
                netPay: effectiveGross * 0.98,
              );
              effectiveExpectedHours = octWorkingDays * 8.0;
            }
          }

          final key = '${timesheet.state}-${timesheet.location}';
          final srt = srtMap[key] ?? 'N/A';
          // The new constructor now handles ALL calculations, including deductions from timesheet entries.
          final paymentItem = PaymentScheduleItem(
            timesheet: timesheet,
            baseSalary: effectiveSalary,
            expectedHours: effectiveExpectedHours,
            srt: srt,
          );
          items.add(paymentItem);
        } else {
          debugPrint("Warning: No salary scale found for designation: '${timesheet.designation}' for staff ${timesheet.staffName}");
        }
      }

      // 4. Fetch bank details and finalize the list
      final List<String> staffIds = widget.timesheets!.map((ts) => ts.staffId).toList();
      await _fetchStaffBankDetails(staffIds);
      
      // Fetch September Part 2 data if this is October (to show side-by-side)
      final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;
      debugPrint("Current month: $currentMonth, Is October: ${currentMonth == 10}");
      debugPrint("Master payment list length before Sept fetch: ${_masterPaymentList.length}");
      if (currentMonth == 10) {
        debugPrint("Calling _fetchSeptPart2DataForAllStaff() for October schedule");
        await _fetchSeptPart2DataForAllStaff();
        debugPrint("September Part 2 cache size after fetch: ${_septPart2DataCache.length}");
      } else {
        debugPrint("Not October schedule, skipping September Part 2 data fetch");
      }
      
      debugPrint("Created ${items.length} payment items");
      items.sort((a, b) => a.timesheet.staffName.compareTo(b.timesheet.staffName));
      _setupFilters(items);

      setState(() {
        _masterPaymentList = items;
        _filteredPaymentList = items;
        _isLoading = false;
      });
      debugPrint("Set master payment list with ${_masterPaymentList.length} items");
      _paginateData();
      _getApproversForCurrentStep();

    } catch (e) {
      debugPrint("Error preparing payment data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
    }
  }

  void _setupFilters(List<PaymentScheduleItem> items) {
    final Set<String> states = {};
    final Set<String> designations = {};
    for (var item in items) {
      states.add(item.timesheet.state);
      designations.add(item.timesheet.designation);
    }
    setState(() {
      _availableStates..clear()..add('All States')..addAll(states.toList()..sort());
      _availableDesignations..clear()..add('All Designations')..addAll(designations.toList()..sort());
    });
  }

  // --- NEW WORKFLOW METHODS ---
  String get _currentState {
    return (_isReviewMode ? widget.scheduleModel!.state : _masterPaymentList.first.timesheet.state);
  }

  bool get _isOctoberSchedule {
    final result = (_isReviewMode ? widget.scheduleModel!.month == 10 : widget.month == 10);
    debugPrint("Is October schedule: $result (review mode: $_isReviewMode, model month: ${widget.scheduleModel?.month}, widget month: ${widget.month})");
    return result;
  }

  Future<void> _getApproversForCurrentStep() async {
    setState(() {
      _approversLoading = true;
      _approverList = [];
      _selectedApprover = null;
    });

    final currentStatus = _isReviewMode ? widget.scheduleModel!.status : "Draft";
    String nextDept;
    String? targetState = _currentState;

    switch (currentStatus) {
      case "Draft":
        nextDept = "Internal Audit";
        break;
      case "Pending Audit":
        nextDept = "Compliance";
        break;
      case "Pending Compliance":
        nextDept = "Finance";
        break;
      case "Pending State Finance":
        nextDept = "Finance";
        targetState = null; // HQ Finance is not state-specific
        break;
      default:
        nextDept = ''; // No more steps
    }

    if (nextDept.isNotEmpty) {
      _approverList = await _fetchApprovers(nextDept, forState: targetState);
    }

    setState(() => _approversLoading = false);
  }

// In lib/pages/admin/payment_schedule_page.dart -> _PaymentSchedulePageState

  Future<List<Map<String, String>>> _fetchApprovers(String department, {String? forState}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('Staff').where('department', isEqualTo: department);
      if (forState != null) {
        query = query.where('state', isEqualTo: forState);
      }
      final snapshot = await query.get();
      // --- FIX IS HERE ---
      // Explicitly define the generic type for the map function.
      return snapshot.docs.map<Map<String, String>>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        return {'name': name, 'email': data['emailAddress'] ?? ''};
      }).toList();
      // --- END OF FIX ---
    } catch (e) {
      debugPrint("Error fetching approvers: $e");
      return [];
    }
  }

// In lib/pages/admin/payment_schedule_page.dart -> _PaymentSchedulePageState

  Future<void> _submitOrForwardSchedule() async {
    if (_selectedApprover == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an approver to forward to.")));
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("You must be logged in to submit.");

      // --- FIX #2: Fetch accurate user info from 'Staff' collection ---
      final staffDoc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      if (!staffDoc.exists) throw Exception("Could not find your staff profile. Cannot submit.");

      final staffData = staffDoc.data()!;
      final approverName = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}'.trim();
      final approverEmail = staffData['emailAddress'] ?? user.email!;
      final approverRole = staffData['designation'] ?? 'Unknown Role';
      // --- END OF FIX #2 ---

      final totalPayroll = _masterPaymentList.fold(0.0, (sum, item) => sum + item.proratedNet);
      final scheduleJson = jsonEncode(_masterPaymentList.map((item) => item.toJson()).toList());

      String nextStatus;
      final currentStatus = _isReviewMode ? widget.scheduleModel!.status : "Draft";
      switch(currentStatus) {
        case "Draft": nextStatus = "Pending Audit"; break;
        case "Pending Audit": nextStatus = "Pending Compliance"; break;
        case "Pending Compliance": nextStatus = "Pending State Finance"; break;
        case "Pending State Finance": nextStatus = "Pending HQ Finance"; break;
        default: throw Exception("Invalid status for forwarding.");
      }

      final newHistoryEntry = ApprovalHistoryEntry(
        approverName: approverName, // Use accurate name
        approverEmail: approverEmail, // Use accurate email
        role: approverRole, // Use accurate role (designation)
        action: "Approved and Forwarded",
        timestamp: Timestamp.now(),
      );

      // --- FIX #1: Create a predictable Document ID ---
      final int year = _isReviewMode ? widget.scheduleModel!.year : widget.year!;
      final int month = _isReviewMode ? widget.scheduleModel!.month : widget.month!;
      final String state = _currentState;
      final String docId = '${state}_${month}_$year'.replaceAll(' ', '_');
      // --- END OF FIX #1 ---

      final DocumentReference scheduleRef = FirebaseFirestore.instance.collection('PaymentSchedules').doc(docId);

      if (_isReviewMode) {
        // Update existing document
        await scheduleRef.update({
          'status': nextStatus,
          'currentAssigneeName': _selectedApprover!['name'],
          'currentAssigneeEmail': _selectedApprover!['email'],
          'approvalHistory': FieldValue.arrayUnion([newHistoryEntry.toMap()]),
          // Also update data in case edits were made before submission was possible
          'scheduleDataJson': scheduleJson,
          'totalNetPayroll': totalPayroll,
        });
      } else {
        // Create or Overwrite document using .set with merge option
        await scheduleRef.set({
          'year': year, 'month': month, 'state': state,
          'status': nextStatus, 'submittedByName': approverName, 'submittedByEmail': approverEmail,
          'submittedAt': Timestamp.now(), 'currentAssigneeName': _selectedApprover!['name'],
          'currentAssigneeEmail': _selectedApprover!['email'], 'totalNetPayroll': totalPayroll,
          'scheduleDataJson': scheduleJson,
          'approvalHistory': [newHistoryEntry.toMap()],
        }, SetOptions(merge: true)); // merge:true is crucial for updates
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Schedule successfully submitted to $nextStatus.")));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  // 4. NEW: Method to fetch bank details in batches
  Future<void> _fetchStaffBankDetails(List<String> staffIds) async {
    if (staffIds.isEmpty) return;
    try {
      // Firestore 'whereIn' queries are limited to 30 items
      for (var i = 0; i < staffIds.length; i += 30) {
        final chunk = staffIds.sublist(i, i + 30 > staffIds.length ? staffIds.length : i + 30);
        final snapshot = await FirebaseFirestore.instance.collection('Staff').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _staffBankDetailsCache[doc.id] = StaffBankInfo(
            bankName: data['bankName'] ?? 'N/A',
            accountNumber: data['accountNumber'] ?? 'N/A',
            sortCode: data['sortCode'] ?? 'N/A',
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching staff bank details: $e");
    }
  }

  Widget _buildChartsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) { // Mobile view
            return Column(
              children: [
                _buildPayrollByStateChart(),
                const SizedBox(height: 16),
                _buildStaffCountByDesignationChart(),
              ],
            );
          }
          // Desktop view
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPayrollByStateChart()),
              const SizedBox(width: 16),
              Expanded(child: _buildStaffCountByDesignationChart()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPayrollByStateChart() {
    final Map<String, double> payrollByState = {};
    for (var item in _filteredPaymentList) {
      payrollByState.update(item.timesheet.state, (value) => value + item.proratedNet, ifAbsent: () => item.proratedNet);
    }

    if (payrollByState.isEmpty) return const SizedBox.shrink();

    final chartData = payrollByState.entries.map((e) => BarChartGroupData(
        x: payrollByState.keys.toList().indexOf(e.key),
        barRods: [BarChartRodData(toY: e.value, color: Colors.teal, width: 16, borderRadius: BorderRadius.circular(4))]
    )).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Total Net Payroll by State", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                barGroups: chartData,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                    // Safety check for index out of bounds
                    if (value.toInt() >= 0 && value.toInt() < payrollByState.keys.length) {
                      return Text(payrollByState.keys.toList()[value.toInt()], style: const TextStyle(fontSize: 10));
                    }
                    return const Text('');
                  }, reservedSize: 30)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final state = payrollByState.keys.toList()[group.x];
                  // --- THIS IS THE CORRECTED PART ---
                  // The error was that TextSpan(...) is a constructor, not a function call.
                  // And we use Flutter's TextSpan, not the excel package one.
                  return BarTooltipItem(
                    _currencyFormat.format(rod.toY),
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: <TextSpan>[ // children expects a List<TextSpan>
                      TextSpan(
                        text: '\n$state',
                        style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                      ),
                    ],
                  );
                  // --- END OF CORRECTION ---
                })),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCountByDesignationChart() {
    final Map<String, int> staffByDesignation = {};
    for (var item in _filteredPaymentList) {
      staffByDesignation.update(item.timesheet.designation, (value) => value + 1, ifAbsent: () => 1);
    }

    if (staffByDesignation.isEmpty) return const SizedBox.shrink();

    final top5 = staffByDesignation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final chartData = top5.take(5).toList(); // Show top 5 for clarity

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Top 5 Staff Count by Designation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            ...chartData.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(width: 150, child: Text(e.key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: e.value / top5.first.value,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }

  Future<void> _applyFilters() async {
    // --- MODIFIED: Reset to page 0 on filter change ---
    setState(() => _isFiltering = true);
    await Future.delayed(const Duration(milliseconds: 300));

    List<PaymentScheduleItem> filtered = List.from(_masterPaymentList);
    final String searchQuery = _searchController.text.toLowerCase();

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) => item.timesheet.staffName.toLowerCase().contains(searchQuery)).toList();
    }
    if (!_selectedStates.contains('All States')) {
      final selectionSet = _selectedStates.toSet();
      filtered = filtered.where((item) => selectionSet.contains(item.timesheet.state)).toList();
    }
    if (!_selectedDesignations.contains('All Designations')) {
      final selectionSet = _selectedDesignations.toSet();
      filtered = filtered.where((item) => selectionSet.contains(item.timesheet.designation)).toList();
    }

    setState(() {
      _filteredPaymentList = filtered;
      _currentPage = 0; // Reset to the first page after filtering
      _isFiltering = false;
    });

    _paginateData(); // Re-paginate the newly filtered data
  }


  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(0, _isReviewMode ? widget.scheduleModel!.month : widget.month!));
    final year = _isReviewMode ? widget.scheduleModel!.year : widget.year!;
    final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;
    final double totalNetPayroll = _filteredPaymentList.fold(0.0, (sum, item) => sum + item.proratedNet);

    debugPrint("=== BUILD METHOD ===");
    debugPrint("Current month: $currentMonth");
    debugPrint("Is October: ${currentMonth == 10}");
    debugPrint("Master payment list length: ${_masterPaymentList.length}");
    debugPrint("Filtered payment list length: ${_filteredPaymentList.length}");

    String title;
    if (_isCombinedView) {
      title = "Combined Payment Schedule - Sep 20 to Oct 19, $year";
    } else if (currentMonth == 9) {
      title = "Payment Schedule - September Part 2 $year";
    } else if (currentMonth == 10) {
      title = "Payment Schedule - October $year (with September Part 2)";
    } else {
      title = "Payment Schedule - $monthName $year";
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isExporting) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else IconButton(icon: const Icon(Icons.download_rounded), tooltip: "Export to Excel", onPressed: _masterPaymentList.isEmpty ? null : _exportToExcel),
          if (_isOctoberSchedule) IconButton(
            icon: const Icon(Icons.merge_rounded),
            tooltip: "Combine Sep Part 2 + Oct",
            onPressed: _combineSepPart2AndOct,
          ),
        ],
      ),
      // --- MODIFIED: Wrapped the body's Column in a SingleChildScrollView ---
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _masterPaymentList.isEmpty
          ? _buildEmptyState("No matching salary data found", "Please ensure staff designations have a corresponding entry in the 'Manage Salary Scales' page.")
          : SingleChildScrollView(
        child: Column(
          children: [
            if (!_isReviewMode) _buildFilterBar(),
            if ((currentMonth == 9 || currentMonth == 10) || _isCombinedView) _buildDescriptionCard(),
            _buildKpiHeader(totalNetPayroll),
            if (!_isLoading && _filteredPaymentList.isNotEmpty) _buildChartsSection(),
            // --- MODIFIED: Removed Expanded and Padding, now directly in the Column ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _filteredPaymentList.isEmpty && !_isFiltering
                  ? _buildEmptyState("No Staff Found", "No staff match the current filter criteria.")
                  : Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isFiltering ? 0.5 : 1.0,
                    child: _buildDataTableCard(),
                  ),
                  if (_isFiltering)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF722F37)),
                      ),
                    ),
                ],
              ),
            ),
            _buildWorkflowSection(),
          ],
        ),
      ),
    );
  }



  Widget _buildWorkflowSection() {
    final status = _isReviewMode ? widget.scheduleModel!.status : "Draft";
    String title;
    bool canForward = false;

    switch (status) {
      case "Draft": title = "Forward to Internal Audit"; canForward = true; break;
      case "Pending Audit": title = "Forward to Compliance"; canForward = true; break;
      case "Pending Compliance": title = "Forward to State Finance"; canForward = true; break;
      case "Pending State Finance": title = "Forward to HQ Finance"; canForward = true; break;
      default: title = "Schedule is Fully Approved"; canForward = false;
    }

    if (_masterPaymentList.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            if (canForward) ...[
              if (_approversLoading) const Center(child: CircularProgressIndicator())
              else if (_approverList.isEmpty) const Text("No approvers found for the next step.", style: TextStyle(color: Colors.red))
              else
              // --- CHANGE: Wrapped dropdown and button in a Row ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Map<String, String>>(
                        initialValue: _selectedApprover,
                        decoration: const InputDecoration(
                          labelText: "Select Approver",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_search),
                        ),
                        items: _approverList.map((approver) {
                          return DropdownMenuItem(
                            value: approver,
                            child: Text(approver['name']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedApprover = value);
                        },
                        validator: (value) => value == null ? 'Please select an approver' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _isSubmitting
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(),
                    )
                        : ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text("Approve & Forward"),
                      onPressed: _submitOrForwardSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      ),
                    ),
                  ],
                ),
            ] else
              Text("This schedule has been forwarded and is awaiting action from: ${widget.scheduleModel?.currentAssigneeName ?? 'N/A'}", textAlign: TextAlign.center),
            if(_isReviewMode) ...[
              const SizedBox(height: 16),
              _buildApprovalHistory(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalHistory() {
    return ExpansionTile(
      title: const Text("View Approval History"),
      children: widget.scheduleModel!.approvalHistory.map((entry) {
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text("${entry.role}: ${entry.approverName}"),
          subtitle: Text("${entry.action} on ${DateFormat.yMMMd().add_jm().format(entry.timestamp.toDate())}"),
        );
      }).toList(),
    );
  }

  // --- UI BUILDER WIDGETS ---

// REPLACE the _buildFilterBar method

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column( // Always use a column for better responsiveness
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildMultiSelectButton('Filter by State', _selectedStates, _availableStates, 'All States', (selected) {
                    setState(() => _selectedStates = selected);
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildMultiSelectButton('Filter by Designation', _selectedDesignations, _availableDesignations, 'All Designations', (selected) {
                    setState(() => _selectedDesignations = selected);
                    _applyFilters();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // --- NEW: Search by Name Field ---
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Staff Name',
                hintText: 'Enter name to search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
                    : null,
              ),
              onChanged: (value) => _applyFilters(),
            ),
          ],
        ),
      ),
    );
  }

// NEW HELPER METHOD for the multi-select buttons in the filter bar
  Widget _buildMultiSelectButton(String label, List<String> selectedOptions, List<String> allOptions, String allText, ValueChanged<List<String>> onSelectionChanged) {

    String getButtonText() {
      if (selectedOptions.contains(allText)) return allText;
      if (selectedOptions.length == 1) return selectedOptions.first;
      if (selectedOptions.isNotEmpty) return '${selectedOptions.length} Selected';
      return 'Select...';
    }

    return InkWell(
      onTap: () async {
        final List<String>? result = await showDialog(
          context: context,
          builder: (context) => MultiSelectDialog(
            title: 'Select $label',
            allOptions: allOptions,
            initialSelectedOptions: selectedOptions,
            allText: allText,
          ),
        );
        if (result != null) {
          onSelectionChanged(result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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

  Widget _buildDropdown(List<String> items, String value, String label, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDescriptionCard() {
    String description;
    if (_isCombinedView) {
      description = "This is a combined payment schedule from September 20th to October 19th. The data has been merged from September Part 2 and October schedules. All hours, deductions, and payments have been summed accordingly.";
    } else {
      final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;
      if (currentMonth == 9) {
        description = "This is September Part 2 (20th-30th). The gross pay is calculated based on the last period of September from 20th to 30th, prorated for the partial period.";
      } else if (currentMonth == 10) {
        description = "This is October (1st-19th) with September Part 2 data. The table shows both September Part 2 data (20th-30th) and October data (1st-19th) side-by-side. The gross pay for October is calculated based on the prorated period from October 1st to October 19th.";
      } else {
        description = "";
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: Colors.orange.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.withOpacity(0.3))
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiHeader(double totalNetPayroll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: const Color(0xFF722F37).withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFF722F37).withOpacity(0.3))
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF722F37)),
              const SizedBox(width: 12),
              Text(
                "Total Net Payroll (Filtered): ",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              Text(
                _currencyFormat.format(totalNetPayroll),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF722F37)),
              ),
            ],
          ),
        ),
      ),
    );
  }


  List<DataColumn> _getDataTableColumns() {
    final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;

    if (currentMonth == 9) {
      // September Part 2 - show only September columns
      return const [
        DataColumn(label: Text('S/No')),
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('State')),
        DataColumn(label: Text('SRT')),
        DataColumn(label: Text('Bank Name')),
        DataColumn(label: Text('Account Number')),
        DataColumn(label: Text('Sort Code')),
        DataColumn(label: Text('Expected Hrs'), numeric: true),
        DataColumn(label: Text('Hrs Worked'), numeric: true),
        DataColumn(label: Text('% Worked'), numeric: true),
        DataColumn(label: Text('Gross Pay'), numeric: true),
        DataColumn(label: Text('WHT'), numeric: true),
        DataColumn(label: Text('Other Deductions'), numeric: true),
        DataColumn(label: Text('Gross After Deductions'), numeric: true),
        DataColumn(label: Text('Additions'), numeric: true),
        DataColumn(label: Text('Final Net Pay'), numeric: true),
        DataColumn(label: Text('Comments')),
        DataColumn(label: Text('Action')),
      ];
    } else if (currentMonth == 10) {
      // October - show both September and October columns
      return const [
        DataColumn(label: Text('S/No')),
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('State')),
        DataColumn(label: Text('SRT')),
        DataColumn(label: Text('Bank Name')),
        DataColumn(label: Text('Account Number')),
        DataColumn(label: Text('Sort Code')),
        DataColumn(label: Text('Sept Expected Hrs'), numeric: true),
        DataColumn(label: Text('Oct Expected Hrs'), numeric: true),
        DataColumn(label: Text('Sept Hrs Worked'), numeric: true),
        DataColumn(label: Text('Oct Hrs Worked'), numeric: true),
        DataColumn(label: Text('Sept % Worked'), numeric: true),
        DataColumn(label: Text('Oct % Worked'), numeric: true),
        DataColumn(label: Text('Sept Gross Pay'), numeric: true),
        DataColumn(label: Text('Oct Gross Pay'), numeric: true),
        DataColumn(label: Text('Sept WHT'), numeric: true),
        DataColumn(label: Text('Oct WHT'), numeric: true),
        DataColumn(label: Text('Sept Other Deductions'), numeric: true),
        DataColumn(label: Text('Oct Other Deductions'), numeric: true),
        DataColumn(label: Text('Sept Gross After Deductions'), numeric: true),
        DataColumn(label: Text('Oct Gross After Deductions'), numeric: true),
        DataColumn(label: Text('Sept Additions'), numeric: true),
        DataColumn(label: Text('Oct Additions'), numeric: true),
        DataColumn(label: Text('Sept Final Net Pay'), numeric: true),
        DataColumn(label: Text('Oct Final Net Pay'), numeric: true),
        DataColumn(label: Text('Comments')),
        DataColumn(label: Text('Action')),
      ];
    } else {
      // Other months - show only current month columns
      return const [
        DataColumn(label: Text('S/No')),
        DataColumn(label: Text('Staff Name')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('State')),
        DataColumn(label: Text('SRT')),
        DataColumn(label: Text('Bank Name')),
        DataColumn(label: Text('Account Number')),
        DataColumn(label: Text('Sort Code')),
        DataColumn(label: Text('Expected Hrs'), numeric: true),
        DataColumn(label: Text('Hrs Worked'), numeric: true),
        DataColumn(label: Text('% Worked'), numeric: true),
        DataColumn(label: Text('Gross Pay'), numeric: true),
        DataColumn(label: Text('WHT'), numeric: true),
        DataColumn(label: Text('Other Deductions'), numeric: true),
        DataColumn(label: Text('Gross After Deductions'), numeric: true),
        DataColumn(label: Text('Additions'), numeric: true),
        DataColumn(label: Text('Final Net Pay'), numeric: true),
        DataColumn(label: Text('Comments')),
        DataColumn(label: Text('Action')),
      ];
    }
  }

  List<DataCell> _getDataTableCells(int index, PaymentScheduleItem item, StaffBankInfo bankInfo, Map<String, dynamic> septData, String deductionText) {
    final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;

    if (currentMonth == 9) {
      // September Part 2 - show only current month data
      return [
        // 1. S/No
        DataCell(Text((index + 1).toString())),
        // 2. Staff Name
        DataCell(Row(children: [
          if (item.additionAmount > 0) Tooltip(message: "Addition: ${item.additionReason ?? ''}", child: Icon(Icons.arrow_upward, size: 14, color: Colors.green.shade700)),
          if (item.deductionAmount > 0) Tooltip(message: "Deduction: ${item.deductionReason ?? ''}", child: Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade700)),
          if (item.isEdited) const Tooltip(message: 'Manually Edited', child: Icon(Icons.push_pin, size: 14, color: Colors.orange)),
          if (item.additionAmount > 0 || item.deductionAmount > 0 || item.isEdited) const SizedBox(width: 4),
          Text(item.timesheet.staffName),
        ])),
        // 3. Designation
        DataCell(SizedBox(width: 200, child: Text(item.timesheet.designation, overflow: TextOverflow.ellipsis))),
        // 4. State
        DataCell(Text(item.timesheet.state)),
        // 5. SRT
        DataCell(Text(item.srt ?? 'N/A')),
        // 6. Bank Name
        DataCell(SizedBox(width: 150, child: Text(bankInfo.bankName, overflow: TextOverflow.ellipsis))),
        // 7. Account Number
        DataCell(Text(bankInfo.accountNumber)),
        // 8. Sort Code
        DataCell(Text(bankInfo.sortCode)),
        // 9. Expected Hours
        DataCell(Text(item.expectedHours.toStringAsFixed(2))),
        // 10. Hours Worked
        DataCell(Text(item.actualHoursWorked.toStringAsFixed(2))),
        // 11. % Worked
        DataCell(_buildPercentageChip(item.percentageWorked)),
        // 12. Gross Pay
        DataCell(Text(_currencyFormat.format(item.baseSalary.grossPay))),
        // 13. WHT
        DataCell(Text(_currencyFormat.format(item.payeFromGrossBase))),
        // 14. Other Deductions
        DataCell(Text(deductionText, style: TextStyle(color: item.otherDeductionsAmount > 0 ? Colors.red.shade700 : Colors.grey), textAlign: TextAlign.right)),
        // 15. Gross After Deductions
        DataCell(Text(_currencyFormat.format(item.grossAfterDeductions))),
        // 16. Additions
        DataCell(Text(_currencyFormat.format(item.additionAmount), style: TextStyle(color: item.additionAmount > 0 ? Colors.green.shade700 : Colors.grey))),
        // 17. Final Net Pay
        DataCell(Text(_currencyFormat.format(item.proratedNet), style: const TextStyle(fontWeight: FontWeight.bold))),
        // 18. Comments
        DataCell(SizedBox(width: 250, child: Text(item.comments, overflow: TextOverflow.ellipsis))),
        // 19. Action
        DataCell(IconButton(
          icon: const Icon(Icons.edit_note, size: 20),
          color: _isReviewMode ? Colors.grey : Colors.blueAccent,
          onPressed: _isReviewMode ? null : () => _showEditSalaryDialog(item),
          tooltip: _isReviewMode ? 'Schedule Submitted (Read-only)' : 'Adjust Salary',
        )),
      ];
    } else if (currentMonth == 10) {
      // October - show both September and October data
      return [
        // 1. S/No
        DataCell(Text((index + 1).toString())),
        // 2. Staff Name
        DataCell(Row(children: [
          if (item.additionAmount > 0) Tooltip(message: "Addition: ${item.additionReason ?? ''}", child: Icon(Icons.arrow_upward, size: 14, color: Colors.green.shade700)),
          if (item.deductionAmount > 0) Tooltip(message: "Deduction: ${item.deductionReason ?? ''}", child: Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade700)),
          if (item.isEdited) const Tooltip(message: 'Manually Edited', child: Icon(Icons.push_pin, size: 14, color: Colors.orange)),
          if (item.additionAmount > 0 || item.deductionAmount > 0 || item.isEdited) const SizedBox(width: 4),
          Text(item.timesheet.staffName),
        ])),
        // 3. Designation
        DataCell(SizedBox(width: 200, child: Text(item.timesheet.designation, overflow: TextOverflow.ellipsis))),
        // 4. State
        DataCell(Text(item.timesheet.state)),
        // 5. SRT
        DataCell(Text(item.srt ?? 'N/A')),
        // 6. Bank Name
        DataCell(SizedBox(width: 150, child: Text(bankInfo.bankName, overflow: TextOverflow.ellipsis))),
        // 7. Account Number
        DataCell(Text(bankInfo.accountNumber)),
        // 8. Sort Code
        DataCell(Text(bankInfo.sortCode)),
        // 9. Sept Expected Hours
        DataCell(Text(septData['expectedHours'].toStringAsFixed(2))),
        // 10. Oct Expected Hours
        DataCell(Text(item.expectedHours.toStringAsFixed(2))),
        // 11. Sept Hrs Worked
        DataCell(Text(septData['hoursWorked'].toStringAsFixed(2))),
        // 12. Oct Hrs Worked
        DataCell(Text(item.actualHoursWorked.toStringAsFixed(2))),
        // 13. Sept % Worked
        DataCell(_buildPercentageChip(septData['percentageWorked'])),
        // 14. Oct % Worked
        DataCell(_buildPercentageChip(item.percentageWorked)),
        // 15. Sept Gross Pay
        DataCell(Text(_currencyFormat.format(septData['grossPay']))),
        // 16. Oct Gross Pay
        DataCell(Text(_currencyFormat.format(item.baseSalary.grossPay))),
        // 17. Sept WHT
        DataCell(Text(_currencyFormat.format(septData['wht']))),
        // 18. Oct WHT
        DataCell(Text(_currencyFormat.format(item.payeFromGrossBase))),
        // 19. Sept Other Deductions
        DataCell(Text(_currencyFormat.format(septData['otherDeductions']))),
        // 20. Oct Other Deductions
        DataCell(Text(deductionText, style: TextStyle(color: item.otherDeductionsAmount > 0 ? Colors.red.shade700 : Colors.grey), textAlign: TextAlign.right)),
        // 21. Sept Gross After Deductions
        DataCell(Text(_currencyFormat.format(septData['grossAfterDeductions']))),
        // 22. Oct Gross After Deductions
        DataCell(Text(_currencyFormat.format(item.grossAfterDeductions))),
        // 23. Sept Additions
        DataCell(Text(_currencyFormat.format(septData['additions']), style: TextStyle(color: septData['additions'] > 0 ? Colors.green.shade700 : Colors.grey))),
        // 24. Oct Additions
        DataCell(Text(_currencyFormat.format(item.additionAmount), style: TextStyle(color: item.additionAmount > 0 ? Colors.green.shade700 : Colors.grey))),
        // 25. Sept Final Net Pay
        DataCell(Text(_currencyFormat.format(septData['finalNetPay']), style: const TextStyle(fontWeight: FontWeight.bold))),
        // 26. Oct Final Net Pay
        DataCell(Text(_currencyFormat.format(item.proratedNet), style: const TextStyle(fontWeight: FontWeight.bold))),
        // 27. Comments
        DataCell(SizedBox(width: 250, child: Text(item.comments, overflow: TextOverflow.ellipsis))),
        // 28. Action
        DataCell(IconButton(
          icon: const Icon(Icons.edit_note, size: 20),
          color: _isReviewMode ? Colors.grey : Colors.blueAccent,
          onPressed: _isReviewMode ? null : () => _showEditSalaryDialog(item),
          tooltip: _isReviewMode ? 'Schedule Submitted (Read-only)' : 'Adjust Salary',
        )),
      ];
    } else {
      // Other months - show only current month data
      return [
        // 1. S/No
        DataCell(Text((index + 1).toString())),
        // 2. Staff Name
        DataCell(Row(children: [
          if (item.additionAmount > 0) Tooltip(message: "Addition: ${item.additionReason ?? ''}", child: Icon(Icons.arrow_upward, size: 14, color: Colors.green.shade700)),
          if (item.deductionAmount > 0) Tooltip(message: "Deduction: ${item.deductionReason ?? ''}", child: Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade700)),
          if (item.isEdited) const Tooltip(message: 'Manually Edited', child: Icon(Icons.push_pin, size: 14, color: Colors.orange)),
          if (item.additionAmount > 0 || item.deductionAmount > 0 || item.isEdited) const SizedBox(width: 4),
          Text(item.timesheet.staffName),
        ])),
        // 3. Designation
        DataCell(SizedBox(width: 200, child: Text(item.timesheet.designation, overflow: TextOverflow.ellipsis))),
        // 4. State
        DataCell(Text(item.timesheet.state)),
        // 5. SRT
        DataCell(Text(item.srt ?? 'N/A')),
        // 6. Bank Name
        DataCell(SizedBox(width: 150, child: Text(bankInfo.bankName, overflow: TextOverflow.ellipsis))),
        // 7. Account Number
        DataCell(Text(bankInfo.accountNumber)),
        // 8. Sort Code
        DataCell(Text(bankInfo.sortCode)),
        // 9. Expected Hours
        DataCell(Text(item.expectedHours.toStringAsFixed(2))),
        // 10. Hours Worked
        DataCell(Text(item.actualHoursWorked.toStringAsFixed(2))),
        // 11. % Worked
        DataCell(_buildPercentageChip(item.percentageWorked)),
        // 12. Gross Pay
        DataCell(Text(_currencyFormat.format(item.baseSalary.grossPay))),
        // 13. WHT
        DataCell(Text(_currencyFormat.format(item.payeFromGrossBase))),
        // 14. Other Deductions
        DataCell(Text(deductionText, style: TextStyle(color: item.otherDeductionsAmount > 0 ? Colors.red.shade700 : Colors.grey), textAlign: TextAlign.right)),
        // 15. Gross After Deductions
        DataCell(Text(_currencyFormat.format(item.grossAfterDeductions))),
        // 16. Additions
        DataCell(Text(_currencyFormat.format(item.additionAmount), style: TextStyle(color: item.additionAmount > 0 ? Colors.green.shade700 : Colors.grey))),
        // 17. Final Net Pay
        DataCell(Text(_currencyFormat.format(item.proratedNet), style: const TextStyle(fontWeight: FontWeight.bold))),
        // 18. Comments
        DataCell(SizedBox(width: 250, child: Text(item.comments, overflow: TextOverflow.ellipsis))),
        // 19. Action
        DataCell(IconButton(
          icon: const Icon(Icons.edit_note, size: 20),
          color: _isReviewMode ? Colors.grey : Colors.blueAccent,
          onPressed: _isReviewMode ? null : () => _showEditSalaryDialog(item),
          tooltip: _isReviewMode ? 'Schedule Submitted (Read-only)' : 'Adjust Salary',
        )),
      ];
    }
  }

  Widget _buildDataTableCard() {
    const double scrollAmount = 300.0;
    return Card(
      elevation: 5.0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Details (${_filteredPaymentList.length} staff)', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _scrollController.animateTo(_scrollController.offset - scrollAmount, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), tooltip: "Scroll Left"),
                    IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _scrollController.animateTo(_scrollController.offset + scrollAmount, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), tooltip: "Scroll Right"),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: _getDataTableColumns(),
              rows: _paginatedList.asMap().entries.map((entry) {
                int index = (_currentPage * _rowsPerPage) + entry.key;
                PaymentScheduleItem item = entry.value;

                final bankInfo = _staffBankDetailsCache[item.timesheet.staffId] ?? StaffBankInfo();
                
                // Get September Part 2 data if available
                final septData = _getSeptPart2DataForStaff(item.timesheet.staffId);

                double deductedPercentage = (item.expectedHours > 0) ? (item.totalDeductedHoursFromTimesheet / item.expectedHours * 100) : 0;
                String deductionText = item.otherDeductionsAmount > 0
                    ? "${_currencyFormat.format(item.otherDeductionsAmount)}\n(-${deductedPercentage.toStringAsFixed(1)}%)"
                    : _currencyFormat.format(0);

                return DataRow(
                  cells: _getDataTableCells(index, item, bankInfo, septData, deductionText),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  // --- NEW WIDGET: _buildPaginationControls ---
  Widget _buildPaginationControls() {
    final totalItems = _filteredPaymentList.length;
    if (totalItems == 0) return const SizedBox.shrink();

    final totalPages = (totalItems / _rowsPerPage).ceil();
    final startItem = (_currentPage * _rowsPerPage) + 1;
    final endItem = min((_currentPage + 1) * _rowsPerPage, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing $startItem-$endItem of $totalItems",
            style: const TextStyle(color: Colors.grey),
          ),
          Row(
            children: [
              Text("Page ${_currentPage + 1} of $totalPages"),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage == 0
                    ? null
                    : () {
                  setState(() {
                    _currentPage--;
                  });
                  _paginateData();
                },
                tooltip: "Previous Page",
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (_currentPage + 1) >= totalPages
                    ? null
                    : () {
                  setState(() {
                    _currentPage++;
                  });
                  _paginateData();
                },
                tooltip: "Next Page",
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPercentageChip(double percentage) {
    Color chipColor;
    if (percentage >= 95.0) {
      chipColor = Colors.green;
    } else if (percentage >= 75.0) {
      chipColor = Colors.orange;
    } else {
      chipColor = Colors.red;
    }
    return Chip(
      label: Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle, style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Helper method to get September Part 2 data for a specific staff
  Map<String, dynamic> _getSeptPart2DataForStaff(String staffId) {
    final data = _septPart2DataCache[staffId] ?? _createEmptySeptDataForTable();
    debugPrint("Getting September Part 2 data for staff $staffId: ${data['expectedHours']}, ${data['hoursWorked']}, ${data['finalNetPay']}");
    return data;
  }

  // Helper method to create empty September Part 2 data
  Map<String, dynamic> _createEmptySeptDataForTable() {
    return {
      'expectedHours': 0,
      'hoursWorked': 0,
      'percentageWorked': 0,
      'grossPay': 0,
      'wht': 0,
      'otherDeductions': 0,
      'grossAfterDeductions': 0,
      'additions': 0,
      'finalNetPay': 0,
    };
  }

  // Helper method to create empty September Part 2 data
  Map<String, dynamic> _createEmptySeptData() {
    return {
      'expectedHours': 0,
      'hoursWorked': 0,
      'percentageWorked': 0,
      'grossPay': 0,
      'wht': 0,
      'otherDeductions': 0,
      'grossAfterDeductions': 0,
      'additions': 0,
      'finalNetPay': 0,
    };
  }

  // Method to fetch September Part 2 data for all staff
  Future<void> _fetchSeptPart2DataForAllStaff() async {
    try {
      final currentYear = _isReviewMode ? widget.scheduleModel!.year : widget.year!;
      
      // Clear existing cache
      _septPart2DataCache.clear();
      
      // Get all staff IDs from the current payment list
      final List<String> staffIds = _masterPaymentList.map((item) => item.timesheet.staffId).toList();
      
      debugPrint("=== FETCHING SEPTEMBER PART 2 DATA ===");
      debugPrint("Current year: $currentYear");
      debugPrint("Master payment list length: ${_masterPaymentList.length}");
      debugPrint("Fetching September Part 2 data for ${staffIds.length} staff members");
      debugPrint("Staff IDs: $staffIds");
      
      // Try multiple collection name variations
      final List<String> possibleCollectionNames = [
        "September_${currentYear}_part2",
        "September_${currentYear}_part_2",
        "september_${currentYear}_part2",
        "september_${currentYear}_part_2",
        "September_${currentYear}_Part2",
        "September_${currentYear}_Part_2",
        "September $currentYear part2",
        "September $currentYear part_2",
        "September${currentYear}part2",
        "September${currentYear}part_2",
      ];
      
      String? foundCollectionName;
      
      // First, try to find a valid collection name by checking the first staff member
      if (staffIds.isNotEmpty) {
        final sampleStaffRef = FirebaseFirestore.instance.collection('Staff').doc(staffIds.first);
        
        // Try each possible collection name
        for (final collectionName in possibleCollectionNames) {
          debugPrint("Trying collection name: $collectionName");
          final sampleTimesheetsRef = sampleStaffRef.collection('TimeSheets').doc(collectionName);
          final sampleSnapshot = await sampleTimesheetsRef.get();
          
          if (sampleSnapshot.exists) {
            foundCollectionName = collectionName;
            debugPrint("Found valid collection name: $collectionName");
            break;
          }
        }
        
        // If no specific collection name found, try to find any document with 'september' and 'part' in the name
        if (foundCollectionName == null) {
          debugPrint("No specific collection name found. Searching for any document with 'september' and 'part' in name");
          final timesheetsCollection = await sampleStaffRef.collection('TimeSheets').get();

          debugPrint("Found ${timesheetsCollection.docs.length} total documents in TimeSheets collection");
          for (var doc in timesheetsCollection.docs) {
            final docId = doc.id.toLowerCase();
            debugPrint("Checking document ID: $docId");

            if (docId.contains('september') && (docId.contains('part2') || docId.contains('part_2') || docId.contains('part'))) {
              foundCollectionName = doc.id;
              debugPrint("Found matching document: $docId");
              break;
            }
          }

          // If still not found, try a broader search for any document containing 'sept'
          if (foundCollectionName == null) {
            debugPrint("No 'september' document found. Trying broader search for 'sept'");
            for (var doc in timesheetsCollection.docs) {
              final docId = doc.id.toLowerCase();
              debugPrint("Checking document ID: $docId");

              if (docId.contains('sept')) {
                foundCollectionName = doc.id;
                debugPrint("Found document with 'sept': $docId");
                break;
              }
            }
          }

          // Final fallback: try to find any document that might contain timesheet data for September
          if (foundCollectionName == null) {
            debugPrint("No September-related document found. Trying to find any recent timesheet document");
            // Look for documents that might be from September based on creation date or content
            for (var doc in timesheetsCollection.docs) {
              final docId = doc.id.toLowerCase();
              final data = doc.data();

              // Check if the document contains timesheet entries and might be from September
              if (data.containsKey('timesheetEntries') && data['timesheetEntries'] is List) {
                final entries = data['timesheetEntries'] as List;
                if (entries.isNotEmpty) {
                  // Check if any entry has a date in September
                  for (var entry in entries) {
                    if (entry is Map && entry.containsKey('date')) {
                      final dateStr = entry['date'].toString();
                      if (dateStr.contains('2024-09') || dateStr.contains('09/') || dateStr.contains('/09/')) {
                        foundCollectionName = doc.id;
                        debugPrint("Found document with September data: $docId");
                        break;
                      }
                    }
                  }
                  if (foundCollectionName != null) break;
                }
              }
            }
          }
        }
        
        // If we found a collection name, fetch data for all staff
        if (foundCollectionName != null) {
          debugPrint("Using collection name: $foundCollectionName");
          
          for (final staffId in staffIds) {
            try {
              debugPrint("Processing staff ID: $staffId");
              
              final staffRef = FirebaseFirestore.instance.collection('Staff').doc(staffId);
              final timesheetsRef = staffRef.collection('TimeSheets').doc(foundCollectionName);
              
              final docSnapshot = await timesheetsRef.get();
              
              debugPrint("Document exists for staff $staffId: ${docSnapshot.exists}");
              
              if (docSnapshot.exists) {
                final data = docSnapshot.data() as Map<String, dynamic>;
                debugPrint("Data for staff $staffId: ${data.keys}");
                
                // Calculate total hours worked from timesheetEntries
                double totalHoursWorked = 0;
                if (data['timesheetEntries'] != null) {
                  final entries = data['timesheetEntries'] as List;
                  debugPrint("Found ${entries.length} timesheet entries for staff $staffId");
                  for (var entry in entries) {
                    totalHoursWorked += (entry['noOfHours'] as num).toDouble();
                    debugPrint("Added ${entry['noOfHours']} hours, total: $totalHoursWorked");
                  }
                }
                
                // Calculate expected hours for September Part 2 (Sep 20-30)
                DateTime sepStart = DateTime(currentYear, 9, 20);
                DateTime sepEnd = DateTime(currentYear, 9, 30);
                List<DateTime> sepDays = List.generate(sepEnd.difference(sepStart).inDays + 1, (i) => sepStart.add(Duration(days: i)));
                int sepWorkingDays = sepDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
                double expectedHours = sepWorkingDays * 8.0;
                
                debugPrint("Staff $staffId - Expected hours: $expectedHours, Working days: $sepWorkingDays");
                
                // Calculate percentage worked
                double percentageWorked = expectedHours > 0 ? (totalHoursWorked / expectedHours * 100) : 0;
                if (percentageWorked > 100) percentageWorked = 100;
                
                // Get staff's salary scale to calculate pay
                final designation = data['designation'] ?? _masterPaymentList.firstWhere(
                  (item) => item.timesheet.staffId == staffId,
                  orElse: () => _masterPaymentList.first,
                ).timesheet.designation;
                
                debugPrint("Staff $staffId - Designation: $designation");
                
                double grossPay = 0;
                double wht = 0;
                double netPay = 0;
                
                final salaryScaleSnapshot = await FirebaseFirestore.instance
                    .collection('SalaryScales')
                    .where('designation', isEqualTo: designation)
                    .get();
                
                debugPrint("Found ${salaryScaleSnapshot.docs.length} salary scales for designation $designation");
                
                if (salaryScaleSnapshot.docs.isNotEmpty) {
                  final salaryData = salaryScaleSnapshot.docs.first.data();
                  final baseGrossPay = (salaryData['grossPay'] as num).toDouble();
                  
                  debugPrint("Staff $staffId - Base gross pay: $baseGrossPay");
                  
                  // For September Part 2, we need to prorate the salary
                  // Full period: Sep 20 to Oct 19
                  DateTime fullStart = DateTime(currentYear, 9, 20);
                  DateTime fullEnd = DateTime(currentYear, 10, 19);
                  List<DateTime> fullDays = List.generate(fullEnd.difference(fullStart).inDays + 1, (i) => fullStart.add(Duration(days: i)));
                  int fullWorkingDays = fullDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
                  
                  double dailyGross = baseGrossPay / fullWorkingDays;
                  grossPay = dailyGross * sepWorkingDays;
                  wht = grossPay * 0.05; // 5% WHT
                  netPay = grossPay - wht;
                  
                  debugPrint("Staff $staffId - Gross pay: $grossPay, WHT: $wht, Net pay: $netPay");
                }
                
                // Cache the calculated September Part 2 data
                _septPart2DataCache[staffId] = {
                  'expectedHours': expectedHours,
                  'hoursWorked': totalHoursWorked,
                  'percentageWorked': percentageWorked,
                  'grossPay': grossPay,
                  'wht': wht,
                  'otherDeductions': 0, // No other deductions for now
                  'grossAfterDeductions': grossPay - wht,
                  'additions': 0, // No additions for now
                  'finalNetPay': netPay,
                };
                
                debugPrint("Cached September Part 2 data for staff $staffId: ${{
                  'expectedHours': expectedHours,
                  'hoursWorked': totalHoursWorked,
                  'percentageWorked': percentageWorked,
                  'grossPay': grossPay,
                  'wht': wht,
                  'finalNetPay': netPay,
                }}");
              } else {
                debugPrint("No September Part 2 data found for staff $staffId");
              }
            } catch (e) {
              debugPrint("Error fetching September Part 2 data for staff $staffId: $e");
            }
          }
        } else {
          debugPrint("No September Part 2 collection found for any staff member");
        }
      }
      
      debugPrint("Final cache size: ${_septPart2DataCache.length}");
      debugPrint("Fetched September Part 2 data for ${_septPart2DataCache.length} staff members");

      // If no data was found, try a more comprehensive search
      if (_septPart2DataCache.isEmpty && staffIds.isNotEmpty) {
        debugPrint("No data found with standard approach. Trying comprehensive search...");
        await _comprehensiveSeptPart2Search(staffIds, currentYear);

        // If still no data, try state-level collection approach
        if (_septPart2DataCache.isEmpty) {
          debugPrint("No data found in comprehensive search. Trying state-level collection...");
          await _fetchSeptPart2FromStateCollection(staffIds, currentYear);
        }
      }

    } catch (e) {
      debugPrint("Error fetching September Part 2 data: $e");
      // Don't show error to user, just continue with empty data
    }
  }

  // Comprehensive search for September Part 2 data across all staff
  Future<void> _comprehensiveSeptPart2Search(List<String> staffIds, int currentYear) async {
    debugPrint("=== COMPREHENSIVE SEPTEMBER PART 2 SEARCH ===");

    for (final staffId in staffIds) {
      try {
        debugPrint("Searching for September data for staff: $staffId");

        final staffRef = FirebaseFirestore.instance.collection('Staff').doc(staffId);
        final timesheetsCollection = await staffRef.collection('TimeSheets').get();

        debugPrint("Staff $staffId has ${timesheetsCollection.docs.length} timesheet documents");

        for (var doc in timesheetsCollection.docs) {
          final docId = doc.id;
          final data = doc.data();

          debugPrint("Checking document: $docId");
          debugPrint("Document keys: ${data.keys.toList()}");

          // Check if this document has timesheet entries
          if (data.containsKey('timesheetEntries') && data['timesheetEntries'] is List) {
            final entries = data['timesheetEntries'] as List;
            debugPrint("Document has ${entries.length} timesheet entries");

            if (entries.isNotEmpty) {
              // Check if any entry has a date in September
              bool hasSeptemberData = false;
              double totalHoursWorked = 0;

              for (var entry in entries) {
                if (entry is Map && entry.containsKey('date')) {
                  final dateStr = entry['date'].toString();
                  debugPrint("Entry date: $dateStr");

                  // Check for September dates in various formats
                  if (dateStr.contains('2024-09') ||
                      dateStr.contains('09/') ||
                      dateStr.contains('/09/') ||
                      dateStr.contains('September') ||
                      dateStr.contains('Sept')) {
                    hasSeptemberData = true;
                    debugPrint("Found September data in entry: $dateStr");
                  }

                  // Sum up hours worked
                  if (entry.containsKey('noOfHours')) {
                    totalHoursWorked += (entry['noOfHours'] as num).toDouble();
                  }
                }
              }

              if (hasSeptemberData) {
                debugPrint("Found September data in document: $docId");
                debugPrint("Total hours worked: $totalHoursWorked");

                // Calculate expected hours for September Part 2 (Sep 20-30)
                DateTime sepStart = DateTime(currentYear, 9, 20);
                DateTime sepEnd = DateTime(currentYear, 9, 30);
                List<DateTime> sepDays = List.generate(sepEnd.difference(sepStart).inDays + 1, (i) => sepStart.add(Duration(days: i)));
                int sepWorkingDays = sepDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
                double expectedHours = sepWorkingDays * 8.0;

                // Calculate percentage worked
                double percentageWorked = expectedHours > 0 ? (totalHoursWorked / expectedHours * 100) : 0;
                if (percentageWorked > 100) percentageWorked = 100;

                // Get staff's salary scale to calculate pay
                final designation = data['designation'] ?? _masterPaymentList.firstWhere(
                  (item) => item.timesheet.staffId == staffId,
                  orElse: () => _masterPaymentList.first,
                ).timesheet.designation;

                double grossPay = 0;
                double wht = 0;
                double netPay = 0;

                final salaryScaleSnapshot = await FirebaseFirestore.instance
                    .collection('SalaryScales')
                    .where('designation', isEqualTo: designation)
                    .get();

                if (salaryScaleSnapshot.docs.isNotEmpty) {
                  final salaryData = salaryScaleSnapshot.docs.first.data();
                  final baseGrossPay = (salaryData['grossPay'] as num).toDouble();

                  // For September Part 2, we need to prorate the salary
                  DateTime fullStart = DateTime(currentYear, 9, 20);
                  DateTime fullEnd = DateTime(currentYear, 10, 19);
                  List<DateTime> fullDays = List.generate(fullEnd.difference(fullStart).inDays + 1, (i) => fullStart.add(Duration(days: i)));
                  int fullWorkingDays = fullDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                  double dailyGross = baseGrossPay / fullWorkingDays;
                  grossPay = dailyGross * sepWorkingDays;
                  wht = grossPay * 0.05; // 5% WHT
                  netPay = grossPay - wht;

                  debugPrint("Calculated pay for staff $staffId: gross=$grossPay, wht=$wht, net=$netPay");
                }

                // Cache the calculated September Part 2 data
                _septPart2DataCache[staffId] = {
                  'expectedHours': expectedHours,
                  'hoursWorked': totalHoursWorked,
                  'percentageWorked': percentageWorked,
                  'grossPay': grossPay,
                  'wht': wht,
                  'otherDeductions': 0,
                  'grossAfterDeductions': grossPay - wht,
                  'additions': 0,
                  'finalNetPay': netPay,
                };

                debugPrint("Successfully cached comprehensive September Part 2 data for staff $staffId");
                break; // Found data for this staff, move to next staff
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error in comprehensive search for staff $staffId: $e");
      }
    }

    debugPrint("Comprehensive search completed. Final cache size: ${_septPart2DataCache.length}");
  }

  // Fetch September Part 2 data from state-level collection (like the combine schedules functionality)
  Future<void> _fetchSeptPart2FromStateCollection(List<String> staffIds, int currentYear) async {
    debugPrint("=== FETCHING SEPTEMBER PART 2 FROM STATE COLLECTION ===");

    try {
      // Get unique states from the current payment list
      final Set<String> states = {};
      for (var item in _masterPaymentList) {
        states.add(item.timesheet.state);
      }

      debugPrint("Found ${states.length} unique states: $states");

      for (final stateId in states) {
        debugPrint("Searching in state: $stateId");

        final collectionName = "September_${currentYear}_part_2";
        final stateRef = FirebaseFirestore.instance.collection('states').doc(stateId);
        final schedulesRef = stateRef.collection(collectionName);

        debugPrint("Looking in collection: states/$stateId/$collectionName");

        final snapshot = await schedulesRef.get();
        debugPrint("Found ${snapshot.docs.length} documents in state collection");

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final staffId = data['staffId'] as String?;

          debugPrint("Document ${doc.id} has staffId: $staffId");

          if (staffId != null && staffIds.contains(staffId)) {
            debugPrint("Found September Part 2 data for staff $staffId in state collection");

            // Calculate expected hours for September Part 2 (Sep 20-30)
            DateTime sepStart = DateTime(currentYear, 9, 20);
            DateTime sepEnd = DateTime(currentYear, 9, 30);
            List<DateTime> sepDays = List.generate(sepEnd.difference(sepStart).inDays + 1, (i) => sepStart.add(Duration(days: i)));
            int sepWorkingDays = sepDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
            double expectedHours = sepWorkingDays * 8.0;

            // Calculate percentage worked
            double percentageWorked = expectedHours > 0 ? ((data['hoursWorked'] as num?)?.toDouble() ?? 0) / expectedHours * 100 : 0;
            if (percentageWorked > 100) percentageWorked = 100;

            // Get staff's salary scale to calculate pay
            final designation = data['designation'] as String?;

            double grossPay = 0;
            double wht = 0;
            double netPay = 0;

            if (designation != null) {
              final salaryScaleSnapshot = await FirebaseFirestore.instance
                  .collection('SalaryScales')
                  .where('designation', isEqualTo: designation)
                  .get();

              if (salaryScaleSnapshot.docs.isNotEmpty) {
                final salaryData = salaryScaleSnapshot.docs.first.data();
                final baseGrossPay = (salaryData['grossPay'] as num).toDouble();

                // For September Part 2, we need to prorate the salary
                DateTime fullStart = DateTime(currentYear, 9, 20);
                DateTime fullEnd = DateTime(currentYear, 10, 19);
                List<DateTime> fullDays = List.generate(fullEnd.difference(fullStart).inDays + 1, (i) => fullStart.add(Duration(days: i)));
                int fullWorkingDays = fullDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                double dailyGross = baseGrossPay / fullWorkingDays;
                grossPay = dailyGross * sepWorkingDays;
                wht = grossPay * 0.05; // 5% WHT
                netPay = grossPay - wht;

                debugPrint("Calculated pay for staff $staffId from state collection: gross=$grossPay, wht=$wht, net=$netPay");
              }
            }

            // Cache the calculated September Part 2 data
            _septPart2DataCache[staffId] = {
              'expectedHours': expectedHours,
              'hoursWorked': (data['hoursWorked'] as num?)?.toDouble() ?? 0,
              'percentageWorked': percentageWorked,
              'grossPay': grossPay,
              'wht': wht,
              'otherDeductions': (data['otherDeductions'] as num?)?.toDouble() ?? 0,
              'grossAfterDeductions': grossPay - wht,
              'additions': (data['additions'] as num?)?.toDouble() ?? 0,
              'finalNetPay': netPay,
            };

            debugPrint("Successfully cached state collection September Part 2 data for staff $staffId");
          }
        }
      }

      debugPrint("State collection search completed. Final cache size: ${_septPart2DataCache.length}");

    } catch (e) {
      debugPrint("Error fetching from state collection: $e");
    }
  }

  // --- LOGIC & HELPER FUNCTIONS ---


  void _showEditSalaryDialog(PaymentScheduleItem item) {
    final itemIndex = _masterPaymentList.indexOf(item);
    if (itemIndex == -1) return; // Safety check in case item is not found

    // Initialize controllers for all fields
    final formKey = GlobalKey<FormState>();
    final netController = TextEditingController(text: item.proratedNet.toStringAsFixed(2));
    final additionController = TextEditingController(text: item.additionAmount > 0 ? item.additionAmount.toStringAsFixed(2) : '');
    final additionReasonController = TextEditingController(text: item.additionReason ?? '');
    final deductionController = TextEditingController(text: item.deductionAmount > 0 ? item.deductionAmount.toStringAsFixed(2) : '');
    final deductionReasonController = TextEditingController(text: item.deductionReason ?? '');
    final daysWorkedController = TextEditingController(); // Controller for "Adjust by Days"

    // Initialize local state variables for the dialog
    bool isManualOverride = item.isEdited;
    bool isSaving = false;

    showDialog(
      context: context,
      // Using a builder to wrap the dialog with the blur effect
      builder: (BuildContext context) {
        // BackdropFilter applies a blur to the content behind the dialog
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: StatefulBuilder( // StatefulBuilder allows updating the dialog's UI independently
            builder: (context, setDialogState) {

              // --- Helper function for "Adjust by Days" logic ---
              void adjustByDays() {
                final days = int.tryParse(daysWorkedController.text);
                if (days == null || days <= 0) {
                  // Optionally show a small feedback message
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a valid number of days."), duration: Duration(seconds: 2))
                  );
                  return;
                }

                // --- FIX IS HERE ---
                // Determine the correct year and month before using them
                final int currentYear = _isReviewMode ? widget.scheduleModel!.year : widget.year!;
                final int currentMonth = _isReviewMode ? widget.scheduleModel!.month : widget.month!;

                // For Sep and Oct, use full period for calculation
                DateTime calcStartDate;
                DateTime calcEndDate;
                double originalNetPay;

                if (currentMonth == 9 || currentMonth == 10) {
                  // Full period: Sep 20 to Oct 19
                  calcStartDate = DateTime(currentYear, 9, 20);
                  calcEndDate = DateTime(currentYear, 10, 19);

                  // Calculate partial working days
                  DateTime partialStart = currentMonth == 9 ? DateTime(currentYear, 9, 20) : DateTime(currentYear, 10, 1);
                  DateTime partialEnd = currentMonth == 9 ? DateTime(currentYear, 9, 30) : DateTime(currentYear, 10, 19);
                  List<DateTime> partialDays = List.generate(partialEnd.difference(partialStart).inDays + 1, (i) => partialStart.add(Duration(days: i)));
                  int partialWorkingDays = partialDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                  // Calculate full working days
                  List<DateTime> fullDays = List.generate(calcEndDate.difference(calcStartDate).inDays + 1, (i) => calcStartDate.add(Duration(days: i)));
                  int fullWorkingDays = fullDays.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                  // Original gross pay
                  double originalGrossPay = item.baseSalary.grossPay / (partialWorkingDays / fullWorkingDays);
                  originalNetPay = originalGrossPay * 0.98;
                } else {
                  // Other months: 20th of previous to 19th of current
                  calcStartDate = DateTime(currentYear, currentMonth - 1, 20);
                  calcEndDate = DateTime(currentYear, currentMonth, 19);
                  originalNetPay = item.baseSalary.netPay;
                }

                final daysInRange = List.generate(calcEndDate.difference(calcStartDate).inDays + 1, (i) => calcStartDate.add(Duration(days: i)));
                final int totalWorkingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                if (totalWorkingDays > 0) {
                  final ratio = days / totalWorkingDays;
                  final newNet = originalNetPay * ratio;
                  netController.text = newNet.toStringAsFixed(2);

                  // When this feature is used, we assume it's a manual override of the system calculation.
                  isManualOverride = true;
                }
              }

              return AlertDialog(
                title: Text("Adjust Salary for ${item.timesheet.staffName}"),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display the system-calculated net pay for reference
                        Text(
                            "System-Calculated Net: ${_currencyFormat.format((item.baseSalary.netPay * item.percentageWorked / 100.0))}",
                            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)
                        ),
                        const Divider(height: 20),

                        // --- "Prorate by Days Worked" section ---
                        Text("Prorate by Days Worked", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: daysWorkedController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(labelText: "No. of Days", border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Use setDialogState to rebuild the dialog and show the new calculated value
                                setDialogState(adjustByDays);
                              },
                              child: const Text("Calculate"),
                            ),
                          ],
                        ),
                        const Divider(height: 30),

                        // --- "Additions / Bonuses" section ---
                        Text("Additions / Bonuses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: additionController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Addition Amount (₦)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                              return "Invalid number";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: additionReasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Reason for Addition (e.g., Bonus)",
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Divider(height: 30),

                        // --- "Salary Deduction" section ---
                        Text("Salary Deduction", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: deductionController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Deduction Amount (₦)",
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                              return "Invalid number";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: deductionReasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Reason for Deduction",
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const Divider(height: 30),

                        // --- "Manual Net Pay Override" section ---
                        CheckboxListTile(
                          title: const Text("Manual Net Pay Override", style: TextStyle(fontWeight: FontWeight.bold)),
                          value: isManualOverride,
                          onChanged: (val) {
                            setDialogState(() => isManualOverride = val ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        TextFormField(
                          controller: netController,
                          enabled: isManualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: "Final Net Pay (₦)",
                            border: const OutlineInputBorder(),
                            filled: !isManualOverride,
                            fillColor: Colors.grey[200],
                          ),
                          validator: (value) {
                            if (isManualOverride && (value == null || value.isEmpty || double.tryParse(value) == null)) {
                              return "Enter a valid net pay amount";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),

                  // --- Animated Save Button with Progress Indicator ---
                  isSaving
                      ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3.0, color: Color(0xFF722F37)),
                    ),
                  )
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF722F37),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        // Show the loading indicator
                        setDialogState(() { isSaving = true; });

                        // Simulate a brief delay to make the loader visible
                        await Future.delayed(const Duration(milliseconds: 700));

                        // Update the main page's state with the new values
                        setState(() {
                          final editedItem = _masterPaymentList[itemIndex];
                          editedItem.isEdited = isManualOverride;

                          editedItem.additionAmount = double.tryParse(additionController.text) ?? 0.0;
                          String additionReasonText = additionReasonController.text.trim();

                          // Add a comment if prorating by days
                          if (daysWorkedController.text.isNotEmpty && isManualOverride) {
                            String prorateComment = "Prorated for ${daysWorkedController.text} days.";
                            additionReasonText = additionReasonText.isEmpty ? prorateComment : "$additionReasonText; $prorateComment";
                          }
                          editedItem.additionReason = additionReasonText.isNotEmpty ? additionReasonText : null;

                          editedItem.deductionAmount = double.tryParse(deductionController.text) ?? 0.0;
                          editedItem.deductionReason = deductionReasonController.text.trim().isNotEmpty ? deductionReasonController.text.trim() : null;

                          if (isManualOverride) {
                            // If manual override is active, use the value from the netController
                            editedItem.proratedNet = double.tryParse(netController.text) ?? editedItem.proratedNet;
                          } else {
                            // Otherwise, recalculate based on system logic + adjustments
                            editedItem.calculateProratedSalary();
                          }

                          // Re-apply filters to refresh the UI with new calculated totals
                          _applyFilters();
                        });

                        // Close the dialog after saving is complete
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text("Save Adjustments"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }



  Future<void> _exportToExcel() async {
    if (_filteredPaymentList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("There is no data to export for the current filter.")),
        );
      }
      return;
    }
    setState(() => _isExporting = true);
    try {
      final excel = xls.Excel.createExcel();
      final String defaultSheetName = excel.sheets.keys.first;
      final xls.Sheet sheet = excel.sheets[defaultSheetName]!;

      // --- CHANGE: Renamed header ---
      const List<String> headers = [
        'S/No', 'Staff Name', 'Designation', 'State', 'SRT', 'Location',
        'Bank Name', 'Account Number', 'Sort Code',
        'Expected Hours', 'Hours Worked', '% Worked', 'Gross Pay (Base)',
        'Withholding Tax (WHT)', 'Other Deductions', 'Gross after Deductions',
        'Additions (Manual)', 'Final Net Pay', 'Comments', 'Is Manually Edited?'
      ];
      sheet.appendRow(headers.map((e) =>  xls.TextCellValue(e)).toList());

      // Style for header row
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell( xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle =  xls.CellStyle(
          bold: true,
          backgroundColorHex:  xls.ExcelColor.fromHexString("#722F37"),
          fontColorHex:  xls.ExcelColor.fromHexString("#FFFFFF"),
        );
      }
      for (int i = 0; i < _filteredPaymentList.length; i++) {
        final item = _filteredPaymentList[i];
        final bankInfo = _staffBankDetailsCache[item.timesheet.staffId] ?? StaffBankInfo();
        final List< xls.CellValue> rowData = [
          xls.IntCellValue(i + 1),
          xls.TextCellValue(item.timesheet.staffName),
          xls.TextCellValue(item.timesheet.designation),
          xls.TextCellValue(item.timesheet.state),
          xls.TextCellValue(item.srt ?? 'N/A'),
          xls.TextCellValue(item.timesheet.location),
          xls.TextCellValue(bankInfo.bankName),
          xls.TextCellValue(bankInfo.accountNumber),
          xls.TextCellValue(bankInfo.sortCode),
          xls.DoubleCellValue(item.expectedHours),
          xls.DoubleCellValue(item.actualHoursWorked),
          xls.TextCellValue('${item.percentageWorked.toStringAsFixed(1)}%'),
          xls.DoubleCellValue(item.baseSalary.grossPay),
          xls.DoubleCellValue(item.payeFromGrossBase),
          xls.DoubleCellValue(item.otherDeductionsAmount),
          xls.DoubleCellValue(item.grossAfterDeductions),
          xls.DoubleCellValue(item.additionAmount),
          xls.DoubleCellValue(item.proratedNet),
          xls.TextCellValue(item.comments),
          xls.TextCellValue(item.isEdited ? 'Yes' : 'No'),
        ];
        sheet.appendRow(rowData);
      }
      final fileBytes = excel.save();
      if (fileBytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = 'Payment_Schedule_${widget.month}_${widget.year}.xlsx';
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        } else {
          // Mobile platform - show message that download is not supported
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel download is only supported on web platform'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint("Error generating Excel file: $e\n$stack");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("An error occurred while generating the Excel file: $e"))
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _combineSepPart2AndOct() async {
    try {
      setState(() => _isLoading = true);

      // Get current year
      final currentYear = _isReviewMode ? widget.scheduleModel!.year : widget.year!;

      // Find September Part 2 and October schedules for the same state
      final currentState = _currentState;
      
      // First try to find October schedule in main collection
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('PaymentSchedules')
          .where('state', isEqualTo: currentState)
          .get();

      DocumentSnapshot? octSchedule;
      DocumentSnapshot? sepPart2Schedule;

      for (var doc in schedulesSnapshot.docs) {
        final docId = doc.id.toLowerCase();
        final data = doc.data();
        final status = data['status'] as String?;

        // Check for October
        if (docId.contains('october') || data['month'] == 10) {
          octSchedule = doc;
        }
      }

      // If October schedule found, fetch September Part 2 from sub-collection
      if (octSchedule != null) {
        final octData = octSchedule.data() as Map<String, dynamic>;
        final octStaffIds = List<String>.from(jsonDecode(octData['scheduleDataJson']).map((item) => item['staffId']));
        
        // Fetch September Part 2 from sub-collection for each staff
        final septPart2Data = await _fetchSeptPart2FromSubCollection(currentState, octStaffIds, currentYear);
        
        if (septPart2Data.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No September Part 2 data found in sub-collection.")),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Create side-by-side view
        await _createSideBySideView(octData, septPart2Data, currentYear);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("October schedule not found.")),
          );
        }
        setState(() => _isLoading = false);
      }

    } catch (e) {
      debugPrint("Error combining schedules: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error combining schedules: $e")),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSeptPart2FromSubCollection(
      String stateId, List<String> staffIds, int year) async {
    
    final collectionName = "September_${year}_part_2";
    final stateRef = FirebaseFirestore.instance.collection('states').doc(stateId);
    final schedulesRef = stateRef.collection(collectionName);
    
    final snapshot = await schedulesRef.get();
    final septPart2Data = <Map<String, dynamic>>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (staffIds.contains(data['staffId'])) {
        septPart2Data.add({
          'id': doc.id,
          'staffId': data['staffId'],
          'staffName': data['staffName'],
          'designation': data['designation'],
          'expectedHours': data['expectedHours'],
          'hoursWorked': data['hoursWorked'],
          'percentageWorked': data['percentageWorked'],
          'grossPay': data['grossPay'],
          'wht': data['wht'],
          'otherDeductions': data['otherDeductions'],
          'grossAfterDeductions': data['grossAfterDeductions'],
          'additions': data['additions'],
          'finalNetPay': data['finalNetPay'],
        });
      }
    }
    
    return septPart2Data;
  }

  Future<void> _createSideBySideView(
      Map<String, dynamic> octData,
      List<Map<String, dynamic>> septPart2Data,
      int year) async {
    
    // Fetch salary scales for processing
    final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
    final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

    // Process October data
    final List<dynamic> octJsonData = jsonDecode(octData['scheduleDataJson']);
    final octItems = octJsonData.map((itemJson) => PaymentScheduleItem.fromJson(itemJson as Map<String, dynamic>, salaryScales)).toList();

    // Create side-by-side data structure
    final sideBySideData = <Map<String, dynamic>>[];
    
    // Add header row
    sideBySideData.add({
      'type': 'header',
      'staffName': 'Staff Name',
      'designation': 'Designation',
      'septExpectedHours': 'Sept Expected Hours',
      'octExpectedHours': 'Oct Expected Hours',
      'septHoursWorked': 'Sept Hours Worked',
      'octHoursWorked': 'Oct Hours Worked',
      'septPercentageWorked': 'Sept % Worked',
      'octPercentageWorked': 'Oct % Worked',
      'septGrossPay': 'Sept Gross Pay',
      'octGrossPay': 'Oct Gross Pay',
      'septWHT': 'Sept WHT',
      'octWHT': 'Oct WHT',
      'septOtherDeductions': 'Sept Other Deductions',
      'octOtherDeductions': 'Oct Other Deductions',
      'septGrossAfterDeductions': 'Sept Gross After Deductions',
      'octGrossAfterDeductions': 'Oct Gross After Deductions',
      'septAdditions': 'Sept Additions',
      'octAdditions': 'Oct Additions',
      'septFinalNetPay': 'Sept Final Net Pay',
      'octFinalNetPay': 'Oct Final Net Pay',
    });

    // Add staff rows
    for (var octItem in octItems) {
      final septData = septPart2Data.firstWhere(
        (sept) => sept['staffId'] == octItem.timesheet.staffId,
        orElse: () => _createEmptySeptData(),
      );

      sideBySideData.add({
        'type': 'staff',
        'staffName': octItem.timesheet.staffName,
        'designation': octItem.timesheet.designation,
        'septExpectedHours': septData['expectedHours'],
        'octExpectedHours': octItem.expectedHours,
        'septHoursWorked': septData['hoursWorked'],
        'octHoursWorked': octItem.actualHoursWorked,
        'septPercentageWorked': '${septData['percentageWorked']}%',
        'octPercentageWorked': '${octItem.percentageWorked.toStringAsFixed(1)}%',
        'septGrossPay': '\$${septData['grossPay'].toStringAsFixed(2)}',
        'octGrossPay': '\$${octItem.baseSalary.grossPay.toStringAsFixed(2)}',
        'septWHT': '\$${septData['wht'].toStringAsFixed(2)}',
        'octWHT': '\$${octItem.payeFromGrossBase.toStringAsFixed(2)}',
        'septOtherDeductions': '\$${septData['otherDeductions'].toStringAsFixed(2)}',
        'octOtherDeductions': '\$${octItem.otherDeductionsAmount.toStringAsFixed(2)}',
        'septGrossAfterDeductions': '\$${septData['grossAfterDeductions'].toStringAsFixed(2)}',
        'octGrossAfterDeductions': '\$${octItem.grossAfterDeductions.toStringAsFixed(2)}',
        'septAdditions': '\$${septData['additions'].toStringAsFixed(2)}',
        'octAdditions': '\$${octItem.additionAmount.toStringAsFixed(2)}',
        'septFinalNetPay': '\$${septData['finalNetPay'].toStringAsFixed(2)}',
        'octFinalNetPay': '\$${octItem.proratedNet.toStringAsFixed(2)}',
      });
    }

    // Add totals row
    sideBySideData.add({
      'type': 'total',
      'staffName': 'TOTAL',
      'designation': '',
      'septExpectedHours': _calculateTotal(septPart2Data, 'expectedHours'),
      'octExpectedHours': _calculateTotal(octItems, 'expectedHours'),
      'septHoursWorked': _calculateTotal(septPart2Data, 'hoursWorked'),
      'octHoursWorked': _calculateTotal(octItems, 'actualHoursWorked'),
      'septPercentageWorked': '100%',
      'octPercentageWorked': '100%',
      'septGrossPay': _calculateTotal(septPart2Data, 'grossPay'),
      'octGrossPay': _calculateTotal(octItems, 'baseSalary.grossPay'),
      'septWHT': _calculateTotal(septPart2Data, 'wht'),
      'octWHT': _calculateTotal(octItems, 'payeFromGrossBase'),
      'septOtherDeductions': _calculateTotal(septPart2Data, 'otherDeductions'),
      'octOtherDeductions': _calculateTotal(octItems, 'otherDeductionsAmount'),
      'septGrossAfterDeductions': _calculateTotal(septPart2Data, 'grossAfterDeductions'),
      'octGrossAfterDeductions': _calculateTotal(octItems, 'grossAfterDeductions'),
      'septAdditions': _calculateTotal(septPart2Data, 'additions'),
      'octAdditions': _calculateTotal(octItems, 'additionAmount'),
      'septFinalNetPay': _calculateTotal(septPart2Data, 'finalNetPay'),
      'octFinalNetPay': _calculateTotal(octItems, 'proratedNet'),
    });

    // Update the UI to show side-by-side view
    setState(() {
      _masterPaymentList = []; // Clear current payment list
      _isCombinedView = true;
      _isLoading = false;
    });

    // Show the side-by-side table
    if (mounted) {
      _showSideBySideDialog(sideBySideData, year);
    }
  }


  String _calculateTotal(List<dynamic> data, String field) {
    if (data.isEmpty) return '\$0.00';
    
    double total = 0;
    if (data.first is Map<String, dynamic>) {
      // For septPart2Data
      total = data.fold(0, (sum, item) => sum + (item[field] as num).toDouble());
    } else {
      // For octItems (PaymentScheduleItem)
      total = data.fold(0, (sum, item) {
        if (field == 'expectedHours') return sum + item.expectedHours;
        if (field == 'actualHoursWorked') return sum + item.actualHoursWorked;
        if (field == 'baseSalary.grossPay') return sum + item.baseSalary.grossPay;
        if (field == 'payeFromGrossBase') return sum + item.payeFromGrossBase;
        if (field == 'otherDeductionsAmount') return sum + item.otherDeductionsAmount;
        if (field == 'grossAfterDeductions') return sum + item.grossAfterDeductions;
        if (field == 'additionAmount') return sum + item.additionAmount;
        if (field == 'proratedNet') return sum + item.proratedNet;
        return sum;
      });
    }
    
    return '\$${total.toStringAsFixed(2)}';
  }

  void _showSideBySideDialog(List<Map<String, dynamic>> data, int year) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Combined Payment Schedule - September Part 2 + October $year'),
        content: SizedBox(
          width: 1200,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text('Staff Name')),
                DataColumn(label: Text('Designation')),
                DataColumn(label: Text('Sept Expected Hours')),
                DataColumn(label: Text('Oct Expected Hours')),
                DataColumn(label: Text('Sept Hours Worked')),
                DataColumn(label: Text('Oct Hours Worked')),
                DataColumn(label: Text('Sept % Worked')),
                DataColumn(label: Text('Oct % Worked')),
                DataColumn(label: Text('Sept Gross Pay')),
                DataColumn(label: Text('Oct Gross Pay')),
                DataColumn(label: Text('Sept WHT')),
                DataColumn(label: Text('Oct WHT')),
                DataColumn(label: Text('Sept Other Deductions')),
                DataColumn(label: Text('Oct Other Deductions')),
                DataColumn(label: Text('Sept Gross After Deductions')),
                DataColumn(label: Text('Oct Gross After Deductions')),
                DataColumn(label: Text('Sept Additions')),
                DataColumn(label: Text('Oct Additions')),
                DataColumn(label: Text('Sept Final Net Pay')),
                DataColumn(label: Text('Oct Final Net Pay')),
              ],
              rows: data.map((row) {
                if (row['type'] == 'header') {
                  return DataRow(
                    color: WidgetStateProperty.all(Colors.grey[300]),
                    cells: [
                      DataCell(Text(row['staffName']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['designation']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septExpectedHours']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octExpectedHours']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septHoursWorked']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octHoursWorked']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septPercentageWorked']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octPercentageWorked']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septGrossPay']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octGrossPay']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septWHT']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octWHT']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septOtherDeductions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octOtherDeductions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septGrossAfterDeductions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octGrossAfterDeductions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septAdditions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octAdditions']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['septFinalNetPay']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['octFinalNetPay']!, style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  );
                } else if (row['type'] == 'total') {
                  return DataRow(
                    color: WidgetStateProperty.all(Colors.grey[200]),
                    cells: [
                      DataCell(Text(row['staffName']!, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(row['designation']!)),
                      DataCell(Text(row['septExpectedHours']!)),
                      DataCell(Text(row['octExpectedHours']!)),
                      DataCell(Text(row['septHoursWorked']!)),
                      DataCell(Text(row['octHoursWorked']!)),
                      DataCell(Text(row['septPercentageWorked']!)),
                      DataCell(Text(row['octPercentageWorked']!)),
                      DataCell(Text(row['septGrossPay']!)),
                      DataCell(Text(row['octGrossPay']!)),
                      DataCell(Text(row['septWHT']!)),
                      DataCell(Text(row['octWHT']!)),
                      DataCell(Text(row['septOtherDeductions']!)),
                      DataCell(Text(row['octOtherDeductions']!)),
                      DataCell(Text(row['septGrossAfterDeductions']!)),
                      DataCell(Text(row['octGrossAfterDeductions']!)),
                      DataCell(Text(row['septAdditions']!)),
                      DataCell(Text(row['octAdditions']!)),
                      DataCell(Text(row['septFinalNetPay']!)),
                      DataCell(Text(row['octFinalNetPay']!)),
                    ],
                  );
                } else {
                  return DataRow(cells: [
                    DataCell(Text(row['staffName']!)),
                    DataCell(Text(row['designation']!)),
                    DataCell(Text(row['septExpectedHours'].toString())),
                    DataCell(Text(row['octExpectedHours'].toString())),
                    DataCell(Text(row['septHoursWorked'].toString())),
                    DataCell(Text(row['octHoursWorked'].toString())),
                    DataCell(Text(row['septPercentageWorked'].toString())),
                    DataCell(Text(row['octPercentageWorked'].toString())),
                    DataCell(Text(row['septGrossPay'].toString())),
                    DataCell(Text(row['octGrossPay'].toString())),
                    DataCell(Text(row['septWHT'].toString())),
                    DataCell(Text(row['octWHT'].toString())),
                    DataCell(Text(row['septOtherDeductions'].toString())),
                    DataCell(Text(row['octOtherDeductions'].toString())),
                    DataCell(Text(row['septGrossAfterDeductions'].toString())),
                    DataCell(Text(row['octGrossAfterDeductions'].toString())),
                    DataCell(Text(row['septAdditions'].toString())),
                    DataCell(Text(row['octAdditions'].toString())),
                    DataCell(Text(row['septFinalNetPay'].toString())),
                    DataCell(Text(row['octFinalNetPay'].toString())),
                  ]);
                }
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportSideBySideToExcel(data, year);
            },
            child: Text('Export to Excel'),
          ),
        ],
      ),
    );
  }

  void _exportSideBySideToExcel(List<Map<String, dynamic>> data, int year) async {
    try {
      final excel = xls.Excel.createExcel();
      final String defaultSheetName = excel.sheets.keys.first;
      final xls.Sheet sheet = excel.sheets[defaultSheetName]!;

      // Add headers
      sheet.appendRow([
        xls.TextCellValue('Staff Name'),
        xls.TextCellValue('Designation'),
        xls.TextCellValue('Sept Expected Hours'),
        xls.TextCellValue('Oct Expected Hours'),
        xls.TextCellValue('Sept Hours Worked'),
        xls.TextCellValue('Oct Hours Worked'),
        xls.TextCellValue('Sept % Worked'),
        xls.TextCellValue('Oct % Worked'),
        xls.TextCellValue('Sept Gross Pay'),
        xls.TextCellValue('Oct Gross Pay'),
        xls.TextCellValue('Sept WHT'),
        xls.TextCellValue('Oct WHT'),
        xls.TextCellValue('Sept Other Deductions'),
        xls.TextCellValue('Oct Other Deductions'),
        xls.TextCellValue('Sept Gross After Deductions'),
        xls.TextCellValue('Oct Gross After Deductions'),
        xls.TextCellValue('Sept Additions'),
        xls.TextCellValue('Oct Additions'),
        xls.TextCellValue('Sept Final Net Pay'),
        xls.TextCellValue('Oct Final Net Pay'),
      ]);

      // Style for header row
      for (var i = 0; i < 20; i++) {
        var cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = xls.CellStyle(
          bold: true,
          backgroundColorHex: xls.ExcelColor.fromHexString("#722F37"),
          fontColorHex: xls.ExcelColor.fromHexString("#FFFFFF"),
        );
      }

      // Add data rows
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        if (row['type'] == 'header' || row['type'] == 'total') continue; // Skip header and total rows for now

        sheet.appendRow([
          xls.TextCellValue(row['staffName'].toString()),
          xls.TextCellValue(row['designation'].toString()),
          xls.TextCellValue(row['septExpectedHours'].toString()),
          xls.TextCellValue(row['octExpectedHours'].toString()),
          xls.TextCellValue(row['septHoursWorked'].toString()),
          xls.TextCellValue(row['octHoursWorked'].toString()),
          xls.TextCellValue(row['septPercentageWorked'].toString()),
          xls.TextCellValue(row['octPercentageWorked'].toString()),
          xls.TextCellValue(row['septGrossPay'].toString()),
          xls.TextCellValue(row['octGrossPay'].toString()),
          xls.TextCellValue(row['septWHT'].toString()),
          xls.TextCellValue(row['octWHT'].toString()),
          xls.TextCellValue(row['septOtherDeductions'].toString()),
          xls.TextCellValue(row['octOtherDeductions'].toString()),
          xls.TextCellValue(row['septGrossAfterDeductions'].toString()),
          xls.TextCellValue(row['octGrossAfterDeductions'].toString()),
          xls.TextCellValue(row['septAdditions'].toString()),
          xls.TextCellValue(row['octAdditions'].toString()),
          xls.TextCellValue(row['septFinalNetPay'].toString()),
          xls.TextCellValue(row['octFinalNetPay'].toString()),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = 'Combined_Payment_Schedule_Sep2_Oct_$year.xlsx';
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Combined schedule exported successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Error exporting side-by-side data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting: $e")),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _combineSchedules(List<DocumentSnapshot> schedules) async {
    try {
      // Validate that we have September Part 2 and October
      final schedule1 = schedules[0].data() as Map<String, dynamic>;
      final schedule2 = schedules[1].data() as Map<String, dynamic>;

      final month1 = schedule1['month'] as int?;
      final month2 = schedule2['month'] as int?;
      final year1 = schedule1['year'] as int?;
      final year2 = schedule2['year'] as int?;

      bool isValidCombination = false;
      if ((month1 == 9 && month2 == 10) || (month1 == 10 && month2 == 9)) {
        isValidCombination = true;
      }

      if (!isValidCombination) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Can only combine September Part 2 and October schedules.")),
          );
        }
        return;
      }

      setState(() => _isLoading = true);

      // Fetch salary scales
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

      // Fetch SRT assignments
      final srtSnapshot = await FirebaseFirestore.instance.collection('SRTAssignments').get();
      final Map<String, String> srtMap = {};
      for (var doc in srtSnapshot.docs) {
        final data = doc.data();
        final key = '${data['state']}-${data['location']}';
        srtMap[key] = data['srt'] ?? 'N/A';
      }

      // Combine the schedules
      final List<dynamic> jsonData1 = jsonDecode(schedule1['scheduleDataJson']);
      final List<dynamic> jsonData2 = jsonDecode(schedule2['scheduleDataJson']);

      final Map<String, PaymentScheduleItem> combinedItems = {};

      // Process first schedule
      for (var itemJson in jsonData1) {
        final item = PaymentScheduleItem.fromJson(itemJson as Map<String, dynamic>, salaryScales);
        final key = '${item.timesheet.staffId}-${item.timesheet.designation}';
        combinedItems[key] = item;
      }

      // Process second schedule and merge
      for (var itemJson in jsonData2) {
        final item = PaymentScheduleItem.fromJson(itemJson as Map<String, dynamic>, salaryScales);
        final key = '${item.timesheet.staffId}-${item.timesheet.designation}';

        if (combinedItems.containsKey(key)) {
          // Merge the items
          final existingItem = combinedItems[key]!;
          existingItem.actualHoursWorked += item.actualHoursWorked;
          existingItem.additionAmount += item.additionAmount;
          existingItem.deductionAmount += item.deductionAmount;
          existingItem.calculateProratedSalary();
        } else {
          combinedItems[key] = item;
        }
      }

      // Update the current payment list with combined data
      final combinedList = combinedItems.values.toList();
      combinedList.sort((a, b) => a.timesheet.staffName.compareTo(b.timesheet.staffName));

      setState(() {
        _masterPaymentList = combinedList;
        _filteredPaymentList = combinedList;
        _isCombinedView = true;
        _isLoading = false;
      });

      _paginateData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Combined ${combinedList.length} staff records from the selected schedules.")),
        );
      }

    } catch (e) {
      debugPrint("Error combining schedules: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error combining schedules: $e")),
        );
      }
    }
  }
}

// ADD THIS ENTIRE WIDGET CLASS AT THE BOTTOM OF payment_schedule_page.dart

class MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> allOptions;
  final List<String> initialSelectedOptions;
  final String allText;

  const MultiSelectDialog({
    super.key,
    required this.title,
    required this.allOptions,
    required this.initialSelectedOptions,
    required this.allText,
  });

  @override
  _MultiSelectDialogState createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _tempSelectedOptions;

  @override
  void initState() {
    super.initState();
    _tempSelectedOptions = List.from(widget.initialSelectedOptions);
  }

  void _onAllChanged(bool? value) {
    setState(() {
      if (value == true) {
        _tempSelectedOptions = [widget.allText];
      } else {
        _tempSelectedOptions.clear();
      }
    });
  }

  void _onItemChanged(bool? value, String item) {
    setState(() {
      _tempSelectedOptions.remove(widget.allText); // De-select "All"
      if (value == true) {
        _tempSelectedOptions.add(item);
      } else {
        _tempSelectedOptions.remove(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllSelected = _tempSelectedOptions.contains(widget.allText) || (_tempSelectedOptions.length == widget.allOptions.where((o) => o != widget.allText).length);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(widget.allText, style: const TextStyle(fontWeight: FontWeight.bold)),
              value: isAllSelected,
              onChanged: _onAllChanged,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allOptions.where((o) => o != widget.allText).length,
                itemBuilder: (context, index) {
                  final option = widget.allOptions.where((o) => o != widget.allText).toList()[index];
                  return CheckboxListTile(
                    title: Text(option),
                    value: _tempSelectedOptions.contains(option),
                    onChanged: (bool? value) => _onItemChanged(value, option),
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
            // If nothing is selected, default to "All"
            if (_tempSelectedOptions.isEmpty) {
              _tempSelectedOptions.add(widget.allText);
            }
            // If all individual items are selected, simplify to just "All"
            if (_tempSelectedOptions.length == widget.allOptions.where((o) => o != widget.allText).length) {
              _tempSelectedOptions = [widget.allText];
            }
            Navigator.pop(context, _tempSelectedOptions);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}