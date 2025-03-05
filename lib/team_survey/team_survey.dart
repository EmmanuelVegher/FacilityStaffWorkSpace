import 'dart:convert';
import 'dart:math';
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bio_model.dart';
import '../models/facility_staff_model.dart';
import '../models/survey_result_model.dart';
import 'best_player_chart_page.dart'; // For web local storage


//import '../../services/isar_service.dart'; // Removed isar_service


class PsychologicalMetricsPage extends StatefulWidget {
  //final Isar isar; // Removed isar

  const PsychologicalMetricsPage({super.key, /*required this.isar*/}); // Removed isar

  @override
  _PsychologicalMetricsPageState createState() =>
      _PsychologicalMetricsPageState();
}

class _PsychologicalMetricsPageState extends State<PsychologicalMetricsPage> {
  Map<String, List<Map<String, String>>> _sections = {};
  final Map<String, dynamic> _responses = {};
  List<FacilityStaffModel> _reorderableItems = []; // For storing shuffled staff list
  List<FacilityStaffModel> _staffList = []; // Use your FacilityStaffModel
  bool _isLoadingStaffList = true; // Track loading state
  bool isLoading = true;
  String? BioState;
  String? BioName;
  String? BioUUID;
  String? BioEmailAddress;
  String? BioPhoneNumber;
  String? BioStaffCategory;
  String? BioLocation;
  BioModel? bioData;

  @override
  void initState() {
    super.initState();
    _loadPsychologicalMetricsData();
    _loadBioData();
    _loadStaffList(); // Load the staff list when the page initializes
  }

  Future<void> _loadBioData() async {
    // Replace IsarService with Firestore or SharedPreferences for web
    final prefs = await SharedPreferences.getInstance();
    String? bioDataString = prefs.getString('bioData'); // Try to load from shared_preferences

    if (bioDataString != null) {
      Map<String, dynamic> bioDataMap = jsonDecode(bioDataString) as Map<String, dynamic>;
      bioData = BioModel.fromJson(bioDataMap);
      if (bioData != null) {
        String fullName = "${bioData!.firstName!} ${bioData!.lastName!}";
        setState(() {
          BioState = bioData!.state;
          BioLocation = bioData!.location;
          BioName = fullName;
          BioUUID = bioData!.firebaseAuthId;
          BioEmailAddress = bioData!.emailAddress;
          BioPhoneNumber = bioData!.mobile;
          BioStaffCategory = bioData!.staffCategory;
        });
      }
    } else {
      // If not in shared_preferences, fetch from Firestore (assuming user is logged in and we have UUID)
      if (BioUUID != null) { // Assuming BioUUID is available from auth context in web app. If not, you need to get it.
        try {
          DocumentSnapshot bioDoc = await FirebaseFirestore.instance.collection('Staff').doc(BioUUID).get();
          if (bioDoc.exists) {
            Map<String, dynamic> data = bioDoc.data() as Map<String, dynamic>;
            bioData = BioModel.fromJson(data);
            if (bioData != null) {
              String fullName = "${bioData!.firstName!} ${bioData!.lastName!}";
              setState(() {
                BioState = bioData!.state;
                BioLocation = bioData!.location;
                BioName = fullName;
                BioUUID = bioData!.firebaseAuthId;
                BioEmailAddress = bioData!.emailAddress;
                BioPhoneNumber = bioData!.mobile;
                BioStaffCategory = bioData!.staffCategory;
              });
              // Save to shared_preferences for faster subsequent loads (optional, but good for web)
              await prefs.setString('bioData', jsonEncode(bioData!.toJson()));
            }
          } else {
            print("Bio data not found in Firestore for UUID: $BioUUID");
          }
        } catch (e) {
          print("Error loading bio data from Firestore: $e");
        }
      } else {
        print("No bio data found locally or remotely and BioUUID is null.");
      }
    }
  }


  Future<void> _loadStaffList() async {
    setState(() {
      _isLoadingStaffList = true;
    });
    try {
      if (BioLocation == null || BioState == null) {
        print("BioLocation or BioState is null, cannot fetch staff list.");
        setState(() {
          _isLoadingStaffList = false;
        });
        return;
      }

      QuerySnapshot staffSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .where('location', isEqualTo: BioLocation)
          .where('state', isEqualTo: BioState)
      //.where('department', isEqualTo: BioDepartment) // if you have department in bioData
          .get();

      List<FacilityStaffModel> staff = staffSnapshot.docs.map((doc) {
        return FacilityStaffModel.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();


      // Remove current user from staff list if needed. Assuming BioEmailAddress is unique staff identifier.
      staff.removeWhere((s) => s.emailAddress == BioEmailAddress);


      setState(() {
        _staffList = staff;
        _staffList.shuffle();
        _reorderableItems = List.from(_staffList); // Store shuffled list
        _isLoadingStaffList = false;
      });
    } catch (error) {
      print('Error loading staff list from Firestore: $error');
      setState(() {
        _isLoadingStaffList = false;
      });
    }
  }

  Future<void> _loadPsychologicalMetricsData() async {
    try {
      DocumentSnapshot metricsSnapshot = await FirebaseFirestore.instance
          .collection('PsychologicalMetrics')
          .doc('metrics_doc_id') // Replace 'metrics_doc_id' with your actual document ID
          .get();

      if (metricsSnapshot.exists) {
        Map<String, dynamic> metricsData = metricsSnapshot.data() as Map<String, dynamic>;
        String sectionsJson = metricsData['sectionsJson'] as String? ?? '[]'; // Assuming field name is 'sectionsJson'

        final decodedSections = (jsonDecode(sectionsJson) as List<dynamic>)
            .fold<Map<String, List<Map<String, String>>>>({}, (map, section) {
          final entry = section as Map<String, dynamic>;
          entry.forEach((key, value) {
            var questions = List<Map<String, String>>.from(
                (value as List<dynamic>).map((item) =>
                Map<String, String>.from(item as Map<String, dynamic>)));

            map[key] = questions;
          });
          return map;
        });

        setState(() {
          _sections = decodedSections;
        });
      } else {
        print('Psychological metrics data not found in Firestore.');
      }
    } catch (e) {
      print('Error fetching psychological metrics data from Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Weekly Review'),
        centerTitle: true,
        elevation: 4.0,
      ),
      body: _sections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _sections.entries
                    .map((entry) => _buildSection(
                  title: _capitalize(entry.key.replaceAll('_', ' ')),
                  questions: entry.value,
                ))
                    .toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _submitAndSyncOrNavigate,
              child: const Text('Submit Weekly Survey Review'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAndSyncOrNavigate() async {
    try {
      await _submitResponses(); // Submit responses to local storage first

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          await syncDataToFirestore();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BestPlayerChartPage()),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data saved locally, but Firestore sync failed. Will sync later.'))
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BestPlayerChartPage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection. Data saved locally.'))
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BestPlayerChartPage()),
        );
      }
    } catch (submissionError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit data.')),
      );
    }
  }

  Future<void> syncDataToFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final prefs = await SharedPreferences.getInstance();
      String? surveyResultString = prefs.getString('surveyResult');

      if (surveyResultString != null) {
        SurveyResultModel metric = SurveyResultModel.fromJson(jsonDecode(surveyResultString) as Map<String, dynamic>);
        final data = jsonDecode(metric.staffJson!) as Map<String, dynamic>;
        final staffData = data['staff'] as List;
        List<Map<String, dynamic>> firestoreDataList = [];

        for (var section in staffData) {
          for (var key in section.keys) {
            final sectionData = section[key] as List;
            for (var questionData in sectionData) {
              Map<String, dynamic> firestoreData = {};
              for (var questionKey in questionData.keys) {
                firestoreData['section'] = key;
                if (questionKey == 'For the current week, who is the best team player in your facility') {
                  final bestTeamPlayerList = questionData[questionKey];
                  firestoreData[questionKey] = jsonEncode(bestTeamPlayerList);
                } else {
                  firestoreData[questionKey] = questionData[questionKey];
                }
              }
              firestoreDataList.add(firestoreData);
            }
          }
        }

        final formattedDate = DateFormat('yyyy-MM-dd').format(metric.date!);
        final docRef = firestore.collection('Staff').doc(BioUUID);
        final dateTime = DateFormat('yyyy-MM-dd').parse(data['date']);
        final formattedMonthYear = DateFormat('MMMM yyyy').format(dateTime);

        await docRef.collection('SurveyResponses').doc(formattedDate).set({
          'surveyData': firestoreDataList,
          'syncedAt': DateTime.now(),
          'SubmittedBy': metric.name,
          'FacilityName': metric.facilityName,
          'State': metric.state,
          'StaffUUID': metric.uuid,
          'StaffEmailAddress': metric.emailAddress,
          'StaffPhoneNumber': metric.phoneNumber,
          'StaffCategory': metric.staffCategory,
          'date': data['date'],
          'month_year': formattedMonthYear
        });

        // Clear local storage after successful sync (optional, or you can mark as synced)
        await prefs.remove('surveyResult'); // or set a flag in shared preferences
        print("Data synced successfully!");
      } else {
        print("No survey data found in local storage to sync.");
      }
    } catch (error) {
      print("Error syncing data to Firestore: $error");
      rethrow; // Re-throw to be caught in _submitAndSyncOrNavigate
    }
  }


  Widget _buildCard(int index, FacilityStaffModel staff) {
    Color cardBackgroundColor = (index % 2 == 0) ? Colors.grey[100]! : Colors.white;

    return Card(
      key: ValueKey(staff.id),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: cardBackgroundColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[200],
          child: Text(
            "${index + 1}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staff.name ?? 'Unnamed Staff',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            if (staff.designation != null)
              Text(
                staff.designation!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: const Column(
          children: [
            Icon(Icons.drag_indicator, color: Colors.grey),
            Text(
              'Press & Hold & Drag up or down to Rearrange',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Map<String, String>> questions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800],
          ),
        ),
        const SizedBox(height: 8.0),
        ...questions.asMap().entries.map((entry) {
          int index = entry.key + 1;
          return _buildQuestionTile(entry.value, index);
        }),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildQuestionTile(Map<String, String> questionData, int index) {
    final question = questionData['question'] ?? '';
    final type = questionData['type'] ?? '';

    if (type == 'tick_box') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. $question',
            style: const TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Yes'),
                  value: 'Yes',
                  groupValue: _responses[question],
                  onChanged: (value) {
                    setState(() {
                      _responses[question] = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('No'),
                  value: 'No',
                  groupValue: _responses[question],
                  onChanged: (value) {
                    setState(() {
                      _responses[question] = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      );
    } else if (type == 'list') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$index. $question', style: const TextStyle(fontSize: 16)),
          ExpansionTile(
            title: const Text("Instructions: Click HERE to expand the list of all staff member in your facility (Excluding yourself).From the list, Press and Hold and Drag the cards either Upward or Downward to re-arrange the Best team player from top to down", style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              _isLoadingStaffList
                  ? const Center(child: CircularProgressIndicator())
                  : AnimatedReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                items: _staffList,
                isSameItem: (oldItem, newItem) => oldItem.id == newItem.id,
                itemBuilder: (context, index) => _buildCard(index, _staffList[index]),
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    final staffMember = _staffList.removeAt(oldIndex);
                    _staffList.insert(newIndex, staffMember);
                    _responses[question] = _staffList;
                  });
                },
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 5,
                  shadowColor: Colors.black,
                  child: child,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }


  Future<void> _submitResponses() async {
    try {
      if (listEquals(_staffList, _reorderableItems)) {
        Fluttertoast.showToast(
          msg: 'Hey!!, You forgot to answer the question "For the current week, who is the best team player in your facility". We value your opinion and would love you to re-arrange who you feel has been the best team player from top to bottom. Kindly read the instructions for the question before answering.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 8,
        );
        return;
      } else {
        for (var entry in _sections.entries) {
          final sectionTitle = entry.key;
          final questions = entry.value;
          for (var questionData in questions) {
            final question = questionData['question'] ?? '';
            if (question == 'For the current week, who is the best team player in your facility') {
              continue;
            }
            if (!_responses.containsKey(question) || _responses[question] == null) {
              Fluttertoast.showToast(
                msg: 'Please answer all questions in the "${_capitalize(sectionTitle.replaceAll('_', ' '))}" section before submitting.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
                timeInSecForIosWeb: 8,
              );
              return;
            }
          }
        }
      }

      String collaborationResponse = _responses['Is there good collaboration among your team members?'];
      String supportResponse = _responses['Do you get good support from your team members?'];
      String challengeResponse = _responses['Do you have any challenge carrying out your duties?'];
      String neededMaterialsResponse = _responses['Do you have the needed materials to do your job?'];

      if (collaborationResponse != supportResponse) {
        if (collaborationResponse == "Yes" && supportResponse == "No") {
          Fluttertoast.showToast(
            msg: 'You responded that there is good collaboration among your team members BUT Do you get good support from your team members. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          return;
        } else {
          Fluttertoast.showToast(
            msg: 'You responded that there is NO good collaboration among your team members BUT you get good support from your team members. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          return;
        }
      }

      if (challengeResponse == neededMaterialsResponse) {
        if (challengeResponse == "No" && neededMaterialsResponse == "No") {
          Fluttertoast.showToast(
            msg: 'You responded that you DO NOT HAVE any challenge carrying out your duties BUT YOU ALSO DO NOT HAVE the needed materials to do your job.Not having the needed materials is also a challenge. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          return;
        }
      }

      final now = DateTime.now();
      final dateOnly = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final dateOnly1 = DateTime(now.year, now.month, now.day);

      final formattedResponses1 = {
        "id": Random().nextInt(1000),
        "date": dateOnly,
        "state": BioState,
        "facilityName": BioLocation,
        "staff": _sections.entries.map((entry) {
          final sectionTitle = entry.key;
          final questions = entry.value;

          return {
            sectionTitle: questions.map((question) {
              final questionText = question['question'] ?? '';
              final answer = _responses[questionText];

              if (questionText == 'For the current week, who is the best team player in your facility') {
                return {
                  questionText: (answer as List<FacilityStaffModel>).map((staff) => {
                    "id": staff.id,
                    "name": staff.name,
                    "state": staff.state,
                    "facilityName": staff.facilityName,
                    "userId": staff.userId,
                    "designation": staff.designation,
                  }).toList(),
                };
              } else {
                return {questionText: answer};
              }
            }).toList(),
          };
        }).toList(),
      };


      final surveyResult = SurveyResultModel()
        ..date = dateOnly1
        ..emailAddress = BioEmailAddress
        ..isSynced = false
        ..name = BioName
        ..phoneNumber = BioPhoneNumber
        ..staffCategory = BioStaffCategory
        ..uuid = BioUUID
        ..state = BioState
        ..facilityName = BioLocation
        ..staffJson = jsonEncode(formattedResponses1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('surveyResult', jsonEncode(surveyResult.toJson()));


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey submitted successfully!')),
      );
    } catch (error) {
      print('Error submitting responses: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit responses.')),
      );
    }
  }


  String _getSectionForQuestion(String question) {
    for (var entry in _sections.entries) {
      if (entry.value.any((q) => q['question'] == question)) {
        return _capitalize(entry.key.replaceAll('_', ' '));
      }
    }
    return 'Unknown';
  }


  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}