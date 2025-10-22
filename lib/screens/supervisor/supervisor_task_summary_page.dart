import 'dart:convert';
import 'dart:html' as html; // For web download
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
// Make sure to import your Report and BioModel classes
// Adjust the path as per your project structure
import '../../widgets/drawer2.dart';
import '../activity_monitoring/activity_monitoring_page.dart';


// A model to hold the structured summary data (can be in its own file)
class TaskSummaryData {
  final String indicator;
  final String submittedBy;
  final int total;

  TaskSummaryData({
    required this.indicator,
    required this.submittedBy,
    required this.total,
  });
}

class SupervisorTaskSummaryPage extends StatefulWidget {
  const SupervisorTaskSummaryPage({super.key});

  @override
  State<SupervisorTaskSummaryPage> createState() => _SupervisorTaskSummaryPageState();
}

class _SupervisorTaskSummaryPageState extends State<SupervisorTaskSummaryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State for UI
  DateTime _selectedDailyDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  BioModel? _supervisorBio;
  bool _isLoading = true;
  bool _isExporting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // Rebuild on tab change to update FAB
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _fetchSupervisorBio();
  }

  Future<void> _fetchSupervisorBio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) setState(() { _isLoading = false; _errorMessage = "Authentication error."; });
      return;
    }
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      if (docSnapshot.exists) {
        final bio = BioModel.fromFirestore(docSnapshot, null);
        if (bio.state != null && bio.state!.isNotEmpty) {
          final stateDoc = await FirebaseFirestore.instance.collection('Location').where('name', isEqualTo: bio.state).limit(1).get();
          if(stateDoc.docs.isNotEmpty) {
            // Assuming BioModel has a stateId property
            // bio.stateId = stateDoc.docs.first.id;
          }
        }
        if (mounted) setState(() { _supervisorBio = bio; _isLoading = false; });
      } else {
        if(mounted) setState(() { _isLoading = false; _errorMessage = "Could not find your staff profile."; });
      }
    } catch (e) {
      if(mounted) setState(() { _isLoading = false; _errorMessage = "An error occurred fetching your profile."; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CSV Export Logic ---

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating CSV report...')));

    List<List<dynamic>> csvData;
    String fileName;

    try {
      if (_tabController.index == 0) {
        csvData = await _generateDailyCsvData();
        fileName = 'Daily_Summary_${DateFormat('yyyy-MM-dd').format(_selectedDailyDate)}.csv';
      } else {
        csvData = await _generateWeeklyCsvData();
        fileName = 'Weekly_Summary_${DateFormat('yyyy-MM').format(_selectedMonth)}.csv';
      }

      if (csvData.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data available to export.')));
        setState(() => _isExporting = false);
        return;
      }

      String csv = const ListToCsvConverter().convert(csvData);

      if (kIsWeb) {
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile platform - show message that download is not supported
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV download is only supported on web platform'),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating CSV: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isExporting = false);
    }
  }

  Future<List<List<dynamic>>> _generateDailyCsvData() async {
    List<List<dynamic>> rows = [];
    final formattedDate = DateFormat('dd-MMM-yyyy').format(_selectedDailyDate);

    final facilitySnapshot = await FirebaseFirestore.instance.collection('Location').doc(_supervisorBio!.state).collection(_supervisorBio!.state!).where('category', isEqualTo: 'Facility').get();
    final facilityDocs = facilitySnapshot.docs;

    Set<String> allUsernames = {};
    for (var facilityDoc in facilityDocs) {
      final facilityName = (facilityDoc.data())['LocationName'] ?? '';
      final reportPath = 'Reports/${_supervisorBio!.state}/${_supervisorBio!.state}/$facilityName/$formattedDate';
      final reportSnapshot = await FirebaseFirestore.instance.collection(reportPath).get();
      for (var reportDoc in reportSnapshot.docs) {
        final report = Report.fromFirestore(reportDoc as DocumentSnapshot<Map<String, dynamic>>, null);
        if (report.reportEntries != null) {
          allUsernames.addAll(report.reportEntries!.keys);
        }
      }
    }
    final sortedUsernames = allUsernames.toList()..sort();

    rows.add(['Facility', 'Designation', 'Indicator', ...sortedUsernames, 'Total']);

    for (var facilityDoc in facilityDocs) {
      final facilityName = (facilityDoc.data())['LocationName'] ?? '';
      final reportPath = 'Reports/${_supervisorBio!.state}/${_supervisorBio!.state}/$facilityName/$formattedDate';
      final reportSnapshot = await FirebaseFirestore.instance.collection(reportPath).get();

      if (reportSnapshot.docs.isNotEmpty) {
        Map<String, Map<String, Map<String, ReportEntry>>> data = {};
        for(var reportDoc in reportSnapshot.docs){
          final report = Report.fromFirestore(reportDoc as DocumentSnapshot<Map<String, dynamic>>, null);
          if (report.reportType != null && report.reportEntries != null) {
            if (data[report.reportType!] == null) data[report.reportType!] = {};
            report.reportEntries!.forEach((username, indicatorMap) {
              indicatorMap.forEach((indicator, entryList) {
                if (entryList.isNotEmpty) {
                  if (data[report.reportType!]![indicator] == null) data[report.reportType!]![indicator] = {};
                  data[report.reportType!]![indicator]![username] = entryList.first;
                }
              });
            });
          }
        }

        data.forEach((reportType, indicatorData) {
          indicatorData.forEach((indicator, userData) {
            if(indicator == "Comments") return;
            int rowTotal = 0;
            List<dynamic> row = [facilityName, reportType.replaceAll('_', ' ').toUpperCase(), indicator];
            for(var username in sortedUsernames){
              final value = int.tryParse(userData[username]?.value ?? '0') ?? 0;
              row.add(value);
              rowTotal += value;
            }
            row.add(rowTotal);
            rows.add(row);
          });
        });
      }
    }
    return rows;
  }

  Future<List<List<dynamic>>> _generateWeeklyCsvData() async {
    List<List<dynamic>> rows = [];
    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];
    rows.add(['Facility', 'Designation', 'Indicator', ...weeks, 'Monthly Total']);

    final facilitySnapshot = await FirebaseFirestore.instance.collection('Location').doc(_supervisorBio!.state).collection(_supervisorBio!.state!).where('category', isEqualTo: 'Facility').get();

    for (var facilityDoc in facilitySnapshot.docs) {
      final facilityName = (facilityDoc.data())['LocationName'] ?? '';
      final weeklyData = await _fetchAndAggregateWeeklyDataForFacility(facilityName);

      weeklyData.forEach((reportType, weekData) {
        final allIndicators = weekData.values.expand((map) => map.keys).toSet().toList()..sort();
        for (var indicator in allIndicators) {
          List<dynamic> row = [facilityName, reportType.replaceAll('_', ' ').toUpperCase(), indicator];
          int monthlyTotal = 0;
          for (var week in weeks) {
            final value = weekData[week]?[indicator] ?? 0;
            row.add(value);
            monthlyTotal += value;
          }
          row.add(monthlyTotal);
          rows.add(row);
        }
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Supervisor Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              tooltip: _tabController.index == 0 ? 'Download Daily Summary CSV' : 'Download Weekly Summary CSV',
              onPressed: _isExporting ? null : _exportToCsv,
              icon: _isExporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download_for_offline_outlined),
            ),
          const SizedBox(width: 10),
        ],
        bottom: _isLoading || _errorMessage.isNotEmpty
            ? null
            : TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orangeAccent,
          tabs: const [
            Tab(icon: Icon(Icons.today_outlined), text: 'Daily Summary'),
            Tab(icon: Icon(Icons.calendar_view_week_outlined), text: 'Weekly Summary'),
          ],
        ),
      ),
      drawer: drawer2(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.black87, Colors.yellow.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_errorMessage.isNotEmpty) return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 18)));

    return TabBarView(
      controller: _tabController,
      children: [
        _buildDailySummaryTab(),
        _buildWeeklySummaryTab(),
      ],
    );
  }

  // --- TAB 1: Daily Summary with Search ---
  Widget _buildDailySummaryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMMEEEEd().format(_selectedDailyDate), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text("Selected Date", style: TextStyle(color: Colors.white70)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                onPressed: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: _selectedDailyDate, firstDate: DateTime(2022), lastDate: DateTime.now());
                  if (pickedDate != null && pickedDate != _selectedDailyDate) {
                    setState(() => _selectedDailyDate = pickedDate);
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.grey.shade800),
            decoration: InputDecoration(
              hintText: 'Search by Facility Name...',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: Icon(Icons.clear, color: Colors.grey.shade600), onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
        const Divider(color: Colors.white54, indent: 16, endIndent: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Location').doc(_supervisorBio!.state).collection(_supervisorBio!.state!).where('category', isEqualTo: 'Facility').snapshots(),
            builder: (context, facilitySnapshot) {
              if (facilitySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
              if (!facilitySnapshot.hasData || facilitySnapshot.data!.docs.isEmpty) return const Center(child: Text("No facilities configured for this state.", style: TextStyle(color: Colors.white)));

              var facilityDocs = facilitySnapshot.data!.docs;

              if (_searchQuery.isNotEmpty) {
                facilityDocs = facilityDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final facilityName = (data['LocationName'] as String? ?? '').toLowerCase();
                  return facilityName.contains(_searchQuery);
                }).toList();
              }

              if (facilityDocs.isEmpty) {
                return const Center(child: Text("No facilities match your search.", style: TextStyle(color: Colors.white)));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: facilityDocs.length,
                itemBuilder: (context, index) {
                  final facilityData = facilityDocs[index].data() as Map<String, dynamic>;
                  final facilityName = facilityData['LocationName'] ?? 'Unnamed Facility';
                  return _buildDailyFacilitySummaryCard(facilityName);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: Weekly Summary Segregated by Facility and Designation ---
  Widget _buildWeeklySummaryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: const TextStyle(fontSize: 18)),
            onPressed: () => showMonthPicker(context: context, initialDate: _selectedMonth).then((date) {
              if (date != null) setState(() => _selectedMonth = date);
            }),
          ),
        ),
        const Divider(color: Colors.white54, indent: 16, endIndent: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Location').doc(_supervisorBio!.state).collection(_supervisorBio!.state!).where('category', isEqualTo: 'Facility').snapshots(),
            builder: (context, facilitySnapshot) {
              if (facilitySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
              if (!facilitySnapshot.hasData || facilitySnapshot.data!.docs.isEmpty) return const Center(child: Text("No facilities configured for this state.", style: TextStyle(color: Colors.white)));

              final facilityDocs = facilitySnapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: facilityDocs.length,
                itemBuilder: (context, index) {
                  final facilityData = facilityDocs[index].data() as Map<String, dynamic>;
                  final facilityName = facilityData['LocationName'] ?? 'Unnamed Facility';
                  return _buildWeeklyFacilitySummaryCard(facilityName);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// --- WIDGET FOR DAILY SUMMARY CARD ---
  Widget _buildDailyFacilitySummaryCard(String facilityName) {
    final formattedDate = DateFormat('dd-MMM-yyyy').format(_selectedDailyDate);
    final reportPath = 'Reports/${_supervisorBio!.state}/${_supervisorBio!.state}/$facilityName/$formattedDate';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(facilityName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(reportPath).snapshots(),
              builder: (context, reportSnapshot) {
                if (reportSnapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator());
                if (!reportSnapshot.hasData || reportSnapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('No reports submitted for this facility on this date.')));

                final Map<String, List<Report>> reportsByType = {};
                for (var doc in reportSnapshot.data!.docs) {
                  final report = Report.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
                  if (report.reportType != null) {
                    if (reportsByType[report.reportType!] == null) reportsByType[report.reportType!] = [];
                    reportsByType[report.reportType!]!.add(report);
                  }
                }

                if (reportsByType.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('No valid reports found.')));

                final sortedReportTypes = reportsByType.keys.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedReportTypes.map((reportType) {
                    final reportsForThisType = reportsByType[reportType]!;
                    final Set<String> allUsernames = {};
                    final Map<String, Map<String, ReportEntry>> summaryData = {};

                    for (var report in reportsForThisType) {
                      if (report.reportEntries != null) {
                        report.reportEntries!.forEach((username, indicatorMap) {
                          allUsernames.add(username);
                          indicatorMap.forEach((indicator, entryList) {
                            if (entryList.isNotEmpty) {
                              if (summaryData[indicator] == null) summaryData[indicator] = {};
                              summaryData[indicator]![username] = entryList.first;
                            }
                          });
                        });
                      }
                    }

                    if (allUsernames.isEmpty) return const SizedBox.shrink();

                    final sortedUsernames = allUsernames.toList()..sort();
                    final sortedIndicators = summaryData.keys.toList()..sort();

                    List<DataColumn> columns = [
                      const DataColumn(label: Text('Indicator', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...sortedUsernames.map((name) => DataColumn(label: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)))),
                      const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ];

                    List<DataRow> rows = [];
                    for (var indicator in sortedIndicators) {
                      if (indicator == "Comments") continue;
                      int rowTotal = 0;
                      List<DataCell> cells = [DataCell(Text(indicator))];
                      for (var username in sortedUsernames) {
                        final entry = summaryData[indicator]?[username];
                        final value = int.tryParse(entry?.value ?? '0') ?? 0;
                        rowTotal += value;
                        cells.add(DataCell(_buildCellContent(entry)));
                      }
                      cells.add(DataCell(Text(rowTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                      rows.add(DataRow(cells: cells));
                    }
                    if (summaryData.containsKey("Comments")) {
                      List<DataCell> commentCells = [const DataCell(Text("Comments"))];
                      for (var username in sortedUsernames) {
                        commentCells.add(DataCell(_buildCellContent(summaryData["Comments"]?[username])));
                      }
                      commentCells.add(const DataCell(Text("0", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                      rows.add(DataRow(cells: commentCells));
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reportType.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' '), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(columns: columns, rows: rows, dataRowMinHeight: 60, dataRowMaxHeight: 80),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// --- WIDGET FOR WEEKLY SUMMARY CARD ---
  Widget _buildWeeklyFacilitySummaryCard(String facilityName) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(facilityName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const Divider(),
            FutureBuilder<Map<String, Map<String, Map<String, int>>>>(
              future: _fetchAndAggregateWeeklyDataForFacility(facilityName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator());
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No data found for this facility in the selected month."));

                final dataByReportType = snapshot.data!;
                final sortedReportTypes = dataByReportType.keys.toList()..sort();

                return Column(
                  children: sortedReportTypes.map((reportType) {
                    final weeklySummary = dataByReportType[reportType]!;
                    final allIndicators = weeklySummary.values.expand((map) => map.keys).toSet().toList()..sort();
                    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];

                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reportType.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' '),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Indicator', style: TextStyle(fontWeight: FontWeight.bold))),
                                ...weeks.map((week) => DataColumn(label: Text(week, style: const TextStyle(fontWeight: FontWeight.bold)))),
                                const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              ],
                              rows: allIndicators.map((indicator) {
                                int monthlyTotal = 0;
                                final cells = weeks.map((week) {
                                  final value = weeklySummary[week]?[indicator] ?? 0;
                                  monthlyTotal += value;
                                  return DataCell(Text(value.toString()));
                                }).toList();
                                cells.add(DataCell(Text(monthlyTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold))));
                                return DataRow(cells: [DataCell(SizedBox(width: 250, child: Text(indicator, softWrap: true))), ...cells]);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// --- Fetches weekly data for ONE facility and groups by Report Type ---
  Future<Map<String, Map<String, Map<String, int>>>> _fetchAndAggregateWeeklyDataForFacility(String facilityName) async {
    // Structure: { "report_type": { "Week 1": { "indicator": total } } }
    final Map<String, Map<String, Map<String, int>>> dataByReportType = {};
    if (_supervisorBio == null) return dataByReportType;

    final startDateOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDateOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    for (DateTime date = startDateOfMonth; date.isBefore(endDateOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final reportPath = 'Reports/${_supervisorBio!.state}/${_supervisorBio!.state}/$facilityName/$formattedDate';
      final reportSnapshot = await FirebaseFirestore.instance.collection(reportPath).get();

      for (var doc in reportSnapshot.docs) {
        final report = Report.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
        final reportType = report.reportType;
        final weekIdentifier = report.reportingWeek;

        if (reportType != null && weekIdentifier != null && report.reportEntries != null) {
          if (dataByReportType[reportType] == null) dataByReportType[reportType] = {};
          if (dataByReportType[reportType]![weekIdentifier] == null) dataByReportType[reportType]![weekIdentifier] = {};

          report.reportEntries!.forEach((username, indicatorMap) {
            indicatorMap.forEach((indicator, entryList) {
              if (indicator != "Comments" && entryList.isNotEmpty) {
                final value = int.tryParse(entryList.first.value) ?? 0;
                final currentMap = dataByReportType[reportType]![weekIdentifier]!;
                currentMap[indicator] = (currentMap[indicator] ?? 0) + value;
              }
            });
          });
        }
      }
    }
    return dataByReportType;
  }

  // --- Cell content helper widget ---
  Widget _buildCellContent(ReportEntry? entry) {
    if (entry == null || entry.value.isEmpty) {
      return const Text("0", textAlign: TextAlign.center);
    }

    Color statusColor;
    switch (entry.reviewStatus?.toLowerCase()) {
      case 'approved': statusColor = Colors.green; break;
      case 'returned': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(entry.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Reviewed by: ${entry.reviewedBy ?? 'N/A'}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            children: [
              const TextSpan(text: 'Status: '),
              TextSpan(text: entry.reviewStatus ?? 'Pending', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
        ),
      ],
    );
  }
}