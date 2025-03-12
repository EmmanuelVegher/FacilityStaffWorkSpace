import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import '../models/facility_staff_model.dart';

class BestPlayerChartPage extends StatefulWidget {
  const BestPlayerChartPage({super.key});

  @override
  _BestPlayerChartPageState createState() => _BestPlayerChartPageState();
}

class _BestPlayerChartPageState extends State<BestPlayerChartPage> {
  Map<String, int> _firestoreBestPlayerCounts = {};
  bool _isLoadingFirestore = true;
  FacilityStaffModel? _bestPlayerOfWeek;
  String? _currentUserState; // State for current user's filter
  String? _currentUserLocation; // Location for current user's filter

  @override
  void initState() {
    super.initState();
    _loadCurrentUserBioData().then((_) { // Load bio data first
      _loadFirestoreData(); // Then load survey data, which depends on bio data
    });
  }

  Future<void> _loadCurrentUserBioData() async {
    try {
      final userUUID = FirebaseAuth.instance.currentUser?.uid;
      if (userUUID == null) {
        print("No user logged in.");
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> bioDataSnapshot =
      await FirebaseFirestore.instance
          .collection("Staff")
          .doc(userUUID)
          .get();

      if (bioDataSnapshot.exists) {
        final bioData = bioDataSnapshot.data();
        if (bioData != null) {
          setState(() {
            _currentUserState = bioData['state'] as String?;
            _currentUserLocation = bioData['location'] as String?;
          });
          print("Current User State: $_currentUserState, Location: $_currentUserLocation");
        } else {
          print("Bio data is null for UUID: $userUUID");
        }
      } else {
        print("No bio data found for UUID: $userUUID");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }


  Future<void> _loadFirestoreData() async {
    if (_currentUserState == null || _currentUserLocation == null) {
      print("Current user state or location is not loaded yet. Skipping Firestore data load.");
      setState(() {
        _isLoadingFirestore = false;
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    print("_loadFirestoreData started for date: $formattedDate, location: $_currentUserLocation, state: $_currentUserState");

    try {
      final bestPlayerCounts = <String, int>{};
      int totalSurveyCount = 0;

      // 1. Query the "Staff" collection, filtered by state and location
      final staffCollection = firestore.collection('Staff')
          .where('state', isEqualTo: _currentUserState)
          .where('location', isEqualTo: _currentUserLocation);

      final staffSnapshot = await staffCollection.get();

      print("Number of Staff documents found in current location/state: ${staffSnapshot.docs.length}");

      // 2. Iterate through each staff document (already filtered)
      for (final staffDoc in staffSnapshot.docs) {
        // 3. Access the "SurveyResponses" sub-collection
        final surveyResponsesCollection = staffDoc.reference.collection('SurveyResponses');
        // 4. Query for the document with the current date as ID
        final surveyDocSnapshot = await surveyResponsesCollection.doc(formattedDate).get();

        if (surveyDocSnapshot.exists) {
          totalSurveyCount++;
          final surveyDataFull = surveyDocSnapshot.data();
          if (surveyDataFull == null) {
            print("Survey data is null for document: ${surveyDocSnapshot.id}");
            continue;
          }

          print("Survey data found for staff: ${staffDoc.id}, date: $formattedDate");

          if (surveyDataFull.containsKey('surveyData')) {
            final surveyDataList = surveyDataFull['surveyData'] as List;

            for (var surveyData in surveyDataList) {
              if (surveyData is Map<String, dynamic>) {
                if (surveyData.containsKey("For the current week, who is the best team player in your facility")) {
                  final bestPlayerFieldValue = surveyData["For the current week, who is the best team player in your facility"];

                  if (bestPlayerFieldValue is String) {
                    try {
                      final bestPlayerList = json.decode(bestPlayerFieldValue) as List;
                      for (var player in bestPlayerList) {
                        if (player is Map<String, dynamic> && player.containsKey('name')) {
                          final playerName = player['name'] as String;
                          bestPlayerCounts[playerName] = (bestPlayerCounts[playerName] ?? 0) + 1;
                        }
                      }
                    } catch (e) {
                      print("Error decoding JSON string (string value case): $e");
                    }
                  } else if (bestPlayerFieldValue is List) {
                    for (var player in bestPlayerFieldValue) {
                      if (player is Map<String, dynamic> && player.containsKey('name')) {
                        final playerName = player['name'] as String;
                        bestPlayerCounts[playerName] = (bestPlayerCounts[playerName] ?? 0) + 1;
                      }
                    }
                  } else {
                    print("Unexpected bestPlayerFieldValue type: ${bestPlayerFieldValue.runtimeType}, value: $bestPlayerFieldValue");
                  }
                }
              } else {
                print("Unexpected surveyData format: $surveyData");
              }
            }
          } else {
            print("surveyData field not found in document: ${surveyDocSnapshot.id}");
          }
        } else {
          print("No survey response found for staff: ${staffDoc.id}, date: $formattedDate");
        }
      }

      print("Total surveys processed for $formattedDate in current location/state: $totalSurveyCount");


      String? bestPlayerName;
      int maxCount = 0;
      bestPlayerCounts.forEach((playerName, count) {
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


      setState(() {
        _firestoreBestPlayerCounts = bestPlayerCounts;
        _isLoadingFirestore = false;
      });
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
        if (_firestoreBestPlayerCounts.isNotEmpty)
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
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 20.0, bottom: 20.0),
            child: Text("No survey data available for the current week in your facility to display the chart.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,),
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
            Row(
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