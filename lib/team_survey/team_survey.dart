import 'dart:convert';
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../screens/staff_dashboard.dart';

// BioModel definition (plain Dart class) - No changes needed
class BioModel {
  String? id;
  String? firstName;
  String? lastName;
  String? maritalStatus;
  String? gender;
  String? staffCategory;
  String? designation;
  String? password;
  String? state;
  String? emailAddress;
  String? role;
  String? location;
  String? firebaseAuthId;
  String? department;
  String? mobile;
  String? project;
  bool? isSynced;
  String? supervisor;
  String? supervisorEmail;
  String? version;
  bool? isRemoteDelete;
  bool? isRemoteUpdate;
  DateTime? lastUpdateDate;
  String? signatureLink;

  BioModel({
    this.id,
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.designation,
    this.password,
    this.state,
    this.emailAddress,
    this.role,
    this.location,
    this.firebaseAuthId,
    this.department,
    this.mobile,
    this.project,
    this.isSynced,
    this.supervisor,
    this.supervisorEmail,
    this.version,
    this.isRemoteDelete,
    this.isRemoteUpdate,
    this.lastUpdateDate,
    this.signatureLink,
    this.maritalStatus,
    this.gender,
  });

  factory BioModel.fromJson(Map<String, dynamic> json) {
    return BioModel(
        id: json['id'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        staffCategory: json['staffCategory'] as String?,
        designation: json['designation'] as String?,
        password: json['password'] as String?,
        state: json['state'] as String?,
        emailAddress: json['emailAddress'] as String?,
        role: json['role'] as String?,
        location: json['location'] as String?,
        firebaseAuthId: json['firebaseAuthId'] as String?,
        department: json['department'] as String?,
        mobile: json['mobile'] as String?,
        project: json['project'] as String?,
        isSynced: json['isSynced'] as bool?,
        supervisor: json['supervisor'] as String?,
        supervisorEmail: json['supervisorEmail'] as String?,
        version: json['version'] as String?,
        isRemoteDelete: json['isRemoteDelete'] as bool?,
        isRemoteUpdate: json['isRemoteUpdate'] as bool?,
        lastUpdateDate: json['lastUpdateDate'] == null
            ? null
            : (json['lastUpdateDate'] as Timestamp).toDate(),
        signatureLink: json['signatureLink'] as String?,
        maritalStatus: json['maritalStatus'] as String?,
        gender: json['gender'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'firstName': firstName,
      'lastName': lastName,
      'staffCategory': staffCategory,
      'designation': designation,
      'password': password,
      'state': state,
      'emailAddress': emailAddress,
      'role': role,
      'location': location,
      'firebaseAuthId': firebaseAuthId,
      'department': department,
      'mobile': mobile,
      'project': project,
      'isSynced': isSynced,
      'supervisor': supervisor,
      'supervisorEmail': supervisorEmail,
      'version': version,
      'isRemoteDelete': isRemoteDelete,
      'isRemoteUpdate': isRemoteUpdate,
      'lastUpdateDate': lastUpdateDate,
      'signatureLink': signatureLink,
      'maritalStatus': maritalStatus,
      'gender': gender,
    };
  }

  static BioModel fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return BioModel.fromJson(data!)..id = snapshot.id;
  }
}

// FacilityStaffModel definition (plain Dart class) - No changes needed
class FacilityStaffModel {
  String? id;
  String? name;
  String? state;
  String? facilityName;
  String? userId;
  String? designation;

  FacilityStaffModel({
    this.id,
    this.name,
    this.state,
    this.facilityName,
    this.userId,
    this.designation,
  });

  factory FacilityStaffModel.fromJson(Map<String, dynamic> json) {
    String? firstName = json['firstName'] as String?;
    String? lastName = json['lastName'] as String?;
    String? fullName;

    if (firstName != null && lastName != null) {
      fullName = '$firstName $lastName';
    } else if (firstName != null) {
      fullName = firstName;
    } else if (lastName != null) {
      fullName = lastName;
    } else {
      fullName = null;
    }

    return FacilityStaffModel(
      id: json['id'] as String?,
      name: fullName,
      state: json['state'] as String?,
      facilityName: json['location'] as String?,
      userId: json['id'] as String?,
      designation: json['designation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'name': name,
      'state': state,
      'facilityName': facilityName,
      'userId': userId,
      'designation': designation,
    };
  }

  static FacilityStaffModel fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return FacilityStaffModel.fromJson(data!)..id = snapshot.id;
  }
}


// SurveyResultModel definition (plain Dart class) - No changes needed
class SurveyResultModel {
  String? id;
  DateTime? date;
  String? name;
  String? uuid;
  String? emailAddress;
  String? phoneNumber;
  String? staffCategory;
  String? state;
  String? facilityName;
  bool? isSynced;
  late String staffJson;

  SurveyResultModel({
    this.id,
    this.date,
    this.name,
    this.uuid,
    this.emailAddress,
    this.phoneNumber,
    this.staffCategory,
    this.state,
    this.facilityName,
    this.isSynced,
    required this.staffJson,
  });

  List<FacilityStaffModel>? get staff {
    if (staffJson.isNotEmpty) {
      return (jsonDecode(staffJson) as List)
          .map((data) => FacilityStaffModel.fromJson(data))
          .toList();
    }
    return null;
  }

  set staff(List<FacilityStaffModel>? value) {
    staffJson = jsonEncode(value?.map((e) => e.toJson()).toList() ?? []);
  }

  factory SurveyResultModel.fromJson(Map<String, dynamic> json) {
    return SurveyResultModel(
      id: json['id'] as String?,
      date: json['date'] == null
          ? null
          : (json['date'] as Timestamp).toDate(),
      name: json['name'] as String?,
      uuid: json['uuid'] as String?,
      emailAddress: json['emailAddress'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      staffCategory: json['staffCategory'] as String?,
      state: json['state'] as String?,
      facilityName: json['facilityName'] as String?,
      isSynced: json['isSynced'] as bool?,
      staffJson: json['staffJson'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'date': date,
      'name': name,
      'uuid': uuid,
      'emailAddress': emailAddress,
      'phoneNumber': phoneNumber,
      'staffCategory': staffCategory,
      'state': state,
      'facilityName': facilityName,
      'isSynced': isSynced,
      'staffJson': staffJson,
    };
  }

  static SurveyResultModel fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return SurveyResultModel.fromJson(data!)..id = snapshot.id;
  }
}


class PsychologicalMetricsPage extends StatefulWidget {
  const PsychologicalMetricsPage({super.key});

  @override
  _PsychologicalMetricsPageState createState() => _PsychologicalMetricsPageState();
}

class _PsychologicalMetricsPageState extends State<PsychologicalMetricsPage> {
  Map<String, List<Map<String, String>>> _sections = {};
  final Map<String, dynamic> _responses = {};
  List<FacilityStaffModel> _reorderableItems = [];
  List<FacilityStaffModel> _staffList = [];
  bool _isLoadingStaffList = true;
  bool isLoading = true;
  String? bioState;
  String? bioName;
  String? bioUUID;
  String? bioEmailAddress;
  String? bioPhoneNumber;
  String? bioStaffCategory;
  String? bioLocation;
  BioModel? bioData;

  @override
  void initState() {
    super.initState();
    _loadPsychologicalMetricsData();
    _loadBioData().then((_) {
      _loadStaffList();
    });
  }

  Future<void> _loadBioData() async {
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
        bioData = BioModel.fromFirestore(bioDataSnapshot);
        String fullName = "${bioData!.firstName} ${bioData!.lastName}";
        print("BioLocation ==${bioData!.location}");
        print("BioState ==${bioData!.state}");
        setState(() {
          bioState = bioData!.state;
          bioLocation = bioData!.location;
          bioName = fullName;
          bioUUID = userUUID;
          bioEmailAddress = bioData!.emailAddress;
          bioPhoneNumber = bioData!.mobile;
          bioStaffCategory = bioData!.staffCategory;
        });
      } else {
        print("No bio data found for UUID: $userUUID");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }

  Future<void> _loadStaffList() async {
    setState(() {
      _isLoadingStaffList = true;
    });
    try {
      if (bioLocation == null || bioState == null) {
        print("BioLocation or BioState is null, cannot load staff list.");
        setState(() {
          _isLoadingStaffList = false;
        });
        return;
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid; // Get current user ID
      if (currentUserId == null) {
        print("Current user ID is null, cannot exclude from staff list.");
        setState(() {
          _isLoadingStaffList = false;
        });
        return;
      }

      QuerySnapshot<Map<String, dynamic>> staffSnapshot =
      await FirebaseFirestore.instance
          .collection("Staff")
          .where("location", isEqualTo: bioLocation)
          .where("state", isEqualTo: bioState)
          .where("staffCategory", isEqualTo: "Facility Staff")
          .where(FieldPath.documentId,
          isNotEqualTo: currentUserId) // Exclude current user ID
          .get();

      List<FacilityStaffModel> staffList = staffSnapshot.docs.map((doc) {
        return FacilityStaffModel.fromFirestore(doc);
      }).toList();

      Set<String?> userIds = staffList.map((staff) => staff.userId).toSet();
      if (userIds.length < staffList.length) {
        print("WARNING: Duplicate userIds found in staff list!");
        print("Staff List: $staffList");
      }
      print("Loaded Staff List (excluding current user): ${staffList.map((s) => '${s.name} - ${s.userId}').toList()}");


      setState(() {
        _staffList = staffList;
        _staffList.shuffle();
        _reorderableItems = List.from(_staffList);
        _isLoadingStaffList = false;
      });
    } catch (error) {
      print('Error loading staff list: $error');
      setState(() {
        _isLoadingStaffList = false;
      });
    }
  }


  Future<void> _loadPsychologicalMetricsData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> metricsSnapshot =
      await FirebaseFirestore.instance
          .collection("PsychologicalMetrics")
          .doc("PsychologicalMetrics")
          .get();

      if (metricsSnapshot.exists) {
        final data = metricsSnapshot.data()!;
        Map<String, List<Map<String, String>>> decodedSections = {};
        data.forEach((sectionName, questionsList) {
          if (questionsList is List) {
            decodedSections[sectionName] = List<Map<String, String>>.from(
              questionsList.map((item) =>
              Map<String, String>.from(item.cast<String, dynamic>())),
            );
          }
        });

        setState(() {
          _sections = decodedSections;
        });
      } else {
        print("PsychologicalMetrics document not found.");
      }
    } catch (e) {
      print('Error fetching psychological metrics data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('We would Love to hear from you!'),
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
                  title: _capitalize(
                      entry.key.replaceAll('_', ' ')),
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
              child: const Text('Submit Your Review'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAndSyncOrNavigate() async {
    try {
      await _submitResponses(); // Validate responses first
      await syncDataToFirestore(); // If validations pass, sync to Firestore
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const UserDashboardPage()),
      );
    } catch (submissionError) {
      // Errors are handled within _submitResponses and syncDataToFirestore
      // No need to handle them again here, just ensure navigation doesn't happen on error.
    }
  }


  Future<void> syncDataToFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final dataToSync = await _prepareDataForFirestore();
      if (dataToSync == null) return; // _prepareDataForFirestore will handle errors and null returns

      final formattedDate = DateFormat('yyyy-MM-dd').format(dataToSync['date']);
      final formattedMonthYear =
      DateFormat('MMMM yyyy').format(dataToSync['date']);

      final docRef = firestore.collection('Staff').doc(bioUUID);

      await docRef.collection('SurveyResponses').doc(formattedDate).set({
        'surveyData': dataToSync['surveyData'],
        'syncedAt': DateTime.now(),
        'SubmittedBy': bioName,
        'FacilityName': bioLocation,
        'State': bioState,
        'StaffUUID': bioUUID,
        'StaffEmailAddress': bioEmailAddress,
        'StaffPhoneNumber': bioPhoneNumber,
        'StaffCategory': bioStaffCategory,
        //'date': DateFormat('yyyy-MM-dd').format(dataToSync['date']),
        'date': DateTime.now(),
        'month_year': formattedMonthYear,
      });

      print("Data synced successfully to Firestore!");
      Fluttertoast.showToast(
        msg: 'Survey submitted and synced successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
      );

    } catch (error) {
      print("Error syncing data to Firestore: $error");
      Fluttertoast.showToast(
        msg: 'Failed to submit survey. Please check your internet connection and try again.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 5,
      );
      rethrow; // Re-throw error to prevent navigation in _submitAndSyncOrNavigate
    }
  }


  Future<Map<String, dynamic>?> _prepareDataForFirestore() async {
    List<Map<String, dynamic>> firestoreDataList = [];
    SurveyResultModel surveyResultModel = SurveyResultModel(
      date: DateTime.now(),
      name: bioName,
      uuid: bioUUID,
      emailAddress: bioEmailAddress,
      phoneNumber: bioPhoneNumber,
      staffCategory: bioStaffCategory,
      state: bioState,
      facilityName: bioLocation,
      isSynced: false,
      staffJson: '',
    );

    for (var sectionEntry in _sections.entries) {
      String sectionName = sectionEntry.key;
      List<Map<String, String>> questions = sectionEntry.value;

      for (var questionData in questions) {
        Map<String, dynamic> firestoreData = {};
        String questionText = questionData['question'] ?? '';
        dynamic answer = _responses[questionText];

        firestoreData['section'] = sectionName;

        if (questionText ==
            'For the current week, who is the best team player in your facility') {
          if (answer is List<FacilityStaffModel>) {
            firestoreData[questionText] = answer.map((staff) => {
              "id": staff.userId,
              "name": staff.name,
              "state": staff.state,
              "facilityName": staff.facilityName,
              "designation": staff.designation,
            }).toList();
          } else {
            firestoreData[questionText] = answer;
          }
        } else {
          firestoreData[questionText] = answer;
        }
        firestoreDataList.add(firestoreData);
      }
    }

    surveyResultModel.staffJson =
        jsonEncode(firestoreDataList);

    return {
      'surveyData': firestoreDataList,
      'date': surveyResultModel.date!,
    };
  }

  Widget _buildCard(int index, FacilityStaffModel staff) {
    Color cardBackgroundColor = (index % 2 == 0) ? Colors.grey[100]! : Colors.white;

    print("Building Card for: ${staff.name}, userId: ${staff.userId}, index: $index");

    return Card(
      key: ValueKey(staff.userId),
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
              'Press & Hold & Drag to Rearrange',
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
          return _buildQuestionTile(
            questionData: entry.value,
            index: index,
          );
        }),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildQuestionTile({
    required Map<String, String> questionData,
    required int index,
  }) {
    final question = questionData['question'] ?? '';
    final type = questionData['type'] ?? '';

    if (type == 'tick_box') {
      return _buildTickBoxQuestion(question: question, index: index);
    } else if (type == 'list') {
      return _buildListQuestion(question: question, index: index);
    }
    return const SizedBox.shrink();
  }


  Widget _buildTickBoxQuestion({required String question, required int index}) {
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
                    _responses[question] = value;
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
                    _responses[question] = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildListQuestion({required String question, required int index}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. $question', style: const TextStyle(fontSize: 16)),
        ExpansionTile(
          title: const Text(
              "Instructions: Click HERE to expand the list of all staff member in your facility (Excluding yourself).From the list, Press and Hold the '=' icon ,and and Drag the cards either Upward or Downward to re-arrange the Best team player from top to down",
              style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            _isLoadingStaffList
                ? const Center(child: CircularProgressIndicator())
                : AnimatedReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              items: _staffList,
              isSameItem: (oldItem, newItem) =>
              oldItem.userId == newItem.userId,
              itemBuilder: (context, index) =>
                  _buildCard(index, _staffList[index]),
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  final staffMember = _staffList.removeAt(oldIndex);
                  _staffList.insert(newIndex, staffMember);
                  _responses[question] = _staffList;
                });
              },
            ),
          ],
        ),
      ],
    );
  }


  Future<void> _submitResponses() async {
    try {
      if (listEquals(_staffList, _reorderableItems)) {
        Fluttertoast.showToast(
          msg:
          'Hey!!, You forgot to answer the question "For the current week, who is the best team player in your facility". We value your opinion and would love you to re-arrange who you feel has been the best team player from top to bottom. Kindly read the instructions for the question before answering.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 8,
        );
        throw Exception('Best team player question not answered'); // Prevent Firestore save
      } else {
        for (var entry in _sections.entries) {
          final sectionTitle = entry.key;
          final questions = entry.value;

          for (var questionData in questions) {
            final question = questionData['question'] ?? '';
            if (question ==
                'For the current week, who is the best team player in your facility') {
              continue;
            }
            if (!_responses.containsKey(question) ||
                _responses[question] == null) {
              Fluttertoast.showToast(
                msg:
                'Please answer all questions in the "${_capitalize(sectionTitle.replaceAll('_', ' '))}" section before submitting.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.CENTER,
                timeInSecForIosWeb: 8,
              );
              throw Exception('Incomplete survey answers'); // Prevent Firestore save
            }
          }
        }
      }

      String collaborationResponse =
      _responses['Is there good collaboration among your team members?'];
      String supportResponse =
      _responses['Do you get good support from your team members?'];
      String challengeResponse =
      _responses['Do you have any challenge carrying out your duties?'];
      String neededMaterialsResponse =
      _responses['Do you have the needed materials to do your job?'];

      if (collaborationResponse != supportResponse) {
        if (collaborationResponse == "Yes" && supportResponse == "No") {
          Fluttertoast.showToast(
            msg:
            'You responded that there is good collaboration among your team members BUT Do you get good support from your team members. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          throw Exception('Inconsistent Team Spirit responses'); // Prevent Firestore save
        } else {
          Fluttertoast.showToast(
            msg:
            'You responded that there is NO good collaboration among your team members BUT you get good support from your team members. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          throw Exception('Inconsistent Team Spirit responses'); // Prevent Firestore save
        }
      }

      if (challengeResponse == neededMaterialsResponse) {
        if (challengeResponse == "No" && neededMaterialsResponse == "No") {
          Fluttertoast.showToast(
            msg:
            'You responded that you DO NOT HAVE any challenge carrying out your duties BUT YOU ALSO DO NOT HAVE the needed materials to do your job.Not having the needed materials is also a challenge. Please review your answers.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 8,
          );
          throw Exception('Inconsistent Attitude to Work responses'); // Prevent Firestore save
        }
      }

      print('User Responses Validated: $_responses');
      // If all validations pass, proceed to syncDataToFirestore which is called in _submitAndSyncOrNavigate

    } catch (error) {
      print('Validation Error: $error');
      // Error messages are already shown via Fluttertoast in validations.
      // No need to show another general error here, just re-throw to stop submission process
      rethrow; // Re-throw to prevent Firestore submission in _submitAndSyncOrNavigate
    }
  }


  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}