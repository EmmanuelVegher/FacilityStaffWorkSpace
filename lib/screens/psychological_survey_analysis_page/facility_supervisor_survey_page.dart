import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer2.dart';
import '../../widgets/drawer4.dart'; // Assuming a shared drawer widget

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

// Reusable animated number widget for KPIs
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

class FacilitySupervisorPsychologicalSurveyAnalysisPage extends StatefulWidget {
  const FacilitySupervisorPsychologicalSurveyAnalysisPage({super.key});

  @override
  _FacilitySupervisorPsychologicalSurveyAnalysisPageState createState() => _FacilitySupervisorPsychologicalSurveyAnalysisPageState();
}

class _FacilitySupervisorPsychologicalSurveyAnalysisPageState extends State<FacilitySupervisorPsychologicalSurveyAnalysisPage> {
  // --- Services & State ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasLoadedData = false;

  // --- User & Filter State ---
  String? _userState;
  String? _userLocation; // KEY CHANGE: We now store the user's specific location
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  // --- Aggregated Data State ---
  SurveyAnalysisData _facilityAnalysisData = SurveyAnalysisData.empty();
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
    _initializeUserAndLoadData();
  }

  // KEY CHANGE: Renamed and simplified initialization
  Future<void> _initializeUserAndLoadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      if (!mounted) return;

      if (staffDoc.exists) {
        setState(() {
          _userState = staffDoc.data()?['state'] as String?;
          _userLocation = staffDoc.data()?['location'] as String?; // Fetch the user's location
        });

        if (_userState != null && _userLocation != null) {
          // Automatically load data after discovering user's location
          await _loadSurveyData();
        } else {
          throw Exception("User state or location is missing from profile.");
        }
      } else {
        throw Exception("User profile not found.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error initializing: $e";
          _isLoading = false;
        });
      }
    }
  }

  // KEY CHANGE: This function is now simpler and more focused
  Future<void> _loadSurveyData() async {
    if (_userState == null || _userLocation == null) {
      setState(() => _errorMessage = "Could not determine user's state and location.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasLoadedData = false;
    });

    try {
      // The query is now much more specific and efficient
      final query = _firestore.collectionGroup('SurveyResponses')
          .where('State', isEqualTo: _userState)
          .where('FacilityName', isEqualTo: _userLocation) // Filter by the user's specific facility
          .where('date', isGreaterThanOrEqualTo: _startDate)
          .where('date', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)));

      final snapshot = await query.get();
      _processAndAggregateData(snapshot.docs);

    } catch (e, stack) {
      debugPrint("Error loading survey data: $e\n$stack");
      if (mounted) {
        setState(() => _errorMessage = "An error occurred while fetching data. Please check Firestore indexes. Error: $e");
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
    final facilityData = SurveyAnalysisData.empty();
    final teamPlayerScores = <String, int>{};

    facilityData.totalSurveys = docs.length;

    for (final doc in docs) {
      final docData = doc.data();
      final surveyDataList = docData['surveyData'] as List? ?? [];

      for (final item in surveyDataList) {
        final surveyItem = item as Map<String, dynamic>;
        final question = surveyItem.keys.firstWhere((k) => k != 'section', orElse: () => '');
        if (question.isEmpty) continue;

        final answer = surveyItem[question];

        // Aggregate Yes/No answers
        if (answer is String && (answer == 'Yes' || answer == 'No')) {
          facilityData.questionAggregates.putIfAbsent(question, () => {'Yes': 0, 'No': 0});
          facilityData.questionAggregates[question]![answer] = (facilityData.questionAggregates[question]![answer] ?? 0) + 1;
        }
        // Aggregate Team Player points
        else if (question == Q_TEAM_PLAYER && answer is List) {
          for (int i = 0; i < answer.length; i++) {
            final player = answer[i] as Map<String, dynamic>;
            final playerName = player['name'] as String?;
            if (playerName == null || playerName.isEmpty) continue;
            // Award 3 points for 1st, 2 for 2nd, 1 for 3rd
            int points = (i < 3) ? 3 - i : 0;
            if (points > 0) {
              teamPlayerScores[playerName] = (teamPlayerScores[playerName] ?? 0) + points;
            }
          }
        }
      }
    }

    // Sort team player scores and update the analysis object
    final sortedScores = teamPlayerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    facilityData.teamPlayerScores = sortedScores.map((e) => TeamPlayerScore(name: e.key, score: e.value)).toList();

    setState(() {
      _facilityAnalysisData = facilityData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Survey Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF722F37), Color(0xFFB34A5A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        actions: [
          _isLoading
              ? const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
          )
              : IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadSurveyData,
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: drawer4(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16))))
                : !_hasLoadedData
                ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Click 'Analyze Surveys' to view data.", style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center)))
                : _buildDashboardContent(),
          ),
        ],
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
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyze Surveys'),
              onPressed: _isLoading ? null : _loadSurveyData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_facilityAnalysisData.totalSurveys == 0) {
      return const Center(child: Text("No survey data found for your facility in the selected date range."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              "Analysis for: ${_userLocation ?? 'Your Facility'}",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
          ),
          Text(
              "Total Surveys Submitted: ${_facilityAnalysisData.totalSurveys}",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700)
          ),
          const SizedBox(height: 24),
          _buildAnalysisSection(
            title: "Team Spirit",
            children: [
              _buildYesNoPieChart(Q_COLLABORATION, ['Good', 'Lacking'], _facilityAnalysisData.questionAggregates),
              _buildYesNoPieChart(Q_SUPPORT, ['Supported', 'Unsupported'], _facilityAnalysisData.questionAggregates),
            ],
          ),
          const SizedBox(height: 24),
          _buildAnalysisSection(
            title: "Attitude to Work & Environment",
            children: [
              _buildYesNoPieChart(Q_CHALLENGE, ['Challenged', 'Unchallenged'], _facilityAnalysisData.questionAggregates),
              _buildYesNoPieChart(Q_MATERIALS, ['Equipped', 'Unequipped'], _facilityAnalysisData.questionAggregates),
            ],
          ),
          const SizedBox(height: 24),
          _buildAnalysisSection(
            title: "Team Player Recognition",
            children: [
              _buildTeamPlayerChart(_facilityAnalysisData.teamPlayerScores),
            ],
          ),
        ],
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
        LayoutBuilder(
          builder: (context, constraints) {
            // Use a Column for narrow screens, a Wrap for wider screens
            if (constraints.maxWidth < 600) {
              return Column(
                children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: child)).toList(),
              );
            } else {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceEvenly,
                children: children,
              );
            }
          },
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
        child: const Center(child: Text("No team player data submitted.")),
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
          majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5]),
        ),
        tooltipBehavior: _tooltipBehavior,
        series: <CartesianSeries>[
          ColumnSeries<TeamPlayerScore, String>(
            dataSource: teamPlayerScores.take(10).toList(), // Show top 10
            xValueMapper: (d, _) => d.name,
            yValueMapper: (d, _) => d.score,
            name: "Score",
            color: Colors.amber.shade700,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            dataLabelSettings: const DataLabelSettings(
                isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              // Make width responsive
              width: constraints.maxWidth < 600 ? double.infinity : 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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