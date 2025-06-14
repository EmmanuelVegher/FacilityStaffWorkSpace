// A ROBUST PAGE FOR REVIEWING STAFF TIMESHEETS STATE-WIDE (FINAL ADVANCED VERSION)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../widgets/drawer2.dart'; // Assuming you have a state-level drawer

// --- DATA MODELS TO MATCH FIRESTORE STRUCTURE ---

class TimesheetEntry {
  final String date;
  final String durationWorked;
  final num noOfHours;
  final bool isOffDay;
  final String projectName;

  TimesheetEntry({
    required this.date,
    required this.durationWorked,
    required this.noOfHours,
    required this.isOffDay,
    required this.projectName,
  });

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) {
    return TimesheetEntry(
      date: map['date'] as String? ?? 'N/A',
      durationWorked: map['durationWorked'] as String? ?? 'N/A',
      noOfHours: map['noOfHours'] as num? ?? 0,
      isOffDay: map['offDay'] as bool? ?? false,
      projectName: map['projectName'] as String? ?? 'N/A',
    );
  }
}

class TimesheetModel {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String designation;
  final String department;
  final String location;
  final String state;
  final String? staffSignature;
  final String? staffSignatureDate;
  final String? projectName;
  final String facilitySupervisor;
  final String facilitySupervisorSignatureStatus;
  final String? facilitySupervisorSignature;
  final String? facilitySupervisorSignatureDate;
  final String caritasSupervisor;
  final String caritasSupervisorSignatureStatus;
  final String? caritasSupervisorSignature;
  final String? caritasSupervisorSignatureDate;
  final List<TimesheetEntry> entries;
  final double totalHours;

  TimesheetModel({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.designation,
    required this.department,
    required this.location,
    required this.state,
    this.staffSignature,
    this.staffSignatureDate,
    this.projectName,
    required this.facilitySupervisor,
    required this.facilitySupervisorSignatureStatus,
    this.facilitySupervisorSignature,
    this.facilitySupervisorSignatureDate,
    required this.caritasSupervisor,
    required this.caritasSupervisorSignatureStatus,
    this.caritasSupervisorSignature,
    this.caritasSupervisorSignatureDate,
    required this.entries,
  }) : totalHours = entries.fold(0.0, (sum, item) => sum + item.noOfHours);

  factory TimesheetModel.fromMap(Map<String, dynamic> map, String id) {
    var entriesData = (map['timesheetEntries'] as List<dynamic>?)
        ?.map((e) => TimesheetEntry.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];

    return TimesheetModel(
      staffId: map['staffId'] as String? ?? id,
      staffName: map['staffName'] as String? ?? 'N/A',
      staffEmail: map['staffEmail'] as String? ?? 'N/A',
      designation: map['designation'] as String? ?? 'N/A',
      department: map['department'] as String? ?? 'N/A',
      location: map['location'] as String? ?? 'N/A',
      state: map['state'] as String? ?? 'N/A',
      staffSignature: map['staffSignature'] as String?,
      staffSignatureDate: map['staffSignatureDate'] as String?,
      projectName: map['projectName'] as String?,
      facilitySupervisor: map['facilitySupervisor'] as String? ?? 'N/A',
      facilitySupervisorSignatureStatus: map['facilitySupervisorSignatureStatus'] as String? ?? 'Pending',
      facilitySupervisorSignature: map['facilitySupervisorSignature'] as String?,
      facilitySupervisorSignatureDate: map['facilitySupervisorSignatureDate'] as String?,
      caritasSupervisor: map['caritasSupervisor'] as String? ?? 'N/A',
      caritasSupervisorSignatureStatus: map['caritasSupervisorSignatureStatus'] as String? ?? 'Pending',
      caritasSupervisorSignature: map['caritasSupervisorSignature'] as String?,
      caritasSupervisorSignatureDate: map['caritasSupervisorSignatureDate'] as String?,
      entries: entriesData,
    );
  }
}

class TimesheetMetrics {
  int totalExpected = 0;
  int totalSubmitted = 0;
  int pendingFacilityApproval = 0;
  int pendingCaritasApproval = 0;
  int fullyApproved = 0;
  double totalHoursLogged = 0;
  double percentFullyApproved = 0.0;
}

class _ChartData {
  final String category;
  final int value;
  final Color color;
  _ChartData(this.category, this.value, this.color);
}


// --- MAIN WIDGET ---
class TimesheetReviewPage extends StatefulWidget {
  const TimesheetReviewPage({super.key});

  @override
  _TimesheetReviewPageState createState() => _TimesheetReviewPageState();
}

class _TimesheetReviewPageState extends State<TimesheetReviewPage> {
  // --- Services & State Management ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isFilterLoading = true;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // --- Filter & User Context ---
  String? _userState;
  List<String> _availableFacilities = [];
  String? _selectedFacilityName;
  late int _selectedYear;
  late int _selectedMonth;
  List<TimesheetModel> _staffListForFilter = [];
  String? _selectedStaffId;

  // --- Data Lists & Metrics ---
  List<TimesheetModel> _allTimesheetsMaster = [];
  List<TimesheetModel> _displayedTimesheets = [];
  TimesheetMetrics _metrics = TimesheetMetrics();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _initializeUserContext();
  }

  Future<void> _initializeUserContext() async {
    setState(() => _isFilterLoading = true);
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final userState = staffDoc.data()?['state'] as String?;
      if (userState == null || userState.isEmpty) throw Exception("State not found in profile.");
      _userState = userState;
      final facilityNames = await _getFacilitiesForState(userState);
      if (mounted) {
        setState(() {
          _availableFacilities = ['All Facilities', ...facilityNames];
          _isFilterLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _errorMessage = "Failed to load filters: $e");
    } finally {
      if(mounted) setState(() => _isFilterLoading = false);
    }
  }

  Future<List<String>> _getFacilitiesForState(String state) async {
    final snapshot = await _firestore.collection('Location').doc(state).collection(state).get();
    final List<String> facilityNames = [];
    for (final doc in snapshot.docs) {
      final locationName = doc.data()['LocationName'] as String?;
      if (locationName != null && locationName.isNotEmpty) facilityNames.add(locationName);
    }
    facilityNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return facilityNames;
  }

  Future<void> _loadTimesheets() async {
    if (_selectedFacilityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a facility.")));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allTimesheetsMaster = [];
      _staffListForFilter = [];
      _selectedStaffId = null;
    });

    try {
      if (_userState == null) throw Exception("User State is not defined.");

      Query staffQuery = _firestore.collection('Staff').where('state', isEqualTo: _userState);
      if (_selectedFacilityName != 'All Facilities') {
        staffQuery = staffQuery.where('location', isEqualTo: _selectedFacilityName);
      }

      final staffSnapshot = await staffQuery.get();
      final staffIds = staffSnapshot.docs.map((doc) => doc.id).toList();

      if (staffIds.isEmpty) {
        setState(() => _isLoading = false);
        _applyFiltersAndCalculateMetrics(0);
        return;
      }

      int expectedCount = 0;
      final facilityStaffQuery = staffQuery.where('staffCategory', isEqualTo: 'Facility Staff');
      final facilityStaffSnapshot = await facilityStaffQuery.get();
      expectedCount = facilityStaffSnapshot.docs.length;

      final monthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth));
      final timesheetDocId = '${monthName}_$_selectedYear';

      final futures = staffIds.map((staffId) {
        return _firestore.collection('Staff').doc(staffId).collection('TimeSheets').doc(timesheetDocId).get();
      }).toList();

      final results = await Future.wait(futures);

      final List<TimesheetModel> fetchedTimesheets = [];
      for (final doc in results) {
        if (doc.exists && doc.data() != null) {
          fetchedTimesheets.add(TimesheetModel.fromMap(doc.data()!, doc.id));
        }
      }
      _allTimesheetsMaster = fetchedTimesheets..sort((a,b) => a.staffName.compareTo(b.staffName));
      _staffListForFilter = List.from(_allTimesheetsMaster);
      _applyFiltersAndCalculateMetrics(expectedCount);

    } catch (e, stack) {
      debugPrint('Error loading timesheets: $e\n$stack');
      if (mounted) setState(() => _errorMessage = 'Failed to load timesheets: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndCalculateMetrics([int? expectedCount]) {
    List<TimesheetModel> filteredList = _allTimesheetsMaster;

    if (_selectedStaffId != null) {
      filteredList = _allTimesheetsMaster.where((ts) => ts.staffId == _selectedStaffId).toList();
    }

    final newMetrics = TimesheetMetrics();
    newMetrics.totalExpected = expectedCount ?? _metrics.totalExpected;
    newMetrics.totalSubmitted = filteredList.length;

    for (final timesheet in filteredList) {
      if (timesheet.facilitySupervisorSignatureStatus == 'Approved' && timesheet.caritasSupervisorSignatureStatus == 'Approved') {
        newMetrics.fullyApproved++;
      } else if (timesheet.facilitySupervisorSignatureStatus == 'Approved' && timesheet.caritasSupervisorSignatureStatus == 'Pending') {
        newMetrics.pendingCaritasApproval++;
      } else if (timesheet.facilitySupervisorSignatureStatus == 'Pending') {
        newMetrics.pendingFacilityApproval++;
      }
      newMetrics.totalHoursLogged += timesheet.totalHours;
    }

    if (newMetrics.totalExpected > 0) {
      newMetrics.percentFullyApproved = (newMetrics.fullyApproved / newMetrics.totalExpected) * 100;
    }

    setState(() {
      _displayedTimesheets = filteredList;
      _metrics = newMetrics;
    });
  }

  // --- UI WIDGET BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Timesheet Review", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if(_isExporting)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined),
              tooltip: "Download Options",
              onSelected: (value) {
                if(value == 'bulk') _downloadBulkPdf();
              },
              enabled: !_isLoading && _displayedTimesheets.isNotEmpty,
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'bulk',
                    child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text("Download All (PDF)"))
                )
              ],
            )
        ],
      ),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_errorMessage != null) Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
          _buildMetricsDashboard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allTimesheetsMaster.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("No timesheets submitted for the selected criteria.")))
                : _buildTimesheetList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(5, (index) => DateTime.now().year - index);
    final months = List.generate(12, (index) => index + 1);

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (_isFilterLoading) const Text("Loading filters...") else ...[
              DropdownButtonFormField<String>(
                value: _selectedFacilityName,
                hint: const Text('Select Facility'),
                decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 250)),
                items: _availableFacilities.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (value) => setState(() => _selectedFacilityName = value),
              ),
              DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 150)),
                items: months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM').format(DateTime(0, m))))).toList(),
                onChanged: (value) => setState(() => _selectedMonth = value!),
              ),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 120)),
                items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (value) => setState(() => _selectedYear = value!),
              ),
              DropdownButtonFormField<String>(
                value: _selectedStaffId,
                hint: const Text('All Staff'),
                decoration: const InputDecoration(labelText: 'Staff Member', border: OutlineInputBorder(), constraints: BoxConstraints(maxWidth: 250)),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Staff')),
                  ..._staffListForFilter.map((ts) => DropdownMenuItem(value: ts.staffId, child: Text(ts.staffName, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: _allTimesheetsMaster.isEmpty ? null : (value) => setState(() {
                  _selectedStaffId = value;
                  _applyFiltersAndCalculateMetrics();
                }),
              ),
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: _isLoading ? null : _loadTimesheets,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
        children: [
          _buildKpiCard("Expected Timesheets", _metrics.totalExpected.toString(), Icons.people_alt_rounded, Colors.indigo),
          _buildKpiCard("Total Submitted", _metrics.totalSubmitted.toString(), Icons.file_present_rounded, Colors.blueGrey),
          _buildKpiCard("Awaiting Facility Approval", _metrics.pendingFacilityApproval.toString(), Icons.hourglass_top_rounded, Colors.orange),
          _buildKpiCard("Awaiting CARITAS Approval", _metrics.pendingCaritasApproval.toString(), Icons.hourglass_bottom_rounded, Colors.deepPurple),
          _buildKpiCard("Fully Approved", _metrics.fullyApproved.toString(), Icons.check_circle_rounded, Colors.green),
          _buildKpiCard("% Fully Approved", "${_metrics.percentFullyApproved.toStringAsFixed(1)}%", Icons.pie_chart, Colors.pink),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 240,
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedTimesheets.length,
      itemBuilder: (context, index) {
        final timesheet = _displayedTimesheets[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timesheet.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(timesheet.location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildStatusChip(timesheet.facilitySupervisorSignatureStatus, timesheet.caritasSupervisorSignatureStatus),
                const SizedBox(width: 8),
                Text("${timesheet.totalHours.toStringAsFixed(2)} hrs", style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  tooltip: "Download PDF",
                  onPressed: () => _downloadSinglePdf(timesheet),
                )
              ],
            ),
            children: [_buildExpansionDetails(timesheet)],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String facilityStatus, String caritasStatus) {
    String text; Color color;
    if (facilityStatus == 'Approved' && caritasStatus == 'Approved') {
      text = 'Fully Approved'; color = Colors.green;
    } else if (facilityStatus == 'Approved' && caritasStatus == 'Pending') {
      text = 'CARITAS Pending'; color = Colors.deepPurple;
    } else {
      text = 'Facility Pending'; color = Colors.orange;
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildExpansionDetails(TimesheetModel timesheet) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSupervisorInfo("Facility Supervisor", timesheet.facilitySupervisor, timesheet.facilitySupervisorSignatureStatus, timesheet.facilitySupervisorSignatureDate, timesheet.facilitySupervisorSignature)),
              Expanded(child: _buildSupervisorInfo("CARITAS Supervisor", timesheet.caritasSupervisor, timesheet.caritasSupervisorSignatureStatus, timesheet.caritasSupervisorSignatureDate, timesheet.caritasSupervisorSignature)),
            ],
          ),
          const Divider(height: 24),
          Text("Daily Entries", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildEntriesTable(timesheet.entries),
        ],
      ),
    );
  }

  Widget _buildSupervisorInfo(String title, String name, String status, String? date, String? signatureUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(name),
        Text("Status: $status"),
        if (date != null) Text("Date: $date"),
        if (signatureUrl != null && signatureUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Image.network(signatureUrl, height: 40, errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red)),
        ]
      ],
    );
  }

  Widget _buildEntriesTable(List<TimesheetEntry> entries) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [ DataColumn(label: Text("Date")), DataColumn(label: Text("Duration Worked")), DataColumn(label: Text("Hours"), numeric: true)],
        rows: entries.map((entry) => DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((s) => entry.isOffDay ? Colors.blue.withOpacity(0.05) : null),
            cells: [
              DataCell(Text(entry.date)), DataCell(Text(entry.durationWorked)), DataCell(Text(entry.noOfHours.toStringAsFixed(2))),
            ]
        )).toList(),
      ),
    );
  }

  // --- PDF DOWNLOAD LOGIC ---

  Future<void> _downloadSinglePdf(TimesheetModel timesheet) async {
    setState(() => _isExporting = true);
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(font);
    final ttfBold = pw.Font.ttf(boldFont);

    final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());

    pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));

    final pdfBytes = await pdf.save();
    _triggerDownload(pdfBytes, 'Timesheet_${timesheet.staffName.replaceAll(' ','_')}_${_selectedMonth}_${_selectedYear}.pdf');
    setState(() => _isExporting = false);
  }

  Future<void> _downloadBulkPdf() async {
    setState(() => _isExporting = true);
    final pdf = pw.Document();
    final font = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final boldFont = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttf = pw.Font.ttf(font);
    final ttfBold = pw.Font.ttf(boldFont);

    final logoImage = pw.MemoryImage((await rootBundle.load('assets/image/ccfn_logo.png')).buffer.asUint8List());

    for(final timesheet in _displayedTimesheets) {
      pdf.addPage(await _createSingleTimesheetPage(timesheet, logoImage, ttf, ttfBold));
    }

    final pdfBytes = await pdf.save();
    final facilityName = _selectedFacilityName?.replaceAll(' ','_') ?? "All";
    _triggerDownload(pdfBytes, 'Bulk_Timesheets_${facilityName}_${_selectedMonth}_${_selectedYear}.pdf');
    setState(() => _isExporting = false);
  }

  Future<Uint8List?> _networkImageToByte(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await Dio().get<List<int>>(imageUrl, options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data!);
    } catch (e) {
      debugPrint('Error fetching image for PDF: $e');
      return null;
    }
  }

  void _triggerDownload(Uint8List data, String filename) {
    final blob = html.Blob([data], 'application/pdf');
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

  Future<pw.Page> _createSingleTimesheetPage(TimesheetModel timesheet, pw.ImageProvider logoImage, pw.Font ttf, pw.Font ttfBold) async {
    final monthName = DateFormat('MMMM, yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final startDate = DateTime(_selectedYear, _selectedMonth - 1, 20);
    final endDate = DateTime(_selectedYear, _selectedMonth, 19);
    final daysInRange = List.generate(endDate.difference(startDate).inDays + 1, (i) => startDate.add(Duration(days: i)));

    final tableHeaders = ['Project Name', ...daysInRange.map((date) => DateFormat('dd').format(date)), 'Total Hours', '%'];

    Map<String, List<double>> projectDailyHours = {};
    Map<String, List<double>> outOfOfficeDailyHours = {
      'Annual leave': List.filled(daysInRange.length, 0.0),
      'Holiday': List.filled(daysInRange.length, 0.0),
      'Maternity': List.filled(daysInRange.length, 0.0),
    };

    for(int i = 0; i < daysInRange.length; i++) {
      final date = daysInRange[i];
      for(final entry in timesheet.entries) {
        if(entry.date == DateFormat('yyyy-MM-dd').format(date)) {
          double hours = entry.noOfHours.toDouble() > 8.0 ? 8.0 : entry.noOfHours.toDouble();
          if(entry.isOffDay) {
            if(outOfOfficeDailyHours.containsKey(entry.durationWorked)){
              outOfOfficeDailyHours[entry.durationWorked]![i] += hours;
            }
          } else {
            projectDailyHours.putIfAbsent(entry.projectName, () => List.filled(daysInRange.length, 0.0));
            projectDailyHours[entry.projectName]![i] += hours;
          }
        }
      }
    }

    final int workingDays = daysInRange.where((d) => d.weekday != DateTime.saturday && d.weekday != DateTime.sunday).length;
    final double maxHours = (workingDays * 8.0);

    List<List<String>> allRows = [];

    final mainProjectName = timesheet.projectName ?? (projectDailyHours.keys.isNotEmpty ? projectDailyHours.keys.first : "Project");
    final mainProjectHours = projectDailyHours[mainProjectName] ?? List.filled(daysInRange.length, 0.0);
    final totalProjectHours = mainProjectHours.reduce((a, b) => a + b);
    final percentProject = maxHours > 0 ? (totalProjectHours / maxHours * 100) : 0;
    allRows.add([mainProjectName, ...mainProjectHours.map((h) => h.round().toString()), totalProjectHours.round().toString(), '${percentProject.round()}%']);

    outOfOfficeDailyHours.forEach((category, hours) {
      final total = hours.reduce((a, b) => a + b);
      final percent = maxHours > 0 ? (total / maxHours * 100) : 0;
      allRows.add([category, ...hours.map((h) => h.round().toString()), total.round().toString(), '${percent.round()}%']);
    });

    final staffSigBytes = await _networkImageToByte(timesheet.staffSignature);
    final facilitySigBytes = await _networkImageToByte(timesheet.facilitySupervisorSignature);
    final caritasSigBytes = await _networkImageToByte(timesheet.caritasSupervisorSignature);

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Name: ${timesheet.staffName}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Department: ${timesheet.department}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Designation: ${timesheet.designation}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Location: ${timesheet.location}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('State: ${timesheet.state}', style: const pw.TextStyle(fontSize: 9)),
                    ]
                ),
                pw.Column(
                    children: [
                      pw.Text("CARITAS NIGERIA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                      pw.SizedBox(height: 5),
                      pw.Text("Monthly Time Report ($monthName)", style: const pw.TextStyle(fontSize: 14))
                    ]
                ),
                pw.Image(logoImage, width: 70, height: 70),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                for (int i = 1; i <= daysInRange.length; i++) i: const pw.FlexColumnWidth(0.7),
                daysInRange.length + 1: const pw.FlexColumnWidth(1.2),
                daysInRange.length + 2: const pw.FlexColumnWidth(0.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: tableHeaders.map((h) => pw.Container(
                      alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(2),
                      child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7))
                  )).toList(),
                ),
                ...allRows.map((row) {
                  return pw.TableRow(
                    children: row.asMap().entries.map((entry) {
                      final i = entry.key;
                      final data = entry.value;
                      final isWeekend = i > 0 && i <= daysInRange.length && (daysInRange[i-1].weekday == 6 || daysInRange[i-1].weekday == 7);
                      return pw.Container(
                        color: isWeekend ? PdfColors.grey200 : null,
                        alignment: pw.Alignment.center, padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(data, style: const pw.TextStyle(fontSize: 6.5)),
                      );
                    }).toList(),
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: List.generate(tableHeaders.length, (i) {
                    if (i == 0) return pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7), textAlign: pw.TextAlign.center);
                    if (i > 0 && i <= daysInRange.length) {
                      double dayTotal = allRows.fold(0.0, (sum, row) => sum + (double.tryParse(row[i]) ?? 0.0));
                      return pw.Text(dayTotal.round().toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7), textAlign: pw.TextAlign.center);
                    }
                    if (i == daysInRange.length + 1) {
                      double grandTotal = allRows.fold(0.0, (sum, row) => sum + (double.tryParse(row[i]) ?? 0.0));
                      return pw.Text(grandTotal.round().toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7), textAlign: pw.TextAlign.center);
                    }
                    double grandTotalHours = allRows.fold(0.0, (sum, row) => sum + (double.tryParse(row[daysInRange.length+1]) ?? 0.0));
                    double grandPercent = maxHours > 0 ? (grandTotalHours / maxHours * 100) : 0.0;
                    return pw.Text('${grandPercent.round()}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7), textAlign: pw.TextAlign.center);
                  }),
                )
              ],
            ),
            pw.Spacer(),
            pw.Text('Signature & Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Divider(height: 1),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildPdfSignatureColumn('Name of Staff', timesheet.staffName, staffSigBytes, timesheet.staffSignatureDate),
                _buildPdfSignatureColumn('Name of Project Coordinator', timesheet.facilitySupervisor, facilitySigBytes, timesheet.facilitySupervisorSignatureDate),
                _buildPdfSignatureColumn('Name of Caritas Supervisor', timesheet.caritasSupervisor, caritasSigBytes, timesheet.caritasSupervisorSignatureDate),
              ],
            ),
          ],
        );
      },
    );
  }

  pw.Widget _buildPdfSignatureColumn(String title, String name, Uint8List? imageBytes, String? date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Text(name.toUpperCase(), style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Container(
            height: 35, width: 100,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
            child: imageBytes != null ? pw.Image(pw.MemoryImage(imageBytes)) : pw.Center(child: pw.Text('Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)))
        ),
        pw.SizedBox(height: 2),
        pw.Text("Date: ${date ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}