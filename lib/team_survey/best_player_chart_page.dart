import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/facility_staff_model.dart'; // Make sure this path is correct for web

class BestPlayerChartPage extends StatefulWidget {
  const BestPlayerChartPage({super.key});

  @override
  _BestPlayerChartPageState createState() => _BestPlayerChartPageState();
}

class _BestPlayerChartPageState extends State<BestPlayerChartPage> {
  Map<String, int> _firestoreBestPlayerCounts = {};
  bool _isLoadingFirestore = true;
  FacilityStaffModel? _bestPlayerOfWeek;

  @override
  void initState() {
    super.initState();
    _loadFirestoreData();
  }


  Future<void> _loadFirestoreData() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    print("_loadFirestoreData ==_loadFirestoreData");

    try {
      // Fetch responses for the current date
      final querySnapshot = await firestore
          .collection('PsychologicalMetrics')
          .doc('responses')
          .collection('responses')
          .where('date', isEqualTo: formattedDate)
          .get();

      print("querySnapshot ==$querySnapshot");

      if (querySnapshot.docs.isNotEmpty) {
        final bestPlayerCounts = <String, int>{};

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          print("data ==$data");

          if (data.containsKey('surveyData')) {
            final surveyDataList = data['surveyData'] as List;

            for (var surveyData in surveyDataList) {
              // Check if surveyData is a Map
              if (surveyData is Map<String, dynamic>) {
                print("surveyData ==$surveyData");
                if (surveyData.containsKey(
                    "For the current week, who is the best team player in your facility")) {
                  final bestPlayerString = surveyData[
                  "For the current week, who is the best team player in your facility"];

                  try {
                    // Decode the JSON string into a List
                    final bestPlayerList = json.decode(bestPlayerString) as List;

                    print("bestPlayerList ==$bestPlayerList");
                    for (var player in bestPlayerList) {
                      if (player is Map<String, dynamic> &&
                          player.containsKey('name')) {
                        final playerName = player['name'] as String;
                        bestPlayerCounts[playerName] =
                            (bestPlayerCounts[playerName] ?? 0) + 1;
                      }
                    }
                  } catch (e) {
                    print("Error decoding JSON string: $e");
                  }
                }
              } else {
                print("Unexpected surveyData format: $surveyData");
              }
            }
          }
        }

        String? bestPlayerName;
        int maxCount = 0;
        _firestoreBestPlayerCounts.forEach((playerName, count) {
          if (count > maxCount) {
            maxCount = count;
            bestPlayerName = playerName;
          }
        });
        if (bestPlayerName != null) {
          _bestPlayerOfWeek = FacilityStaffModel(name: bestPlayerName);
        } else {
          _bestPlayerOfWeek = null;
        }


        // Update state with the retrieved data
        setState(() {
          _firestoreBestPlayerCounts = bestPlayerCounts;
          _isLoadingFirestore = false;
        });
      } else {
        // No data found for the current date
        setState(() => _isLoadingFirestore = false);
      }
    } catch (e) {
      print('Error loading Firestore data: $e');
      setState(() => _isLoadingFirestore = false);
    }
  }


  Widget _buildFirestoreChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What the view of everyone is",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SfCartesianChart(
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[
            BarSeries<MapEntry<String, int>, String>(
              dataSource: _firestoreBestPlayerCounts.entries.toList(),
              xValueMapper: (entry, _) => entry.key,
              yValueMapper: (entry, _) => entry.value,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecognitionCard() {
    if (_bestPlayerOfWeek == null) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Icon(Icons.star, color: Colors.orange, size: 50),
          const Text(
            "Best Team Player of the Week",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _bestPlayerOfWeek!.name ?? "Unknown",
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecognitionCard1() {

    if (_bestPlayerOfWeek == null) {
      return const SizedBox.shrink();
    }


    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row( // Star and Name Row
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 32),
                const SizedBox(width: 8),
                Text(
                  _bestPlayerOfWeek!.name!,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: Colors.amber, size: 32),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Best team player from your facility for the week!',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),

            // ... (Add more recognition elements as needed)
          ],
        ),
      ),
    );


  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Player Charts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _isLoadingFirestore ? const CircularProgressIndicator() : _buildRecognitionCard(),
            const SizedBox(height: 20),
            _isLoadingFirestore
                ? const CircularProgressIndicator()
                : _buildFirestoreChart(),
          ],
        ),
      ),
    );
  }
}