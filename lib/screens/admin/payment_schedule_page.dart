// lib/pages/admin/payment_schedule_page.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xls hide TextSpan;
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'dart:ui';
import '../timesheet/hq_timesheet_review_page.dart';
import 'salary_scale_page.dart';

// Model to hold all data for one row in the payment table

// 1. Add a new data model for Staff Bank Info
class StaffBankInfo {
  final String bankName;
  final String accountNumber;
  final String sortCode;
  StaffBankInfo({this.bankName = '', this.accountNumber = '', this.sortCode = ''});
}

class PaymentScheduleItem {
  final TimesheetModel timesheet;
  final SalaryScale baseSalary;
  final double expectedHours;

  double actualHoursWorked; // To store the original hours from timesheet
  double hoursUsedForCalc; // Capped hours for calculation
  double percentageWorked;
  double proratedGross;
  double proratedBasic;
  double proratedHousing;
  double proratedTransport;
  double proratedMeal;
  double proratedUtility;
  double proratedPaye;
  double proratedNet;
  bool isEdited = false;

  // --- ADD THESE NEW FIELDS ---
  double deductionAmount = 0.0;
  String? deductionReason;
  double additionAmount = 0.0;
  String? additionReason;
  // --- END OF ADDITION ---

  PaymentScheduleItem({
    required this.timesheet,
    required this.baseSalary,
    required this.expectedHours,
  })  : percentageWorked = 0, proratedGross = 0, proratedBasic = 0, actualHoursWorked = 0,
        proratedHousing = 0, proratedTransport = 0, proratedMeal = 0,hoursUsedForCalc = 0,
        proratedUtility = 0, proratedPaye = 0, proratedNet = 0 {
    // --- Store actual hours from the timesheet ---
    actualHoursWorked = timesheet.totalHours;
    calculateProratedSalary();
  }

  void calculateProratedSalary() {
    // --- Cap the hours worked at the expected hours ---
    hoursUsedForCalc = (actualHoursWorked > expectedHours) ? expectedHours : actualHoursWorked;
    // Calculate percentage based on the CAPPED hours
    double rawPercentage = (expectedHours > 0) ? (hoursUsedForCalc / expectedHours * 100) : 0.0;
    percentageWorked = rawPercentage > 100.0 ? 100.0 : rawPercentage;

    final ratio = percentageWorked / 100.0;

    if (!isEdited) {
      proratedGross = (baseSalary.grossPay * ratio) + additionAmount;
      proratedBasic = baseSalary.basic * ratio;
      proratedHousing = baseSalary.housing * ratio;
      proratedTransport = baseSalary.transport * ratio;
      proratedMeal = baseSalary.meal * ratio;
      proratedUtility = baseSalary.utility * ratio;
      proratedPaye = baseSalary.paye * ratio;
    }

    proratedNet = (baseSalary.netPay * ratio) + additionAmount - deductionAmount;
    if (proratedNet < 0) proratedNet = 0;
  }
}



class PaymentSchedulePage extends StatefulWidget {
  final List<TimesheetModel> timesheets;
  final int year;
  final int month;

  const PaymentSchedulePage({
    Key? key,
    required this.timesheets,
    required this.year,
    required this.month,
  }) : super(key: key);

  @override
  _PaymentSchedulePageState createState() => _PaymentSchedulePageState();
}

class _PaymentSchedulePageState extends State<PaymentSchedulePage> {
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isFiltering = false;

  // Data stores
  List<PaymentScheduleItem> _masterPaymentList = [];
  List<PaymentScheduleItem> _filteredPaymentList = [];
  Map<String, StaffBankInfo> _staffBankDetailsCache = {};

  // Filter options
  List<String> _availableStates = ['All States'];
  List<String> _availableDesignations = ['All Designations'];
  List<String> _selectedStates = ['All States'];
  List<String> _selectedDesignations = ['All Designations'];
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');

  @override
  void initState() {
    super.initState();
    _preparePaymentData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preparePaymentData() async {
    setState(() => _isLoading = true);

    try {
      final scaleSnapshot = await FirebaseFirestore.instance.collection('SalaryScales').get();
      final salaryScales = {
        for (var doc in scaleSnapshot.docs)
          (doc.data()['designation'] as String): SalaryScale.fromFirestore(doc)
      };

      final startDate = DateTime(widget.year, widget.month - 1, 20);
      final endDate = DateTime(widget.year, widget.month, 19);
      final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));
      final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
      final double totalExpectedHours = (workingDays * 8.0);

      final List<PaymentScheduleItem> items = [];
      final Set<String> states = {};
      final Set<String> designations = {};

      for (final timesheet in widget.timesheets) {
        final salary = salaryScales[timesheet.designation.trim()];

        if (salary != null) {
          items.add(PaymentScheduleItem(
            timesheet: timesheet,
            baseSalary: salary,
            expectedHours: totalExpectedHours,
          ));
          states.add(timesheet.state);
          designations.add(timesheet.designation);
        } else {
          debugPrint("Warning: No salary scale found for designation: '${timesheet.designation}' for staff ${timesheet.staffName}");
        }
      }
      final List<String> staffIds = widget.timesheets.map((ts) => ts.staffId).toList();
      await _fetchStaffBankDetails(staffIds);

      items.sort((a,b) => a.timesheet.staffName.compareTo(b.timesheet.staffName));

      setState(() {
        _masterPaymentList = items;
        _filteredPaymentList = items;
        _availableStates.addAll(states.toList()..sort());
        _availableDesignations.addAll(designations.toList()..sort());
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error preparing payment data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
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
    setState(() => _isFiltering = true);
    await Future.delayed(const Duration(milliseconds: 300));

    List<PaymentScheduleItem> filtered = List.from(_masterPaymentList);
    final String searchQuery = _searchController.text.toLowerCase();

    // Handle Search by Name filter (highest priority)
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) => item.timesheet.staffName.toLowerCase().contains(searchQuery)).toList();
    }

    // Handle State filter
    if (!_selectedStates.contains('All States')) {
      final selectionSet = _selectedStates.toSet();
      filtered = filtered.where((item) => selectionSet.contains(item.timesheet.state)).toList();
    }

    // Handle Designation filter
    if (!_selectedDesignations.contains('All Designations')) {
      final selectionSet = _selectedDesignations.toSet();
      filtered = filtered.where((item) => selectionSet.contains(item.timesheet.designation)).toList();
    }

    setState(() {
      _filteredPaymentList = filtered;
      _isFiltering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(DateTime(0, widget.month));
    final double totalNetPayroll = _filteredPaymentList.fold(0.0, (sum, item) => sum + item.proratedNet);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Payment Schedule - $monthName ${widget.year}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4.0,
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: "Export to Excel",
              onPressed: _masterPaymentList.isEmpty ? null : _exportToExcel,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _masterPaymentList.isEmpty
          ? _buildEmptyState("No matching salary data found", "Please ensure staff designations have a corresponding entry in the 'Manage Salary Scales' page.")
          : Column(
        children: [
          _buildFilterBar(),
          _buildKpiHeader(totalNetPayroll),
          if (!_isLoading && _filteredPaymentList.isNotEmpty)
            _buildChartsSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _filteredPaymentList.isEmpty && !_isFiltering // Don't show empty state while filtering
                  ? _buildEmptyState("No Staff Found", "No staff match the current filter criteria.")
              // --- NEW: Wrap the card in a Stack to overlay the loader ---
                  : Stack(
                alignment: Alignment.center,
                children: [
                  // The data table, which becomes slightly transparent while loading
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isFiltering ? 0.5 : 1.0,
                    child: _buildDataTableCard(),
                  ),

                  // The animated loader, which appears and disappears
                  if (_isFiltering)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF722F37),
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
      value: value,
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
          // --- Header with scroll controls ---
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

          // --- Fully Scrollable Data Table Implementation ---
          Expanded(
            child: SingleChildScrollView( // Vertical scroll for the entire table
              child: SingleChildScrollView( // Horizontal scroll for the entire table
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // The header and rows will now scroll together
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('S/No')),
                    DataColumn(label: Text('Staff Name')),
                    DataColumn(label: Text('Designation')),
                    DataColumn(label: Text('State')),
                    DataColumn(label: Text('Bank Name')),
                    DataColumn(label: Text('Account Number')),
                    DataColumn(label: Text('Sort Code')),
                    DataColumn(label: Text('Expected Hrs'), numeric: true),
                    DataColumn(label: Text('Hrs Worked'), numeric: true),
                    DataColumn(label: Text('% Worked'), numeric: true),
                    DataColumn(label: Text('Gross Pay (Base)'), numeric: true), // <-- ADDED COLUMN
                    DataColumn(label: Text('Prorated Gross'), numeric: true),
                    DataColumn(label: Text('Additions'), numeric: true),
                    DataColumn(label: Text('Deductions'), numeric: true),
                    DataColumn(label: Text('Comments')),
                    DataColumn(label: Text('Final Net Pay'), numeric: true),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _filteredPaymentList.asMap().entries.map((entry) {
                    int index = entry.key;
                    PaymentScheduleItem item = entry.value;
                    // --- NEW: Get bank info from cache ---
                    final bankInfo = _staffBankDetailsCache[item.timesheet.staffId] ?? StaffBankInfo();
                    String comment = [item.additionReason, item.deductionReason]
                        .where((s) => s != null && s.isNotEmpty)
                        .join('; ');

                    return DataRow(
                      cells: [
                        DataCell(Text((index + 1).toString())),
                        DataCell(
                          Row(
                            children: [
                              if (item.additionAmount > 0)
                                Tooltip(message: "Addition: ${item.additionReason ?? ''}", child: Icon(Icons.arrow_upward, size: 14, color: Colors.green.shade700)),
                              if (item.deductionAmount > 0)
                                Tooltip(message: "Deduction: ${item.deductionReason ?? ''}", child: Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade700)),
                              if (item.isEdited && item.additionAmount == 0 && item.deductionAmount == 0)
                                const Tooltip(message: 'Manually Edited', child: Icon(Icons.push_pin, size: 14, color: Colors.orange)),
                              if (item.additionAmount > 0 || item.deductionAmount > 0 || item.isEdited)
                                const SizedBox(width: 4),
                              Text(item.timesheet.staffName),
                            ],
                          ),
                        ),
                        DataCell(SizedBox(width: 200, child: Text(item.timesheet.designation, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(item.timesheet.state)),
                        // --- NEW CELLS ---
                        DataCell(SizedBox(width: 150, child: Text(bankInfo.bankName, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(bankInfo.accountNumber)),
                        DataCell(Text(bankInfo.sortCode)),
                        // --- END OF NEW ---
                        DataCell(Text(item.expectedHours.toStringAsFixed(2))),
                        DataCell(Text(item.hoursUsedForCalc.toStringAsFixed(2))),
                        DataCell(_buildPercentageChip(item.percentageWorked)),
                        DataCell(Text(_currencyFormat.format(item.baseSalary.grossPay))), // <-- DATA FOR NEW COLUMN
                        DataCell(Text(_currencyFormat.format(item.proratedGross))),
                        DataCell(
                          Text(
                            _currencyFormat.format(item.additionAmount),
                            style: TextStyle(color: item.additionAmount > 0 ? Colors.green.shade700 : Colors.grey),
                          ),
                        ),
                        DataCell(
                          Text(
                            _currencyFormat.format(item.deductionAmount),
                            style: TextStyle(color: item.deductionAmount > 0 ? Colors.red.shade700 : Colors.grey),
                          ),
                        ),
                        DataCell(SizedBox(width: 200, child: Text(comment, overflow: TextOverflow.ellipsis))),
                        DataCell(
                          Text(
                            _currencyFormat.format(item.proratedNet),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit_note, size: 20, color: Colors.blueAccent),
                            onPressed: () => _showEditSalaryDialog(item),
                            tooltip: 'Adjust Salary',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
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
    bool _isSaving = false;

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

                // Recalculate the number of working days in the month
                final startDate = DateTime(widget.year, widget.month - 1, 20);
                final endDate = DateTime(widget.year, widget.month, 19);
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
                  _isSaving
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
                        setDialogState(() { _isSaving = true; });

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
      // 1. Get the default sheet created by createExcel()
      final String defaultSheetName = excel.sheets.keys.first;
      final xls.Sheet sheet = excel.sheets[defaultSheetName]!;
      // 2. Rename it to what you want
      //sheet.sheet = 'Payment Schedule';
      // --- END OF FIX ---
    //  final  xls.Sheet sheet = excel['Payment Schedule'];

      // --- MODIFIED: Added "Gross Pay (Base)" header ---
      const List<String> headers = [
        'S/No', 'Staff Name', 'Designation', 'State', 'Location',
        'Bank Name', 'Account Number', 'Sort Code', // <-- ADDED
        'Expected Hours', 'Hours Worked', '% Worked (Capped at 100%)', 'Gross Pay (Base)',
        'Prorated Gross', 'Addition Amount', 'Addition Reason', 'Deduction Amount',
        'Deduction Reason', 'Final Net Pay', 'Is Manually Edited?'
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

      // Iterate through the filtered data and append rows
      for (int i = 0; i < _filteredPaymentList.length; i++) {
        final item = _filteredPaymentList[i];
        // --- Get bank info from cache for export ---
        final bankInfo = _staffBankDetailsCache[item.timesheet.staffId] ?? StaffBankInfo();

        // --- MODIFIED: Added item.baseSalary.grossPay to the row data ---
        final List< xls.CellValue> rowData = [
          xls.IntCellValue(i + 1),
          xls.TextCellValue(item.timesheet.staffName),
          xls.TextCellValue(item.timesheet.designation),
          xls.TextCellValue(item.timesheet.state),
          xls.TextCellValue(item.timesheet.location),
          // --- ADDED BANK DATA ---
          xls.TextCellValue(bankInfo.bankName),
          xls.TextCellValue(bankInfo.accountNumber),
          xls.TextCellValue(bankInfo.sortCode),
          // --- END OF ADDED ---
          xls.DoubleCellValue(item.expectedHours),
          xls.DoubleCellValue(item.timesheet.totalHours),
          xls.TextCellValue('${item.percentageWorked.toStringAsFixed(1)}%'),
          xls.DoubleCellValue(item.baseSalary.grossPay), // <-- THE NEW DATA CELL
          xls.DoubleCellValue(item.proratedGross),
          xls.DoubleCellValue(item.additionAmount),
          xls.TextCellValue(item.additionReason ?? ''),
          xls.DoubleCellValue(item.deductionAmount),
          xls.TextCellValue(item.deductionReason ?? ''),
          xls.DoubleCellValue(item.proratedNet),
          xls.TextCellValue(item.isEdited ? 'Yes' : 'No'),
        ];

        sheet.appendRow(rowData);
      }

      // Auto-fit columns
      // for (var i = 0; i < headers.length; i++) {
      //   sheet.setColAutoFit(i);
      // }

      // Save the file and trigger the download
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
    Key? key,
    required this.title,
    required this.allOptions,
    required this.initialSelectedOptions,
    required this.allText,
  }) : super(key: key);

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