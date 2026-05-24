// A DEDICATED PAGE FOR PSYCHOLOGICAL SURVEY ANALYSIS (PER-FACILITY BREAKDOWN)
//
// FEATURES:
// - Aggregates and displays survey analysis on a PER-FACILITY basis.
// - Uses ExpansionTiles to create a clean, organized, and comparable view.
// - "Best Team Player" scores are scoped to each individual facility.
// - Retains high-performance collectionGroup queries and robust filtering.
// - Uses vertical column charts for clear "Team Player" visualization.
//
// FULL AND COMPLETE CODE - CREATED BY GEMINI

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer2.dart'; // Assuming a shared drawer widget

// --- DATA MODELS & HELPERS ---

// A class to hold the aggregated analysis for a single facility.
class SurveyAnalysisData {
  int totalSurveys = 0;
  Map<String, Map<String, int>> questionAggregates = {};
  List<TeamPlayerScore> teamPlayerScores = [];

  SurveyAnalysisData.empty();
}

class TeamPlayerScore {
  final String name;
  final int score;
  TeamPlayerScore({required this.name, required this.score});
}

class ChartData {
  final String category;
  final num value;
  final Color color;
  ChartData(this.category, this.value, this.color);
}

// AnimatedNumberText can be reused from your other pages for a nice effect
class AnimatedNumberText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumberText(this.value, {super.key, this.style, this.duration = const Duration(milliseconds: 800)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      builder: (context, animatedValue, child) => Text(
        animatedValue.toInt().toString(),
        style: style,
      ),
    );
  }
}

// --- MAIN WIDGET ---

class PsychologicalSurveyAnalysisPage extends StatefulWidget {
  const PsychologicalSurveyAnalysisPage({super.key});

  @override
  _PsychologicalSurveyAnalysisPageState createState() => _PsychologicalSurveyAnalysisPageState();
}

class _PsychologicalSurveyAnalysisPageState extends State<PsychologicalSurveyAnalysisPage> {
  // --- Services & State ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;
  String? _userState;
  bool _hasLoadedData = false;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  List<String> _availableFacilities = [];
  List<String> _selectedFacilities = [];

  // --- Aggregated Data State ---
  Map<String, SurveyAnalysisData> _facilityAnalysisData = {};
  int _totalSurveysAllFacilities = 0;
  late TooltipBehavior _tooltipBehavior;

  // --- Constants for Questions ---
  static const Q_COLLABORATION = 'Is there good collaboration among your team members?';
  static const Q_SUPPORT = 'Do you get good support from your team members?';
  static const Q_CHALLENGE = 'Do you have any challenge carrying out your duties?';
  static const Q_MATERIALS = 'Do you have the needed materials to do your job?';
  static const Q_TEAM_PLAYER = 'For the current week, who is the best team player in your facility';


  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!mounted) return;

      setState(() {
        _userState = staffDoc.data()?['state'] as String?;
      });

      if (_userState != null) {
        final facilitiesSnapshot = await _firestore.collection('Facilities').where('state', isEqualTo: _userState).get();
        final facilities = facilitiesSnapshot.docs
            .map((doc) => doc.data()['LocationName'] as String?)
            .whereType<String>()
            .toList()..sort();

        if (mounted) {
          setState(() {
            _availableFacilities = facilities;
            // By default, select all available facilities
            _selectedFacilities = List.from(facilities);
          });

          // --- ADDED THIS LINE ---
          // After successfully setting the default filters, automatically load the data.
          await _loadSurveyData();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing filters: $e");
    }
  }


  Future<void> _loadSurveyData() async {
    if (_userState == null) {
      setState(() => _errorMessage = "Could not determine user's state.");
      return;
    }
    if (_selectedFacilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one facility.")));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasLoadedData = false;
    });

    try {
      Query<Map<String, dynamic>> query = _firestore.collectionGroup('SurveyResponses')
          .where('State', isEqualTo: _userState)
          .where('date', isGreaterThanOrEqualTo: _startDate)
          .where('date', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)));

      if (_selectedFacilities.length <= 30) {
        query = query.where('FacilityName', whereIn: _selectedFacilities);
      }

      final snapshot = await query.get();
      final docs = _selectedFacilities.length > 30
          ? snapshot.docs.where((doc) => _selectedFacilities.contains(doc.data()['FacilityName'])).toList()
          : snapshot.docs;

      _processAndAggregateData(docs);

    } catch (e, stack) {
      debugPrint("Error loading survey data: $e\n$stack");
      if (mounted) {
        setState(() => _errorMessage = "An error occurred. Make sure the required Firestore index has been created. Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedData = true;
        });
      }
    }
  }

  void _processAndAggregateData(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final perFacilityAggregates = <String, SurveyAnalysisData>{};
    final perFacilityTeamPlayerScores = <String, Map<String, int>>{};

    for (final doc in docs) {
      final docData = doc.data();
      final facilityName = docData['FacilityName'] as String?;
      if (facilityName == null) continue;

      perFacilityAggregates.putIfAbsent(facilityName, () => SurveyAnalysisData.empty());
      perFacilityTeamPlayerScores.putIfAbsent(facilityName, () => {});

      final currentFacilityData = perFacilityAggregates[facilityName]!;
      currentFacilityData.totalSurveys++;

      final surveyDataList = docData['surveyData'] as List? ?? [];

      for (final item in surveyDataList) {
        final surveyItem = item as Map<String, dynamic>;
        final question = surveyItem.keys.firstWhere((k) => k != 'section', orElse: () => '');
        if (question.isEmpty) continue;

        final answer = surveyItem[question];

        if (answer is String && (answer == 'Yes' || answer == 'No')) {
          currentFacilityData.questionAggregates.putIfAbsent(question, () => {'Yes': 0, 'No': 0});
          currentFacilityData.questionAggregates[question]![answer] = (currentFacilityData.questionAggregates[question]![answer] ?? 0) + 1;
        }
        else if (question == Q_TEAM_PLAYER && answer is List) {
          final facilityScores = perFacilityTeamPlayerScores[facilityName]!;
          for (int i = 0; i < answer.length; i++) {
            final player = answer[i] as Map<String, dynamic>;
            final playerName = player['name'] as String?;
            if (playerName == null || playerName.isEmpty) continue;
            int points = (i < 3) ? 3 - i : 0;
            if (points > 0) {
              facilityScores[playerName] = (facilityScores[playerName] ?? 0) + points;
            }
          }
        }
      }
    }

    perFacilityAggregates.forEach((facilityName, data) {
      final scores = perFacilityTeamPlayerScores[facilityName] ?? {};
      final sortedScores = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      data.teamPlayerScores = sortedScores.map((e) => TeamPlayerScore(name: e.key, score: e.value)).toList();
    });

    setState(() {
      _facilityAnalysisData = perFacilityAggregates;
      _totalSurveysAllFacilities = docs.length;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Survey Analysis',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)
        ),
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
          _isLoading
              ? const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))),
          )
              : IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadSurveyData,
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: drawer2(context),
      body: SelectionArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16))))
                  : !_hasLoadedData
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Please select filters and click 'Analyze Surveys' to view data.", style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleMedium), textAlign: TextAlign.center,),
              ))
                  : _buildDashboardContent(),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            ),
            if (_availableFacilities.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: MultiSelectDialogField(
                  items: _availableFacilities.map((f) => MultiSelectItem<String>(f, f)).toList(),
                  initialValue: _selectedFacilities,
                  title: const Text("Select Facilities"),
                  buttonIcon: const Icon(Icons.location_city, color: Colors.teal),
                  buttonText: Text(
                    "Facilities (${_selectedFacilities.length})",
                    style: TextStyle(color: Colors.teal[800], fontSize: 16),
                  ),
                  onConfirm: (results) => setState(() => _selectedFacilities = results.cast<String>()),
                  chipDisplay: MultiSelectChipDisplay.none(),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(color: Colors.teal, width: 1),
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined),
              label: Text('Analyze Surveys', style: GoogleFonts.poppins()),
              onPressed: _isLoading ? null : _loadSurveyData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C1A2E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_totalSurveysAllFacilities == 0) {
      return const Center(child: Text("No survey data found for the selected criteria."));
    }

    final sortedFacilityNames = _facilityAnalysisData.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKpiSection(),
          const SizedBox(height: 24),
          Text(
              "Per-Facility Analysis Breakdown",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
          ),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedFacilityNames.length,
            itemBuilder: (context, index) {
              final facilityName = sortedFacilityNames[index];
              final facilityData = _facilityAnalysisData[facilityName]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.grey.shade50,
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(facilityData.totalSurveys.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  title: Text(
                    facilityName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: const Text("Tap to view detailed analysis"),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFacilityAnalysisDetails(facilityData),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityAnalysisDetails(SurveyAnalysisData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnalysisSection(
          title: "Team Spirit",
          children: [
            _buildYesNoPieChart(Q_COLLABORATION, ['Good', 'Lacking'], data.questionAggregates),
            _buildYesNoPieChart(Q_SUPPORT, ['Supported', 'Unsupported'], data.questionAggregates),
          ],
        ),
        const SizedBox(height: 24),
        _buildAnalysisSection(
          title: "Attitude to Work & Environment",
          children: [
            _buildYesNoPieChart(Q_CHALLENGE, ['Challenged', 'Unchallenged'], data.questionAggregates),
            _buildYesNoPieChart(Q_MATERIALS, ['Equipped', 'Unequipped'], data.questionAggregates),
          ],
        ),
        const SizedBox(height: 24),
        _buildAnalysisSection(
          title: "Team Player Recognition",
          children: [
            _buildTeamPlayerChart(data.teamPlayerScores),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Surveys Submitted", _totalSurveysAllFacilities, Icons.poll_outlined, Colors.blue.shade700),
        _buildKpiCard("Facilities Responding", _facilityAnalysisData.keys.length, Icons.location_city, Colors.green.shade700),
      ],
    );
  }

  Widget _buildKpiCard(String title, num value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 280,
        child: Row(
          children: [
            CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumberText(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.teal)),
        const Divider(color: Colors.teal, thickness: 1.5),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceEvenly,
          children: children,
        )
      ],
    );
  }

  Widget _buildYesNoPieChart(String question, List<String> labels, Map<String, Map<String, int>> questionAggregates) {
    final data = questionAggregates[question] ?? {'Yes': 0, 'No': 0};
    final yesCount = data['Yes']!;
    final noCount = data['No']!;
    final total = yesCount + noCount;

    if (total == 0) return _buildChartCard(title: question, child: const Center(child: Text("No data for this question.")));

    final chartData = [
      ChartData(labels[0], yesCount, Colors.green.shade400),
      ChartData(labels[1], noCount, Colors.red.shade400),
    ];

    return _buildChartCard(
      title: question,
      child: SfCircularChart(
        tooltipBehavior: _tooltipBehavior,
        legend: const Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
        series: <CircularSeries>[
          PieSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (d, _) => d.category,
            yValueMapper: (d, _) => d.value,
            pointColorMapper: (d, _) => d.color,
            dataLabelMapper: (d, _) => '${d.value} (${(d.value / total * 100).toStringAsFixed(0)}%)',
            dataLabelSettings: const DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside),
          )
        ],
      ),
    );
  }

  Widget _buildTeamPlayerChart(List<TeamPlayerScore> teamPlayerScores) {
    const chartTitle = "Top Team Players (Points-Based)";
    if (teamPlayerScores.isEmpty) {
      return _buildChartCard(
        title: chartTitle,
        child: const Center(child: Text("No team player data submitted for this facility.")),
      );
    }
    return _buildChartCard(
      title: chartTitle,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelRotation: -45,
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: "Points Score"),
          majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5]),
          isVisible: true,
        ),
        tooltipBehavior: _tooltipBehavior,
        series: <CartesianSeries>[
          // Switched to ColumnSeries for vertical bars
          ColumnSeries<TeamPlayerScore, String>(
            dataSource: teamPlayerScores.take(10).toList(), // Show top 10
            xValueMapper: (d, _) => d.name,
            yValueMapper: (d, _) => d.score,
            name: "Score",
            color: Colors.amber.shade700,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            // Data labels are now on top of the columns
            dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.top
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width > 600 ? 500 : MediaQuery.of(context).size.width - 32, // Responsive width
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
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
                  _endDate = value.endDate ?? value.startDate ?? _endDate;
                });
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}