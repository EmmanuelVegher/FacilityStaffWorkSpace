// lib/pages/reports/state_survey_analysis_page.dart

// A STATE-LEVEL PAGE FOR PSYCHOLOGICAL SURVEY ANALYSIS (PER-FACILITY BREAKDOWN)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer3.dart';

// --- DATA MODELS & HELPERS ---
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
class StateSurveyAnalysisPage extends StatefulWidget {
  const StateSurveyAnalysisPage({super.key});
  @override
  _StateSurveyAnalysisPageState createState() => _StateSurveyAnalysisPageState();
}

class _StateSurveyAnalysisPageState extends State<StateSurveyAnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _hasLoadedData = false;
  bool _isFilterLoading = true;

  // --- Filter State ---
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  List<String> _availableStates = [];
  List<String> _selectedStates = ['All States'];
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
    // 1. Indicate that the filter UI is being prepared.
    setState(() => _isFilterLoading = true);
    try {
      final facilitiesSnapshot = await _firestore.collection('Facilities').get();
      if (!mounted) return;

      final states = facilitiesSnapshot.docs
          .map((doc) => (doc.data())['state'] as String?)
          .whereType<String>()
          .toSet()
          .toList()..sort();

      // 2. The filter UI is now ready with available states.
      // The default selection is already set to ['All States'].
      setState(() {
        _availableStates = ['All States', ...states];
        _isFilterLoading = false; // The filter bar can now be built.
      });

      // 3. With filters initialized, automatically trigger the data load.
      // _loadSurveyData will handle its own main loading indicator (_isLoading).
      await _loadSurveyData();

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error initializing page: $e";
          _isFilterLoading = false; // Ensure filter loader is off on error.
        });
      }
    }
  }

  Future<void> _onStatesChanged(List<String> newStates) async {
    setState(() {
      _selectedStates = newStates;
      _isLoading = true;
      _availableFacilities.clear();
      _selectedFacilities.clear();
    });

    if (newStates.contains('All States') || newStates.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      Query query = _firestore.collection('Facilities').where('state', whereIn: newStates);
      final snapshot = await query.get();

      // --- THIS IS THE CORRECTED LINE ---
      final facilities = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['LocationName'] as String?)
          .whereType<String>()
          .toSet()
          .toList()..sort();

      if(mounted) {
        setState(() {
          _availableFacilities = facilities;
          _selectedFacilities = List.from(facilities);
        });
      }
    } catch (e) {
      if(mounted) setState(() => _errorMessage = "Error fetching facilities: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSurveyData() async {
    if (_selectedStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one state.")));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasLoadedData = false;
    });

    try {
      Query<Map<String, dynamic>> query = _firestore.collectionGroup('SurveyResponses')
          .where('date', isGreaterThanOrEqualTo: _startDate)
          .where('date', isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)));

      if (!_selectedStates.contains('All States')) {
        query = query.where('State', whereIn: _selectedStates);
      }

      if (!_selectedStates.contains('All States') && _selectedFacilities.isNotEmpty) {
        if (_selectedFacilities.length <= 30) {
          query = query.where('FacilityName', whereIn: _selectedFacilities);
        }
      }

      final snapshot = await query.get();
      final docs = (_selectedFacilities.isNotEmpty && _selectedFacilities.length > 30)
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF722F37), Color(0xFFB34A5A)],
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
      drawer: drawer3(context),
      body: Column(
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
              child: Text("Please select filters and click 'Analyze Surveys' to view data.", style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center,),
            ))
                : _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isFilterLoading
            ? const Center(child: CircularProgressIndicator())
            : Wrap(
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
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: MultiSelectDialogField(
                items: _availableStates.map((s) => MultiSelectItem<String>(s, s)).toList(),
                initialValue: _selectedStates,
                title: const Text("Select States"),
                buttonIcon: const Icon(Icons.map_outlined, color: Colors.teal),
                buttonText: Text(
                  "States (${_selectedStates.contains('All States') ? 'All' : _selectedStates.length})",
                  style: TextStyle(color: Colors.teal[800], fontSize: 16),
                ),
                onConfirm: (results) => _onStatesChanged(results.cast<String>()),
                chipDisplay: MultiSelectChipDisplay.none(),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: const BorderRadius.all(Radius.circular(8)), border: Border.all(color: Colors.teal, width: 1)),
              ),
            ),
            if (!_selectedStates.contains('All States') && _availableFacilities.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: MultiSelectDialogField(
                  items: _availableFacilities.map((f) => MultiSelectItem<String>(f, f)).toList(),
                  initialValue: _selectedFacilities,
                  title: const Text("Select Facilities"),
                  buttonIcon: const Icon(Icons.location_city, color: Colors.teal),
                  buttonText: Text("Facilities (${_selectedFacilities.length})", style: TextStyle(color: Colors.teal[800], fontSize: 16)),
                  onConfirm: (results) => setState(() => _selectedFacilities = results.cast<String>()),
                  chipDisplay: MultiSelectChipDisplay.none(),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: const BorderRadius.all(Radius.circular(8)), border: Border.all(color: Colors.teal, width: 1)),
                ),
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
          Text("Per-Facility Analysis Breakdown", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                  leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: Text(facilityData.totalSurveys.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                  title: Text(facilityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: const Text("Tap to view detailed analysis"),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildFacilityAnalysisDetails(facilityData)],
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
        _buildAnalysisSection(title: "Team Spirit", children: [
          _buildYesNoPieChart(Q_COLLABORATION, ['Good', 'Lacking'], data.questionAggregates),
          _buildYesNoPieChart(Q_SUPPORT, ['Supported', 'Unsupported'], data.questionAggregates),
        ]),
        const SizedBox(height: 24),
        _buildAnalysisSection(title: "Attitude to Work & Environment", children: [
          _buildYesNoPieChart(Q_CHALLENGE, ['Challenged', 'Unchallenged'], data.questionAggregates),
          _buildYesNoPieChart(Q_MATERIALS, ['Equipped', 'Unequipped'], data.questionAggregates),
        ]),
        const SizedBox(height: 24),
        _buildAnalysisSection(title: "Team Player Recognition", children: [
          _buildTeamPlayerChart(data.teamPlayerScores),
        ]),
      ],
    );
  }

  Widget _buildKpiSection() {
    return Wrap(
      spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
      children: [
        _buildKpiCard("Total Surveys Submitted", _totalSurveysAllFacilities, Icons.poll_outlined, Colors.blue.shade700),
        _buildKpiCard("Facilities Responding", _facilityAnalysisData.keys.length, Icons.location_city, Colors.green.shade700),
      ],
    );
  }

  Widget _buildKpiCard(String title, num value, IconData icon, Color color) {
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16), width: 280,
        child: Row(
          children: [
            CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 28, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
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
        Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.spaceEvenly, children: children)
      ],
    );
  }

  Widget _buildYesNoPieChart(String question, List<String> labels, Map<String, Map<String, int>> questionAggregates) {
    final data = questionAggregates[question] ?? {'Yes': 0, 'No': 0};
    final yesCount = data['Yes']!;
    final noCount = data['No']!;
    final total = yesCount + noCount;
    if (total == 0) return _buildChartCard(title: question, child: const Center(child: Text("No data for this question.")));

    final chartData = [ChartData(labels[0], yesCount, Colors.green.shade400), ChartData(labels[1], noCount, Colors.red.shade400)];

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
      return _buildChartCard(title: chartTitle, child: const Center(child: Text("No team player data submitted for this facility.")));
    }
    return _buildChartCard(
      title: chartTitle,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(labelRotation: -45, labelIntersectAction: AxisLabelIntersectAction.rotate45, majorGridLines: const MajorGridLines(width: 0)),
        primaryYAxis: NumericAxis(title: AxisTitle(text: "Points Score"), majorGridLines: const MajorGridLines(width: 0.5, dashArray: [5,5]), isVisible: true),
        tooltipBehavior: _tooltipBehavior,
        series: <CartesianSeries>[
          ColumnSeries<TeamPlayerScore, String>(
            dataSource: teamPlayerScores.take(10).toList(),
            xValueMapper: (d, _) => d.name,
            yValueMapper: (d, _) => d.score,
            name: "Score",
            color: Colors.amber.shade700,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            dataLabelSettings: const DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16), width: 500, height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
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
        content: SizedBox(width: 350, height: 350,
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