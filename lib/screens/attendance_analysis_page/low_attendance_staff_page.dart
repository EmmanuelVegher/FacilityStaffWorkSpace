// LOW ATTENDANCE STAFF PAGE
// Displays facility staff with attendance <95% in selected period

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show Blob, Url, document, AnchorElement;
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../widgets/drawer2.dart';
import '../../widgets/drawer3.dart';
import '../../widgets/global_multi_select_dropdown.dart';

class LowAttendanceStaffPage extends StatefulWidget {
  final bool isHqMode;
  const LowAttendanceStaffPage({super.key, this.isHqMode = false});

  @override
  _LowAttendanceStaffPageState createState() => _LowAttendanceStaffPageState();
}

class _LowAttendanceStaffPageState extends State<LowAttendanceStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  String? _userState;
  String? _userStaffCategory;

  // Date range
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  // Filters
  List<String> _availableStates = [];
  List<String> _selectedStates = [];
  List<String> _availableFacilities = [];
  List<String> _selectedFacilities = [];
  List<String> _availableDesignations = [];
  List<String> _selectedDesignations = [];
  double _attendanceThreshold = 99.0;
  late TextEditingController _thresholdController;
  late ScrollController _tableScrollController;

  // Pagination
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final List<int> _availableRowsPerPage = [10, 25, 50, 100];

  // Data
  List<Map<String, dynamic>> _lowAttendanceStaff = [];

  // Pagination helpers
  List<Map<String, dynamic>> get _paginatedData {
    if (_lowAttendanceStaff.isEmpty) return [];
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, _lowAttendanceStaff.length);
    return _lowAttendanceStaff.sublist(startIndex, endIndex);
  }

  int get _totalPages => _lowAttendanceStaff.isEmpty ? 0 : (_lowAttendanceStaff.length / _rowsPerPage).ceil();

  int get _startRecord => _lowAttendanceStaff.isEmpty ? 0 : (_currentPage * _rowsPerPage) + 1;
  
  int get _endRecord => _lowAttendanceStaff.isEmpty ? 0 : ((_currentPage + 1) * _rowsPerPage).clamp(0, _lowAttendanceStaff.length);

  void _goToPage(int page) {
    setState(() {
      _currentPage = page.clamp(0, _totalPages - 1);
    });
  }

  void _changeRowsPerPage(int? newRowsPerPage) {
    if (newRowsPerPage == null) return;
    setState(() {
      _rowsPerPage = newRowsPerPage;
      _currentPage = 0; // Reset to first page
    });
  }

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController(text: _attendanceThreshold.toString());
    _tableScrollController = ScrollController();
    _initializePage();
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final staffData = staffDoc.data() ?? {};
      _userState = staffData['state'] as String?;
      final userLocation = staffData['location'] as String?;
      final staffCategory = staffData['staffCategory'] as String? ?? staffData['role'] as String? ?? '';
      _userStaffCategory = staffCategory; // Store for drawer selection

      if (_userState == null && !staffCategory.toLowerCase().contains('hq')) {
        throw Exception("User state not found.");
      }

      // Automatically detect HQ Mode if staffCategory contains "HQ"
      bool isHqUser = staffCategory.toLowerCase().contains('hq');
      // Detect State Office User if staffCategory contains "State Office"
      bool isStateOfficeUser = staffCategory.toLowerCase().contains('state office');

      if (isHqUser || widget.isHqMode) {
        // HQ Staff: Load all states, show all facilities (by selecting all states and clearing facility filter)
        await _loadAvailableStates();
        _selectedStates = List.from(_availableStates);
        _selectedFacilities = []; // Empty implies "All Facilities" in _loadFilters context
      } else if (isStateOfficeUser) {
        // State Office Staff: Pre-select their state, clear facility filter to show ALL facilities in that state
        _selectedStates = _userState != null ? [_userState!] : [];
        _selectedFacilities = []; // Empty means ALL facilities within the selected state
      } else {
        // Facility Staff: Pre-select their state AND their specific facility
        _selectedStates = _userState != null ? [_userState!] : [];
        if (userLocation != null && userLocation.isNotEmpty) {
           _selectedFacilities = [userLocation];
        } else {
           _selectedFacilities = [];
        }
      }

      await _loadFilters();
      await _loadLowAttendanceData();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableStates() async {
    final statesSnapshot = await _firestore.collection('Facilities').get();
    final states = statesSnapshot.docs
        .map((doc) => doc.data()['state'] as String?)
        .where((state) => state != null)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    if (mounted) {
      setState(() => _availableStates = states);
    }
  }

  Future<void> _loadFilters() async {
    if (_selectedStates.isEmpty) return;

    // For facilities, we need to load from all selected states
    Query query = _firestore.collection('Facilities')
        .where('category', isEqualTo: 'Facility');

    // Firestore whereIn has a limit of 30 values
    if (_selectedStates.isNotEmpty && _selectedStates.length <= 30) {
      query = query.where('state', whereIn: _selectedStates);
    }

    final facilitiesSnapshot = await query.get();

    var facilities = facilitiesSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        // Secondary filtering for states if > 30 selected
        .where((data) => _selectedStates.isEmpty || _selectedStates.contains(data['state']))
        .map((data) => data['LocationName'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toList();

    final designations = await _getUniqueFieldValues('designation');

    if (mounted) {
      setState(() {
        _availableFacilities = facilities..sort();
        _availableDesignations = designations..sort();
        // For facility users, keep their location pre-selected but allow them to change if needed
        if (_selectedFacilities.isEmpty && _availableFacilities.isNotEmpty) {
          _selectedFacilities = List.from(_availableFacilities);
        }
      });
    }
  }

  Future<List<String>> _getUniqueFieldValues(String field) async {
    var query = _firestore
        .collection('Staff')
        .where('staffCategory', isEqualTo: 'Facility Staff')
        .where('accountStatus', isEqualTo: 'Active');

    // Filter by state in query if possible for better performance (limit 30)
    if (_selectedStates.isNotEmpty && _selectedStates.length <= 30) {
      query = query.where('state', whereIn: _selectedStates);
    }

    final snapshot = await query.get();

    final values = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final state = data['state'] as String?;
      if (state != null && _selectedStates.contains(state)) {
        final value = data[field] as String?;
        if (value != null && value.isNotEmpty) values.add(value);
      }
    }
    return values.toList();
  }

  Future<void> _loadLowAttendanceData() async {
    if (_selectedStates.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all facility staff - filter by states in query if possible (limit 30)
      var staffQuery = _firestore
          .collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .where('accountStatus', isEqualTo: 'Active');

      if (_selectedStates.isNotEmpty && _selectedStates.length <= 30) {
        staffQuery = staffQuery.where('state', whereIn: _selectedStates);
      }

      if (_selectedDesignations.isNotEmpty && _selectedDesignations.length <= 30) {
        staffQuery = staffQuery.where('designation', whereIn: _selectedDesignations);
      }

      final staffSnapshot = await staffQuery.get();
      final allStaff = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'designation': data['designation'] ?? '',
          'facility': data['location'] ?? '',
          'state': data['state'] ?? '',
          'email': data['emailAddress'] ?? '',
          'phone': data['mobile'] ?? '',
        };
      }).toList();

      // Filter by selected states in code (important for HQ users who have > 30 states)
      final staffList = allStaff.where((staff) => _selectedStates.contains(staff['state'])).toList();

      // Filter by facilities (lenient: only filter by name if user has made a specific subset selection)
      final bool isAllFacilitiesSelected = _selectedFacilities.length == _availableFacilities.length;
      final filteredStaff = (isAllFacilitiesSelected || _selectedFacilities.isEmpty)
          ? staffList
          : staffList.where((s) => _selectedFacilities.contains(s['facility'])).toList();

      // Calculate expected days (weekdays)
      final expectedDays = _calculateExpectedDays(_startDate, _endDate);

      // Get attendance records
      final recordsSnapshot = await _firestore
          .collectionGroup('Record')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp', isLessThan: _endDate.add(const Duration(days: 1)))
          .get();

      // Count unique attendance days per staff
      final attendanceDays = <String, Set<String>>{};
      for (final record in recordsSnapshot.docs) {
        final staffId = record.reference.parent.parent!.id;
        final data = record.data();
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          final dateStr = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
          attendanceDays.putIfAbsent(staffId, () => {}).add(dateStr);
        } else if (data['date'] != null) {
          // Fallback to date string if timestamp is missing
          attendanceDays.putIfAbsent(staffId, () => {}).add(data['date'] as String);
        }
      }

      // Calculate low attendance staff
      final lowAttendance = <Map<String, dynamic>>[];
      for (final staff in filteredStaff) {
        final actual = attendanceDays[staff['id']]?.length ?? 0;
        final percentage = expectedDays > 0 ? (actual / expectedDays) * 100 : 0.0;
        if (percentage < _attendanceThreshold) {
          lowAttendance.add({
            ...staff,
            'expected': expectedDays,
            'actual': actual,
            'percentage': percentage,
          });
        }
      }

      lowAttendance.sort((a, b) => a['percentage'].compareTo(b['percentage']));

      if (mounted) {
        setState(() => _lowAttendanceStaff = lowAttendance);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateExpectedDays(DateTime start, DateTime end) {
    int count = 0;
    for (DateTime date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      if (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday) {
        count++;
      }
    }
    return count;
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);

    try {
      List<List<dynamic>> rows = [];
      rows.add(['Name', 'Designation', 'Facility', 'State', 'Email', 'Phone', 'Expected Days', 'Actual Days', 'Attendance %', 'Status']);

      for (final staff in _lowAttendanceStaff) {
        final percentage = staff['percentage'];
        String status;
        if (percentage < 50) {
          status = 'Critical';
        } else if (percentage < 80) {
          status = 'Warning';
        } else {
          status = 'Caution';
        }

        rows.add([
          staff['name'],
          staff['designation'],
          staff['facility'],
          staff['state'] ?? '',
          staff['email'],
          staff['phone'] ?? '',
          staff['expected'],
          staff['actual'],
          '${percentage.toStringAsFixed(1)}%',
          status,
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      _triggerDownload(
        utf8.encode(csvData),
        'low_attendance_staff_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting CSV: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      var excel = xls.Excel.createExcel();
      xls.Sheet sheetObject = excel['Low Attendance Staff'];

      var headerStyle = xls.CellStyle(bold: true);

      List<String> headers = ['Name', 'Designation', 'Facility', 'State', 'Email', 'Phone', 'Expected Days', 'Actual Days', 'Attendance %', 'Status'];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xls.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      for (int i = 0; i < _lowAttendanceStaff.length; i++) {
        final staff = _lowAttendanceStaff[i];
        final percentage = staff['percentage'];
        String status;
        if (percentage < 50) {
          status = 'Critical';
        } else if (percentage < 80) {
          status = 'Warning';
        } else {
          status = 'Caution';
        }

        List<xls.CellValue> rowData = [
          xls.TextCellValue(staff['name']),
          xls.TextCellValue(staff['designation']),
          xls.TextCellValue(staff['facility']),
          xls.TextCellValue(staff['state'] ?? ''),
          xls.TextCellValue(staff['email']),
          xls.TextCellValue(staff['phone'] ?? ''),
          xls.IntCellValue(staff['expected']),
          xls.IntCellValue(staff['actual']),
          xls.TextCellValue('${percentage.toStringAsFixed(1)}%'),
          xls.TextCellValue(status),
        ];
        sheetObject.insertRowIterables(rowData, i + 1, startingColumn: 0);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        _triggerDownload(
          fileBytes,
          'low_attendance_staff_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting Excel: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _triggerDownload(List<int> bytes, String filename, [String mimeType = 'text/csv']) {
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
    }
  }


  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 350,
          height: 350,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            maxDate: DateTime.now(),
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange) {
                setState(() {
                  _startDate = value.startDate ?? _startDate;
                  _endDate = value.endDate ?? _endDate;
                });
                _loadLowAttendanceData();
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
      ),
    ));
  }

  // Helper method to select appropriate drawer based on user role
  Widget _getDrawer(BuildContext context) {
    // Check if user is HQ Staff
    if (_userStaffCategory?.toLowerCase().contains('hq') ?? false) {
      return drawer3(context);
    }
    // Default to drawer2 for State Office Staff and others
    return drawer2(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Low Attendance Staff",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5C1A2E), // Corporate Maroon
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
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if (value == 'csv') _exportToCsv();
                if (value == 'excel') _exportToExcel();
              },
              enabled: !_isLoading && _lowAttendanceStaff.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.list_alt_rounded),
                    title: Text("Download CSV"),
                  ),
                ),
                const PopupMenuItem(
                  value: 'excel',
                  child: ListTile(
                    leading: Icon(Icons.grid_on_sharp),
                    title: Text("Download Excel"),
                  ),
                ),
              ],
            )
        ],
      ),
      drawer: _getDrawer(context),
      body: SelectionArea(
        child: Column(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                     _buildSummaryCards(),
                     _buildFilters(),
                    if (_lowAttendanceStaff.isNotEmpty && !_isLoading)
                      _buildCharts(),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(_errorMessage!,
                            style: GoogleFonts.poppins(color: Colors.red)),
                      ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_lowAttendanceStaff.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text("No staff with low attendance found.",
                              style: GoogleFonts.poppins())),
                      ),
                ],
                ),
              ),
            ),
            if (!_isLoading && _lowAttendanceStaff.isNotEmpty)
              Expanded(child: _buildDataTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (widget.isHqMode)
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: GlobalMultiSelectDropdown<String>(
                  items: _availableStates,
                  selectedItems: _selectedStates,
                  title: "Select States",
                  labelBuilder: (val) => val,
                  onChanged: (results) {
                    setState(() => _selectedStates = results);
                    _loadFilters();
                    _loadLowAttendanceData();
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${DateFormat("MMM d, yyyy").format(_startDate)} - ${DateFormat("MMM d, yyyy").format(_endDate)}',
                style: GoogleFonts.poppins(),
              ),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
            ),
             Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: GlobalMultiSelectDropdown<String>(
                  items: _availableFacilities,
                  selectedItems: _selectedFacilities,
                  title: "Select Facilities",
                  labelBuilder: (val) => val,
                  onChanged: (results) {
                    setState(() => _selectedFacilities = results);
                    _loadLowAttendanceData();
                  },
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: GlobalMultiSelectDropdown<String>(
                items: _availableDesignations,
                selectedItems: _selectedDesignations,
                title: "Select Designations",
                labelBuilder: (val) => val,
                onChanged: (results) {
                  setState(() => _selectedDesignations = results);
                  _loadLowAttendanceData();
                },
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Threshold: ", style: GoogleFonts.poppins()),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: _thresholdController,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      final newThreshold = double.tryParse(value);
                      if (newThreshold != null &&
                          newThreshold >= 0 &&
                          newThreshold <= 100) {
                        setState(() => _attendanceThreshold = newThreshold);
                        _thresholdController.text = newThreshold.toString();
                        _loadLowAttendanceData();
                      }
                    },
                  ),
                ),
                Text("%", style: GoogleFonts.poppins()),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('Refresh', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C1A2E), // Corporate Maroon
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              onPressed: _isLoading ? null : _loadLowAttendanceData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_lowAttendanceStaff.isEmpty) return const SizedBox.shrink();

    final totalLow = _lowAttendanceStaff.length;
    // Calculate average metrics if needed, for now using simple counts
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
           _buildMetricCard("Total Low Attendance", totalLow.toString(), Colors.redAccent),
           _buildMetricCard("Threshold", "${_attendanceThreshold.toStringAsFixed(0)}%", Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
     return Card(
       elevation: 4,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       child: Container(
         width: 200,
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           border: Border(left: BorderSide(color: color, width: 6)),
           borderRadius: BorderRadius.circular(12),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(title, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
             const SizedBox(height: 8),
             Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
           ],
         ),
       ),
     );
  }

  Widget _buildCharts() {
    if (_lowAttendanceStaff.isEmpty) return const SizedBox.shrink();

    // Data for Bar Chart (Distribution)
    int critical = 0; // < 50
    int warning = 0; // 50-80
    int caution = 0; // 80-99 (or threshold)

    for (var staff in _lowAttendanceStaff) {
      double pct = staff['percentage'];
      if (pct < 50) critical++;
      else if (pct < 80) warning++;
      else caution++;
    }

    final barData = [
       _ChartData('Critical (<50%)', critical, Colors.red),
       _ChartData('Warning (50-80%)', warning, Colors.orange),
       _ChartData('Caution (>80%)', caution, Colors.yellow[700]!),
    ];
    
    // Data for Pie Chart (Breakdown)
    // HQ -> By State, Else -> By Designation
    final Map<String, int> breakdown = {};
    String breakdownKey = widget.isHqMode  ? 'state' : 'designation'; // HQ sees State breakdown, others see Designation
    bool isHq = widget.isHqMode; // Actually logic should be based on user role too, but using widget flag or implicit logic
    // Refined logic: If multiple states selected, breakdown by state. Else by designation.
    if (_selectedStates.length > 1) {
       breakdownKey = 'state';
    } else {
       breakdownKey = 'designation';
    }

    for (var staff in _lowAttendanceStaff) {
       String key = staff[breakdownKey] ?? 'Unknown';
       breakdown[key] = (breakdown[key] ?? 0) + 1;
    }

    final pieData = breakdown.entries.map((e) => _ChartData(e.key, e.value, null)).toList();
    // Sort pie data desc
    pieData.sort((a,b) => b.y.compareTo(a.y));


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
               Expanded(
                 child: Card(
                   elevation: 4,
                   margin: const EdgeInsets.all(8),
                   child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       children: [
                         Text("Attendance Distribution", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 16),
                         SfCartesianChart(
                           primaryXAxis: CategoryAxis(),
                           series: <CartesianSeries>[
                             ColumnSeries<_ChartData, String>(
                               dataSource: barData,
                               xValueMapper: (_ChartData data, _) => data.x,
                               yValueMapper: (_ChartData data, _) => data.y,
                               pointColorMapper: (_ChartData data, _) => data.color,
                               dataLabelSettings: const DataLabelSettings(isVisible: true),
                             )
                           ],
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
               Expanded(
                 child: Card(
                   elevation: 4,
                   margin: const EdgeInsets.all(8),
                   child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       children: [
                         Text("Breakdown by ${breakdownKey == 'state' ? 'State' : 'Designation'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 16),
                         SfCircularChart(
                           legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
                           series: <CircularSeries>[
                             PieSeries<_ChartData, String>(
                               dataSource: pieData,
                               xValueMapper: (_ChartData data, _) => data.x,
                               yValueMapper: (_ChartData data, _) => data.y,
                               dataLabelSettings: const DataLabelSettings(isVisible: true),
                             )
                           ],
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildDataTable() {
    return Column(
      children: [
        // Horizontal scroll navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _tableScrollController.animateTo(
                  _tableScrollController.offset - 200,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: 'Scroll Left',
            ),
            const SizedBox(width: 16),
            Text('Scroll Table Horizontally', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                _tableScrollController.animateTo(
                  _tableScrollController.offset + 200,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tooltip: 'Scroll Right',
            ),
          ],
        ),
        const Divider(),
        
        // Data table with horizontal and vertical scrolling
        Expanded(
          child: SingleChildScrollView(
            controller: _tableScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                dataTextStyle: GoogleFonts.poppins(),
                columns: [
                  DataColumn(label: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Designation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Facility', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('State', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Email', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Phone', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Expected', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actual', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Percentage', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                ],
                rows: _paginatedData.map((staff) {
                  final percentage = staff['percentage'];
                  Color color = percentage < 50 ? Colors.red : percentage < 80 ? Colors.orange : Colors.yellow;
                  return DataRow(
                    cells: [
                      DataCell(Text(staff['name'], style: GoogleFonts.poppins())),
                      DataCell(Text(staff['designation'], style: GoogleFonts.poppins())),
                      DataCell(Text(staff['facility'], style: GoogleFonts.poppins())),
                      DataCell(Text(staff['state'] ?? '', style: GoogleFonts.poppins())),
                      DataCell(Text(staff['email'], style: GoogleFonts.poppins())),
                      DataCell(Text(staff['phone'] ?? '', style: GoogleFonts.poppins())),
                      DataCell(Text(staff['expected'].toString(), style: GoogleFonts.poppins())),
                      DataCell(Text(staff['actual'].toString(), style: GoogleFonts.poppins())),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                  color: Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        
        // Pagination controls
        if (_lowAttendanceStaff.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 600;
                
                if (isSmallScreen) {
                  // Stack pagination controls vertically on small screens
                  return Column(
                    children: [
                      // Record count and rows per page
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Showing $_startRecord-$_endRecord of ${_lowAttendanceStaff.length}',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Rows: ', style: GoogleFonts.poppins(fontSize: 12)),
                              DropdownButton<int>(
                                value: _rowsPerPage,
                                items: _availableRowsPerPage.map((rows) {
                                  return DropdownMenuItem(
                                    value: rows,
                                    child: Text(rows.toString(), style: GoogleFonts.poppins(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: _changeRowsPerPage,
                                underline: const SizedBox(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.first_page),
                            onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                            tooltip: 'First Page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                            tooltip: 'Previous Page',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Page ${_currentPage + 1} of $_totalPages',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
                            tooltip: 'Next Page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.last_page),
                            onPressed: _currentPage < _totalPages - 1 ? () => _goToPage(_totalPages - 1) : null,
                            tooltip: 'Last Page',
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Single row layout for larger screens
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Record count
                      Text(
                        'Showing $_startRecord-$_endRecord of ${_lowAttendanceStaff.length}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      
                      // Navigation buttons
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.first_page),
                            onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
                            tooltip: 'First Page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                            tooltip: 'Previous Page',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Page ${_currentPage + 1} of $_totalPages',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
                            tooltip: 'Next Page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.last_page),
                            onPressed: _currentPage < _totalPages - 1 ? () => _goToPage(_totalPages - 1) : null,
                            tooltip: 'Last Page',
                          ),
                        ],
                      ),
                      
                      // Rows per page selector
                      Row(
                        children: [
                          Text('Rows per page: ', style: GoogleFonts.poppins(fontSize: 14)),
                          DropdownButton<int>(
                            value: _rowsPerPage,
                            items: _availableRowsPerPage.map((rows) {
                              return DropdownMenuItem(
                                value: rows,
                                child: Text(rows.toString(), style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: _changeRowsPerPage,
                            underline: const SizedBox(),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }
}

class _ChartData {
  final String x;
  final int y;
  final Color? color;

  _ChartData(this.x, this.y, [this.color]);
}