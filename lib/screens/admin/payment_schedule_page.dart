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

  PaymentScheduleItem({ required this.timesheet, required this.baseSalary, required this.expectedHours,})
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

    // --- CHANGE: Updated from 5% (0.05) to 2% (0.02) ---
    payeFromGrossBase = baseSalary.grossPay * 0.02;

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
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

      final List<dynamic> jsonData = jsonDecode(widget.scheduleModel!.scheduleDataJson);
      final List<PaymentScheduleItem> items = jsonData.map((itemJson) {
        return PaymentScheduleItem.fromJson(itemJson as Map<String, dynamic>, salaryScales);
      }).toList();

      final List<String> staffIds = items.map((item) => item.timesheet.staffId).toList();
      await _fetchStaffBankDetails(staffIds);
      _setupFilters(items);

      setState(() {
        _masterPaymentList = items;
        _filteredPaymentList = items;
        _isLoading = false;
      });
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
      // 1. Fetch Salary Scales
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = { for (var doc in scaleSnapshot.docs) (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc) };

      // 2. Calculate Expected Hours for the Month
      final startDate = DateTime(widget.year!, widget.month! - 1, 20);
      final endDate = DateTime(widget.year!, widget.month!, 19);
      final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));

      // Calculate working days to determine total expected hours.
      final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
      final double totalExpectedHours = (workingDays * 8.0);

      final List<PaymentScheduleItem> items = [];

      // 3. Loop through timesheets to build payment items
      for (final timesheet in widget.timesheets!) {
        final salary = salaryScales[timesheet.designation.trim()];
        if (salary != null) {
          // The new constructor now handles ALL calculations, including deductions from timesheet entries.
          final paymentItem = PaymentScheduleItem(
            timesheet: timesheet,
            baseSalary: salary,
            expectedHours: totalExpectedHours,
          );
          items.add(paymentItem);
        } else {
          debugPrint("Warning: No salary scale found for designation: '${timesheet.designation}' for staff ${timesheet.staffName}");
        }
      }

      // 4. Fetch bank details and finalize the list
      final List<String> staffIds = widget.timesheets!.map((ts) => ts.staffId).toList();
      await _fetchStaffBankDetails(staffIds);
      items.sort((a, b) => a.timesheet.staffName.compareTo(b.timesheet.staffName));
      _setupFilters(items);

      setState(() {
        _masterPaymentList = items;
        _filteredPaymentList = items;
        _isLoading = false;
      });
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
    final double totalNetPayroll = _filteredPaymentList.fold(0.0, (sum, item) => sum + item.proratedNet);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Payment Schedule - $monthName $year", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isExporting) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else IconButton(icon: const Icon(Icons.download_rounded), tooltip: "Export to Excel", onPressed: _masterPaymentList.isEmpty ? null : _exportToExcel),
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
              columns: const [
                DataColumn(label: Text('S/No')), DataColumn(label: Text('Staff Name')), DataColumn(label: Text('Designation')),
                DataColumn(label: Text('State')), DataColumn(label: Text('Bank Name')), DataColumn(label: Text('Account Number')),
                DataColumn(label: Text('Sort Code')), DataColumn(label: Text('Expected Hrs'), numeric: true),
                DataColumn(label: Text('Hrs Worked'), numeric: true), DataColumn(label: Text('% Worked'), numeric: true),
                DataColumn(label: Text('Gross Pay (Base)'), numeric: true),
                // --- CHANGE: Renamed column header ---
                DataColumn(label: Text('Withholding Tax (WHT)'), numeric: true),
                DataColumn(label: Text('Other Deductions'), numeric: true),
                DataColumn(label: Text('Gross after Deductions'), numeric: true),
                DataColumn(label: Text('Additions'), numeric: true),
                DataColumn(label: Text('Final Net Pay'), numeric: true),
                DataColumn(label: Text('Comments')),
                DataColumn(label: Text('Action')),
              ],
              rows: _paginatedList.asMap().entries.map((entry) {
                int index = (_currentPage * _rowsPerPage) + entry.key;
                PaymentScheduleItem item = entry.value;

                final bankInfo = _staffBankDetailsCache[item.timesheet.staffId] ?? StaffBankInfo();

                double deductedPercentage = (item.expectedHours > 0) ? (item.totalDeductedHoursFromTimesheet / item.expectedHours * 100) : 0;
                String deductionText = item.otherDeductionsAmount > 0
                    ? "${_currencyFormat.format(item.otherDeductionsAmount)}\n(-${deductedPercentage.toStringAsFixed(1)}%)"
                    : _currencyFormat.format(0);

                return DataRow(
                  cells: [
                    DataCell(Text((index + 1).toString())),
                    DataCell(Row(children: [
                      if (item.additionAmount > 0) Tooltip(message: "Addition: ${item.additionReason ?? ''}", child: Icon(Icons.arrow_upward, size: 14, color: Colors.green.shade700)),
                      if (item.deductionAmount > 0) Tooltip(message: "Deduction: ${item.deductionReason ?? ''}", child: Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade700)),
                      if (item.isEdited) const Tooltip(message: 'Manually Edited', child: Icon(Icons.push_pin, size: 14, color: Colors.orange)),
                      if (item.additionAmount > 0 || item.deductionAmount > 0 || item.isEdited) const SizedBox(width: 4),
                      Text(item.timesheet.staffName),
                    ])),
                    DataCell(SizedBox(width: 200, child: Text(item.timesheet.designation, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(item.timesheet.state)), DataCell(SizedBox(width: 150, child: Text(bankInfo.bankName, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(bankInfo.accountNumber)), DataCell(Text(bankInfo.sortCode)),
                    DataCell(Text(item.expectedHours.toStringAsFixed(2))), DataCell(Text(item.actualHoursWorked.toStringAsFixed(2))),
                    DataCell(_buildPercentageChip(item.percentageWorked)), DataCell(Text(_currencyFormat.format(item.baseSalary.grossPay))),
                    DataCell(Text(_currencyFormat.format(item.payeFromGrossBase))),
                    DataCell(Text(deductionText, style: TextStyle(color: item.otherDeductionsAmount > 0 ? Colors.red.shade700 : Colors.grey), textAlign: TextAlign.right)),
                    DataCell(Text(_currencyFormat.format(item.grossAfterDeductions))),
                    DataCell(Text(_currencyFormat.format(item.additionAmount), style: TextStyle(color: item.additionAmount > 0 ? Colors.green.shade700 : Colors.grey))),
                    DataCell(Text(_currencyFormat.format(item.proratedNet), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(SizedBox(width: 250, child: Text(item.comments, overflow: TextOverflow.ellipsis))),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit_note, size: 20),
                      color: _isReviewMode ? Colors.grey : Colors.blueAccent,
                      onPressed: _isReviewMode ? null : () => _showEditSalaryDialog(item),
                      tooltip: _isReviewMode ? 'Schedule Submitted (Read-only)' : 'Adjust Salary',
                    )),
                  ],
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

                // Recalculate the number of working days in the month using the non-nullable variables
                final startDate = DateTime(currentYear, currentMonth - 1, 20);
                final endDate = DateTime(currentYear, currentMonth, 19);
                // --- END OF FIX ---
                final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));
                final int totalWorkingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;

                if (totalWorkingDays > 0) {
                  final ratio = days / totalWorkingDays;
                  final newNet = item.baseSalary.netPay * ratio;
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
        'S/No', 'Staff Name', 'Designation', 'State', 'Location',
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