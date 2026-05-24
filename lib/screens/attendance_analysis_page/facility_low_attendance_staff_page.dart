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
import 'package:service_delivery_workspace/widgets/drawer.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show Blob, Url, document, AnchorElement;

class FacilityLowAttendanceStaffPage extends StatefulWidget {
  final bool isHqMode;
  const FacilityLowAttendanceStaffPage({super.key, this.isHqMode = false});

  @override
  _FacilityLowAttendanceStaffPageState createState() =>
      _FacilityLowAttendanceStaffPageState();
}

class _FacilityLowAttendanceStaffPageState
    extends State<FacilityLowAttendanceStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  String? _userState;

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

  // Data
  List<Map<String, dynamic>> _lowAttendanceStaff = [];

  @override
  void initState() {
    super.initState();
    _thresholdController =
        TextEditingController(text: _attendanceThreshold.toString());
    _tableScrollController = ScrollController();
    _initializePage();
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      _userState = staffDoc.data()?['state'] as String?;
      final userLocation = staffDoc.data()?['location'] as String?;

      if (_userState == null) throw Exception("User state not found.");

      if (widget.isHqMode) {
        await _loadAvailableStates();
        _selectedStates = List.from(_availableStates);
      } else {
        _selectedStates = _userState != null ? [_userState!] : [];
        // For facility-level users, pre-select their specific location
        // For state-level users (e.g., State Office), leave empty so all facilities are loaded
        if (userLocation != null &&
            userLocation.isNotEmpty &&
            !userLocation.toLowerCase().contains('state office')) {
          _selectedFacilities = [userLocation];
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
    final facilitiesSnapshot = await _firestore
        .collection('Facilities')
        .where('state', whereIn: _selectedStates)
        .where('category', isEqualTo: 'Facility')
        .get();

    final facilities = facilitiesSnapshot.docs
        .map((doc) => doc.data()['LocationName'] as String?)
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

    // Filter by state in query if possible for better performance
    if (_selectedStates.isNotEmpty && _selectedStates.length <= 30) {
      query = query.where('state', whereIn: _selectedStates);
    }

    final snapshot = await query.get();

    final values = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final value = data[field] as String?;
      if (value != null && value.isNotEmpty) values.add(value);
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
      // Get all facility staff for the selected states - filter by states in query
      var staffQuery = _firestore
          .collection('Staff')
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .where('accountStatus', isEqualTo: 'Active');

      if (_selectedStates.isNotEmpty && _selectedStates.length <= 30) {
        staffQuery = staffQuery.where('state', whereIn: _selectedStates);
      }

      if (_selectedDesignations.isNotEmpty &&
          _selectedDesignations.length <= 30) {
        staffQuery =
            staffQuery.where('designation', whereIn: _selectedDesignations);
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

      // Filter by facilities (lenient: only filter by name if user has made a specific subset selection)
      final bool isAllFacilitiesSelected = _selectedFacilities.length == _availableFacilities.length;
      final filteredStaff = (isAllFacilitiesSelected || _selectedFacilities.isEmpty)
          ? allStaff
          : allStaff.where((s) => _selectedFacilities.contains(s['facility'])).toList();

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
    for (DateTime date = start;
        date.isBefore(end.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
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
      rows.add([
        'Name',
        'Designation',
        'Facility',
        'State',
        'Email',
        'Phone',
        'Expected Days',
        'Actual Days',
        'Attendance %',
        'Status'
      ]);

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

      List<String> headers = [
        'Name',
        'Designation',
        'Facility',
        'State',
        'Email',
        'Phone',
        'Expected Days',
        'Actual Days',
        'Attendance %',
        'Status'
      ];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
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

  void _triggerDownload(List<int> bytes, String filename,
      [String mimeType = 'text/csv']) {
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

  void _showFilterDialog({
    required String title,
    required List<String> allItems,
    required List<String> selectedItems,
    required Function(List<String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelectedItems = List.from(selectedItems);
        bool isAllSelected = tempSelectedItems.length == allItems.length;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: Text("Select All", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          isAllSelected = value ?? false;
                          if (isAllSelected) {
                            tempSelectedItems = List.from(allItems);
                          } else {
                            tempSelectedItems.clear();
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          final isSelected = tempSelectedItems.contains(item);
                          return CheckboxListTile(
                            title: Text(item, style: GoogleFonts.poppins()),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempSelectedItems.add(item);
                                } else {
                                  tempSelectedItems.remove(item);
                                }
                                isAllSelected = tempSelectedItems.length == allItems.length;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    onConfirm(tempSelectedItems);
                    Navigator.pop(context);
                  },
                  child: Text("Confirm", style: GoogleFonts.poppins(color: const Color(0xFF5C1A2E))),
                ),
              ],
            );
          },
        );
      },
    );
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Low Attendance Staff",
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF5C1A2E), // Corporate Maroon
        iconTheme: const IconThemeData(color: Colors.white),
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
      drawer: drawer(context),
      body: SelectionArea(
        child: Column(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildFilters(),
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
              OutlinedButton.icon(
                onPressed: () {
                  _showFilterDialog(
                    title: "Select States",
                    allItems: _availableStates,
                    selectedItems: _selectedStates,
                    onConfirm: (List<String> newSelection) {
                      setState(() => _selectedStates = newSelection);
                      _loadFilters();
                      _loadLowAttendanceData();
                    },
                  );
                },
                icon: Icon(Icons.map_outlined, color: Colors.grey.shade700),
                label: Text(
                  _selectedStates.isEmpty
                      ? "State"
                      : "${_selectedStates.length} selected",
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade800, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
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
            if (widget.isHqMode)
              OutlinedButton.icon(
                onPressed: () {
                  _showFilterDialog(
                    title: "Select Facilities",
                    allItems: _availableFacilities,
                    selectedItems: _selectedFacilities,
                    onConfirm: (List<String> newSelection) {
                      setState(() => _selectedFacilities = newSelection);
                      _loadLowAttendanceData();
                    },
                  );
                },
                icon:
                    Icon(Icons.location_city_outlined, color: Colors.grey.shade700),
                label: Text(
                  _selectedFacilities.isEmpty
                      ? "Facility"
                      : "${_selectedFacilities.length} selected",
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade800, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
              ),
            OutlinedButton.icon(
              onPressed: () {
                _showFilterDialog(
                  title: "Select Designations",
                  allItems: _availableDesignations,
                  selectedItems: _selectedDesignations,
                  onConfirm: (List<String> newSelection) {
                    setState(() => _selectedDesignations = newSelection);
                    _loadLowAttendanceData();
                  },
                );
              },
              icon: Icon(Icons.work_outline, color: Colors.grey.shade700),
              label: Text(
                _selectedDesignations.isEmpty
                    ? "Designation"
                    : "${_selectedDesignations.length} selected",
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade800, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
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
                backgroundColor: const Color(0xFF5C1A2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
              ),
              onPressed: _isLoading ? null : _loadLowAttendanceData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Column(
      children: [
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
            ),
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
            ),
          ],
        ),
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
                rows: _lowAttendanceStaff.map((staff) {
                  final percentage = staff['percentage'];
                  Color color = percentage < 50
                      ? Colors.red
                      : percentage < 80
                          ? Colors.orange
                          : Colors.yellow;
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
