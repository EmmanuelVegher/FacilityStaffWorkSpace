import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Make sure to import your Report and BioModel classes
// Adjust the path as per your project structure
import '../activity_monitoring/activity_monitoring_page.dart';


// A model to hold the structured summary data
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
  DateTime _selectedDate = DateTime.now();

  BioModel? _supervisorBio;
  bool _isLoading = true; // To show a loading indicator while fetching bio
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSupervisorBio();
  }

  // --- NEW METHOD: Fetches current user's data ---
  Future<void> _fetchSupervisorBio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Authentication error. Please log in again.";
      });
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      if (docSnapshot.exists) {
        // We can use your existing BioModel.fromFirestore factory
        final bio = BioModel.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>, null);
        setState(() {
          _supervisorBio = bio;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not find your staff profile. Please contact support.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An error occurred while fetching your profile.";
      });
    }
  }



  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Supervisor Task Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // Only show the TabBar if data has loaded successfully
        bottom: _isLoading || _errorMessage.isNotEmpty
            ? null
            : TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orangeAccent,
          tabs: const [
            Tab(icon: Icon(Icons.summarize_outlined), text: 'Task Summary'),
            Tab(icon: Icon(Icons.checklist_rtl_outlined), text: 'Review Approvals'),
          ],
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.black87, Colors.white, Colors.yellow.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }


  // --- NEW: Helper to decide what to show based on loading state ---
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 18)));
    }

    // If loading is done and there are no errors, build the main UI
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTaskSummaryTab(),
        _buildReviewApprovalsTab(),
      ],
    );
  }


  // --- TAB 1: Task Summary ---
// In _SupervisorTaskSummaryPageState class

  // --- TAB 1: Task Summary ---
  Widget _buildTaskSummaryTab() {
    // This method now safely assumes _supervisorBio is not null
    return Column(
      children: [
        // Date Picker UI
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd().format(_selectedDate),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text("Selected Date", style: TextStyle(color: Colors.white70)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white54),

        // --- NEW, CORRECTED QUERY LOGIC ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // STEP 1: Query the 'Location' collection to get all facilities for the supervisor's state.
            stream: FirebaseFirestore.instance
                .collection('Location')
                .doc(_supervisorBio!.state) // Use the STATE ID (e.g., 'Enugu' doc ID)
                .collection(_supervisorBio!.state!) // Go into the subcollection
                .where('category', isEqualTo: 'Facility') // Filter for only facilities
                .snapshots(),
            builder: (context, facilitySnapshot) {
              if (facilitySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (facilitySnapshot.hasError) {
                return Center(child: Text('Error fetching facilities: ${facilitySnapshot.error}', style: const TextStyle(color: Colors.white)));
              }
              if (!facilitySnapshot.hasData || facilitySnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No facilities found for this state.', style: TextStyle(color: Colors.white, fontSize: 18)));
              }

              final facilityDocs = facilitySnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80), // Add padding for FAB
                itemCount: facilityDocs.length,
                itemBuilder: (context, index) {
                  final facilityData = facilityDocs[index].data() as Map<String, dynamic>;
                  final facilityName = facilityData['LocationName'] ?? 'Unnamed Facility';

                  // STEP 2: Pass the facility name to the card, which will fetch the specific reports for that facility.
                  return _buildFacilitySummaryCard(facilityName);
                },
              );
            },
          ),
        ),
      ],
    );
  }

// In _SupervisorTaskSummaryPageState class

  Widget _buildCellContent(ReportEntry? entry) {
    if (entry == null || entry.value.isEmpty) {
      return const Text("0", textAlign: TextAlign.center);
    }

    Color statusColor;
    switch (entry.reviewStatus?.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'returned':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          entry.value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "Reviewed by: ${entry.reviewedBy ?? 'N/A'}",
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            children: [
              const TextSpan(text: 'Status: '),
              TextSpan(
                text: entry.reviewStatus ?? 'Pending',
                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- REWRITTEN: Widget to build the summary card and DYNAMIC TABLES for each report type ---
  Widget _buildFacilitySummaryCard(String facilityName) {
    final formattedDate = DateFormat('dd-MMM-yyyy').format(_selectedDate);
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
            Text(
              facilityName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
            const Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(reportPath).snapshots(),
              builder: (context, reportSnapshot) {
                if (reportSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                }
                if (!reportSnapshot.hasData || reportSnapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('No reports submitted for this facility on this date.')),
                  );
                }

                // --- NEW CORE LOGIC: Group reports by their 'reportType' ---
                final Map<String, List<Report>> reportsByType = {};
                for (var doc in reportSnapshot.data!.docs) {
                  final report = Report.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
                  if (report.reportType != null) {
                    if (reportsByType[report.reportType!] == null) {
                      reportsByType[report.reportType!] = [];
                    }
                    reportsByType[report.reportType!]!.add(report);
                  }
                }

                if (reportsByType.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('No valid reports found.')),
                  );
                }

                // --- Generate a list of widgets, one for each table ---
                final sortedReportTypes = reportsByType.keys.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedReportTypes.map((reportType) {
                    // Pre-process data for this specific table
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

                    // Prepare columns and rows for this specific table
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
                    // Manually add the "Comments" row at the end
                    if (summaryData.containsKey("Comments")) {
                      List<DataCell> commentCells = [const DataCell(Text("Comments"))];
                      for (var username in sortedUsernames) {
                        commentCells.add(DataCell(_buildCellContent(summaryData["Comments"]?[username])));
                      }
                      commentCells.add(const DataCell(Text("0", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                      rows.add(DataRow(cells: commentCells));
                    }

                    // Return a widget containing the title and the table for this report type
                    return Padding(
                      padding: const EdgeInsets.only(top: 24.0),
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
                              columns: columns,
                              rows: rows,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 80,
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

  // --- TAB 2: Review Approvals (Placeholder) ---
  Widget _buildReviewApprovalsTab() {
    return const Center(
      child: Text(
        'Review and Approvals Page\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}