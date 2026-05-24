import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

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

  // --- Theme Colors ---
  static const Color maroonPrimary = Color(0xFF5C1A2E);
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
        title: Text('Facility Survey Analysis', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
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
      body: SelectionArea( // Wrapped in SelectionArea for copyable text
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: maroonPrimary))
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red, fontSize: 16))))
                  : !_hasLoadedData
                  ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Click 'Analyze Surveys' to view data.", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center)))
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
      margin: const EdgeInsets.all(12.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined, color: maroonPrimary),
              label: Text(
                '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(color: maroonPrimary, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: maroonPrimary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics_outlined),
              label: Text('Analyze Surveys', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              onPressed: _isLoading ? null : _loadSurveyData,
              style: ElevatedButton.styleFrom(
                backgroundColor: maroonPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_facilityAnalysisData.totalSurveys == 0) {
      return Center(child: Text("No survey data found for your facility in the selected date range.", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Analysis for: ${_userLocation ?? 'Your Facility'}",
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: maroonPrimary)
                  ),
                  const SizedBox(height: 4),
                  Text(
                      "Total Surveys Submitted: ${_facilityAnalysisData.totalSurveys}",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildAnalysisSection(
            title: "Team Spirit",
            children: [
              _buildYesNoPieChart(Q_COLLABORATION, ['Good', 'Lacking'], _facilityAnalysisData.questionAggregates),
              _buildYesNoPieChart(Q_SUPPORT, ['Supported', 'Unsupported'], _facilityAnalysisData.questionAggregates),
            ],
          ),
          const SizedBox(height: 32),
          _buildAnalysisSection(
            title: "Attitude to Work & Environment",
            children: [
              _buildYesNoPieChart(Q_CHALLENGE, ['Challenged', 'Unchallenged'], _facilityAnalysisData.questionAggregates),
              _buildYesNoPieChart(Q_MATERIALS, ['Equipped', 'Unequipped'], _facilityAnalysisData.questionAggregates),
            ],
          ),
          const SizedBox(height: 32),
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
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: maroonPrimary)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Divider(color: maroonPrimary, thickness: 2),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Use a Column for narrow screens, a Wrap for wider screens
            if (constraints.maxWidth < 700) {
              return Column(
                children: children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 24.0), child: child)).toList(),
              );
            } else {
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.spaceEvenly,
                children: children.map((child) => SizedBox(width: (constraints.maxWidth - 64) / 2, child: child)).toList(),
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

    if (total == 0) return _buildChartCard(title: question, child: Center(child: Text("No data for this question.", style: GoogleFonts.poppins(color: Colors.grey))));

    final chartData = [
      ChartData(labels[0], yesCount, const Color(0xFF4CAF50)),
      ChartData(labels[1], noCount, const Color(0xFFE53935)),
    ];

    return _buildChartCard(
      title: question,
      child: SfCircularChart(
        tooltipBehavior: _tooltipBehavior,
        legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap, textStyle: GoogleFonts.poppins()),
        series: <CircularSeries>[
          PieSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (d, _) => d.category,
            yValueMapper: (d, _) => d.value,
            pointColorMapper: (d, _) => d.color,
            dataLabelMapper: (d, _) => '${d.value} (${(d.value / total * 100).toStringAsFixed(0)}%)',
            dataLabelSettings: DataLabelSettings(isVisible: true, labelPosition: ChartDataLabelPosition.outside, textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
        child: Center(child: Text("No team player data submitted.", style: GoogleFonts.poppins(color: Colors.grey))),
      );
    }
    return _buildChartCard(
      title: chartTitle,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelRotation: -45,
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: GoogleFonts.poppins(),
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(text: "Points Score", textStyle: GoogleFonts.poppins()),
          majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5, 5]),
          labelStyle: GoogleFonts.poppins(),
        ),
        tooltipBehavior: _tooltipBehavior,
        series: <CartesianSeries>[
          ColumnSeries<TeamPlayerScore, String>(
            dataSource: teamPlayerScores.take(10).toList(), // Show top 10
            xValueMapper: (d, _) => d.name,
            yValueMapper: (d, _) => d.score,
            name: "Score",
            color: const Color(0xFFFFB300), // Gold/Amber
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            dataLabelSettings: DataLabelSettings(
                isVisible: true, 
                labelAlignment: ChartDataLabelAlignment.top,
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
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
        title: Text('Select Date Range', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          height: 350,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            maxDate: DateTime.now(),
            showActionButtons: true,
            headerStyle: DateRangePickerHeaderStyle(textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            monthCellStyle: DateRangePickerMonthCellStyle(textStyle: GoogleFonts.poppins()),
            selectionTextStyle: GoogleFonts.poppins(color: Colors.white),
            rangeTextStyle: GoogleFonts.poppins(),
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