import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_picker_timeline/date_picker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
//import 'package:firebase_ml_vision/firebase_ml_vision.dart'; // Import Firebase ML Vision
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../../widgets/button.dart';
import '../../widgets/drawer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File, Directory;
import 'dart:convert';

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;

String? mimeTypeFromUrl(String url) {
  final Uri uri = Uri.parse(url);
  final String path = uri.path;
  return mime(path);
}

class ValidationResult {
  final bool isValid;
  final String messages;

  ValidationResult({required this.isValid, required this.messages});
}

// Models
// bio_model.dart
class BioModel {
  String? firebaseAuthId;
  String? firstName;
  String? lastName;
  String? department;
  String? state;
  String? designation;
  String? location;
  String? staffCategory;
  String? signatureLink;
  String? emailAddress;
  String? mobile;

  BioModel({
    this.firebaseAuthId,
    this.firstName,
    this.lastName,
    this.department,
    this.state,
    this.designation,
    this.location,
    this.staffCategory,
    this.signatureLink,
    this.emailAddress,
    this.mobile,
  });

  factory BioModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return BioModel(
      firebaseAuthId: data?['firebaseAuthId'],
      firstName: data?['firstName'],
      lastName: data?['lastName'],
      department: data?['department'],
      state: data?['state'],
      designation: data?['designation'],
      location: data?['location'],
      staffCategory: data?['staffCategory'],
      signatureLink: data?['signatureLink'],
      emailAddress: data?['emailAddress'],
      mobile: data?['mobile'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (firebaseAuthId != null) "firebaseAuthId": firebaseAuthId,
      if (firstName != null) "firstName": firstName,
      if (lastName != null) "lastName": lastName,
      if (department != null) "department": department,
      if (state != null) "state": state,
      if (designation != null) "designation": designation,
      if (location != null) "location": location,
      if (staffCategory != null) "staffCategory": staffCategory,
      if (signatureLink != null) "signatureLink": signatureLink,
      if (emailAddress != null) "emailAddress": emailAddress,
      if (mobile != null) "mobile": mobile,
    };
  }
}

// report_model.dart
class ReportEntry {
  String key;
  String value;
  String? enteredBy;
  String? editedBy;
  String? reviewedBy;
  String? reviewStatus;
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  List<String>? attachments;
  String? appAnalysis;
  String? reviewerId;

  ReportEntry({
    this.key = "",
    this.value = "",
    this.enteredBy,
    this.editedBy,
    this.reviewedBy,
    this.reviewStatus,
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
    this.attachments,
    this.appAnalysis,
    this.reviewerId,
  });

  factory ReportEntry.fromMap(Map<String, dynamic> map) {
    return ReportEntry(
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      enteredBy: map['enteredBy'],
      editedBy: map['editedBy'],
      reviewedBy: map['reviewedBy'],
      reviewStatus: map['reviewStatus'],
      supervisorName: map['supervisorName'],
      supervisorEmail: map['supervisorEmail'],
      supervisorApprovalStatus: map['supervisorApprovalStatus'],
      supervisorFeedBackComment: map['supervisorFeedBackComment'],
      attachments: (map['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      appAnalysis: map['appAnalysis'],
      reviewerId: map['reviewerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      if (enteredBy != null) 'enteredBy': enteredBy,
      if (editedBy != null) 'editedBy': editedBy,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewStatus != null) 'reviewStatus': reviewStatus,
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
      if (attachments != null) 'attachments': attachments,
      if (appAnalysis != null) 'appAnalysis': appAnalysis,
      if (reviewerId != null) 'reviewerId': reviewerId,
    };
  }

  /// **Add the copyWith method**
  ReportEntry copyWith({
    String? key,
    String? value,
    String? enteredBy,
    String? editedBy,
    String? reviewedBy,
    String? reviewStatus,
    String? supervisorName,
    String? supervisorEmail,
    String? supervisorApprovalStatus,
    String? supervisorFeedBackComment,
    List<String>? attachments,
    String? appAnalysis,
    String? reviewerId,
  }) {
    return ReportEntry(
      key: key ?? this.key,
      value: value ?? this.value,
      enteredBy: enteredBy ?? this.enteredBy,
      editedBy: editedBy ?? this.editedBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorEmail: supervisorEmail ?? this.supervisorEmail,
      supervisorApprovalStatus:
      supervisorApprovalStatus ?? this.supervisorApprovalStatus,
      supervisorFeedBackComment:
      supervisorFeedBackComment ?? this.supervisorFeedBackComment,
      attachments: attachments ?? this.attachments,
      appAnalysis: appAnalysis ?? this.appAnalysis,
      reviewerId: reviewerId ?? this.reviewerId,
    );
  }
}


class Report {
  String? id;
  DateTime? date;
  String? reportType;
  String? reportingWeek;
  String? reportingMonth;
  String? reportStatus;
  String? reportFeedbackComment;
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  List<String>? attachments;
  bool? isSynced;
  // Modified reportEntries to be a Map as per requirement
  Map<String, Map<String, List<ReportEntry>>>? reportEntries;

  Report({
    this.id,
    this.date,
    this.reportType,
    this.reportingWeek,
    this.reportingMonth,
    this.reportStatus,
    this.attachments,
    this.reportFeedbackComment,
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
    this.isSynced,
    this.reportEntries,
  });

  factory Report.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return Report(
      id: snapshot.id,
      reportType: data?['reportType'],
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      reportingWeek: data?['reportingWeek'],
      reportingMonth: data?['reportingMonth'],
      reportStatus: data?['reportStatus'],
      reportFeedbackComment: data?['reportFeedbackComment'],
      supervisorName: data?['supervisorName'],
      supervisorEmail: data?['supervisorEmail'],
      supervisorApprovalStatus: data?['supervisorApprovalStatus'],
      supervisorFeedBackComment: data?['supervisorFeedBackComment'],
      attachments:
      (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      isSynced: data?['isSynced'],
      // Deserialize reportEntries correctly
      reportEntries: (data?['reportEntries'] as Map<String, dynamic>?)?.map(
            (username, indicatorMap) => MapEntry(
          username,
          (indicatorMap as Map<String, dynamic>).map(
                (indicator, entryList) => MapEntry(
              indicator,
              (entryList as List<dynamic>)
                  .map((entryData) =>
                  ReportEntry.fromMap(entryData as Map<String, dynamic>))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (reportType != null) 'reportType': reportType,
      if (date != null) 'date': date,
      if (reportingWeek != null) 'reportingWeek': reportingWeek,
      if (reportingMonth != null) 'reportingMonth': reportingMonth,
      if (reportStatus != null) 'reportStatus': reportStatus,
      if (reportFeedbackComment != null) 'reportFeedbackComment': reportFeedbackComment,
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
      if (attachments != null) 'attachments': attachments,
      if (isSynced != null) 'isSynced': isSynced,
      // Serialize reportEntries correctly
      if (reportEntries != null)
        'reportEntries': reportEntries!.map(
              (username, indicatorMap) => MapEntry(
            username,
            indicatorMap.map(
                  (indicator, entryList) => MapEntry(
                indicator,
                entryList.map((e) => e.toMap()).toList(),
              ),
            ),
          ),
        ),
    };
  }
}

class Task {
  int? id; // Not used in Firestore, Firestore generates document IDs
  DateTime? date;
  String? taskTitle;
  String? taskDescription;
  bool? isSynced;
  String? taskStatus;
  List<String>? attachments;
  String? reviewedBy; // ADDED: Field to store the reviewer's name
  String? appAnalysis; // ADDED: Field to store Gemini analysis for tasks
  String? supervisorName;
  String? supervisorEmail;
  String? supervisorApprovalStatus;
  String? supervisorFeedBackComment;
  String? firestoreId;
  Task({
    this.id,
    this.date,
    this.taskTitle,
    this.firestoreId, // ADDED
    this.taskDescription,
    this.isSynced,
    this.taskStatus,
    this.attachments,
    this.reviewedBy, // ADDED: Include in constructor
    this.appAnalysis, // ADDED: Include in constructor
    this.supervisorName,
    this.supervisorEmail,
    this.supervisorApprovalStatus,
    this.supervisorFeedBackComment,
  });


  factory Task.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return Task(
      id: null, // Firestore doesn't use integer IDs, document ID is used instead
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      taskTitle: data?['taskTitle'],
      taskDescription: data?['taskDescription'],
      isSynced: data?['isSynced'],
      firestoreId: snapshot.id,
      taskStatus: data?['taskStatus'],
      attachments:
      (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      reviewedBy: data?['reviewedBy'], // ADDED: Retrieve from Firestore data
      appAnalysis: data?['appAnalysis'], // ADDED: Retrieve appAnalysis from Firestore
      supervisorName: data?['supervisorName'],
      supervisorEmail: data?['supervisorEmail'],
      supervisorApprovalStatus: data?['supervisorApprovalStatus'],
      supervisorFeedBackComment: data?['supervisorFeedBackComment'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (date != null) 'date': date,
      if (taskTitle != null) 'taskTitle': taskTitle,
      if (taskDescription != null) 'taskDescription': taskDescription,
      if (isSynced != null) 'isSynced': isSynced,
      if (firestoreId != null) 'firestoreId': firestoreId,
      if (taskStatus != null) 'taskStatus': taskStatus,
      if (attachments != null) 'attachments': attachments,
      if (reviewedBy != null) 'reviewedBy': reviewedBy, // ADDED: Include in Firestore data
      if (appAnalysis != null) 'appAnalysis': appAnalysis, // ADDED: Include appAnalysis in Firestore data
      if (supervisorName != null) 'supervisorName': supervisorName,
      if (supervisorEmail != null) 'supervisorEmail': supervisorEmail,
      if (supervisorApprovalStatus != null)
        'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null)
        'supervisorFeedBackComment': supervisorFeedBackComment,
    };
  }
}


class FacilityStaffModel {
  String? id;
  String? userId; // Add userId field
  String? name;
  String? email;
  String? department;
  String? state;
  String? facilityName;
  String? designation;
  String? staffCategory;

  FacilityStaffModel({
    this.id,
    this.userId, // Include userId
    this.name,
    this.email,
    this.department,
    this.state,
    this.facilityName,
    this.designation,
    this.staffCategory,
  });

  factory FacilityStaffModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return FacilityStaffModel(
      id: snapshot.id,
      userId: data?['userId'], // Ensure userId is mapped from Firestore
      name: data?['name'],
      email: data?['email'],
      department: data?['department'],
      state: data?['state'],
      facilityName: data?['facilityName'],
      designation: data?['designation'],
      staffCategory: data?['staffCategory'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (userId != null) 'userId': userId, // Include userId in Firestore writes
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (department != null) 'department': department,
      if (state != null) 'state': state,
      if (facilityName != null) 'facilityName': facilityName,
      if (designation != null) 'designation': designation,
      if (staffCategory != null) 'staffCategory': staffCategory,
    };
  }
}

// Firestore Service (updated for web and Firestore)
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String reportsCollection = 'Reports'; // Updated Collection Name - singular
  final String tasksCollection = 'Tasks';
  final String staffCollection = 'Staff';
  final String bioCollection = 'BioData';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Firebase Storage instance

  String? getUserId() {
    print("Current UUID === ${_auth.currentUser?.uid}");
    return _auth.currentUser?.uid;
  }



  // BioData Operations (same as before)
  Future<BioModel?> getBioData() async {
    try {
      final snapshot = await _firestore
          .collection(staffCollection) // Use staffCollection here
          .where('firebaseAuthId', isEqualTo: getUserId())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first, null);
      } else {
        print(
            "_FirestoreService: getBioData: No documents found for firebaseAuthId: ${getUserId()} in $staffCollection collection."); // More specific log
        return null;
      }
    } catch (e) {
      print("Error fetching BioData: ${e.toString()}"); // Print specific error
      print("_FirestoreService: getBioData: Error details: $e"); // Additional error detail
      return null;
    }
  }

  Future<BioModel?> getBioInfoWithFirebaseAuth() async {
    String? firebaseAuthUid = getUserId();
    if (firebaseAuthUid == null) return null;

    try {
      final snapshot = await _firestore
          .collection(staffCollection) // Use staffCollection here
          .where('firebaseAuthId', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first, null);
      } else {
        print(
            "_FirestoreService: getBioInfoWithFirebaseAuth: No documents found for firebaseAuthId: $firebaseAuthUid in $staffCollection collection."); // More specific log
        return null;
      }
    } catch (e) {
      print("Error fetching BioData with FirebaseAuth: $e");
      print("_FirestoreService: getBioInfoWithFirebaseAuth: Error details: $e"); // Additional error detail
      return null;
    }
  }

  // Report Operations
  Future<List<Report>> getReportsByDate1(DateTime date, BioModel? bioModel) async {
    if (bioModel == null || bioModel.state == null || bioModel.location == null) {
      print("BioModel data is incomplete, cannot fetch reports.");
      return [];
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final CollectionReference<Map<String, dynamic>> reportCollectionRef = _firestore // Explicitly define the type here
          .collection(reportsCollection)
          .doc(bioModel.state)
          .collection(bioModel.state!) // Sub-collection named as state
          .doc(bioModel.location)
          .collection(formattedDate); // Explicit cast here

      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await reportCollectionRef.get();
      List<Report> reports = [];
      for (var doc in snapshot.docs) {
        final reportData = doc.data();
        if (reportData['reportType'] != null) {
          reports.add(Report.fromFirestore(doc, null));
        }
      }
      return reports;
    } catch (e) {
      print("Error fetching reports by date: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  Future<void> saveReport1(Report report, BioModel? bioModel, String department) async {
    if (bioModel == null || bioModel.state == null || bioModel.location == null) {
      print("BioModel data is incomplete, cannot save report.");
      return;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(report.date!);
      final DocumentReference reportDocRef = _firestore
          .collection(reportsCollection)
          .doc(bioModel.state)
          .collection(bioModel.state!) // Sub-collection named as state
          .doc(bioModel.location)
          .collection(formattedDate)
          .doc(department); // Document ID is the department

      await reportDocRef.set(report.toFirestore(),
          SetOptions(merge: true)); // Use set with merge to update or create
    } catch (e) {
      print("Error saving report: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<void> pushReportToFirebase1(Report report) async {
    // Logic for pushing report, if needed, might be similar to saveReport but ensure sync status update
    // For this example, saveReport handles both save and update.
    print(
        "Push to Firebase function is not directly applicable in Firestore's set operation. Using saveReport.");
  }

  Future<void> updateReportSyncStatus1(String reportId, bool isSynced) async {
    // Firestore handles sync implicitly with offline capabilities, explicit sync status might not be needed
    print(
        "Update sync status function is not directly applicable in Firestore. Sync is handled automatically.");
  }

  Future<List<Report>> getUnsyncedReports1() async {
    // Firestore handles sync implicitly, getting unsynced reports might not be directly applicable
    print(
        "Get unsynced reports function is not directly applicable in Firestore. Sync is handled automatically.");
    return []; // Return empty list as Firestore handles sync
  }

  // Task Operations
  Future<List<Task>> getTasksByDate1(DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc, null)).toList();
    } catch (e) {
      print("Error fetching tasks by date: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  Future<void> saveTask1(Task task) async {
    try {
      await _firestore.collection(tasksCollection).add(task.toFirestore());
    } catch (e) {
      print("Error saving task: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<Task?> getTaskByTitleAndDate1(String title, DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('taskTitle', isEqualTo: title)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return Task.fromFirestore(snapshot.docs.first, null);
      }
      return null;
    } catch (e) {
      print("Error fetching task by title and date: $e");
      print("Error details: $e"); // More detailed error log
      return null;
    }
  }

  Future<void> pushTaskToFirebase1(Task task) async {
    try {
      await saveTask1(task); // Save task to Firestore
      await updateTaskSyncStatus1(task.id.toString(), true);
    } catch (e) {
      print("Error pushing task to Firebase: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<void> updateTaskSyncStatus1(String taskId, bool isSynced) async {
    try {
      await _firestore
          .collection(tasksCollection)
          .doc(taskId)
          .update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating task sync status: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<List<Task>> getUnsyncedTasks1() async {
    // Firestore handles sync implicitly, getting unsynced tasks might not be directly applicable
    print(
        "Get unsynced tasks function is not directly applicable in Firestore. Sync is handled automatically.");
    return [];
  }

  Future<void> deleteTask1(String taskId) async {
    try {
      await _firestore.collection(tasksCollection).doc(taskId).delete();
    } catch (e) {
      print("Error deleting task: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  // Facility Staff Operations (same as before)
  Future<List<FacilityStaffModel>> getFacilityListForSpecificFacility1() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('facilityName',
          isEqualTo: 'Your Facility Name') // Replace with actual facility name logic
          .get();
      return snapshot.docs
          .map((doc) => FacilityStaffModel.fromFirestore(doc, null))
          .toList();
    } catch (e) {
      print("Error fetching facility staff list: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Supervisor Operations (same as before)
  Stream<List<String?>> getSupervisorStream1(String department, String state) {
    return _firestore
        .collection(staffCollection)
        .where('department', isEqualTo: department)
        .where('state', isEqualTo: state)
        .where('designation', isEqualTo: 'Supervisor')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FacilityStaffModel.fromFirestore(doc, null).name)
        .toList());
  }

  Future<List<String?>> getSupervisorEmailFromFirestore1(
      String department, String supervisorName) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('department', isEqualTo: department)
          .where('name', isEqualTo: supervisorName)
          .where('designation', isEqualTo: 'Supervisor')
          .limit(1)
          .get();
      return snapshot.docs
          .map((doc) => FacilityStaffModel.fromFirestore(doc, null).email)
          .toList();
    } catch (e) {
      print("Error fetching supervisor email from Firestore: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Function to upload file to Firebase Storage and get download URL
  Future<String?> uploadFileToStorage(String filePath, String fileName, {StreamController<double>? progressStream}) async {
    try {
      File file = File(filePath);
      if (!file.existsSync()) {
        print("File does not exist at path: $filePath");
        return null;
      }

      Reference storageReference = _storage.ref().child('attachments/$fileName');
      UploadTask uploadTask = storageReference.putFile(
        file,
        SettableMetadata(contentType: mime(filePath)), // Set content type
      );

      if (progressStream != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          progressStream.add(progress);
        });
      }

      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading file to storage: $e");
      return null;
    }
  }
}

class DailyActivityMonitoringPage extends StatefulWidget {
  const DailyActivityMonitoringPage({super.key});

  @override
  _DailyActivityMonitoringPageState createState() =>
      _DailyActivityMonitoringPageState();
}

class _DailyActivityMonitoringPageState extends State<DailyActivityMonitoringPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String reportsCollection = 'Reports'; // Updated Collection Name - singular
  final String tasksCollection = 'Tasks';
  final String staffCollection = 'Staff';
  final String bioCollection = 'BioData';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService(); // Initialize FirestoreService
  final int _totalClockIn = 0;
  final int _totalClockOut = 0;

  // Report Operations
  Future<List<Report>> getReportsByDate(DateTime date, BioModel? bioModel) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot fetch reports.");
      return [];
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final CollectionReference<Map<String, dynamic>> reportCollectionRef = _firestore // Explicitly define the type here
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!) // Sub-collection named as state
          .doc(selectedBioLocation)
          .collection(formattedDate); // Explicit cast here


      final QuerySnapshot<Map<String, dynamic>> snapshot = await reportCollectionRef.get();
      List<Report> reports = [];
      for (var doc in snapshot.docs) {
        final reportData = doc.data();
        if (reportData['reportType'] != null) {
          reports.add(Report.fromFirestore(doc, null));
        }
      }
      return reports;
    } catch (e) {
      print("Error fetching reports by date: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }


  Future<List<Report>> getAllReportsForDate(DateTime date, BioModel? bioModel, String department) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot fetch reports.");
      return [];
    }

    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);

      // Use collectionGroup correctly
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collectionGroup(selectedFirebaseId!) // This queries all subcollections named `selectedFirebaseId!`
          .where('department', isEqualTo: department)
          .where('date', isEqualTo: formattedDate)
          .get();

      List<Report> reports = snapshot.docs.map((doc) => Report.fromFirestore(doc, null)).toList();

      return reports;
    } catch (e) {
      print("Error fetching all reports for date: $e");
      return [];
    }
  }



  Future<void> saveReport(Report report, BioModel? bioModel, String department) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot save report.");
      return;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(report.date!);
      final DocumentReference reportDocRef = FirebaseFirestore.instance
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!) // Sub-collection named as state
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(department); // Document ID is the department


      await reportDocRef.set(report.toFirestore(), SetOptions(merge: true)); // Use set with merge to update or create

    } catch (e) {
      print("Error saving report: $e");
      print("Error details: $e"); // More detailed error log
    }
  }


  Future<void> pushReportToFirebase(Report report) async {
    // Logic for pushing report, if needed, might be similar to saveReport but ensure sync status update
    // For this example, saveReport handles both save and update.
    print(
        "Push to Firebase function is not directly applicable in Firestore's set operation. Using saveReport.");
  }

  Future<void> updateReportSyncStatus(String reportId, bool isSynced) async {
    // Firestore handles sync implicitly with offline capabilities, explicit sync status might not be needed
    print(
        "Update sync status function is not directly applicable in Firestore. Sync is handled automatically.");
  }

  Future<List<Report>> getUnsyncedReports() async {
    // Firestore handles sync implicitly, getting unsynced reports might not be directly applicable
    print(
        "Get unsynced reports function is not directly applicable in Firestore. Sync is handled automatically.");
    return []; // Return empty list as Firestore handles sync
  }

  // Task Operations
  Future<List<Task>> getTasksByDate2(DateTime date) async {
    try {
      // Get the start of the day (12:00 AM) for the given date
      DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);

      // Get the end of the day (11:59:59 PM) for the given date
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Convert DateTime objects to Timestamps for Firestore querying
      Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
      Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .get();

      return snapshot.docs.map((doc) => Task.fromFirestore(doc, null)).toList();
    } catch (e) {
      print("Error fetching tasks by date: $e");
      return [];
    }
  }

  // Task Operations (Updated for new path)
  Future<List<Task>> getTasksByDate(DateTime date) async {
    try {
      if (selectedBioState == null || selectedBioLocation == null || selectedFirebaseId == null) {
        print("BioModel or user ID data is incomplete, cannot fetch tasks.");
        return [];
      }
      return await getTasksByDate1(date, bioData, selectedFirebaseId!);
    } catch (e) {
      print("Error fetching tasks by date in Page: $e");
      return [];
    }
  }


  // Task Operations (Updated for new path)
  Future<List<Task>> getTasksByDate1(DateTime date, BioModel? bioModel, String selectedFirebaseId) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel or user ID data is incomplete, cannot fetch tasks.");
      return [];
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final CollectionReference<Map<String, dynamic>> taskCollectionRef = _firestore
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection("Task") // Sub-collection named "Task"
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(selectedFirebaseId)
          .collection(selectedFirebaseId); // User ID as sub-collection


      final QuerySnapshot<Map<String, dynamic>> snapshot = await taskCollectionRef.get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc, null)).toList();
    } catch (e) {
      print("Error fetching tasks by date from new path: $e");
      print("Error details: $e");
      return [];
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      if (bioData == null || selectedFirebaseId == null) {
        print("BioModel or task ID data is incomplete, cannot delete task.");
        return;
      }
      await deleteTask1(taskId, bioData, selectedFirebaseId!, _selectedReportingDate);
    } catch (e) {
      print("Error deleting task in Page: $e");
      print("Error details: $e");
    }
  }


  Future<void> deleteTask1(String taskId, BioModel? bioModel, String selectedFirebaseId, DateTime date) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel or user ID data is incomplete, cannot delete task.");
      return;
    }
    try {
      print("taskId ==$taskId");
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final DocumentReference taskDocRef = _firestore
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection("Task") // Sub-collection named "Task"
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(selectedFirebaseId)
          .collection(selectedFirebaseId)
          .doc(taskId); // Task ID as document
      print("taskId ==$taskDocRef");
      await taskDocRef.delete();
    } catch (e) {
      print("Error deleting task from new path: $e");
      print("Error details: $e");
    }
  }



  Future<void> saveTask(Task task) async {
    String taskId = const Uuid().v4();
    if (selectedBioState == null || selectedBioLocation == null || selectedFirebaseId == null) {
      print("BioModel or user ID data is incomplete, cannot save task.");
      return;
    }

    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(task.date!);
      final DocumentReference taskDocRef = _firestore
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection("Task") // Sub-collection named "Task"
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(selectedFirebaseId)
          .collection(selectedFirebaseId!)
          .doc(taskId); // Task ID as document


      await taskDocRef.set(task.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print("Error saving task to new path: $e");
      print("Error details: $e");
    }
  }

  Future<void> updateTask(Task task,String taskId) async {

    if (selectedBioState == null || selectedBioLocation == null || selectedFirebaseId == null) {
      print("BioModel or user ID data is incomplete, cannot save task.");
      return;
    }

    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(task.date!);
      final DocumentReference taskDocRef = _firestore
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection("Task") // Sub-collection named "Task"
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(selectedFirebaseId)
          .collection(selectedFirebaseId!)
          .doc(taskId); // Task ID as document


      await taskDocRef.set(task.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print("Error saving task to new path: $e");
      print("Error details: $e");
    }
  }


  Future<void> saveTask1(Task task) async {
    try {
      await _firestore.collection(tasksCollection).add(task.toFirestore());
    } catch (e) {
      print("Error saving task: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<Task?> getTaskByTitleAndDate(String title, DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('taskTitle', isEqualTo: title)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return Task.fromFirestore(snapshot.docs.first, null);
      }
      return null;
    } catch (e) {
      print("Error fetching task by title and date: $e");
      print("Error details: $e"); // More detailed error log
      return null;
    }
  }

  // Future<void> pushTaskToFirebase(Task task) async {
  //   try {
  //     await saveTask(task); // Save task to Firestore
  //     await updateTaskSyncStatus(task.id.toString(), true);
  //   } catch (e) {
  //     print("Error pushing task to Firebase: $e");
  //     print("Error details: $e"); // More detailed error log
  //   }
  // }

  Future<void> updateTaskSyncStatus(String taskId, bool isSynced) async {
    try {
      await _firestore
          .collection(tasksCollection)
          .doc(taskId)
          .update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating task sync status: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<List<Task>> getUnsyncedTasks() async {
    // Firestore handles sync implicitly, getting unsynced tasks might not be directly applicable
    print(
        "Get unsynced tasks function is not directly applicable in Firestore. Sync is handled automatically.");
    return [];
  }

  Future<void> deleteTask2(String taskId) async {
    try {
      await _firestore.collection(tasksCollection).doc(taskId).delete();
    } catch (e) {
      print("Error deleting task: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  // Facility Staff Operations
  Future<List<FacilityStaffModel>> getFacilityListForSpecificFacility() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('facilityName',
          isEqualTo: 'Your Facility Name') // Replace with actual facility name logic
          .get();
      return snapshot.docs
          .map((doc) => FacilityStaffModel.fromFirestore(doc, null))
          .toList();
    } catch (e) {
      print("Error fetching facility staff list: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Supervisor Operations
  Stream<List<String?>> getSupervisorStream(String department, String state) {
    return _firestore
        .collection(staffCollection)
        .where('department', isEqualTo: department)
        .where('state', isEqualTo: state)
        .where('designation', isEqualTo: 'Supervisor')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FacilityStaffModel.fromFirestore(doc, null).name)
        .toList());
  }

  Future<List<String?>> getSupervisorEmailFromFirestore2(
      String department, String supervisorName) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('department', isEqualTo: department)
          .where('name', isEqualTo: supervisorName)
          .where('designation', isEqualTo: 'Supervisor')
          .limit(1)
          .get();
      return snapshot.docs
          .map((doc) => FacilityStaffModel.fromFirestore(doc, null).email)
          .toList();
    } catch (e) {
      print("Error fetching supervisor email from Firestore: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Initialize TextEditingControllers dynamically
  final Map<String, Map<String, TextEditingController>> reportControllers = {};
  final Map<String, Map<String, String?>> reportUsernames = {};
  final Map<String, Map<String, String?>> reportEditedUsernames = {};

  // Maps to store the username of who entered the data for each indicator.
  Map<String, String?> tbReportUsernames = {};
  Map<String, String?> vlReportUsernames = {};
  Map<String, String?> pharmTechReportUsernames = {};
  Map<String, String?> trackingAssistantReportUsernames = {};
  Map<String, String?> artNurseReportUsernames = {};
  Map<String, String?> htsReportUsernames = {};
  Map<String, String?> siReportUsernames = {};

  // Maps to store the username of who edited the data for each indicator.
  Map<String, String?> tbReportEditedUsernames = {};
  Map<String, String?> vlReportEditedUsernames = {};
  Map<String, String?> pharmTechReportEditedUsernames = {};
  Map<String, String?> trackingAssistantReportEditedUsernames = {};
  Map<String, String?> artNurseReportEditedUsernames = {};
  Map<String, String?> htsReportEditedUsernames = {};
  Map<String, String?> siReportEditedUsernames = {};

  String _currentUsername = ""; // Stores the current logged-in user's name.
  bool _isEditingTask = false; // Track if editing task in the "Other Tasks" section

  String _selectedReportType = "Daily"; // Default report type.
  String? _selectedReportPeriod; // Selected reporting week (Week 1, Week 2, etc.)
  String? _selectedMonthForWeekly; // Selected month for weekly report.
  List<String> _reportPeriodOptions = []; // Options for report period dropdown.
  List<String> _monthlyOptions = []; // Options for month dropdown.
  final Map<String, bool> _isEditingReportSection =
  {}; // Tracks if a report section is in editing mode.
  final Map<String, Map<String, bool>> _isIndicatorEditable = {}; // Tracks if an indicator is in editing mode within a report section.
  final Map<String, Report?> _loadedReports = {}; // Keep this
  List<Task> _tasksForDate = []; // Stores tasks for the selected date.
  final Map<String, List<Report>> _allReportsForDate = {}; // Stores all reports for the selected date, grouped by department

  Task? _taskBeingEdited; // Track the task being edited
  bool _isPDFLoading = false;
  //final TaskController _taskController = Get.put(TaskController());
  //late NotifyHelper notifyHelper;
  final DateTime _selectedDate =
  DateTime.now(); // Currently selected date (not used for reporting date).
  DateTime _selectedReportingDate =
  DateTime.now(); // Date for which reports are being viewed/entered.
  bool _isLoading = true; // Loading indicator flag.
  Color _datePickerSelectionColor = Colors.red;
  Color _datePickerSelectedTextColor = Colors.white;
  // Add a boolean variable to track saving state
  bool _isSavingReport = false;
  // NEW: State for validation progress
  bool _isValidating = false;
  // NEW: State for Gemini analysis progress
  final bool _isAnalyzingImage = false;

  final GlobalKey<FormState> _genericFormKey =
  GlobalKey<FormState>(); // Single generic form key

  // Track StreamSubscriptions for database watchers to refresh data on changes.
  final List<StreamSubscription> _reportWatchers = [];

  //Controllers for Task BottomSheet
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  String? _selectedSupervisor;

  List<String?> supervisorNames = []; // Store supervisor names from Firestore

  String? selectedProjectName;
  String? selectedBioFirstName;
  String? selectedBioLastName;
  String? selectedBioDepartment;
  String? selectedBioState;
  String? selectedBioDesignation;
  String? selectedBioLocation;
  String? selectedBioStaffCategory;
  String? selectedSignatureLink;
  String? selectedBioEmail;
  String? selectedBioPhone;
  String? selectedFirebaseId;
  String? selectedSupervisor; // State variable to store the selected supervisor
  String? _selectedSupervisorEmail;
  int _selectedIndex = 0; // To track bottom navigation tab index
  Future<Map<String, Map<String, int>>>? _summaryDataCache;

  // Add ImagePicker instance
  final ImagePicker _picker = ImagePicker();
  // State to hold attachments for reports and tasks
  final Map<String, List<AttachmentData>> _reportAttachmentsData =
  {}; // Key is reportType, Value is list of AttachmentData
  List<AttachmentData> _taskBottomSheetAttachmentsData = []; // Attachments for task in bottom sheet
  final Map<int, List<AttachmentData>> _taskCardAttachmentsData =
  {}; // Key is task ID, Value is list of AttachmentData

  List<FacilityStaffModel> _staffList = []; // For staff list dropdown
  bool _isLoadingStaffList = true; // Track loading state of staff list
  FacilityStaffModel? _selectedReviewer; // To store selected reviewer from dropdown

  // NEW: State to hold thematic report definitions
  List<Map<String, dynamic>> _thematicReportDefinitions = [];

  @override
  void initState() {
    super.initState();

    _loadBioData().then((_) {
      _loadStaffList();
      _initializeAsync();
      _loadThematicReportDefinitions(); // Load thematic report definitions on init
    });

    _monthlyOptions = _generateMonthlyOptions();
    _updateReportPeriodOptions(_selectedReportType);

    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _isLoading = false;
      });
    });
  }


  String? getUserId() {
    print("Current UUID === ${FirebaseAuth.instance.currentUser?.uid}");
    return FirebaseAuth.instance.currentUser?.uid;
  }




// NEW: Function to load thematic report definitions from Firestore
  Future<void> _loadThematicReportDefinitions() async {
    _thematicReportDefinitions.clear();
    try {
      DocumentSnapshot<Map<String, dynamic>> thematicReportDoc =
      await FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('ThematicReport')
          .get();

      if (thematicReportDoc.exists) {
        Map<String, dynamic> thematicReportData = thematicReportDoc.data()!;
        Map<String, dynamic> thematicReportIndicators =
        (thematicReportData['ThematicReportIndicators'] ?? {})
        as Map<String, dynamic>;

        List<Map<String, dynamic>> processedDefinitions = [];
        thematicReportIndicators.forEach((departmentName, designationMap) {
          if (designationMap is Map<String, dynamic>) {
            designationMap.forEach((designationName, indicatorsDynamic) {
              if (indicatorsDynamic is List<dynamic>) {
                List<String> indicators = indicatorsDynamic.cast<String>();
                processedDefinitions.add({
                  'department': departmentName,
                  'designation': designationName,
                  'indicators': indicators,
                });
              }
            });
          }
        });
        // Sort definitions by department and then by designation
        processedDefinitions.sort((a, b) {
          int departmentComparison = a['department'].compareTo(b['department']);
          if (departmentComparison != 0) {
            return departmentComparison;
          }
          return a['designation'].compareTo(b['designation']);
        });
        _thematicReportDefinitions = processedDefinitions;
      }

      setState(() {});
      print(
          "Loaded ${_thematicReportDefinitions.length} thematic report definitions.");
    } catch (e) {
      print("Error loading thematic report definitions: $e");
    }
  }


  Future<List<Report>> _fetchReportsForReview() async {
    List<Report> reportsForReview = [];
    String? currentUserId = selectedFirebaseId; // Use selectedFirebaseId from bioData load

    if (currentUserId == null) {
      print("Current user ID is null, cannot fetch reports for review.");
      return [];
    }

    try {
      String currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now()); // Format date

      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('Reports')
          .doc(selectedBioState) // Use loaded selectedBioState
          .collection(selectedBioState!) // Use loaded selectedBioState
          .doc(selectedBioLocation) // Use loaded selectedBioLocation
          .collection(currentDate) // Use current date for now, adjust if needed
          .get();

      print("snapshot ===$snapshot");

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          print("snapshot doc ===$doc");
          Report report = Report.fromFirestore(doc, null);
          print("snapshot report ===$report");
          print("snapshot report.reportStatus ===${report.reportStatus}");
          print("snapshot report.reportEntries ===${report.reportEntries}");
          if (report.reportStatus == 'Pending' && report.reportEntries != null) {
            print("snapshot report.reportStatus ===${report.reportStatus}");
            for (var username in report.reportEntries!.keys) {
              print("snapshot username ===$username");
              var indicatorMap = report.reportEntries![username];
              print("snapshot indicatorMap ===$indicatorMap");
              for (var indicator in indicatorMap!.keys) {
                print("snapshot indicator ===$indicator");
                for (var entry in indicatorMap[indicator]!) {
                  print("snapshot entry.reviewerId ===${entry.reviewerId}");
                  if (entry.reviewerId == selectedFirebaseId) {
                    reportsForReview.add(report);
                    print("snapshot entry.reportsForReview ===$reportsForReview");
                    break;
                  }
                }
              }
            }
          }
        }
      } else {
        print("No reports found for user ID: $currentUserId");
      }
    } catch (e) {
      print("Error fetching reports for review: $e");
    }
    print("reportsForReview ===$reportsForReview");
    return reportsForReview;
  }

  Widget _buildTaskSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment:MainAxisAlignment.spaceEvenly,
            children:[
              Text(
                "Task Summary for ${DateFormat('MMMM yyyy').format(_selectedReportingDate)}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () { // Disable button when saving
                  _performDataValidation(); // Call the data validation function
                },
                child: const Text('Task Validation'),
              ),



            ]
          ),

          const SizedBox(height: 20),

          _isPDFLoading
              ? CircularProgressIndicator()
              : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _createTaskSummaryPDF,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text(
                        'Download Your Task Summary',
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Tables for each unit will be added here dynamically
          ..._buildSummaryTables(), // Call a helper function to build tables
        ],
      ),
    );
  }

  Future<void> _createTaskSummaryPDF() async {
    setState(() {
      _isPDFLoading = true;
    });
    final pdf = pw.Document(pageMode: PdfPageMode.outlines);
    String monthYear = DateFormat('MMMM, yyyy').format(
        DateTime(_selectedReportingDate.year, _selectedReportingDate.month));
    final pageFormat = PdfPageFormat.a4;

    try {
      // Load the logo as bytes (no changes here)
      final ByteData? logoBytes = await rootBundle.load('assets/image/ccfn_logo.png');
      if (logoBytes == null) {
        Fluttertoast.showToast(msg: "Error: Logo asset not found!");
        setState(() {
          _isPDFLoading = false;
        });
        return;
      }
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

      // Fetch reports and other tasks (with detailed debugging)
      // final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      // if (currentUserId == null) {
      //   Fluttertoast.showToast(msg: "User not logged in.");
      //   setState(() {
      //     _isPDFLoading = false;
      //   });
      //   return;
      // }

      final now = _selectedReportingDate;
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      Map<DateTime, List<Report>> reportsByDate = {};
      Map<DateTime, List<Task>> otherTasksByDate = {};

      // Loop through each day of the month, EXCLUDING SATURDAYS AND SUNDAYS
      for (DateTime date = startOfMonth; date.isBefore(endOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
          print("_createTaskSummaryPDF: Skipping weekend date: ${DateFormat('dd-MMM-yyyy').format(date)}");
          continue; // Skip weekends
        }

        final formattedDateForReportPath = DateFormat('dd-MMM-yyyy').format(date);
        final formattedDateForTaskPath = DateFormat('yyyy-MM-dd').format(date); // Format for task path

        // Fetch Daily Reports (as before - with logging)
        print("_createTaskSummaryPDF: Fetching REPORTS for date: $formattedDateForReportPath");
        QuerySnapshot<Map<String, dynamic>> reportSnapshot = await FirebaseFirestore.instance
            .collection('Reports')
            .doc(selectedBioState)
            .collection(selectedBioState!)
            .doc(selectedBioLocation)
            .collection(formattedDateForReportPath)
            .get();
        print("_createTaskSummaryPDF: Number of REPORTS found for $formattedDateForReportPath: ${reportSnapshot.docs.length}");


        List<Report> dailyReports = reportSnapshot.docs
            .map((doc) => Report.fromFirestore(doc, null))
            .where((report) {
          if (report.reportEntries != null) {
            return report.reportEntries!.keys.any((username) => username == _currentUsername);
          }
          return false;
        }).toList();

        reportsByDate[date] = dailyReports; // Store daily reports
        print("_createTaskSummaryPDF: Number of USER REPORTS found for $formattedDateForReportPath: ${dailyReports.length}");



        // Fetch Other Tasks for the date (with detailed logging)
        print("_createTaskSummaryPDF: Fetching TASKS for date: $formattedDateForTaskPath"); // ADDED DEBUG LOG
        String taskCollectionPath = 'Reports/${selectedBioState}/Task/${selectedBioLocation}/${formattedDateForReportPath}/${selectedFirebaseId}/${selectedFirebaseId}'; // Construct path dynamically
        print("_createTaskSummaryPDF: Task Collection Path: $taskCollectionPath"); // ADDED DEBUG LOG


        QuerySnapshot<Map<String, dynamic>> taskSnapshot = await FirebaseFirestore.instance
            .collection('Reports')
            .doc(selectedBioState)
            .collection('Task')
            .doc(selectedBioLocation)
            .collection(formattedDateForReportPath)
            .doc(selectedFirebaseId)
            .collection(selectedFirebaseId!)
            .get();

        print("_createTaskSummaryPDF: Number of TASKS found for $formattedDateForTaskPath: ${taskSnapshot.docs.length}"); // ADDED DEBUG LOG

        List<Task> dailyTasks = taskSnapshot.docs
            .map((doc) => Task.fromFirestore(doc, null))
            .toList();
        otherTasksByDate[date] = dailyTasks; // Store daily tasks
        print("_createTaskSummaryPDF: Number of USER TASKS found for $formattedDateForTaskPath: ${dailyTasks.length}"); // ADDED DEBUG LOG
      }


      if (reportsByDate.isEmpty && otherTasksByDate.isEmpty) {
        Fluttertoast.showToast(msg: "No reports or other tasks found for the current user in this month (excluding weekends).");
        setState(() {
          _isPDFLoading = false;
        });
        return;
      }


      // Prepare summary data structure (no changes here)
      Map<DateTime, Map<String, Map<String, dynamic>>> summaryDataByDate = {};

      reportsByDate.forEach((date, dailyReports) {
        summaryDataByDate[date] = {};

        for (Report report in dailyReports) {
          if (report.reportEntries != null) {
            for (var usernameEntry in report.reportEntries!.entries) {
              String username = usernameEntry.key;
              for (var indicatorEntry in usernameEntry.value.entries) {
                String indicatorName = indicatorEntry.key;
                String indicatorValue = indicatorEntry.value.first.value;
                int value = int.tryParse(indicatorValue) ?? 0;

                if (!summaryDataByDate[date]!.containsKey(indicatorName)) {
                  summaryDataByDate[date]![indicatorName] = {'Total': 0};
                }

                summaryDataByDate[date]![indicatorName]![username] = value;
                summaryDataByDate[date]![indicatorName]!['Total'] = (summaryDataByDate[date]![indicatorName]!['Total'] as int) + value;
              }
            }
          }
        }
      });


      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          header: (pw.Context context) {
            return pw.Header(
              level: 0,
              child: pw.Text('Task Summary Report - $monthYear', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
                child: pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.Theme.of(context)
                        .defaultTextStyle
                        .copyWith(color: PdfColors.grey)
                ));
          },
          build: (pw.Context context) {
            List<pw.Widget> content = [];

            // 1. Tabular Summary of Reports (no changes here)
            summaryDataByDate.forEach((date, indicatorData) {

              // // Fetch attendance record for the date from Isar
              // AttendanceModel? attendanceRecord = await IsarService().getAttendanceByDate(DateFormat('dd-MMMM-yyyy').format(date)); // Fetch attendance for the date
              //
              // // Get clock-in and clock-out times from attendanceRecord
              // String clockInTime = "N/A"; // Default if no attendance data
              // String clockOutTime = "N/A";
              //
              // if (attendanceRecord != null) {
              //   clockInTime = attendanceRecord.clockIn ?? "N/A"; // Access clockInTime from Isar
              //   clockOutTime = attendanceRecord.clockOut ?? "N/A";   // Access clockOut from Isar
              // }

              content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10, top: 20),
                  child: pw.Text(DateFormat('EEEE, dd MMMM yyyy').format(date), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))));

              // content.add(pw.Padding(
              //     padding: const pw.EdgeInsets.only(bottom: 10, top: 20),
              //     child: pw.Row(
              //       children:[
              //         pw.Text(
              //             clockInTime, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              //
              //         pw.Text(
              //             clockOutTime, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))
              //       ]
              //     ),
              //
              // )
              // );

              List<List<String>> tableData = [];
              tableData.add(['Indicator', 'What You Entered', 'Total Value']);

              indicatorData.forEach((indicatorName, userData) {
                String userValue = (userData[_currentUsername]?.toString()) ?? '0';
                String totalValue = (userData['Total']?.toString()) ?? '0';
                tableData.add([indicatorName, userValue, totalValue]);
              });

              content.add(pw.Table.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(),
                  data: tableData,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
              ));
            });

            // 2. Summary of Other Tasks (no changes here)
            if (otherTasksByDate.isNotEmpty) {
              content.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 30),
                  child: pw.Text("Summary of Other Tasks:", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))));

              otherTasksByDate.forEach((date, taskList) {
                if (taskList.isNotEmpty) {
                  content.add(pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5, top: 10),
                      child: pw.Text(DateFormat('EEEE, dd MMMM yyyy').format(date), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))));
                  for (Task task in taskList) {
                    content.add(pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: taskList.map((task) => pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 5, top: 2),
                            child: pw.Text('•'),
                          ),
                          pw.Expanded(
                            child: pw.Text("${task.taskTitle}: ${task.taskDescription}"),
                          ),
                        ],
                      )).toList(),
                    ));
                  }
                }
              });
            }


            return content;
          },
        ),
      );

      // Convert PDF to bytes and trigger download in the browser
      final pdfBytes = await pdf.save();
      final blob = html.Blob([Uint8List.fromList(pdfBytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = 'Task_Summary_Report_${_currentUsername}_$monthYear.pdf';
      anchor.click();
      html.Url.revokeObjectUrl(url);

      setState(() {
        _isPDFLoading = false;
      });
    } catch (e) {
      print("Error generating Task Summary PDF: $e");
      Fluttertoast.showToast(
        msg: "Error generating Task Summary PDF: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.black54,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      setState(() {
        _isPDFLoading = false;
      });
    }
  }


  Future<ValidationResult> _validateMonthlySummaryData(Map<String, Map<String, int>> weeklySummary) async {
    bool validationFailed = false;
    String validationErrorMessage = "";
    Map<String, int> monthlyTotals = {}; // To store monthly totals for each indicator

    String vlResultHandedOverIndicatorKey = "Number of Result Handed over to SIAs /MEAL For the Day";
    String vlResultEnteredNMRSIndicatorKey = "Number of Viral Load Results Entered on NMRS (EMR) For the Day";
    String eligibleClientsTestedHTSRegisterIndicatorKey = "Number of Eligible Clients Tested and documented in the HTS Register For the Day";
    String htsDataEnteredNMRSIndicatorKey = "Number of HTS Data Entered on NMRS (EMR) For the Day";
    String existingClientsEntriesNMRSIndicatorKey = "Number of Existing Clients Entries Entered on NMRS (EMR) For the Day";
    String refillClientsIndicatorKey = "Number of Refill Clients For the day";
    String newARTClientsIndicatorKey = "Number of New ART Clients For the day";
    String txNewIndicatorKey = "Number of Tx_New Clients Entries Entered on NMRS (EMR) For the Day";
    String hivPositiveLinkedToArtIndicatorKey = "Number of newly diagnosed HIV positive linked to ART For the Day";
    String arvPickUpClientsIndicatorKey = "Total Number of Clients that Visited the Facility for ARV Pick Up For the Day";
    String diagnosedHIVPositiveIndicatorKey = "Number of Clients Diagnosed HIV Positive For the Day";
    String eligibleForTestingIndicatorKey = "Number Eligible for Testing For the Day";
    String eligibleClientsTestedReceivedResultIndicatorKey = "Number of Eligible Clients Tested for HIV and Received Result For the Day";


    // Aggregate weekly totals to monthly totals
    for (String week in weeklySummary.keys) {
      weeklySummary[week]?.forEach((indicator, weeklyValue) {
        monthlyTotals[indicator] = (monthlyTotals[indicator] ?? 0) + weeklyValue;
      });
    }

    // Perform monthly validation checks
    int monthlyVLResultHandedOver = monthlyTotals[vlResultHandedOverIndicatorKey] ?? 0;
    int monthlyVLResultEnteredNMRS = monthlyTotals[vlResultEnteredNMRSIndicatorKey] ?? 0;
    int monthlyEligibleClientsTestedHTSRegister = monthlyTotals[eligibleClientsTestedHTSRegisterIndicatorKey] ?? 0;
    int monthlyHTSDataEnteredNMRS = monthlyTotals[htsDataEnteredNMRSIndicatorKey] ?? 0;
    int monthlyExistingClientsEntriesNMRS = monthlyTotals[existingClientsEntriesNMRSIndicatorKey] ?? 0;
    int monthlyRefillClients = monthlyTotals[refillClientsIndicatorKey] ?? 0;
    int monthlyNewARTClients = monthlyTotals[newARTClientsIndicatorKey] ?? 0;
    int monthlyTxNewEntries = monthlyTotals[txNewIndicatorKey] ?? 0;
    int monthlyHIVPositiveLinkedToArt = monthlyTotals[hivPositiveLinkedToArtIndicatorKey] ?? 0;
    int monthlyARVPickUpClients = monthlyTotals[arvPickUpClientsIndicatorKey] ?? 0;
    int monthlyDiagnosedHIVPositive = monthlyTotals[diagnosedHIVPositiveIndicatorKey] ?? 0;
    int monthlyEligibleForTesting = monthlyTotals[eligibleForTestingIndicatorKey] ?? 0;
    int monthlyEligibleClientsTestedReceivedResult = monthlyTotals[eligibleClientsTestedReceivedResultIndicatorKey] ?? 0;


    if (monthlyVLResultHandedOver != monthlyVLResultEnteredNMRS) {
      validationFailed = true;
      validationErrorMessage += "Monthly VL Validation failed:\nTotal Number of Result Handed over to SIAs /MEAL  ($monthlyVLResultHandedOver) does not match Number of Viral Load Results Entered on NMRS (EMR) ($monthlyVLResultEnteredNMRS).\n\n";
    }
    if (monthlyEligibleClientsTestedHTSRegister != monthlyHTSDataEnteredNMRS) {
      validationFailed = true;
      validationErrorMessage += "Monthly HTS_HTSRegister_HTSEntry Validation failed:\nTotal Number of Eligible Clients Tested and documented in the HTS Register ($monthlyEligibleClientsTestedHTSRegister) does not match Number of HTS Data Entered on NMRS (EMR) ($monthlyHTSDataEnteredNMRS).\n\n";
    }
    if (monthlyExistingClientsEntriesNMRS != monthlyRefillClients) {
      validationFailed = true;
      validationErrorMessage += "Monthly ExistingClients_RefillClients Validation failed:\nTotal Number of Existing Clients Entries Entered on NMRS (EMR) ($monthlyExistingClientsEntriesNMRS) does not match Number of Refill Clients ($monthlyRefillClients).\n\n";
    }
    if (monthlyNewARTClients != monthlyTxNewEntries || monthlyNewARTClients != monthlyHIVPositiveLinkedToArt) {
      validationFailed = true;
      validationErrorMessage += "Monthly NewARTClients_TxNew_HIVPositiveLinkedART Validation failed:\nTotal Number of New ART Clients ($monthlyNewARTClients) does not match Number of Tx_New Clients Entries Entered on NMRS (EMR) ($monthlyTxNewEntries) or Number of Newly Diagnosed HIV Positive Linked to ART ($monthlyHIVPositiveLinkedToArt).\n\n";
    }
    if (monthlyARVPickUpClients != monthlyExistingClientsEntriesNMRS || monthlyARVPickUpClients != monthlyRefillClients) {
      validationFailed = true;
      validationErrorMessage += "Monthly ARVPickUpClients_ExistingClients_RefillClients Validation failed:\nTotal Number of Clients that Visited the Facility for ARV Pick Up ($monthlyARVPickUpClients) does not match Number of Existing Clients Entries Entered on NMRS (EMR) ($monthlyExistingClientsEntriesNMRS) or Number of Refill Clients ($monthlyRefillClients).\n\n";
    }
    if (monthlyDiagnosedHIVPositive > monthlyEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "Monthly DiagnosedHIVPositive_EligibleForTesting Validation failed:\nNumber of Clients Diagnosed HIV Positive ($monthlyDiagnosedHIVPositive) cannot be greater than Number Eligible for Testing ($monthlyEligibleForTesting).\n\n";
    }
    if (monthlyEligibleClientsTestedHTSRegister > monthlyEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "Monthly EligibleClientsTestedHTSRegister_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested and documented in the HTS Register ($monthlyEligibleClientsTestedHTSRegister) cannot be greater than Number Eligible for Testing ($monthlyEligibleForTesting).\n\n";
    }
    if (monthlyEligibleClientsTestedReceivedResult > monthlyEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "Monthly EligibleClientsTestedReceivedResult_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested for HIV and Received Result ($monthlyEligibleClientsTestedReceivedResult) cannot be greater than Number Eligible for Testing ($monthlyEligibleForTesting).\n\n";
    }
    if (monthlyHIVPositiveLinkedToArt > monthlyEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "Monthly HIVPositiveLinkedToArt_EligibleForTesting Validation failed:\nNumber of Newly Diagnosed HIV Positive Linked to ART ($monthlyHIVPositiveLinkedToArt) cannot be greater than Number Eligible for Testing ($monthlyEligibleForTesting).\n\n";
    }


    return ValidationResult(isValid: !validationFailed, messages: validationErrorMessage);
  }

  Future<void> _performDataValidation() async {
    bool allValid = true;
    String validationMessages = "";

    setState(() {
      _isValidating = true; // Start validation progress indicator
    });

    Map<String, Map<String, int>> weeklySummaryData = await _fetchWeeklySummaryData(); // Fetch weekly summary data

    ValidationResult weeklyValidationResult = await _validateWeeklySummaryData(weeklySummaryData); // Call weekly validation
    if (!weeklyValidationResult.isValid) {
      allValid = false;
      validationMessages += weeklyValidationResult.messages;
    }

    ValidationResult monthlyValidationResult = await _validateMonthlySummaryData(weeklySummaryData); // Call monthly validation
    if (!monthlyValidationResult.isValid) {
      allValid = false;
      validationMessages += monthlyValidationResult.messages;
    }


    setState(() {
      _isValidating = false; // Stop validation progress indicator
    });

    if (allValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task validation passed for weekly and monthly summaries!')),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Task Validation"),
            content: Text(validationMessages.isNotEmpty ? validationMessages : "Task validation failed."),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<ValidationResult> _validateWeeklySummaryData(Map<String, Map<String, int>> weeklySummary) async {
    bool validationFailed = false;
    String validationErrorMessage = "";

    String vlResultHandedOverIndicatorKey = "Number of Result Handed over to SIAs /MEAL For the Day";
    String vlResultEnteredNMRSIndicatorKey = "Number of Viral Load Results Entered on NMRS (EMR) For the Day";
    String eligibleClientsTestedHTSRegisterIndicatorKey = "Number of Eligible Clients Tested and documented in the HTS Register For the Day";
    String htsDataEnteredNMRSIndicatorKey = "Number of HTS Data Entered on NMRS (EMR) For the Day";
    String existingClientsEntriesNMRSIndicatorKey = "Number of Existing Clients Entries Entered on NMRS (EMR) For the Day";
    String refillClientsIndicatorKey = "Number of Refill Clients For the day";
    String newARTClientsIndicatorKey = "Number of New ART Clients For the day";
    String txNewIndicatorKey = "Number of Tx_New Clients Entries Entered on NMRS (EMR) For the Day";
    String hivPositiveLinkedToArtIndicatorKey = "Number of newly diagnosed HIV positive linked to ART For the Day";
    String arvPickUpClientsIndicatorKey = "Total Number of Clients that Visited the Facility for ARV Pick Up For the Day";
    String diagnosedHIVPositiveIndicatorKey = "Number of Clients Diagnosed HIV Positive For the Day";
    String eligibleForTestingIndicatorKey = "Number Eligible for Testing For the Day";
    String eligibleClientsTestedReceivedResultIndicatorKey = "Number of Eligible Clients Tested for HIV and Received Result For the Day";


    // Perform weekly validation checks - Example validations (adjust as needed)
    for (String week in weeklySummary.keys) {
      int weeklyVLResultHandedOver = weeklySummary[week]![vlResultHandedOverIndicatorKey] ?? 0;
      int weeklyVLResultEnteredNMRS = weeklySummary[week]![vlResultEnteredNMRSIndicatorKey] ?? 0;
      int weeklyEligibleClientsTestedHTSRegister = weeklySummary[week]![eligibleClientsTestedHTSRegisterIndicatorKey] ?? 0;
      int weeklyHTSDataEnteredNMRS = weeklySummary[week]![htsDataEnteredNMRSIndicatorKey] ?? 0;
      int weeklyExistingClientsEntriesNMRS = weeklySummary[week]![existingClientsEntriesNMRSIndicatorKey] ?? 0;
      int weeklyRefillClients = weeklySummary[week]![refillClientsIndicatorKey] ?? 0;
      int weeklyNewARTClients = weeklySummary[week]![newARTClientsIndicatorKey] ?? 0;
      int weeklyTxNewEntries = weeklySummary[week]![txNewIndicatorKey] ?? 0;
      int weeklyHIVPositiveLinkedToArt = weeklySummary[week]![hivPositiveLinkedToArtIndicatorKey] ?? 0;
      int weeklyARVPickUpClients = weeklySummary[week]![arvPickUpClientsIndicatorKey] ?? 0;
      int weeklyDiagnosedHIVPositive = weeklySummary[week]![diagnosedHIVPositiveIndicatorKey] ?? 0;
      int weeklyEligibleForTesting = weeklySummary[week]![eligibleForTestingIndicatorKey] ?? 0;
      int weeklyEligibleClientsTestedReceivedResult = weeklySummary[week]![eligibleClientsTestedReceivedResultIndicatorKey] ?? 0;


      if (weeklyVLResultHandedOver != weeklyVLResultEnteredNMRS) {
        validationFailed = true;
        validationErrorMessage += "Week $week VL Validation failed:\nTotal Number of Result Handed over to SIAs /MEAL  ($weeklyVLResultHandedOver) does not match Number of Viral Load Results Entered on NMRS (EMR) ($weeklyVLResultEnteredNMRS).\n\n";
      }
      if (weeklyEligibleClientsTestedHTSRegister != weeklyHTSDataEnteredNMRS) {
        validationFailed = true;
        validationErrorMessage += "Week $week HTS_HTSRegister_HTSEntry Validation failed:\nTotal Number of Eligible Clients Tested and documented in the HTS Register ($weeklyEligibleClientsTestedHTSRegister) does not match Number of HTS Data Entered on NMRS (EMR) ($weeklyHTSDataEnteredNMRS).\n\n";
      }
      if (weeklyExistingClientsEntriesNMRS != weeklyRefillClients) {
        validationFailed = true;
        validationErrorMessage += "Week $week ExistingClients_RefillClients Validation failed:\nTotal Number of Existing Clients Entries Entered on NMRS (EMR) ($weeklyExistingClientsEntriesNMRS) does not match Number of Refill Clients ($weeklyRefillClients).\n\n";
      }
      if (weeklyNewARTClients != weeklyTxNewEntries || weeklyNewARTClients != weeklyHIVPositiveLinkedToArt) {
        validationFailed = true;
        validationErrorMessage += "Week $week NewARTClients_TxNew_HIVPositiveLinkedART Validation failed:\nTotal Number of New ART Clients ($weeklyNewARTClients) does not match Number of Tx_New Clients Entries Entered on NMRS (EMR) ($weeklyTxNewEntries) or Number of Newly Diagnosed HIV Positive Linked to ART ($weeklyHIVPositiveLinkedToArt).\n\n";
      }
      if (weeklyARVPickUpClients != weeklyExistingClientsEntriesNMRS || weeklyARVPickUpClients != weeklyRefillClients) {
        validationFailed = true;
        validationErrorMessage += "Week $week ARVPickUpClients_ExistingClients_RefillClients Validation failed:\nTotal Number of Clients that Visited the Facility for ARV Pick Up ($weeklyARVPickUpClients) does not match Number of Existing Clients Entries Entered on NMRS (EMR) ($weeklyExistingClientsEntriesNMRS) or Number of Refill Clients ($weeklyRefillClients).\n\n";
      }
      if (weeklyDiagnosedHIVPositive > weeklyEligibleForTesting) {
        validationFailed = true;
        validationErrorMessage += "Week $week DiagnosedHIVPositive_EligibleForTesting Validation failed:\nNumber of Clients Diagnosed HIV Positive ($weeklyDiagnosedHIVPositive) cannot be greater than Number Eligible for Testing ($weeklyEligibleForTesting).\n\n";
      }
      if (weeklyEligibleClientsTestedHTSRegister > weeklyEligibleForTesting) {
        validationFailed = true;
        validationErrorMessage += "Week $week EligibleClientsTestedHTSRegister_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested and documented in the HTS Register ($weeklyEligibleClientsTestedHTSRegister) cannot be greater than Number Eligible for Testing ($weeklyEligibleForTesting).\n\n";
      }
      if (weeklyEligibleClientsTestedReceivedResult > weeklyEligibleForTesting) {
        validationFailed = true;
        validationErrorMessage += "Week $week EligibleClientsTestedReceivedResult_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested for HIV and Received Result ($weeklyEligibleClientsTestedReceivedResult) cannot be greater than Number Eligible for Testing ($weeklyEligibleForTesting).\n\n";
      }
      if (weeklyHIVPositiveLinkedToArt > weeklyEligibleForTesting) {
        validationFailed = true;
        validationErrorMessage += "Week $week HIVPositiveLinkedToArt_EligibleForTesting Validation failed:\nNumber of Newly Diagnosed HIV Positive Linked to ART ($weeklyHIVPositiveLinkedToArt) cannot be greater than Number Eligible for Testing ($weeklyEligibleForTesting).\n\n";
      }


    }


    return ValidationResult(isValid: !validationFailed, messages: validationErrorMessage);
  }

  List<Widget> _buildSummaryTables() {
    List<Widget> summaryWidgets = [];

    for (var definition in _thematicReportDefinitions) {
      String departmentName = definition['department'];
      String designationName = definition['designation'];
      String reportTypeKey = "${departmentName}_$designationName"
          .toLowerCase()
          .replaceAll(' ', '_');
      List<String> indicators =
      List<String>.from(definition['indicators'] ?? []);

      summaryWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            "$departmentName - $designationName",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
      summaryWidgets.add(_buildSummaryDataTable(reportTypeKey, indicators));
    }
    return summaryWidgets;
  }

  Widget _buildSummaryDataTable(String reportTypeKey, List<String> indicators) {
    // Check if data is cached, if not, fetch and cache
    _summaryDataCache ??= _fetchWeeklySummaryData();

    return FutureBuilder<Map<String, Map<String, int>>>(
      future: _summaryDataCache, // Use the cached Future
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text("Error loading summary data: ${snapshot.error}");
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No summary data available for this unit for the current month.");
        } else {
          Map<String, Map<String, int>> summaryData = snapshot.data!;
          return _buildDataTable(indicators, summaryData); // Helper to build the table UI
        }
      },
    );
  }

  Future<Map<String, Map<String, int>>> _fetchWeeklySummaryData() async {
    Map<String, Map<String, int>> weeklySummary = {};
    DateTime startDateOfMonth = DateTime(_selectedReportingDate.year, _selectedReportingDate.month, 1);
    DateTime endDateOfMonth = DateTime(_selectedReportingDate.year, _selectedReportingDate.month + 1, 0);

    print("DEBUG: _fetchWeeklySummaryData - Start fetching for ALL reportTypes, Month: ${DateFormat('MMMM yyyy').format(_selectedReportingDate)}");

    for (DateTime date = startDateOfMonth; date.isBefore(endDateOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(date);
      final CollectionReference<Map<String, dynamic>> reportCollectionRef = _firestore
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDate);

      print("DEBUG: _fetchWeeklySummaryData - Fetching reports for date: $formattedDate");
      final QuerySnapshot<Map<String, dynamic>> snapshot = await reportCollectionRef.get();
      print("DEBUG: _fetchWeeklySummaryData - Snapshot size for $formattedDate: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        Report report = Report.fromFirestore(doc, null);

        if (report.reportEntries != null && report.reportingWeek != null) { // Check for reportingWeek
          String weekIdentifier = report.reportingWeek!; // Use reportingWeek from report
          print("DEBUG: _fetchWeeklySummaryData - Processing report for date: $formattedDate, week: $weekIdentifier, reportType: ${report.reportType}");

          if (!weeklySummary.containsKey(weekIdentifier)) {
            weeklySummary[weekIdentifier] = {};
            print("DEBUG: _fetchWeeklySummaryData - Initializing week: $weekIdentifier in weeklySummary");
          }

          if (report.reportEntries == null) {
            print("DEBUG: _fetchWeeklySummaryData - report.reportEntries is NULL for reportType: ${report.reportType}, date: $formattedDate");
            continue; // Skip to next report if reportEntries is null
          }

          for (var username in report.reportEntries!.keys) {
            if (report.reportEntries![username] != null) {
              for (var indicatorEntry in report.reportEntries![username]!.entries) {
                String indicatorName = indicatorEntry.key;

                if (indicatorEntry.value.isEmpty) {
                  print("DEBUG: _fetchWeeklySummaryData - indicatorEntry.value is NULL or EMPTY for indicator: $indicatorName, week: $weekIdentifier");
                  continue; // Skip if indicatorEntry.value is null or empty
                }
                String valueString = indicatorEntry.value.first.value;
                int value = int.tryParse(valueString) ?? 0;
                print("DEBUG: _fetchWeeklySummaryData - Extracted value: '$valueString', parsed value: $value, indicator: $indicatorName, week: $weekIdentifier, reportType: ${report.reportType}");
                weeklySummary[weekIdentifier]![indicatorName] = (weeklySummary[weekIdentifier]![indicatorName] ?? 0) + value;
                print("DEBUG: _fetchWeeklySummaryData - Accumulated value: ${weeklySummary[weekIdentifier]![indicatorName]}, indicator: $indicatorName, week: $weekIdentifier, reportType: ${report.reportType}");

              }
            }
          }
        } else {
          print("DEBUG: _fetchWeeklySummaryData - Skipping report due to NULL reportEntries or reportingWeek, reportType: ${report.reportType}, date: $formattedDate");
        }
      }
    }
    print("DEBUG: _fetchWeeklySummaryData - Final weeklySummary data: $weeklySummary");
    return weeklySummary;
  }


  // Helper function to get week number (you can use a library for more robust week numbering if needed)
  int getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Widget _buildDataTable(List<String> indicators, Map<String, Map<String, int>> summaryData) {
    List<TableRow> tableRows = [];

    // Header Row
    List<Widget> headerCells = [
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Indicator", style: TextStyle(fontWeight: FontWeight.bold,fontSize:10)),
      ),
      ..._reportPeriodOptions.map((week) => Padding( // Use _reportPeriodOptions for week headers
          padding: const EdgeInsets.all(8.0),
          child: Text(week, style: const TextStyle(fontWeight: FontWeight.bold,fontSize:10))
      )),
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Monthly Total", style: TextStyle(fontWeight: FontWeight.bold,fontSize:10)),
      ),
    ];
    tableRows.add(TableRow(children: headerCells));

    // Data Rows
    for (String indicator in indicators) {
      List<Widget> dataCells = [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(indicator, style: TextStyle(fontWeight: FontWeight.bold,fontSize:10))),
      ];
      int monthlyTotal = 0;
      for (String week in _reportPeriodOptions) { // Use _reportPeriodOptions to iterate through weeks
        int weeklyValue = summaryData[week]?[indicator] ?? 0;
        dataCells.add(Padding(padding: const EdgeInsets.all(8.0), child: Text(weeklyValue.toString(), style: TextStyle(fontWeight: FontWeight.bold,fontSize:10))));
        monthlyTotal += weeklyValue;
      }
      dataCells.add(Padding(padding: const EdgeInsets.all(8.0), child: Text(monthlyTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold,fontSize:10))));
      tableRows.add(TableRow(children: dataCells));
    }


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        width: double.infinity, // Ensures full width
        child: Table(
          border: TableBorder.all(),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1), // Adjusts dynamically
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }
// // selectedFirebaseId
//   Widget _buildReviewListTab1() {
//     return StreamBuilder<List<Report>>( // Changed to StreamBuilder
//       stream: _fetchReportsForReviewStream(), // Changed to _fetchReportsForReviewStream
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasError) {
//           return Center(child: Text("Error loading review list: ${snapshot.error}"));
//         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text("No reports pending your review."));
//         } else {
//
//
//           List<Report> reviewReports = snapshot.data!;
//           print("snapshot.data buildReviewListTab ===${snapshot.data}");
//
//           // Filter reports to only include those where reviewerId matches _selectedFirebaseId
//           List<Report> filteredReviewReports = [];
//           for (Report report in reviewReports) {
//             bool reportNeedsReviewByCurrentUser = false;
//             if (report.reportEntries != null) {
//               for (var usernameEntry in report.reportEntries!.entries) {
//                 for (var indicatorEntry in usernameEntry.value.entries) {
//                   for (ReportEntry entry in indicatorEntry.value) {
//                     if (entry.reviewerId == selectedFirebaseId) { // Check reviewerId against _selectedFirebaseId
//                       reportNeedsReviewByCurrentUser = true;
//                       break;
//                     }
//                   }
//                   if (reportNeedsReviewByCurrentUser) break;
//                 }
//                 if (reportNeedsReviewByCurrentUser) break;
//               }
//             }
//             if (reportNeedsReviewByCurrentUser) {
//               filteredReviewReports.add(report);
//             }
//           }
//
//           // Create a set to store unique report identifiers (reportType + date) for filtered reports
//           Set<String> uniqueReportIdentifiers = {};
//           List<Report> uniqueReviewReports = []; // Use this list for display
//
//           for (Report report in filteredReviewReports) { // Iterate over filtered reports
//             print("report buildReviewListTab ===$report");
//             String reportIdentifier = "${report.reportType}_${DateFormat('yyyy-MM-dd').format(report.date!)}";
//             print("reportIdentifier buildReviewListTab ===$reportIdentifier");
//             if (!uniqueReportIdentifiers.contains(reportIdentifier)) {
//               uniqueReportIdentifiers.add(reportIdentifier);
//               uniqueReviewReports.add(report);
//               print("uniqueReportIdentifiers buildReviewListTab ===$uniqueReportIdentifiers");
//               print("uniqueReviewReports buildReviewListTab ===$uniqueReviewReports");
//             }
//           }
//
//           // Filter out reports that are completely reviewed by current user
//           List<Report> finalReviewReports = uniqueReviewReports.where((report) => !_isReportFullyActionedByCurrentUser(report)).toList();
//           print("finalReviewReports.length  ===${finalReviewReports.length}");
//
//
//           if (finalReviewReports.isEmpty) { // ADDED CONDITION - If no reports left after filtering
//             return const Center(child: Text("No reports pending your review.")); // Show "No reports" message again if list is empty
//           }
//
//
//
//           return ListView.builder(
//             itemCount: finalReviewReports.length, // Use finalReviewReports here
//             itemBuilder: (context, index) {
//               Report report = finalReviewReports[index]; // Use finalReviewReports here
//               print("ListView.builder report ===${report.reportEntries}");
//               return Card(
//                 elevation: 2,
//                 margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("${report.reportType}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//                       const SizedBox(height: 8),
//                       Text("Date: ${DateFormat('yyyy-MM-dd').format(report.date!)}"),
//                       const SizedBox(height: 16),
//                       if (report.reportEntries != null && report.reportEntries!.isNotEmpty)
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: report.reportEntries!.entries.map((usernameEntry) {
//                             return Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: usernameEntry.value.entries.map((indicatorEntry) {
//                                 // Separate Comments entry
//                                 ReportEntry? commentsEntry;
//                                 List<ReportEntry> otherEntries = [];
//                                 for (var entry in indicatorEntry.value) {
//                                   if (entry.key == 'Comments') {
//                                     commentsEntry = entry;
//                                   } else {
//                                     // Filter ReportEntry list to only include entries for the current reviewer
//                                     if (entry.reviewerId == selectedFirebaseId) {
//                                       otherEntries.add(entry);
//                                     }
//                                   }
//                                 }
//
//                                 // Sort otherEntries alphabetically by enteredBy
//                                 otherEntries.sort((a, b) => (a.enteredBy ?? "").compareTo(b.enteredBy ?? ""));
//
//                                 List<Widget> indicatorWidgets = [];
//
//                                 // Build widgets for other entries first
//                                 indicatorWidgets.addAll(otherEntries.map((entry) => _buildIndicatorRowForReview(report, entry, context)).toList());
//
//                                 // Build widget for Comments entry last, if it exists and for current reviewer
//                                 if (commentsEntry != null && commentsEntry.reviewerId == selectedFirebaseId) {
//                                   indicatorWidgets.add(_buildIndicatorRowForReview(report, commentsEntry, context));
//                                 }
//
//
//                                 return Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: indicatorWidgets,
//                                 );
//                               }).toList(),
//                             );
//                           }).toList(),
//                         ),
//                       const SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           ElevatedButton(
//                             onPressed: () {
//                               _approveReport(report);
//                             },
//                             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                             child: const Text("Approve All", style: TextStyle(color: Colors.white)),
//                           ),
//                           const SizedBox(width: 10),
//                           ElevatedButton(
//                             onPressed: () {
//                               _returnReport(report);
//                             },
//                             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                             child: const Text("Return All", style: TextStyle(color: Colors.white)),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         }
//       },
//     );
//   }

  bool _isReportFullyActionedByCurrentUser(Report report) {
    if (report.reportEntries == null) return true; // Consider completely actioned if no entries

    bool allActioned = true; // Assume all actioned initially
    report.reportEntries!.forEach((username, indicatorMap) {
      indicatorMap.forEach((indicatorKey, entryList) {
        for (ReportEntry entry in entryList) {
          if (entry.reviewerId == selectedFirebaseId && entry.reviewStatus == 'Pending') {
            allActioned = false; // If any entry for current reviewer is Pending, report is NOT fully actioned
            break;
          }
        }
        if (!allActioned) return; // Exit inner loop early if not allActioned
      });
      if (!allActioned) return; // Exit outer loop early if not allActioned
    });
    return allActioned; // Returns true if NO indicator is Pending for current reviewer
  }

  bool _isReportCompletelyReviewedByCurrentUser(Report report) {
    if (report.reportEntries == null) return true; // Consider completely reviewed if no entries

    bool allReviewed = true;
    report.reportEntries!.forEach((username, indicatorMap) {
      indicatorMap.forEach((indicatorKey, entryList) {
        for (ReportEntry entry in entryList) {
          if (entry.reviewerId == selectedFirebaseId && entry.reviewStatus != 'Approved') {
            allReviewed = false; // If any entry for current reviewer is not approved, report is not completely reviewed
            break;
          }
        }
        if (!allReviewed) return; // Exit inner loop early if not allReviewed
      });
      if (!allReviewed) return; // Exit outer loop early if not allReviewed
    });
    return allReviewed;
  }

  Widget _buildIndicatorRowForReview1(Report report, ReportEntry entry, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${entry.key}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(entry.value)),
            ],
          ),
          Visibility( // Conditionally show buttons based on reviewStatus
            visible: entry.reviewStatus != 'Approved' && entry.reviewStatus != 'Returned',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _updateIndicatorReviewStatus(report, entry, 'Approved');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Approve", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    _updateIndicatorReviewStatus(report, entry, 'Returned');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Return", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          if (entry.enteredBy != null)
            Text("Entered By: ${entry.enteredBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (entry.editedBy != null)
            Text("Edited By: ${entry.editedBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (entry.reviewedBy != null)
            Text("Reviewed By: ${entry.reviewedBy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (entry.reviewedBy != null)
            Text("Review Status: ${entry.reviewStatus}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (entry.attachments != null && entry.attachments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: GestureDetector(
                onTap: () {
                  String? imageUrl = entry.attachments!.firstWhere(
                          (attachment) => attachment.toLowerCase().endsWith(('.png')) || attachment.toLowerCase().endsWith(('.jpg')) || attachment.toLowerCase().endsWith(('.jpeg')),
                      orElse: () => '');
                  if (imageUrl.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImage(imagePath: imageUrl),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No image attachment found.')),
                    );
                  }
                },
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Image.network(
                    entry.attachments!.firstWhere(
                            (attachment) => attachment.toLowerCase().endsWith(('.png')) || attachment.toLowerCase().endsWith(('.jpg')) || attachment.toLowerCase().endsWith(('.jpeg')),
                        orElse: () => ''),
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.red),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildReviewListTab() {
    return StreamBuilder<List<Report>>(
      stream: _fetchReportsForReviewStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading review list: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No reports pending your review."));
        }

        List<Report> reviewReports = snapshot.data!;
        List<Report> filteredReviewReports = reviewReports.where((report) {
          if (report.reportEntries != null) {
            return report.reportEntries!.entries.any((usernameEntry) {
              return usernameEntry.value.entries.any((indicatorEntry) {
                return indicatorEntry.value.any((entry) => entry.reviewerId == selectedFirebaseId);
              });
            });
          }
          return false;
        }).toList();


        Set<String> uniqueReportIdentifiers = {};
        List<Report> uniqueReviewReports = filteredReviewReports.where((report) {
          String reportIdentifier = "${report.reportType}_${DateFormat('yyyy-MM-dd').format(report.date!)}";
          if (!uniqueReportIdentifiers.contains(reportIdentifier)) {
            uniqueReportIdentifiers.add(reportIdentifier);
            return true;
          }
          return false;
        }).toList();

        List<Map<String, dynamic>> userReportList = []; // Changed type to dynamic

        for (var report in uniqueReviewReports) {
          if (report.reportEntries != null) {
            for (var usernameEntry in report.reportEntries!.entries) {
              String username = usernameEntry.key;
              if (!_isReportFullyActionedByCurrentUserForUser(report, username)) { // Only add if not fully actioned for this user
                userReportList.add({'username': username, 'report': report});
              }
            }
          }
        }

        if (userReportList.isEmpty) {
          return const Center(child: Text("No reports pending your review."));
        }

        return ListView.builder(
          itemCount: userReportList.length,
          itemBuilder: (context, index) {
            final userReportData = userReportList[index];
            Report report = userReportData['report'] as Report; // Cast to Report
            String username = userReportData['username'] as String; // Cast to String

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(report.reportType!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("Date: ${DateFormat('yyyy-MM-dd').format(report.date!)}"),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Entered by: $username", style: const TextStyle(fontWeight: FontWeight.bold)), // Display username in card
                    const SizedBox(height: 16),
                    Column(
                      children: _buildIndicatorRowsForUser(report, username), // Extract indicator row building
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => _approveReportForUser(report, username), // Approve for specific user
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Approve All", style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _returnReportForUser(report, username), // Return for specific user
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text("Return All", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  List<Widget> _buildIndicatorRowsForUser(Report report, String username) {
    Map<String, List<ReportEntry>>? indicatorMap = report.reportEntries?[username];
    if (indicatorMap == null) {
      return [];
    }

    List<Widget> indicatorRowsForUser = [];
    indicatorMap.forEach((indicatorKey, entryList) {
      List<ReportEntry> relevantEntries = entryList.where((entry) => entry.reviewerId == selectedFirebaseId).toList();
      relevantEntries.sort((a, b) => (a.enteredBy ?? "").compareTo(b.enteredBy ?? ""));
      indicatorRowsForUser.addAll(relevantEntries.map((entry) => _buildIndicatorRowForReview(report, entry, context, username)).toList());
    });
    return indicatorRowsForUser;
  }


  Future<void> _approveReportForUser(Report report, String username) async {
    Report updatedReport = report;

    updatedReport.reportEntries?.forEach((entryUsername, indicatorMap) {
      if (entryUsername == username) { // Target specific username
        indicatorMap.forEach((indicatorKey, entryList) {
          List<ReportEntry> newEntryList = entryList.map((entry) {
            if (entry.reviewerId == selectedFirebaseId) {
              return entry.copyWith(reviewStatus: 'Approved'); // Use copyWith for immutability
            }
            return entry;
          }).toList();
          updatedReport.reportEntries![entryUsername]![indicatorKey] = newEntryList;
        });
      }
    });
    await _updateReportReviewStatus(updatedReport);
  }


  Future<void> _returnReportForUser(Report report, String username) async {
    Report updatedReport = report;

    updatedReport.reportEntries?.forEach((entryUsername, indicatorMap) {
      if (entryUsername == username) { // Target specific username
        indicatorMap.forEach((indicatorKey, entryList) {
          List<ReportEntry> newEntryList = entryList.map((entry) {
            if (entry.reviewerId == selectedFirebaseId) {
              return entry.copyWith(reviewStatus: 'Returned'); // Use copyWith for immutability
            }
            return entry;
          }).toList();
          updatedReport.reportEntries![entryUsername]![indicatorKey] = newEntryList;
        });
      }
    });
    await _updateReportReviewStatus(updatedReport);
  }


  bool _isReportFullyActionedByCurrentUserForUser(Report report, String username) {
    if (report.reportEntries == null || report.reportEntries![username] == null) return true;

    bool allActioned = true;
    report.reportEntries![username]!.forEach((indicatorKey, entryList) {
      for (ReportEntry entry in entryList) {
        if (entry.reviewerId == selectedFirebaseId && entry.reviewStatus == 'Pending') {
          allActioned = false;
          break;
        }
      }
      if (!allActioned) return; // Optimization: Exit early if not fully actioned
    });
    return allActioned;
  }

  Future<void> _approveReportEntry1(Report report, String username, ReportEntry entry) async {
    Report updatedReport = report;

    updatedReport.reportEntries?[username]?.forEach((indicatorKey, entryList) {
      for (int i = 0; i < entryList.length; i++) {
        if (entryList[i] == entry && entryList[i].reviewerId == selectedFirebaseId) {
          entryList[i] = entryList[i].copyWith(reviewStatus: 'Approved'); // Use copyWith
          break;
        }
      }
    });
    await _updateReportReviewStatus(updatedReport);
  }

  Future<void> _returnReportEntry1(Report report, String username, ReportEntry entry) async {
    Report updatedReport = report;

    updatedReport.reportEntries?[username]?.forEach((indicatorKey, entryList) {
      for (int i = 0; i < entryList.length; i++) {
        if (entryList[i] == entry && entryList[i].reviewerId == selectedFirebaseId) {
          entryList[i] = entryList[i].copyWith(reviewStatus: 'Returned'); // Use copyWith
          break;
        }
      }
    });
    await _updateReportReviewStatus(updatedReport);
  }


  Widget _buildIndicatorRowForReview(Report report, ReportEntry entry, BuildContext context,String username) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "${entry.key}:  ",
                  softWrap: true,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),

          // Conditionally show buttons based on reviewStatus
          Visibility(
            visible: entry.reviewStatus != 'Approved' && entry.reviewStatus != 'Returned',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildStatusButton(
                  context: context,
                  label: "Approve",
                  color: Colors.green,
                  onPressed: () => _approveReportEntry1(report, username,entry),
                ),
                const SizedBox(width: 10),
                _buildStatusButton(
                  context: context,
                  label: "Return",
                  color: Colors.red,
                  onPressed: () => _returnReportEntry1(report, username,entry),
                ),
              ],
            ),
          ),
          // Display metadata
          _buildMetadata("Entered By", entry.enteredBy),
          _buildMetadata("Edited By", entry.editedBy),
          _buildMetadata("Reviewed By", entry.reviewedBy),
          if (entry.reviewStatus != null)
            _buildMetadata("Review Status", entry.reviewStatus),

          // Display image attachment
          if (entry.attachments != null && entry.attachments!.isNotEmpty)
            _buildAttachmentPreview(entry.attachments!, context),

          const Divider(),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required BuildContext context,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildMetadata(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink(); // Hide metadata if value is empty
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(List<String> attachments, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Attachments:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Image.network(attachments[index], width: 100, fit: BoxFit.cover),
              );
            },
          ),
        ),
      ],
    );
  }





  // Modified _fetchReportsForReview to return Stream
  Stream<List<Report>> _fetchReportsForReviewStream() {
    String? currentUserId = selectedFirebaseId;

    if (currentUserId == null) {
      print("Current user ID is null, cannot fetch reports for review.");
      return Stream.value([]); // Return empty stream if no user ID
    }

    print("_fetchReportsForReview: Current User ID: $currentUserId");

    String currentDate = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    return FirebaseFirestore.instance
        .collection('Reports')
        .doc(selectedBioState)
        .collection(selectedBioState!)
        .doc(selectedBioLocation)
        .collection(currentDate)
        .snapshots()
        .map((snapshot) {
      List<Report> reportsForReview = [];
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          Report report = Report.fromFirestore(doc, null);
          print("_fetchReportsForReviewStream: Report Type: ${report.reportType}, Status: ${report.reportStatus}");

          if (report.reportStatus == 'Pending' && report.reportEntries != null) {
            for (var username in report.reportEntries!.keys) {
              var indicatorMap = report.reportEntries![username];
              for (var indicator in indicatorMap!.keys) {
                for (var entry in indicatorMap[indicator]!) {
                  print("_fetchReportsForReviewStream:   Indicator: ${entry.key}, Reviewer ID: ${entry.reviewerId}");
                  if (entry.reviewerId == currentUserId) {
                    reportsForReview.add(report);
                    break;
                  }
                }
              }
            }
          }
        }
      } else {
        print("No reports found for user ID: $currentUserId");
      }
      return reportsForReview;
    });
  }

  Future<void> _approveReport(Report report) async {
    Report updatedReport = report;
   // updatedReport.reportStatus = 'Approved'; // Keep overall report status update

    // Iterate through report entries to approve individual indicators for the current reviewer
    updatedReport.reportEntries?.forEach((username, indicatorMap) {
      indicatorMap.forEach((indicatorKey, entryList) {
        for (int i = 0; i < entryList.length; i++) {
          if (entryList[i].reviewerId == selectedFirebaseId) { // Check reviewerId
            updatedReport.reportEntries![username]![indicatorKey]![i] = entryList[i]..reviewStatus = 'Approved';
          }
        }
      });
    });

    await _updateReportReviewStatus(updatedReport);
  }

  Future<void> _returnReport(Report report) async {
    Report updatedReport = report;
    //updatedReport.reportStatus = 'Rejected'; // or 'Returned' as per your model, Keep overall report status update

    // Iterate through report entries to return individual indicators for the current reviewer
    updatedReport.reportEntries?.forEach((username, indicatorMap) {
      indicatorMap.forEach((indicatorKey, entryList) {
        for (int i = 0; i < entryList.length; i++) {
          if (entryList[i].reviewerId == selectedFirebaseId) { // Check reviewerId
            updatedReport.reportEntries![username]![indicatorKey]![i] = entryList[i]..reviewStatus = 'Returned'; // Or 'Rejected'
          }
        }
      });
    });

    await _updateReportReviewStatus(updatedReport);
  }


  Future<void> _updateReportReviewStatus(Report report) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot update report status.");
      return;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(report.date!);
      final DocumentReference reportDocRef = FirebaseFirestore.instance
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(report.reportType); // Assuming reportType is used as document ID

      await reportDocRef.set(report.toFirestore(), SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report status updated !')));
      setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating report status.')));
      print("Error updating report status in Firestore: $e");
    }
  }

  Future<void> _updateIndicatorReviewStatus(Report report, ReportEntry entry, String status) async {
    if (selectedBioState == null || selectedBioLocation == null) {
      print("BioModel data is incomplete, cannot update indicator review status.");
      return;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(report.date!);
      final DocumentReference reportDocRef = FirebaseFirestore.instance
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(report.reportType);

      Report updatedReport = report;
      // Assuming reportEntries structure is Map<Username, Map<IndicatorKey, List<ReportEntry>>>
      updatedReport.reportEntries?.forEach((username, indicatorMap) {
        indicatorMap.forEach((indicatorKey, entryList) {
          for (int i = 0; i < entryList.length; i++) {
            // ADDED CONDITION: Check if the entry's key and reviewerId match
            if (entryList[i].key == entry.key && entryList[i].reviewerId == selectedFirebaseId) {
              updatedReport.reportEntries![username]![indicatorKey]![i] = entryList[i]..reviewStatus = status;
              break; // Stop once found and updated for the current reviewer
            }
          }
        });
      });

      await reportDocRef.set(updatedReport.toFirestore(), SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indicator status updated to $status!')));
      setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating indicator status.')));
      print("Error updating indicator status in Firestore: $e");
    }
  }


  @override
  void dispose() {
    for (var watcher in _reportWatchers) {
      watcher.cancel();
    }
    super.dispose();
  }

  // Function to handle media picking (image or document) - Modified to offer document option
  Future<void> _handleMedia(ImageSource? imgSource, {String? reportType, Task? task}) async {
    if (imgSource != null) {
      // Handle image capture/gallery selection
      final XFile? pickedImage = await _picker.pickImage(source: imgSource, maxWidth: 800, maxHeight: 800);
      if (pickedImage != null) {
        _addAttachment(pickedImage, reportType: reportType, task: task);
      }
    } else {
      // Handle document selection
      FilePickerResult? pickedDocument = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'doc', 'docx', 'txt', 'csv', 'ppt', 'pptx', 'odt', 'ods'], // Define allowed document types
      );
      if (pickedDocument != null && pickedDocument.files.isNotEmpty) {
        PlatformFile file = pickedDocument.files.single;
        String? mimeType = mime(file.name);
        XFile xFile = XFile.fromData(file.bytes!, name: file.name, mimeType: mimeType);
        _addAttachment(xFile, reportType: reportType, task: task);
      }
    }
  }


  void _addAttachment(XFile pickedFile, {String? reportType, Task? task}) {
    String fileName = pickedFile.name;

    AttachmentData attachment = AttachmentData(
      file: pickedFile,
      uploadProgress: 0, // Initial progress
      isUploading: false, // Not uploading yet
      downloadUrl: null,
      fileName: fileName,
    );

    print("_addAttachment: Attachment created, fileName: $fileName, pickedFile is null? ${pickedFile == null}"); // ADDED LOG - Check pickedFile right after picking
    print("_addAttachment: Attachment created, attachment.file is null? ${attachment.file == null}"); // ADDED LOG - Check attachment.file after creating AttachmentData

    setState(() {
      if (reportType != null) {
        _reportAttachmentsData[reportType] =
        (_reportAttachmentsData[reportType] ?? [])..add(attachment);
      } else if (task == null) {
        // Assuming task == null means it's for the task bottom sheet
        _taskBottomSheetAttachmentsData.add(attachment);
      } else {
        _taskCardAttachmentsData[task.id ?? -1] =
        (_taskCardAttachmentsData[task.id ?? -1] ?? [])..add(attachment);
      }
    });
  }


  Widget _buildReportDataTable(String reportTypeKey, List<String> indicators) {
    Report? loadedReport = _loadedReports[reportTypeKey];
    if (loadedReport == null || loadedReport.reportEntries == null || loadedReport.reportEntries!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text("No data available for table view."),
      );
    }

    List<String> usernames = loadedReport.reportEntries!.keys.toList();
    List<TableRow> tableRows = [];

    // Header row
    List<Widget> headerCells = [
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Indicator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      ...usernames.map((username) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      )),
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ];
    tableRows.add(TableRow(children: headerCells));

    // Data rows for indicators
    for (String indicator in indicators) {
      List<Widget> dataCells = [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(indicator, style: TextStyle(fontSize: 12))),
      ];
      int indicatorTotal = 0;

      for (String username in usernames) {
        var entry = loadedReport.reportEntries![username]?[indicator]?.first;
        String value = entry?.value ?? "0";
        String reviewedBy = entry?.reviewedBy ?? "N/A";
        String reviewStatus = entry?.reviewStatus ?? "Pending";
        Color statusColor = reviewStatus.toLowerCase() == "approved"
            ? Colors.green.shade700
            : reviewStatus.toLowerCase() == "returned"
            ? Colors.red
            : Colors.blueGrey;

        dataCells.add(Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 12)),
              Text("Reviewed by: $reviewedBy", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
              Text("Status: $reviewStatus", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
        ));

        indicatorTotal += int.tryParse(value) ?? 0;
      }

      dataCells.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(indicatorTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ));
      tableRows.add(TableRow(children: dataCells));
    }

    // "App Analysis" row
    List<Widget> analysisCells = [
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Data Quality Check", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
      ...usernames.map((username) {
        String analysisText = loadedReport.reportEntries![username]![indicators.first]?.first.appAnalysis ?? "No image Uploaded for Analysis";
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(analysisText, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
        );
      }),
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
    tableRows.add(TableRow(children: analysisCells));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: Table(
          border: TableBorder.all(),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }



  String? mimeTypeFromUrl(String url) {
    final Uri uri = Uri.parse(url);
    final String path = uri.path;
    return mime(path);
  }

  // Widget to display attachments in a grid view
// Widget to display attachments in a grid view (Progress bar removed)
  Widget _buildAttachmentGrid(List<AttachmentData> attachmentsData, {String? reportType, Task? task, bool isReadOnly = false}) { // ADDED: isReadOnly flag
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: attachmentsData.length,
      itemBuilder: (context, index) {
        final attachmentData = attachmentsData[index];
        final fileName = attachmentData.fileName;
        String? mimeType = attachmentData.file?.mimeType; // Get mime type from XFile
        String? urlMimeType = mimeTypeFromUrl(attachmentData.downloadUrl ?? ''); // Mime type from URL
        bool isVideo = (mimeType != null && mimeType.startsWith('video/')) || (urlMimeType != null && urlMimeType.startsWith('video/'));
        bool isImage = (mimeType != null && mimeType.startsWith('image/')) || (urlMimeType != null && urlMimeType.startsWith('image/'));
        bool isDocument = !isImage && !isVideo; // Treat everything else as document
        final String? downloadUrl = attachmentData.downloadUrl;

        Widget thumbnailWidget;


        if (isVideo) {
          thumbnailWidget = AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.black,
              child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
            ),
          );
        } else if (isImage) { // Image from XFile bytes
          thumbnailWidget = AspectRatio(
            aspectRatio: 1,
            child: FutureBuilder<Uint8List?>( // Modified FutureBuilder to handle Uint8List?
              future: downloadUrl == null && attachmentData.file != null ? attachmentData.file!.readAsBytes() : null, // Read bytes only if downloadUrl is null and file is available
              builder: (context, snapshot) {
                if (downloadUrl != null) {
                  return Image.network(downloadUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.red)); // Load from URL if available
                } else if (snapshot.hasData && snapshot.data != null) { // Check for null data
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                } else if (snapshot.hasError) {
                  return const Icon(Icons.error_outline, color: Colors.red);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          );
        } else if (isDocument) {
          // Document Preview - Show document icon
          thumbnailWidget = AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file, size: 40, color: Colors.grey[700]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Fallback for unknown types
          thumbnailWidget = AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.attach_file, size: 40, color: Colors.grey)),
            ),
          );
        }


        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (isVideo && downloadUrl != null) {
                  // For web, video preview might need different approach
                  // For now, just show a message or handle as needed
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenVideo(videoPath: downloadUrl), // Pass download URL
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video preview not fully implemented in web yet.')));
                } else if (isImage && downloadUrl != null) { // Use downloadUrl for image preview
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImage(imagePath: downloadUrl), // Pass download URL
                    ),
                  );
                } else if (isImage && attachmentData.file != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageFromMemory(imageData: thumbnailWidget as AspectRatio), // Pass Image.memory widget
                    ),
                  );
                }
                else if (isDocument && downloadUrl != null) {
                  // For web, document open might need different approach
                  // For now, just show a message or handle as needed
                  //ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document open not fully implemented in web yet.')));
                  _openDocument(downloadUrl); // Open document on tap - Original implementation for file path
                }

              },
              child: thumbnailWidget,
            ),
            if (!isReadOnly) // Conditionally show edit/delete options
              Positioned(
                bottom: 0,
                left: 0,
                child: InkWell(
                  onTap: () {
                    _handleChangeAttachment(index, reportType: reportType, task: task);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      children: [
                        Icon(Icons.edit, color: Colors.blue[700], size: 18),
                        Text('Change', style: TextStyle(fontSize: 10, color: Colors.orange[700])),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isReadOnly) // Conditionally show edit/delete options
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () {
                    _handleDeleteAttachment(index, reportType: reportType, task: task);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Column(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        Text('Delete', style: TextStyle(fontSize: 10, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }



// Function to download file and then open it
  Future<void> _downloadAndOpenFile(String downloadUrl, String fileName) async {
    try {
      print("Attempting to download file from URL: $downloadUrl");
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete(); // Delete any existing file
      }

      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print("File downloaded to: ${file.path}");
        _openDocument(file.path); // Open the downloaded file
      } else {
        print("Download failed with status code: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Could not open document.')),
        );
      }
    } catch (e) {
      print("Error downloading or opening file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening document.')),
      );
    }
  }


  // Function to open document (PDF or other types) using OpenFilex - Modified to handle local paths
  Future<void> _openDocument(String localPath) async { // Expecting localPath now
    try {
      OpenFilex.open(localPath);
      print("Attempting to open document at local path: $localPath");
    } catch (e) {
      print("Error opening document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document. Please ensure you have a suitable application installed.')),
      );
    }
  }


  void _handleChangeAttachment(int index, {String? reportType, Task? task}) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose Image from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, ImageSource.gallery,
                  reportType: reportType, task: task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, ImageSource.camera,
                  reportType: reportType, task: task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Choose Document'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, null,
                  isDocument: true, reportType: reportType, task: task);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _replaceAttachment(int index, ImageSource? imgSource,
      {bool isDocument = false, String? reportType, Task? task}) async {
    if (!isDocument) {
      // Replace with image
      final XFile? pickedFile =
      await _picker.pickImage(source: imgSource!, maxWidth: 800, maxHeight: 800);
      if (pickedFile != null) {
        _updateAttachment(index, pickedFile,
            reportType: reportType, task: task);
      }
    } else {
      // Replace with document
      FilePickerResult? pickedDocument = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'xlsx',
          'xls',
          'doc',
          'docx',
          'txt',
          'csv',
          'ppt',
          'pptx',
          'odt',
          'ods'
        ],
      );
      if (pickedDocument != null && pickedDocument.files.isNotEmpty) {
        PlatformFile file = pickedDocument.files.single;
        String? mimeType = mime(file.name);
        XFile xFile = XFile.fromData(file.bytes!, name: file.name, mimeType: mimeType);
        _updateAttachment(index, xFile,
            reportType: reportType, task: task);
      }
    }
  }

  void _updateAttachment(int index, XFile newFile,
      {String? reportType, Task? task}) {
    setState(() {
      if (reportType != null) {
        if (_reportAttachmentsData[reportType] != null &&
            _reportAttachmentsData[reportType]!.length > index) {
          _reportAttachmentsData[reportType]![index] = AttachmentData(
            file: newFile,
            uploadProgress: 0,
            isUploading: false,
            downloadUrl: null,
            fileName: newFile.name,
          );
        }
      } else if (task == null) {
        if (_taskBottomSheetAttachmentsData.length > index) {
          _taskBottomSheetAttachmentsData[index] = AttachmentData(
            file: newFile,
            uploadProgress: 0,
            isUploading: false,
            downloadUrl: null,
            fileName: newFile.name,
          );
        }
      } else if (_taskCardAttachmentsData[task.id ?? -1] != null &&
          _taskCardAttachmentsData[task.id ?? -1]!.length > index) {
        _taskCardAttachmentsData[task.id ?? -1]![index] = AttachmentData(
          file: newFile,
          uploadProgress: 0,
          isUploading: false,
          downloadUrl: null,
          fileName: newFile.name,
        );
      }
    });
  }

  void _handleDeleteAttachment(int index, {String? reportType, Task? task}) {
    setState(() {
      if (reportType != null) {
        if (_reportAttachmentsData[reportType] != null &&
            _reportAttachmentsData[reportType]!.length > index) {
          _reportAttachmentsData[reportType]!.removeAt(index);
          if (_reportAttachmentsData[reportType]!.isEmpty) {
            _reportAttachmentsData.remove(
                reportType); // Remove the list if it becomes empty
          }
        }
      } else if (task == null) {
        if (_taskBottomSheetAttachmentsData.length > index) {
          _taskBottomSheetAttachmentsData.removeAt(index);
        }
      } else if (_taskCardAttachmentsData[task.id ?? -1] != null &&
          _taskCardAttachmentsData[task.id ?? -1]!.length > index) {
        _taskCardAttachmentsData[task.id ?? -1]!.removeAt(index);
        if (_taskCardAttachmentsData[task.id ?? -1]!.isEmpty) {
          _taskCardAttachmentsData.remove(
              task.id ?? -1); // Remove the list if it becomes empty
        }
      }
    });
  }

  // Async initialization to ensure controllers are initialized before loading reports.
  Future<void> _initializeAsync() async {
    print("_initializeAsync: Starting initialization");
    await _loadBioDataForSupervisor();
//    await _initializeControllers();
    await _fetchUsername();
    await _loadReportsForSelectedDate();
    await _loadTasksForSelectedDate();

    print("_initializeAsync: Reports and Tasks loaded, initializing controllers");
    if (selectedBioState != null && selectedBioLocation != null) {
      _initializeReportWatchers();
    } else {
      print(
          "_initializeAsync: BioData is not fully loaded, skipping report watchers initialization.");
    }

    print("_initializeAsync: Controllers initialized");
  }

  Future<void> _loadBioDataForSupervisor() async {
    print(
        "_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Loading bio data for supervisor");
    await _loadBioData().then((_) async {
      if (selectedBioDepartment != null && selectedBioState != null) {
        print(
            "_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data loaded, loading supervisor names - Department: $selectedBioDepartment, State: $selectedBioState");
        await _loadSupervisorNames(selectedBioDepartment!, selectedBioState!);
      } else {
        print(
            "_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data or department/state is missing for supervisor loading!");
        if (bioData == null) {
          print(
              "_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: bioData is NULL");
        } else {
          print(
              "_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Department: $selectedBioDepartment, State: $selectedBioState");
        }
      }
    });
  }

  Future<void> _loadSupervisorNames(String department, String state) async {
    print(
        "_DailyActivityMonitoringPageState: _loadSupervisorNames: Fetching supervisor names for department: $department, state: $state");
    supervisorNames = await _firestoreService.getSupervisorEmailFromFirestore1(
        department, 'Supervisor Name');
    print(
        "_DailyActivityMonitoringPageState: _loadSupervisorNames: Supervisor names list after fetch: $supervisorNames");
    if (supervisorNames.isNotEmpty) {
      setState(() {
        print(
            "_DailyActivityMonitoringPageState: _loadSupervisorNames: setState called to rebuild UI with supervisor names - List is NOT empty");
      });
    } else {
      print(
          "_DailyActivityMonitoringPageState: _loadSupervisorNames: No supervisors found for department: $department, state: $state - List is empty");
    }
  }

  BioModel? bioData;


  Future<void> _loadBioData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid; // Get the user UUID

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot =
      await FirebaseFirestore.instance.collection('Staff').doc(userId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data()!;
        setState(() {
          selectedBioFirstName = data['firstName'] ?? '';
          selectedBioLastName = data['lastName'] ?? '';
          selectedBioDepartment = data['department'] ?? '';
          selectedBioState = data['state'] ?? '';
          selectedBioDesignation = data['designation'] ?? '';
          selectedBioLocation = data['location'] ?? '';
          selectedBioStaffCategory = data['staffCategory'] ?? '';
          selectedBioEmail = data['emailAddress'] ?? '';
          selectedBioPhone = data['mobile'] ?? '';
          selectedSignatureLink = data['signatureLink'] ?? '';
          selectedFirebaseId = userId; // Store the Firebase UUID
        });

        print("selectedBioDepartment ===$selectedBioDepartment");
        print("selectedBioState ===$selectedBioState");
        print("selectedBioLocation ===$selectedBioLocation");
      } else {
        print("No bio data found for user ID: $userId");
      }
    } catch (e) {
      print("Error loading bio data: $e");
    }
  }

  // Function to load staff list (Corrected function name)
  Future<void> _loadStaffList() async { // Corrected function name
    setState(() {
      _isLoadingStaffList = true;
    });

    try {
      if (selectedBioLocation == null || selectedBioState == null) {
        print("BioLocation or BioState is null, cannot load staff list.");
        setState(() => _isLoadingStaffList = false);
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("Current user is not logged in, cannot load staff list.");
        setState(() => _isLoadingStaffList = false);
        return;
      }

      QuerySnapshot<Map<String, dynamic>> staffSnapshot = await FirebaseFirestore.instance
          .collection("Staff")
          .where("location", isEqualTo: selectedBioLocation)
          .where("state", isEqualTo: selectedBioState)
          .where("staffCategory", isEqualTo: "Facility Staff")
          .get();

      List<FacilityStaffModel> staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data();
        return FacilityStaffModel(
          userId: doc.id,
          name: "${data['lastName']} ${data['firstName']}",
          //location: data['location'],
          state: data['state'],
          staffCategory: data['staffCategory'],
        );
      }).toList();

      print("Loaded Staff List: ${staffList.map((s) => '${s.name} - ${s.userId}').toList()}");

      setState(() {
        _staffList = staffList;
        _isLoadingStaffList = false;
      });
    } catch (error, stackTrace) {
      print('Error loading staff list: $error');
      print(stackTrace);
      setState(() => _isLoadingStaffList = false);
    }
  }



  // Fetches the username of the logged-in user from Firestore database (using BioData for now).
  Future<void> _fetchUsername() async {
    print("_fetchUsername: Fetching username");
    BioModel? bio = await _firestoreService.getBioInfoWithFirebaseAuth();
    setState(() {
      if (selectedBioFirstName != null && selectedBioLastName != null) {
        _currentUsername = "${selectedBioFirstName!} ${selectedBioLastName!}";
      } else {
        _currentUsername = "Unknown User";
      }
    });
    print("_fetchUsername: Username fetched: $_currentUsername");
  }

  Future<void> _loadReportsForSelectedDate() async {
    await _loadBioData(); // Ensure bioData is loaded before fetching reports
    // if (bioData == null) {
    //   print("_loadReportsForSelectedDate: BioData is null, cannot load reports.");
    //   return;
    // }
    print("_loadReportsForSelectedDate: Loading reports for date: $_selectedReportingDate");
    _loadedReports.clear();
    _reportAttachmentsData.clear(); // Clear attachment data
    _isEditingReportSection.clear();
    reportControllers.clear(); // Clear controllers on date change
    reportUsernames.clear();
    reportEditedUsernames.clear();

    List<Report> reports = await getReportsByDate(_selectedReportingDate, bioData,); // Example department, adjust as needed
    print("_loadReportsForSelectedDate: Fetched reports count: ${reports.length}");
    print("Loaded Reports: $reports");

    setState(() {
      for (var report in reports) {
        print("_loadReportsForSelectedDate: Processing report type: ${report.reportType}");
        _loadedReports[report.reportType!] = report;
        _isEditingReportSection[report.reportType!] = true;
        if (report.attachments != null) {
          _reportAttachmentsData[report.reportType!] = report.attachments!.map((url) => AttachmentData.fromUrl(url)).toList(); // Convert URLs to AttachmentData
        }
        print(
            "_loadReportsForSelectedDate: Loaded report for ${report.reportType}: ${_loadedReports[report.reportType!]}");
      }
      _updateControllerValuesFromLoadedReports();
    });
    print("_loadReportsForSelectedDate: Report loading and controller update complete.");
  }

  Future<void> _loadAllReportsForSelectedDate() async {
    _allReportsForDate.clear();
    await _loadBioData();
    if (bioData == null) {
      print("_loadAllReportsForSelectedDate: BioData is null, cannot load reports.");
      return;
    }

    final departments = ["Laboratory", "Care and Treatment", "Pharmacy and Logistics", "Prevention", "Strategic Information"]; // Example departments, adjust as needed

    for (String department in departments) {
      List<Report> reports = await getAllReportsForDate(_selectedReportingDate, bioData, department);
      _allReportsForDate[department] = reports;
    }
    setState(() {}); // Rebuild UI to display the table
  }

  Future<void> _loadTasksForSelectedDate() async {
    print("_loadTasksForSelectedDate: Loading tasks for date: $_selectedReportingDate");
    List<Task> tasks = await getTasksByDate(_selectedReportingDate);
    print("Loaded Tasks === $tasks");
    setState(() {
      _tasksForDate = tasks;
      _taskCardAttachmentsData.clear();
      for (var task in tasks) {
        if (task.attachments != null) {
          _taskCardAttachmentsData[task.id ?? -1] = task.attachments!.map((url) => AttachmentData.fromUrl(url)).toList(); // Convert URLs to AttachmentData
        }
      }
    });
    print("_loadTasksForSelectedDate: Fetched tasks count: ${_tasksForDate.length}");
  }
  void _updateControllerValuesFromLoadedReports() {
    for (var definition in _thematicReportDefinitions) {
      String reportTypeKey = "${definition['department']}_${definition['designation']}"
          .toLowerCase()
          .replaceAll(' ', '_');
      List<String> indicators =
      List<String>.from(definition['indicators'] ?? []);

      if (!_isControllerMapInitialized(reportTypeKey)) {
        _initializeControllerMap(reportTypeKey, indicators);
        _initializeEditableMap(reportTypeKey, indicators);
      }
      _updateControllersFromReport(
          _loadedReports[reportTypeKey],
          reportControllers[reportTypeKey]!,
          indicators,
          reportUsernames[reportTypeKey]!,
          reportEditedUsernames[reportTypeKey]!,
          reportTypeKey);
    }
  }



// Helper function to initialize _isIndicatorEditable map
void _initializeEditableMap(String reportTypeKey, List<String> indicators) {
  _isIndicatorEditable[reportTypeKey] = {};
  for (String indicator in indicators) {
    _isIndicatorEditable[reportTypeKey]![indicator] = false; // Default to not editable
  }
}

  void _updateControllersFromReport(
      Report? report,
      Map<String, TextEditingController> controllers,
      List<String> indicators,
      Map<String, String?> usernames,
      Map<String, String?> editedUsernames,
      String reportTypeKey
      ) {
    String reportType = report?.reportType ?? 'unknown';
    if (report != null && report.reportEntries != null) {
      final username = _currentUsername;
      if (report.reportEntries![username] != null) {
        for (var indicatorEntry in report.reportEntries![username]!.entries) {
          final indicatorName = indicatorEntry.key;
          final entryList = indicatorEntry.value;
          if (entryList.isNotEmpty) {
            final entry = entryList.first;
            if (controllers.containsKey(indicatorName)) {
              // Load text only if status is Pending or Returned OR if indicator is in edit mode.
              if (entry.reviewStatus == 'Pending' || entry.reviewStatus == 'Returned' || (_isIndicatorEditable[reportTypeKey]?[indicatorName] ?? false)) {
                controllers[indicatorName]!.text = entry.value;
              }
              // **MODIFIED: Do NOT clear for Approved status. Retain the value.**
              // else {
              //   controllers[indicatorName]!.text = ""; // Clear for Approved status in edit mode
              // }
              usernames[indicatorName] = entry.enteredBy;
              editedUsernames[indicatorName] = entry.editedBy;
            }
          }
        }
      }
    } else {
      _resetControllers(controllers, indicators, usernames, editedUsernames);
    }
  }


  bool _isControllerMapInitialized(String reportTypeKey) {
    return reportControllers.containsKey(reportTypeKey);
  }


  // Helper function to update controllers for a specific report type from a loaded report. (Modified to be dynamic)
  void _updateControllersFromReport1(
      Report? report,
      Map<String, TextEditingController> controllers,
      List<String> indicators,
      Map<String, String?> usernames,
      Map<String, String?> editedUsernames) {
    String reportType = report?.reportType ?? 'unknown';
    if (report != null && report.reportEntries != null) {
      // Assuming reportEntries is now Map<String, Map<String, List<ReportEntry>>>
      final username = _currentUsername; // Use current username as key
      if (report.reportEntries![username] != null) {
        for (var indicatorEntry in report.reportEntries![username]!.entries) {
          final indicatorName = indicatorEntry.key;
          final entryList = indicatorEntry.value; // List of ReportEntry for this indicator
          if (entryList.isNotEmpty) {
            final entry = entryList.first; // Assuming only one entry per indicator for now
            if (controllers.containsKey(indicatorName)) {
              controllers[indicatorName]!.text = entry.value;
              usernames[indicatorName] = entry.enteredBy;
              editedUsernames[indicatorName] = entry.editedBy;
            }
          }
        }
      }
    } else {
      _resetControllers(controllers, indicators, usernames, editedUsernames);
    }
  }


  // Initializes all TextEditingControllers dynamically based on indicators from Firestore.
  void _initializeControllerMap(String reportTypeKey, List<String> indicators) {
    reportControllers[reportTypeKey] = {};
    reportUsernames[reportTypeKey] = {};
    reportEditedUsernames[reportTypeKey] = {};
    for (String indicator in indicators) {
      reportControllers[reportTypeKey]![indicator] = TextEditingController();
    }
  }

  // Updates the report period options based on the selected report type (currently only "Daily").
  void _updateReportPeriodOptions23(String reportType) {
    setState(() {
      _selectedReportPeriod = null;
      _selectedMonthForWeekly = null;
      _reportPeriodOptions =
      reportType == "Daily" ? ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"] : [];
    });
  }


  void _updateReportPeriodOptions(String reportType) {
    setState(() {
      _selectedReportPeriod = null;
      _selectedMonthForWeekly = null;
      _reportPeriodOptions = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"]; // Initialize for Daily reports too

    });
  }

  // Generates a list of last 12 months for the monthly dropdown options.
  List<String> _generateMonthlyOptions() {
    List<String> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat("MMMM yyyy").format(monthDate));
    }
    return months;
  }

// Builds a single indicator text field, either as read-only text or editable TextFormField. (Modified to handle indicator editability and display for "Approved")
  Widget _buildIndicatorTextField({
    required Map<String, TextEditingController> controllers,
    required String indicator,
    required Map<String, String?> usernames,
    required Map<String, String?> editedUsernames,
    required bool isReadOnly,
    required VoidCallback onEditPressed,
    required String reportType,
  }) {
    TextInputType keyboardType = indicator == "Comments"
        ? TextInputType.multiline
        : TextInputType.number;

    Report? loadedReport = _loadedReports[reportType];
    String reviewStatus = '';
    String indicatorValue = '';
    if (loadedReport?.reportEntries?[_currentUsername]?[indicator]?.isNotEmpty == true) {
      reviewStatus = loadedReport!.reportEntries![_currentUsername]![indicator]!.first.reviewStatus ?? '';
      indicatorValue = loadedReport.reportEntries![_currentUsername]![indicator]!.first.value;
    }

    bool currentIndicatorReadOnly = isReadOnly || reviewStatus == 'Approved';
    bool isIndicatorCurrentlyEditable = _isIndicatorEditable[reportType]?[indicator] ?? false;

    bool finalReadOnlyState = currentIndicatorReadOnly && !isIndicatorCurrentlyEditable;


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: finalReadOnlyState
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
              children: <TextSpan>[
                TextSpan(text: "$indicator: "),
                TextSpan(
                  text: indicatorValue.isNotEmpty // Use indicatorValue here
                      ? indicatorValue // Display actual value
                      : 'Not Entered',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: reviewStatus == 'Approved' && indicatorValue.isNotEmpty ? Colors.green : (indicatorValue.isNotEmpty ? Colors.black : Colors.red), // Green for Approved and has value, black for other value, red for Not Entered
                  ),
                ),
              ],
            ),
          ),
          if (usernames[indicator] != null &&
              usernames[indicator]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null &&
              editedUsernames[indicator]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Edited by: ${editedUsernames[indicator]}",
                style: const TextStyle(color: Colors.blue, fontSize: 12.0),
              ),
            ),
          if (finalReadOnlyState)
            _buildReviewFieldsReadOnly(
                indicator: indicator, reportType: reportType),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(indicator,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: controllers[indicator],
                  keyboardType: keyboardType,
                  maxLines: indicator == "Comments" ? 3 : 1,
                  readOnly: finalReadOnlyState,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    suffixIcon: isReadOnly && reviewStatus != 'Approved'
                        ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        setState(() {
                          _isIndicatorEditable[reportType]![indicator] = true;
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty &&
                          (usernames[indicator] == null ||
                              usernames[indicator]!.isEmpty)) {
                        usernames[indicator] = _currentUsername;
                        editedUsernames[indicator] = null;
                      } else if (value.isNotEmpty &&
                          value != controllers[indicator]!.text) {
                        editedUsernames[indicator] = _currentUsername;
                      } else if (value.isEmpty) {
                        usernames[indicator] = null;
                        editedUsernames[indicator] = null;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          if (usernames[indicator] != null &&
              usernames[indicator]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null &&
              editedUsernames[indicator]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Edited by: ${editedUsernames[indicator]}",
                style: const TextStyle(color: Colors.blue, fontSize: 12.0),
              ),
            ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }



  // Helper function to build review fields in ReadOnly mode
  Widget _buildReviewFieldsReadOnly({required String indicator, required String reportType}) {
    Report? loadedReport = _loadedReports[reportType];
    if (loadedReport != null) {
      // Assuming reportEntries is now Map<String, Map<String, List<ReportEntry>>>
      final username = _currentUsername; // Use current username as key
      if (loadedReport.reportEntries![username] != null && loadedReport.reportEntries![username]![indicator] != null) {
        ReportEntry? reportEntry = loadedReport.reportEntries![username]![indicator]!.firstWhere(
              (entry) => entry.key == indicator,
          orElse: () => ReportEntry(key: indicator, value: ''),
        );

        return Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reportEntry.reviewedBy != null && reportEntry.reviewedBy!.isNotEmpty)
                _buildReadOnlyField("To Be Reviewed by", reportEntry.reviewedBy!),
              if (reportEntry.reviewStatus != null && reportEntry.reviewStatus!.isNotEmpty)
                _buildReadOnlyField("Review Status", reportEntry.reviewStatus!),
              if (reportEntry.supervisorName != null && reportEntry.supervisorName!.isNotEmpty)
                _buildReadOnlyField("Supervisor Name", reportEntry.supervisorName!),
              if (reportEntry.supervisorEmail != null && reportEntry.supervisorEmail!.isNotEmpty)
                _buildReadOnlyField("Supervisor Email", reportEntry.supervisorEmail!),
              if (reportEntry.supervisorApprovalStatus != null &&
                  reportEntry.supervisorApprovalStatus!.isNotEmpty)
                _buildReadOnlyField(
                    "Supervisor Approval Status", reportEntry.supervisorApprovalStatus!),
              if (reportEntry.supervisorFeedBackComment != null &&
                  reportEntry.supervisorFeedBackComment!.isNotEmpty)
                _buildReadOnlyField("Supervisor Feedback Comment",
                    reportEntry.supervisorFeedBackComment!),
            ],
          ),
        );
            }
    }
    return const SizedBox.shrink();
  }

  // Helper function to build read-only text fields for review data
  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.grey, fontSize: 12.0),
          children: <TextSpan>[
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: const TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }

  // Function to send report to reviewer and sync to firebase
  Future<void> _sendReportToReviewer(String reportType) async {
    Report? existingReport = _loadedReports[reportType];
    if (existingReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report not found!')));
      return;
    }

    // Update report status to 'Pending Review'
    existingReport.reportStatus = 'Pending Review';
    try {
      await saveReport(existingReport, bioData,
          reportType); // Save updated report status to Firestore
      // Push report to Firebase (already saved in Firestore, so this might be redundant or can be adjusted based on your sync needs)
      // await _firestoreService.pushReportToFirebase(existingReport); // Consider if you need a separate 'push' step
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${titleCase(reportType.replaceAll('_', ' '))} Report sent for review!')));
      setState(() {
        _isEditingReportSection[reportType] =
        true; // Keep in read-only mode after sending for review
        _loadReportsForSelectedDate(); // Refresh report to update status in UI
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Error sending ${titleCase(reportType.replaceAll('_', ' '))} Report for review.')));
      print("Error sending report to Firestore: $e");
    }
  }



  Widget _buildStatusDescription(Widget statusIcon) {
    String description = "";
    if (statusIcon is Icon) {
      if (statusIcon.icon == Icons.check_circle) {
        description = "All Filled";
      } else if (statusIcon.icon == Icons.check) {
        description = "Partially Filled";
      } else if (statusIcon.icon == Icons.remove) {
        description = "Not Filled";
      }
    }
    return Text(description,
        style: const TextStyle(fontSize: 12, color: Colors.grey));
  }

  // Determines the report completion status based on whether indicators are filled and returns an appropriate icon.
  Widget _getIndicatorCompletionStatus(
      String reportType,
      Map<String, TextEditingController> controllers,
      List<String> indicators) {
    bool allFilled = true;
    bool anyFilled = false;
    for (String indicator in indicators) {
      if (controllers[indicator]!.text.isEmpty) {
        allFilled = false;
      } else {
        anyFilled = true;
      }
    }

    if (allFilled) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (anyFilled) {
      return const Icon(Icons.check, color: Colors.orange);
    } else {
      return const Icon(Icons.remove);
    }
  }

  Widget _getReportStatusIcon(String status) {
    if (status == "Pending") {
      return const Icon(Icons.pending, color: Colors.orange);
    } else if (status == "Approved") {
      return const Icon(Icons.check_circle_outline, color: Colors.green);
    } else if (status == "Rejected") {
      return const Icon(Icons.cancel_outlined, color: Colors.red);
    }
    return const Icon(Icons.pending, color: Colors.grey);
  }

  String? _getReportStatusText(String status) {
    if (status == "Pending") {
      return "Approval Pending";
    } else if (status == "Approved") {
      return "Approval Completed";
    } else if (status == "Rejected") {
      return "Approval Rejected";
    }
    return null; // Or return "Unknown Status" if you prefer a default text
  }

  Future<String?> uploadFileToStorage(
      String filePath, String fileName,
      {XFile? xFile, StreamController<double>? progressStream}) async {

    print("Starting upload for file: $fileName, path: $filePath");

    try {
      Uint8List? fileBytes;
      String? contentType = mime(fileName);

      if (kIsWeb) {
        print("Running on Web, using XFile for upload.");

        if (xFile == null) {
          print("Error: XFile is null, cannot proceed with web upload.");
          return null;
        }

        fileBytes = await xFile.readAsBytes();
        contentType ??= xFile.mimeType ?? "application/octet-stream"; // Ensure content type

        print("Using content-type: $contentType");
      } else {
        File file = File(filePath);
        if (!file.existsSync()) {
          print("Error: File does not exist at path: ${file.path}");
          return null;
        }
        contentType = mime(filePath);
      }

      Reference storageReference =
      FirebaseStorage.instance.ref().child('attachments/$fileName');

      UploadTask uploadTask;

      if (kIsWeb && fileBytes != null) {
        uploadTask = storageReference.putData(
          fileBytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        uploadTask = storageReference.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      if (progressStream != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          progressStream.add(progress);
        });
      }

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      print("Upload complete. Download URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  // NEW FUNCTIONS: Convert Image to Base64 and Send to Gemini API
  Future<String?> convertImageToBase64(XFile imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      print("Error converting image to base64: $e");
      return null;
    }
  }

  Future<String?> sendImageToGeminiForValidation(String base64Image, List<String> indicators) async { // Modified to accept List<String> indicators
    try {
      const geminiApiKey = 'AIzaSyC7xwM7GQfcSvZeJqeUK5oib6VCPHCyecs'; // Replace with your actual API key
      const modelName = 'gemini-2.0-flash';
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$geminiApiKey');


      String indicatorsPrompt = indicators.join(", "); // Join all indicators for the prompt
      final requestBody = {
        "contents": [
          {
            "parts": [
              // {
              //   "text": '''
              // Analyze the uploaded image and check if the title reads 'HIV TESTING SERVICES REGISTER'.
              // If the title matches, extract relevant data and generate a table with the following structure:
              //
              // Table Columns:
              // - Indicator (Describes the missing data type)
              // - Count (Number of occurrences where the specified data is missing)
              //
              // Indicators and Their Counting Criteria:
              // 1. 'Number of Records with the "Date (DD/MM/YY)" column with filled data': Count cells with data in the "Date (DD/MM/YY)" column for S/N 1 to 15.
              // 2. 'Number of Records with the "Clients Code" column with filled data': Count cells with data in the "Clients Code" column for S/N 1 to 15 under the same row conditions.
              // 3. 'Number of Records with the "Pre-Test Information session" column with filled data': Count cells with data in the "Pre-Test Information session" column for S/N 1 to 15 under the same row conditions.
              // 4. 'Number of Records with the "Result" column with filled data': Count cells with data in the "Result" column for S/N 1 to 15 under the same row conditions.
              //
              // Return only the table with calculated values.Do not add your summary analysis.
              // '''
              // },

              {
                "text": '''
              Analyze the uploaded image and check for the Following:
              A) Check if the title reads 'HIV TESTING SERVICES REGISTER'.
              If the title matches,scan the image and only make your analysis on rows that have data in any of the cell for that row and extract relevant data and generate a table with the following structure:

              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)

              Indicators and Their Counting Criteria:
              1. 'Number of Records with "Date (DD/MM/YY)" not filled': Count missing cells in the "Date (DD/MM/YY)" column. Only count if the cell in the  "Date (DD/MM/YY)" column is empty but has data in any other cell in the same Row.
              2. 'Number of Records with "Clients Code" not filled': Count missing cells in the "Clients Code" column under the same row conditions.Only count if the cell in the "Clients Code" column is empty but has data in any other cell in the same Row.
              3. 'Number of Records with "Pre-Test Information session" not filled': Count missing cells in the "Pre-Test Information session" column under the same row conditions.Only count if the cell in the "Pre-Test Information session" column is empty but has data in any other cell in the same Row.
              4. 'Number of Records without a ticked HIV Result': The different age range columns from 1-4 down to 50+ are separated into two sections:**Tested and Received HIV Negative Test Result** and **Tested and Received HIV positive Test Result**.A record in a row with Date filled and Client code has to be ticked in one of the age range cells in either the Postive Test Result section or Negative Test Result Section.Check through each age bracket cell for both section and if there is no "X" indicated in any cell for that Row in any section, count it.

              Return only the table with calculated values.Do not add your summary analysis.
              
              B) If it does not  match 'HIV TESTING SERVICES REGISTER' ,then Check if the title reads 'Index Testing Register'.
              If the title matches,scan the image and only make your analysis on rows that have data in any of the cell for that row and extract relevant data and generate a table with the following structure:

              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)

              Indicators and Their Counting Criteria:
              1. 'Number of Records with "INDEX CLIENT'S NAME IN FULL" not filled': Count missing cells in the "INDEX CLIENT'S NAME IN FULL" column. Only count if the cell in the  "INDEX CLIENT'S NAME IN FULL" column is empty but has data in any other cell in the same Row.Also note that the Cells in the "INDEX CLIENT'S NAME IN FULL" Column is sub-divide into two cells 
              2. 'Number of Records with "Client Code/Unique ID" not filled': Count missing cells in the "Client Code/Unique ID" column. Only count if the cell in the  "Client Code/Unique ID" column is empty but has data in any other cell in the same Row.
              3. 'Number of Records with "Age" not filled': The "Age" Column is divided into two sections:**<1 year** and **>=1 year**.Check both columns and if both cells are missing, it means that no age was recorded,and so count it.Only count if the cell in the "Age" column is empty but has data in any other cell in the same Row.
              4. 'Number of Records with "Sex" not filled': Count missing cells in the "Sex" column under the same row conditions.Only count if the cell in the "Sex" column is empty but has data in any other cell in the same Row.
              5. 'Number of Records with "Marital Status" not filled': Count missing cells in the "Marital Status" column under the same row conditions.Only count if the cell in the "Marital Status" column is empty but has data in any other cell in the same Row.
              6. 'Index Contacts Elicitation section': check the "Index Contact's Name in full" column which has a group of four cells numbered from 0ne to Four.Check if any of the cell numbered as "1" does not have data then count it.

              Return only the table with calculated values.Do not add your summary analysis.
              
              C) If it does not  match 'HIV TESTING SERVICES REGISTER' or 'Index Testing Register' ,then Check if the title reads 'ART Register'.
              If the title matches,scan the image and only make your analysis on rows that have data in any of the cell for that row and extract relevant data and generate a table with the following structure:

              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)

              Indicators and Their Counting Criteria:
              1. 'Number of Records with "Hospital No" not filled': Count missing cells in the "Hospital No" column. Only count if the cell in the "Hospital No" column is empty but has data in any other cell in the same Row.
              2. 'Number of Records with "Unique ID No." not filled': Count missing cells in the "Unique ID No." column. Only count if the cell in the "Unique ID No." column is empty but has data in any other cell in the same Row.
              3. 'Number of Records with "ART Start Date (dd/mm/yy)" not filled': Count missing cells in the "ART Start Date (dd/mm/yy)" column. Only count if the cell in the "ART Start Date (dd/mm/yy)" column is empty but has data in any other cell in the same Row.
              4. 'Number of Records with "Address" not filled': Count missing cells in the "Address" column. Only count if the cell in the "Address" column is empty but has data in any other cell in the same Row.
              5. 'Number of Records with "Sex" not filled': Count missing cells in the "Sex" column. Only count if the cell in the "Sex" column is empty but has data in any other cell in the same Row.
              6. 'Number of Records with "D.O.B" not filled': Count missing cells in the "D.O.B" column. Only count if the cell in the "D.O.B" column is empty but has data in any other cell in the same Row.
              7. 'Number of Records with "Age" not filled': Count missing cells in the "Age" column. Only count if the cell in the "Age" column is empty but has data in any other cell in the same Row.
              8. 'Number of Records with "WHO Clinical Stage" not filled': Count missing cells in the "WHO Clinical Stage" column. Only count if the cell in the "WHO Clinical Stage" column is empty but has data in any other cell in the same Row.
              9. 'Number of Records with "Weight (kg)" not filled': Count missing cells in the "Weight (kg)" column. Only count if the cell in the "Weight (kg)" column is empty but has data in any other cell in the same Row.
              10. 'Number of Records with "Height (m)" not filled': Count missing cells in the "Height (m)" column. Only count if the cell in the "Height (m)" column is empty but has data in any other cell in the same Row.
              11. 'Number of Records with "BMI/MUAC" not filled': Count missing cells in the "BMI/MUAC" column. Only count if the cell in the  "BMI/MUAC" column is empty but has data in any other cell in the same Row.
              12. 'Number of Records with "Functional Status" not filled': Count missing cells in the "Functional Status" column. Only count if the cell in the  "Functional Status" column is empty but has data in any other cell in the same Row.
              13. 'Number of Records with "CD4 Count (c/ml)" not filled': Count missing cells in the "CD4 Count (c/ml)" column. Only count if the cell in the  "CD4 Count (c/ml)" column is empty but has data in any other cell in the same Row.
              14. 'Number of Records with "Regimen at Start of ART" not filled': Count missing cells in the "Regimen at Start of ART" column. Only count if the cell in the  "Regimen at Start of ART" column is empty but has data in any other cell in the same Row.
              
              Return only the table with calculated values.Do not add your summary analysis.
              
              D) If it does not  match 'HIV TESTING SERVICES REGISTER' or 'Index Testing Register' OR 'ART Register' ,then Check if the title reads 'LABORATORY VIRAL LOAD REGISTER'.
              If the title matches,scan the image and only make your analysis on rows that have data in any of the cell for that row and extract relevant data and generate a table with the following structure:

              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)

              Indicators and Their Counting Criteria:
              1. 'Number of Records with "Hospital ID" not filled': Count missing cells in the "Hospital ID" column. Only count if the cell in the "Hospital ID" column is empty but has data in any other cell in the same Row.
              2. 'Number of Records with "LIB ID" not filled': Count missing cells in the "LIB ID" column. Only count if the cell in the "LIB ID" column is empty but has data in any other cell in the same Row.
              3. 'Number of Records with "Patient Name" not filled': Count missing cells in the "Patient Name" column. Only count if the cell in the "Patient Name" column is empty but has data in any other cell in the same Row.
              4. 'Number of Records with "Age (in years)" not filled': Count missing cells in the "Age (in years)" column. Only count if the cell in the "Age (in years)" column is empty but has data in any other cell in the same Row.
              5. 'Number of Records with "Sex" not filled': Count missing cells in the "Sex" column. Only count if the cell in the "Sex" column is empty but has data in any other cell in the same Row.
              6. 'Number of Records with "Test Indication *see key below" not filled': Count missing cells in the "Test Indication *see key below" column. Only count if the cell in the "Test Indication *see key below" column is empty but has data in any other cell in the same Row.
              7. 'Number of Records with "Sample Collection Date (dd-mmm-yyyy)" not filled': Count missing cells in the "Sample Collection Date (dd-mmm-yyyy)" column. Only count if the cell in the "Sample Collection Date (dd-mmm-yyyy)" column is empty but has data in any other cell in the same Row.
              
              Return only the table with calculated values.Do not add your summary analysis.
              
              E) If it does not  match 'HIV TESTING SERVICES REGISTER' or 'Index Testing Register' OR 'ART Register' or 'LABORATORY VIRAL LOAD REGISTER' ,then Check if the title reads 'PHARMACY DAILY WORKSHEET'.
              If the title matches,scan the image and only make your analysis on rows that have data in any of the cell for that row and extract relevant data and generate a table with the following structure:

              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)

              Indicators and Their Counting Criteria:
              1. 'Number of Records with "Pharmacy No" not filled': Count missing cells in the "Pharmacy No" column. Only count if the cell in the "Pharmacy No" column is empty but has data in any other cell in the same Row.
              2. 'Number of Records with "Unique ID" not filled': Count missing cells in the "Unique ID" column. Only count if the cell in the "Unique ID" column is empty but has data in any other cell in the same Row.
              3. 'Number of Records with "Patient Name" not filled': Count missing cells in the "Patient Name" column. Only count if the cell in the "Patient Name" column is empty but has data in any other cell in the same Row.
              4. 'Number of Records with "Sex" not filled': The different Sex range has three columns;"Male","F Non preg","F Preg" .A record in a row with "Unique ID" filled has to be ticked in one of the "Sex" range cells in either the "Male" or "F Non Preg" or "F Preg" Section.Check through each Sex bracket cell and if there is any empty cell for that Row in any section, count it.
              5. 'Number of Records with "Age" not filled': The different age range columns are seperated from 1-4 down to 50+. Check through each age bracket cell and if there is any empty cell for that Row in any section, count it.
              6. 'Number of Records with "Regimen Code" not filled': Count missing cells in the "Regimen Code" column. Only count if the cell in the "Regimen Code" column is empty but has data in any other cell in the same Row.
               
              Return only the table with calculated values.Do not add your summary analysis.
              '''
              },

              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      };


      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "No response text from Gemini.";
      } else {
        print("Gemini API Error: ${response.body}");
        return "Gemini API Error: ${response.body}";
      }
    } catch (e) {
      print("Error sending image to Gemini API: $e");
      return "Error communicating with Gemini API.";
    }
  }

  Future<String?> analyzeWithGemini(String imageUrl, String designationPrompt) async {
    try {
      const geminiApiKey = 'AIzaSyDzXGoMQJzSYNjBmhnQepuvp4S5vrckb2k'; // Replace with actual API key
      const modelName = 'gemini-pro-vision';
      const modelName1 = 'gemini-2.0-flash-exp-image-generation';
      const modelName2 = 'gemini-2.0-flash-lite';
      const modelName3 = 'gemini-2.0-pro-exp-02-05';
      const modelName4 = 'gemini-2.0-flash-thinking-exp-01-21';
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$geminiApiKey');

      // Step 1: Download Image as Bytes
      final imageResponse = await http.get(Uri.parse(imageUrl));
      if (imageResponse.statusCode != 200) {
        return "Failed to fetch image from Firebase URL.";
      }

      // Step 2: Convert Image to Base64
      Uint8List imageBytes = imageResponse.bodyBytes;
      String base64Image = base64Encode(imageBytes);

      // Step 3: Construct Request Payload
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": '''
              Analyze the uploaded image and check if the title reads 'HIV TESTING SERVICES REGISTER'.
              If the title matches, extract relevant data and generate a table with the following structure:
              
              Table Columns:
              - Indicator (Describes the missing data type)
              - Count (Number of occurrences where the specified data is missing)
              
              Indicators and Their Counting Criteria:
              1. 'Number of Records with the "Date (DD/MM/YY)" column not filled': Count missing cells in the "Date (DD/MM/YY)" column for S/N 1 to 15. Only count a row if at least one other field in the same row is filled.
              2. 'Number of Records with the "Clients Code" column not filled': Count missing cells in the "Clients Code" column for S/N 1 to 15 under the same row conditions.
              3. 'Number of Records with the "Pre-Test Information session" missing': Count missing cells in the "Pre-Test Information session" column for S/N 1 to 15 under the same row conditions.
              4. 'Number of Records with the "Result" column missing': Count missing cells in the "Result" column for S/N 1 to 15 under the same row conditions.
              
              Return the table with calculated values.
              '''},
              {
                "inlineData": {
                  "mimeType": "image/png",  // Ensure correct MIME type
                  "data": base64Image
                }
              }
            ]
          }
        ]
      };

      // Step 4: Make HTTP Request to Gemini API
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // Step 5: Handle API Response
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "No response text available.";
      } else {
        return "API Error: ${response.body}";
      }
    } catch (e) {
      print('Error analyzing with Gemini API: $e');
      return 'Error analyzing image/document with Gemini API.';
    }
  }


  // NEW Method: Indicator Validation Logic
  Future<bool> _validateIndicators2(String reportTypeKey, Map<String, TextEditingController> controllers) async {
    if (reportTypeKey == "strategic_information_si_assistant") {
      final txNewEntriesController = controllers["number_of_tx_new_entries_entered_on_the_nmrs_emr"]; //SI Assistant Indicator
      final hivPositiveClientsController = reportControllers["prevention_hts_assistant"]?["number_of_clients_diagnosed_hiv_positive"]; // HTS Assistant Indicator

      if (txNewEntriesController != null && hivPositiveClientsController != null) {
        int txNewEntries = int.tryParse(txNewEntriesController.text) ?? 0;
        int hivPositiveClients = int.tryParse(hivPositiveClientsController.text) ?? 0;

        if (txNewEntries != hivPositiveClients) {
          bool? continueSave = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Task Validation Issue"),
                content: Text(
                    "Validation failed:\nNumber of TX_New Entries ($txNewEntries) does not match Number of clients diagnosed HIV Positive ($hivPositiveClients).\n\nDo you want to continue saving?"),
                actions: <Widget>[
                  TextButton(
                    child: const Text("No, Cancel"),
                    onPressed: () {
                      Navigator.of(context).pop(false); // Do not continue saving
                    },
                  ),
                  TextButton(
                    child: const Text("Yes, Continue"),
                    onPressed: () {
                      Navigator.of(context).pop(true); // Continue saving
                    },
                  ),
                ],
              );
            },
          );
          return continueSave ?? false; // Return user's choice (or false if dialog dismissed)
        }
      }
    }
    return true; // Validation passed or not applicable
  }
  // Helper Method to Fetch Report from Firestore (Already defined - keep it)
  Future<Report?> _fetchReportFromFirestore(String reportTypeKey) async {
    // ... (your existing _fetchReportFromFirestore method - no changes needed)
    if (selectedBioState == null || selectedBioLocation == null) {
      print("_fetchReportFromFirestore: BioModel data is incomplete, cannot fetch report.");
      return null;
    }
    try {
      final String formattedDate = DateFormat('dd-MMM-yyyy').format(_selectedReportingDate);
      final DocumentSnapshot<Map<String, dynamic>> reportDocSnapshot = await FirebaseFirestore.instance
          .collection(reportsCollection)
          .doc(selectedBioState)
          .collection(selectedBioState!)
          .doc(selectedBioLocation)
          .collection(formattedDate)
          .doc(reportTypeKey)
          .get();

      if (reportDocSnapshot.exists) {
        return Report.fromFirestore(reportDocSnapshot, null);
      } else {
        print("_fetchReportFromFirestore: No report found for type: $reportTypeKey, date: $_selectedReportingDate");
        return null; // Report does not exist yet
      }
    } catch (e) {
      print("Error fetching report from Firestore for type $reportTypeKey: $e");
      return null;
    }
  }


  // NEW Method: Indicator Validation Logic - Modified and Corrected
  Future<bool> _validateIndicators(String reportTypeKey, Map<String, TextEditingController> controllers) async {
    String siAssistantReportKey = "strategic_information_si_assistant";
    String htsAssistantReportKey = "preventions_hts_assistant";
    String pharmTechReportKey = "pharmacy_and_logistics_pharmacy_technician";
    String labVLChampionReportKey = "laboratory_viral_load_champion";
    String trackingAssistantReportKey = "preventions_tracking_assistant";


    String txNewIndicatorKey = "Number of Tx_New Clients Entries Entered on NMRS (EMR) For the Day";
    String hivPositiveLinkedToArtIndicatorKey = "Number of newly diagnosed HIV positive linked to ART For the Day";
    String diagnosedHIVPositiveIndicatorKey = "Number of Clients Diagnosed HIV Positive For the Day";
    String vlResultHandedOverIndicatorKey = "Number of Result Handed over to SIAs /MEAL For the Day";
    String vlResultEnteredNMRSIndicatorKey = "Number of Viral Load Results Entered on NMRS (EMR) For the Day";
    String eligibleClientsTestedHTSRegisterIndicatorKey = "Number of Eligible Clients Tested and documented in the HTS Register For the Day";
    String htsDataEnteredNMRSIndicatorKey = "Number of HTS Data Entered on NMRS (EMR) For the Day";
    String existingClientsEntriesNMRSIndicatorKey = "Number of Existing Clients Entries Entered on NMRS (EMR) For the Day";
    String refillClientsIndicatorKey = "Number of Refill Clients For the day";
    String newARTClientsIndicatorKey = "Number of New ART Clients For the day";
    String arvPickUpClientsIndicatorKey = "Total Number of Clients that Visited the Facility for ARV Pick Up For the Day";
    String eligibleForTestingIndicatorKey = "Number Eligible for Testing For the Day";
    String eligibleClientsTestedReceivedResultIndicatorKey = "Number of Eligible Clients Tested for HIV and Received Result For the Day";


    TextEditingController? currentTxNewEntriesController;
    TextEditingController? currentHIVPositiveLinkedToArtController;
    TextEditingController? currentDiagnosedHIVPositiveController;
    TextEditingController? currentVLResultHandedOverController;
    TextEditingController? currentVLResultEnteredNMRSController;
    TextEditingController? currentEligibleClientsTestedHTSRegisterController;
    TextEditingController? currentHTSDataEnteredNMRSController;
    TextEditingController? currentExistingClientsEntriesNMRSController;
    TextEditingController? currentRefillClientsController;
    TextEditingController? currentNewARTClientsController;
    TextEditingController? currentARVPickUpClientsController;
    TextEditingController? currentEligibleForTestingController;
    TextEditingController? currentEligibleClientsTestedReceivedResultController;

    String currentUsername = _currentUsername;

    int totalVLResultHandedOver = 0;
    int totalVLResultEnteredNMRS = 0;
    int totalEligibleClientsTestedHTSRegister = 0;
    int totalHTSDataEnteredNMRS = 0;
    int totalExistingClientsEntriesNMRS = 0;
    int totalRefillClients = 0;
    int totalNewARTClients = 0;
    int totalTxNewEntries = 0;
    int totalHIVPositiveLinkedToArt = 0;
    int totalARVPickUpClients = 0;
    int totalDiagnosedHIVPositive = 0;
    int totalEligibleForTesting = 0;
    int totalEligibleClientsTestedReceivedResult = 0;

    bool validationFailed = false;
    String validationErrorMessage = "";


    // Determine which report type is being saved and set controllers accordingly
    if (reportTypeKey == siAssistantReportKey) {
      currentVLResultEnteredNMRSController = controllers[vlResultEnteredNMRSIndicatorKey];
      currentHTSDataEnteredNMRSController = controllers[htsDataEnteredNMRSIndicatorKey];
      currentExistingClientsEntriesNMRSController = controllers[existingClientsEntriesNMRSIndicatorKey];
      currentTxNewEntriesController = controllers[txNewIndicatorKey];
    } else if (reportTypeKey == htsAssistantReportKey) {
      currentEligibleClientsTestedHTSRegisterController = controllers[eligibleClientsTestedHTSRegisterIndicatorKey];
      currentHIVPositiveLinkedToArtController = controllers[hivPositiveLinkedToArtIndicatorKey];
      currentDiagnosedHIVPositiveController = controllers[diagnosedHIVPositiveIndicatorKey];
      currentEligibleForTestingController = controllers[eligibleForTestingIndicatorKey];
      currentEligibleClientsTestedReceivedResultController = controllers[eligibleClientsTestedReceivedResultIndicatorKey];

    }else if (reportTypeKey == labVLChampionReportKey) {
      currentVLResultHandedOverController = controllers[vlResultHandedOverIndicatorKey];
    }else if (reportTypeKey == pharmTechReportKey) {
      currentRefillClientsController = controllers[refillClientsIndicatorKey];
      currentNewARTClientsController = controllers[newARTClientsIndicatorKey];
    }else if (reportTypeKey == trackingAssistantReportKey) {
      currentARVPickUpClientsController = controllers[arvPickUpClientsIndicatorKey];
    }
    else {
      return true; // Validation not applicable for other report types
    }


    // Fetch Reports from Firestore
    final siAssistantReport = await _fetchReportFromFirestore(siAssistantReportKey);
    final htsAssistantReport = await _fetchReportFromFirestore(htsAssistantReportKey);
    final labVLChampionReport = await _fetchReportFromFirestore(labVLChampionReportKey);
    final pharmTechReport = await _fetchReportFromFirestore(pharmTechReportKey);
    final trackingAssistantReport = await _fetchReportFromFirestore(trackingAssistantReportKey);


    // Sum VL Results Handed Over from Lab VL Champion Report
    if (labVLChampionReport?.reportEntries != null) {
      labVLChampionReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == labVLChampionReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving Lab VL Champion report
        }
        else if (indicatorMap[vlResultHandedOverIndicatorKey] != null &&
            indicatorMap[vlResultHandedOverIndicatorKey]!.isNotEmpty) {
          totalVLResultHandedOver += int.tryParse(
              indicatorMap[vlResultHandedOverIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum VL Results Entered NMRS from SI Assistant Report
    if (siAssistantReport?.reportEntries != null) {
      siAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == siAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving SI Assistant report
        }
        else if (indicatorMap[vlResultEnteredNMRSIndicatorKey] != null &&
            indicatorMap[vlResultEnteredNMRSIndicatorKey]!.isNotEmpty) {
          totalVLResultEnteredNMRS += int.tryParse(
              indicatorMap[vlResultEnteredNMRSIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum Eligible Clients Tested HTS Register from HTS Assistant Report
    if (htsAssistantReport?.reportEntries != null) {
      htsAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == htsAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving HTS Assistant report
        }
        else if (indicatorMap[eligibleClientsTestedHTSRegisterIndicatorKey] != null &&
            indicatorMap[eligibleClientsTestedHTSRegisterIndicatorKey]!.isNotEmpty) {
          totalEligibleClientsTestedHTSRegister += int.tryParse(
              indicatorMap[eligibleClientsTestedHTSRegisterIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum HTS Data Entered NMRS from SI Assistant Report
    if (siAssistantReport?.reportEntries != null) {
      siAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == siAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving SI Assistant report
        }
        else if (indicatorMap[htsDataEnteredNMRSIndicatorKey] != null &&
            indicatorMap[htsDataEnteredNMRSIndicatorKey]!.isNotEmpty) {
          totalHTSDataEnteredNMRS += int.tryParse(
              indicatorMap[htsDataEnteredNMRSIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum Existing Clients Entries NMRS from SI Assistant Report
    if (siAssistantReport?.reportEntries != null) {
      siAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == siAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving SI Assistant report
        }
        else if (indicatorMap[existingClientsEntriesNMRSIndicatorKey] != null &&
            indicatorMap[existingClientsEntriesNMRSIndicatorKey]!.isNotEmpty) {
          totalExistingClientsEntriesNMRS += int.tryParse(
              indicatorMap[existingClientsEntriesNMRSIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum Refill Clients from Pharmacy Tech Report
    if (pharmTechReport?.reportEntries != null) {
      pharmTechReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == pharmTechReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving Pharmacy Tech report
        }
        else if (indicatorMap[refillClientsIndicatorKey] != null &&
            indicatorMap[refillClientsIndicatorKey]!.isNotEmpty) {
          totalRefillClients += int.tryParse(
              indicatorMap[refillClientsIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum New ART Clients from Pharmacy Tech Report
    if (pharmTechReport?.reportEntries != null) {
      pharmTechReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == pharmTechReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving Pharmacy Tech report
        }
        else if (indicatorMap[newARTClientsIndicatorKey] != null &&
            indicatorMap[newARTClientsIndicatorKey]!.isNotEmpty) {
          totalNewARTClients += int.tryParse(
              indicatorMap[newARTClientsIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }
    // Sum TX_New Entries from SI Assistant Report
    if (siAssistantReport?.reportEntries != null) {
      siAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == siAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving SI Assistant report
        }
        else if (indicatorMap[txNewIndicatorKey] != null &&
            indicatorMap[txNewIndicatorKey]!.isNotEmpty) {
          totalTxNewEntries += int.tryParse(
              indicatorMap[txNewIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }

    // Sum Newly Diagnosed HIV Positive Linked to ART from HTS Assistant Report
    if (htsAssistantReport?.reportEntries != null) {
      htsAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == htsAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving HTS Assistant report
        }
        else if (indicatorMap[hivPositiveLinkedToArtIndicatorKey] != null &&
            indicatorMap[hivPositiveLinkedToArtIndicatorKey]!.isNotEmpty) {
          totalHIVPositiveLinkedToArt += int.tryParse(
              indicatorMap[hivPositiveLinkedToArtIndicatorKey]!.first.value
          ) ?? 0;
        }

      });
    }
    // Sum Total Number of Clients that Visited Facility for ARV Pick Up from Tracking Assistant Report
    if (trackingAssistantReport?.reportEntries != null) {
      trackingAssistantReport!.reportEntries!.forEach((username, indicatorMap) {
        if (reportTypeKey == trackingAssistantReportKey && username == currentUsername) {
          // Exclude current user's OLD entry when saving Tracking Assistant report
        }
        else if (indicatorMap[arvPickUpClientsIndicatorKey] != null &&
            indicatorMap[arvPickUpClientsIndicatorKey]!.isNotEmpty) {
          totalARVPickUpClients += int.tryParse(
              indicatorMap[arvPickUpClientsIndicatorKey]!.first.value
          ) ?? 0;
        }
      });
    }
    // Sum Number of clients diagnosed HIV Positive from HTS Assistant Report
    if (htsAssistantReport?.reportEntries != null) {
      htsAssistantReport!.reportEntries!.forEach((username, indicatorMap) {

        if (indicatorMap[diagnosedHIVPositiveIndicatorKey] != null &&
            indicatorMap[diagnosedHIVPositiveIndicatorKey]!.isNotEmpty) {
          totalDiagnosedHIVPositive += int.tryParse(
              indicatorMap[diagnosedHIVPositiveIndicatorKey]!.first.value
          ) ?? 0;
        }

      });
    }
    // Sum Number Eligible for Testing from HTS Assistant Report
    if (htsAssistantReport?.reportEntries != null) {
      htsAssistantReport!.reportEntries!.forEach((username, indicatorMap) {

        if (indicatorMap[eligibleForTestingIndicatorKey] != null &&
            indicatorMap[eligibleForTestingIndicatorKey]!.isNotEmpty) {
          totalEligibleForTesting += int.tryParse(
              indicatorMap[eligibleForTestingIndicatorKey]!.first.value
          ) ?? 0;
        }

      });
    }
    // Sum Number of Eligible Clients Tested for HIV and Received Result from HTS Assistant Report
    if (htsAssistantReport?.reportEntries != null) {
      htsAssistantReport!.reportEntries!.forEach((username, indicatorMap) {

        if (indicatorMap[eligibleClientsTestedReceivedResultIndicatorKey] != null &&
            indicatorMap[eligibleClientsTestedReceivedResultIndicatorKey]!.isNotEmpty) {
          totalEligibleClientsTestedReceivedResult += int.tryParse(
              indicatorMap[eligibleClientsTestedReceivedResultIndicatorKey]!.first.value
          ) ?? 0;
        }

      });
    }


    // Get current value based on which report is being saved
    int currentVLResultHandedOver = 0;
    int currentVLResultEnteredNMRS = 0;
    int currentEligibleClientsTestedHTSRegister = 0;
    int currentHTSDataEnteredNMRS = 0;
    int currentExistingClientsEntriesNMRS = 0;
    int currentRefillClients = 0;
    int currentNewARTClients = 0;
    int currentTxNewEntries = 0;
    int currentHIVPositiveLinkedToArt = 0;
    int currentARVPickUpClients = 0;
    int currentDiagnosedHIVPositive = 0;
    int currentEligibleForTesting = 0;
    int currentEligibleClientsTestedReceivedResult = 0;


    if (currentVLResultHandedOverController != null) {
      currentVLResultHandedOver = int.tryParse(currentVLResultHandedOverController.text) ?? 0;
    }
    if (currentVLResultEnteredNMRSController != null) {
      currentVLResultEnteredNMRS = int.tryParse(currentVLResultEnteredNMRSController.text) ?? 0;
    }
    if (currentEligibleClientsTestedHTSRegisterController != null) {
      currentEligibleClientsTestedHTSRegister = int.tryParse(currentEligibleClientsTestedHTSRegisterController.text) ?? 0;
    }
    if (currentHTSDataEnteredNMRSController != null) {
      currentHTSDataEnteredNMRS = int.tryParse(currentHTSDataEnteredNMRSController.text) ?? 0;
    }
    if (currentExistingClientsEntriesNMRSController != null) {
      currentExistingClientsEntriesNMRS = int.tryParse(currentExistingClientsEntriesNMRSController.text) ?? 0;
    }
    if (currentRefillClientsController != null) {
      currentRefillClients = int.tryParse(currentRefillClientsController.text) ?? 0;
    }
    if (currentNewARTClientsController != null) {
      currentNewARTClients = int.tryParse(currentNewARTClientsController.text) ?? 0;
    }
    if (currentTxNewEntriesController != null) {
      currentTxNewEntries = int.tryParse(currentTxNewEntriesController.text) ?? 0;
    }
    if (currentHIVPositiveLinkedToArtController != null) {
      currentHIVPositiveLinkedToArt = int.tryParse(currentHIVPositiveLinkedToArtController.text) ?? 0;
    }
    if (currentARVPickUpClientsController != null) {
      currentARVPickUpClients = int.tryParse(currentARVPickUpClientsController.text) ?? 0;
    }
    if (currentDiagnosedHIVPositiveController != null) {
      currentDiagnosedHIVPositive = int.tryParse(currentDiagnosedHIVPositiveController.text) ?? 0;
    }
    if (currentEligibleForTestingController != null) {
      currentEligibleForTesting = int.tryParse(currentEligibleForTestingController.text) ?? 0;
    }
    if (currentEligibleClientsTestedReceivedResultController != null) {
      currentEligibleClientsTestedReceivedResult = int.tryParse(currentEligibleClientsTestedReceivedResultController.text) ?? 0;
    }


    // Add current user's NEWLY EDITED entry to the respective total for validation
    if (reportTypeKey == labVLChampionReportKey) {
      totalVLResultHandedOver += currentVLResultHandedOver;
    } else if (reportTypeKey == siAssistantReportKey) {
      totalVLResultEnteredNMRS += currentVLResultEnteredNMRS;
      totalHTSDataEnteredNMRS += currentHTSDataEnteredNMRS;
      totalExistingClientsEntriesNMRS += currentExistingClientsEntriesNMRS;
      totalTxNewEntries += currentTxNewEntries;

    } else if (reportTypeKey == htsAssistantReportKey) {
      totalEligibleClientsTestedHTSRegister += currentEligibleClientsTestedHTSRegister;
      totalHIVPositiveLinkedToArt += currentHIVPositiveLinkedToArt;
      totalDiagnosedHIVPositive += currentDiagnosedHIVPositive;
      totalEligibleForTesting += currentEligibleForTesting;
      totalEligibleClientsTestedReceivedResult += currentEligibleClientsTestedReceivedResult;
    }else if (reportTypeKey == pharmTechReportKey) {
      totalRefillClients += currentRefillClients;
      totalNewARTClients += currentNewARTClients;
    }else if (reportTypeKey == trackingAssistantReportKey) {
      totalARVPickUpClients += currentARVPickUpClients;
    }


    if (totalVLResultHandedOver != totalVLResultEnteredNMRS) {
      validationFailed = true;
      validationErrorMessage += "VL Validation failed:\nTotal Number of Result Handed over to SIAs /MEAL (By $labVLChampionReportKey) ($totalVLResultHandedOver) does not match Number of Viral Load Results Entered on NMRS (EMR) (By $siAssistantReportKey) ($totalVLResultEnteredNMRS).\n\n";
    }
    if (totalEligibleClientsTestedHTSRegister != totalHTSDataEnteredNMRS) {
      validationFailed = true;
      validationErrorMessage += "HTS_HTSRegister_HTSEntry Validation failed:\nTotal Number of Eligible Clients Tested and documented in the HTS Register (By $htsAssistantReportKey) ($totalEligibleClientsTestedHTSRegister) does not match Number of HTS Data Entered on NMRS (EMR) (By $siAssistantReportKey) ($totalHTSDataEnteredNMRS).\n\n";
    }
    if (totalExistingClientsEntriesNMRS != totalRefillClients) {
      validationFailed = true;
      validationErrorMessage += "ExistingClients_RefillClients Validation failed:\nTotal Number of Existing Clients Entries Entered on NMRS (EMR) (By $siAssistantReportKey) ($totalExistingClientsEntriesNMRS) does not match Number of Refill Clients (By $pharmTechReportKey) ($totalRefillClients).\n\n";
    }
    if (totalNewARTClients != totalTxNewEntries || totalNewARTClients != totalHIVPositiveLinkedToArt) {
      validationFailed = true;
      validationErrorMessage += "NewARTClients_TxNew_HIVPositiveLinkedART Validation failed:\nTotal Number of New ART Clients (By $pharmTechReportKey) ($totalNewARTClients) does not match Number of Tx_New Clients Entries Entered on NMRS (EMR) (By $siAssistantReportKey) ($totalTxNewEntries) or Number of Newly Diagnosed HIV Positive Linked to ART (By $htsAssistantReportKey) ($totalHIVPositiveLinkedToArt).\n\n";
    }
    if (totalARVPickUpClients != totalExistingClientsEntriesNMRS || totalARVPickUpClients != totalRefillClients) {
      validationFailed = true;
      validationErrorMessage += "ARVPickUpClients_ExistingClients_RefillClients Validation failed:\nTotal Number of Clients that Visited the Facility for ARV Pick Up (By $trackingAssistantReportKey) ($totalARVPickUpClients) does not match Number of Existing Clients Entries Entered on NMRS (EMR) (By $siAssistantReportKey) ($totalExistingClientsEntriesNMRS) or Number of Refill Clients (By $pharmTechReportKey) ($totalRefillClients).\n\n";
    }
    if (totalDiagnosedHIVPositive > totalEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "DiagnosedHIVPositive_EligibleForTesting Validation failed:\nNumber of Clients Diagnosed HIV Positive (By $htsAssistantReportKey) ($totalDiagnosedHIVPositive) cannot be greater than Number Eligible for Testing (By $htsAssistantReportKey) ($totalEligibleForTesting).\n\n";
    }
    if (totalEligibleClientsTestedHTSRegister > totalEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "EligibleClientsTestedHTSRegister_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested and documented in the HTS Register (By $htsAssistantReportKey) ($totalEligibleClientsTestedHTSRegister) cannot be greater than Number Eligible for Testing (By $htsAssistantReportKey) ($totalEligibleForTesting).\n\n";
    }
    if (totalEligibleClientsTestedReceivedResult > totalEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "EligibleClientsTestedReceivedResult_EligibleForTesting Validation failed:\nNumber of Eligible Clients Tested for HIV and Received Result (By $htsAssistantReportKey) ($totalEligibleClientsTestedReceivedResult) cannot be greater than Number Eligible for Testing (By $htsAssistantReportKey) ($totalEligibleForTesting).\n\n";
    }
    if (totalHIVPositiveLinkedToArt > totalEligibleForTesting) {
      validationFailed = true;
      validationErrorMessage += "HIVPositiveLinkedToArt_EligibleForTesting Validation failed:\nNumber of Newly Diagnosed HIV Positive Linked to ART (By $htsAssistantReportKey) ($totalHIVPositiveLinkedToArt) cannot be greater than Number Eligible for Testing (By $htsAssistantReportKey) ($totalEligibleForTesting).\n\n";
    }


    if (validationFailed) {
      bool? continueSave = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Task Validation"),
            content: Text(
                "$validationErrorMessage Do you want to continue saving?"),
            actions: <Widget>[
              TextButton(
                child: const Text("No, Cancel"),
                onPressed: () {
                  Navigator.of(context).pop(false); // Do not continue saving
                },
              ),
              TextButton(
                child: const Text("Yes, Continue"),
                onPressed: () {
                  Navigator.of(context).pop(true); // Continue saving
                },
              ),
            ],
          );
        },
      );
      return continueSave ?? false; // Return user's choice (or false if dialog dismissed)
    }

    return true; // Validation passed or not applicable
  }

// Modified _saveReportToFirestore to include progress indicator state management
  Future<void> _saveReportToFirestore(
      String reportType,
      Map<String, TextEditingController> controllers,
      List<String> indicators,
      Map<String, String?> editedUsernames) async {
    if (_selectedReportType.isEmpty ||
        _selectedReportPeriod == null ||
        _selectedMonthForWeekly == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please select Report Type, Reporting Week, and Reporting Month')));
      return;
    }
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Reviewer')));
      return;
    }
    if (selectedBioState == null || selectedBioLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('BioData is incomplete, cannot save report.')));
      return;
    }
    setState(() {
      _isSavingReport = true; // Set saving state to true
    });


    // **NEW: Perform Validation Check BEFORE saving**
    bool isValid = await _validateIndicators(reportType, controllers);
    if (!isValid) {
      setState(() {
        _isSavingReport = false; // Set saving state to true
      });

      return; // Stop saving if validation fails and user cancels
    }


    Map<String, Map<String, List<ReportEntry>>> structuredReportEntries = {};
    String currentUsername = _currentUsername;

    Map<String, List<ReportEntry>> indicatorMap = {};
    Report? existingReport = _loadedReports[reportType];
    Map<String, String?> currentEnteredBy = {};
    Map<String, String?> currentEditedBy = {};


    List<String> reportAttachmentUrls = [];
    List<AttachmentData> reportAttachmentsToUpload = _reportAttachmentsData[reportType] ?? [];
    List<String> geminiAnalysisResults = [];


    if (reportAttachmentsToUpload.isNotEmpty) {
      setState(() {
        _isSavingReport = true; // Set saving state to true
      });

      for (AttachmentData attachmentData in reportAttachmentsToUpload) {
        if (attachmentData.file != null) {
          String fileExtension = attachmentData.fileName.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) {
            String? base64Image = await convertImageToBase64(attachmentData.file!);
            if (base64Image != null) {
              String? analysisResult = await sendImageToGeminiForValidation(base64Image, indicators);
              if (analysisResult != null) {
                geminiAnalysisResults.add("Analysis for ${attachmentData.fileName}:\n$analysisResult");
              } else {
                geminiAnalysisResults.add("Analysis failed for ${attachmentData.fileName}.");
              }
            } else {
              geminiAnalysisResults.add("Error converting image ${attachmentData.fileName} for analysis.");
            }
          } else {
            geminiAnalysisResults.add("Analysis for ${attachmentData.fileName} only supported for image files.");
          }
        }
      }
    }

    String aggregatedAnalysisResult = "";
    if (geminiAnalysisResults.isNotEmpty) {
      aggregatedAnalysisResult = geminiAnalysisResults.join("\n\n");
    } else {
      aggregatedAnalysisResult = "No images Uploaded for Analysis";
    }



    for (var attachmentData in reportAttachmentsToUpload) {
      if (attachmentData.file != null && attachmentData.downloadUrl == null) {
        String fileExtension = attachmentData.fileName.split('.').last.toLowerCase();
        String fileName = (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension))
            ? 'image_${currentUsername}_$reportType.$fileExtension'
            : 'document_${currentUsername}_$reportType.$fileExtension';

        String? url = await uploadFileToStorage(
          attachmentData.file!.path,
          fileName,
          xFile: kIsWeb ? attachmentData.file : null,
        );

        if (url != null) {
          reportAttachmentUrls.add(url);
          attachmentData.downloadUrl = url;
          print("File uploaded successfully: $fileName");
        } else {
          print("Upload failed for ${attachmentData.fileName}");
        }
      } else if (attachmentData.downloadUrl != null) {
        reportAttachmentUrls.add(attachmentData.downloadUrl!);
      }
    }

    for (String indicator in indicators) {
      String currentValue = controllers[indicator]!.text.trim();

      String? existingValue = existingReport?.reportEntries
          ?.containsKey(currentUsername) == true && existingReport?.reportEntries![currentUsername]!.containsKey(indicator) == true
          ? existingReport!.reportEntries![currentUsername]![indicator]!.isNotEmpty ? existingReport.reportEntries![currentUsername]![indicator]!.first.value : null
          : null;

      String? existingReviewStatus = existingReport?.reportEntries
          ?.containsKey(currentUsername) == true && existingReport?.reportEntries![currentUsername]!.containsKey(indicator) == true
          ? existingReport!.reportEntries![currentUsername]![indicator]!.isNotEmpty ? existingReport.reportEntries![currentUsername]![indicator]!.first.reviewStatus : null
          : null;

      String finalValueToSave;

      if (existingReviewStatus == 'Approved') {
        finalValueToSave = existingValue ?? ""; // Preserve existing "Approved" value
      } else {
        finalValueToSave = currentValue; // Use current controller value for others
      }


      String? finalEnteredBy = existingReport?.reportEntries
          ?.containsKey(currentUsername) == true && existingReport?.reportEntries![currentUsername]!.containsKey(indicator) == true
          ? existingReport!.reportEntries![currentUsername]![indicator]!.isNotEmpty ? existingReport.reportEntries![currentUsername]![indicator]!.first.enteredBy : null
          : null;
      String? finalEditedBy = editedUsernames[indicator];
      String finalReviewStatus = 'Pending';


      if (currentValue.isNotEmpty && (existingValue == null || existingValue.isEmpty)) {
        finalEnteredBy = _currentUsername;
        finalEditedBy = null;
      } else if (currentValue.isNotEmpty && currentValue != existingValue) {
        finalEditedBy = _currentUsername;
        finalEnteredBy = finalEnteredBy ?? _currentUsername; // Preserve existing EnteredBy if available
      } else {
        if (existingValue != null && existingValue.isNotEmpty) {
          finalEnteredBy = finalEnteredBy; // Keep existing EnteredBy
          finalEditedBy = editedUsernames[indicator];
        } else {
          finalEnteredBy = null;
          finalEditedBy = null;
        }
      }


      List<ReportEntry> entryList = [];
      entryList.add(ReportEntry(
        key: indicator,
        value: finalValueToSave, // Use finalValueToSave to preserve "Approved" values
        enteredBy: finalEnteredBy,
        editedBy: finalEditedBy,
        reviewedBy: _selectedReviewer?.name,
        reviewStatus: finalReviewStatus,
        attachments: indicator == indicators.last ? reportAttachmentUrls : null,
        appAnalysis: indicator == indicators.first ? aggregatedAnalysisResult : null,
        reviewerId: _selectedReviewer?.userId,
      ));
      indicatorMap[indicator] = entryList;
      currentEnteredBy[indicator] = finalEnteredBy;
      currentEditedBy[indicator] = finalEditedBy;
    }
    structuredReportEntries[currentUsername] = indicatorMap;

    setState(() {
      _isSavingReport = true; // Set saving state to true
    });


    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);


    try {


      final report = Report(
        reportType: reportType,
        date: _selectedReportingDate,
        reportingWeek: _selectedReportPeriod!,
        reportingMonth: _selectedMonthForWeekly!,
        reportEntries: structuredReportEntries,
        isSynced: false,
        reportStatus: "Pending",
        attachments: null,
        supervisorName: _selectedSupervisor, // ADD THIS LINE
        supervisorEmail: _selectedSupervisorEmail, // ADD THIS LINE
      );


      String department = reportType.split('_')[0];
      String designation = reportType.split('_')[1];
      await saveReport(report, bioData, reportType);
      Get.back();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${titleCase(reportType.replaceAll('_', ' '))} Report saved successfully!')));
      setState(() {
        reportUsernames[reportType] = currentEnteredBy;
        reportEditedUsernames[reportType] = currentEditedBy;
        _isEditingReportSection[reportType] = true;
        _loadReportsForSelectedDate();
        _isSavingReport = false; // Set saving state to false after successful save
      });
    } catch (e) {
      Get.back();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Error saving ${titleCase(reportType.replaceAll('_', ' '))} Report.')));
      print("Error saving report to Firestore: $e");
      setState(() {
        _isSavingReport = false; // Set saving state to false even if save fails
      });
    }
  }



// _addTaskToIsar (Modified for edit to UPDATE instead of INSERT)
  _addTaskToIsar({bool isEditing = false}) async {
    String title = _taskTitleController.text;
    String description = _taskDescriptionController.text;
    FacilityStaffModel? reviewer = _selectedReviewer;

    if (title.isNotEmpty && description.isNotEmpty && reviewer != null) {
      Task task;
      // Show a loading dialog
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      List<String> attachmentUrls = [];
      List<AttachmentData> attachmentsToUpload = _taskBottomSheetAttachmentsData; // _taskBottomSheetAttachmentsData is now used for main page task input
      List<String> geminiAnalysisResults = [];

      try {
        for (var attachmentData in attachmentsToUpload) {
          if (attachmentData.file != null && attachmentData.downloadUrl == null) {
            String fileExtension = attachmentData.fileName.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) {
              String? base64Image = await convertImageToBase64(attachmentData.file!);
              if (base64Image != null) {
                String? analysisResult = await sendImageToGeminiForValidation(base64Image, []); // Indicators not relevant for task analysis here
                if (analysisResult != null) {
                  geminiAnalysisResults.add("Analysis for ${attachmentData.fileName}:\n$analysisResult");
                } else {
                  geminiAnalysisResults.add("Analysis failed for ${attachmentData.fileName}.");
                }
              } else {
                geminiAnalysisResults.add("Error converting image ${attachmentData.fileName} for analysis.");
              }
            }

            String fileName = 'task_attachment_${DateTime.now().millisecondsSinceEpoch}_${attachmentData.fileName}';
            print("_addTaskToIsar: attachmentData.file before uploadFileToStorage: ${attachmentData.file}"); // ADD THIS LINE
            if (attachmentData.file == null) { // ADD THIS CHECK
              print("_addTaskToIsar: attachmentData.file is NULL, skipping upload for ${attachmentData.fileName}");
              continue; // Skip to the next attachment if file is null
            }
            String? url = await uploadFileToStorage(
              kIsWeb ? attachmentData.file!.path : attachmentData.file!.path,
              fileName,
              xFile: kIsWeb ? attachmentData.file : null,
            );
            if (url != null) {
              attachmentUrls.add(url);
              attachmentData.downloadUrl = url;

            } else {
              // Handle upload error for a specific file
              print("Upload failed for ${attachmentData.fileName}");
              // Optionally: decide how to handle partial failures. For now, continue saving task data.
            }
          } else if (attachmentData.downloadUrl != null) {
            attachmentUrls.add(attachmentData.downloadUrl!); // Use existing URL if already uploaded
          }
        }

        String aggregatedAnalysisResult = "";
        if (geminiAnalysisResults.isNotEmpty) {
          aggregatedAnalysisResult = geminiAnalysisResults.join("\n\n");
        } else {
          aggregatedAnalysisResult = "No images Uploaded for Analysis";
        }


        if (isEditing && _taskBeingEdited != null) {
          task = Task( // Use constructor here
            id: _taskBeingEdited!.id,
            date: _taskBeingEdited!.date,
            taskTitle: title,
            taskDescription: description,
            isSynced: _taskBeingEdited!.isSynced,
            taskStatus: _taskBeingEdited!.taskStatus ?? "Pending",
            attachments: attachmentUrls, // Use uploaded URLs
            reviewedBy: _taskBeingEdited!.reviewedBy,
            appAnalysis: aggregatedAnalysisResult,
            firestoreId: _taskBeingEdited!.firestoreId, // ADD THIS LINE FOR UPDATE
            supervisorName: _selectedSupervisor, // ADD THIS LINE
            supervisorEmail: _selectedSupervisorEmail, // ADD THIS LINE
          );


          // Pass taskId for update
          await updateTask(task,_taskBeingEdited!.firestoreId!);
          Get.back(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Task updated successfully!')));
        } else {

          Task newTask = Task( // Create new task with updated info using constructor
            date: _selectedReportingDate,
            taskTitle: title,
            taskDescription: description,
            isSynced: false,
            taskStatus: "Pending",
            attachments: attachmentUrls, // Use uploaded URLs
            reviewedBy: reviewer.name,
            appAnalysis: aggregatedAnalysisResult,
            supervisorName: _selectedSupervisor, // ADD THIS LINE
            supervisorEmail: _selectedSupervisorEmail, // ADD THIS LINE
          );

          await saveTask(newTask);
          Get.back(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Task added successfully!')));
        }


        Task? savedTask = await getTaskByTitleAndDate(title, _selectedReportingDate);
        if (savedTask != null) {
          _taskCardAttachmentsData[savedTask.id ?? -1] =
              List.from(_taskBottomSheetAttachmentsData); // _taskBottomSheetAttachmentsData is now used for main page task input
          _taskBottomSheetAttachmentsData.clear();
        }

        _taskTitleController.clear();
        _taskDescriptionController.clear();
        _taskBeingEdited = null;
        _loadTasksForSelectedDate();
        _selectedReviewer = null; // Reset Reviewer after save/update
        _isEditingTask = false; // Reset edit mode after save
      } catch (e) {
        Get.back(); // Dismiss loading dialog in case of error
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Error saving Task.')));
        print("Error saving Task to Firestore: $e");
      }


    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please fill in all task details and select a Reviewer')));
    }
  }



  Widget _buildTaskCard(Task task) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.taskTitle ?? "No Title",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              task.taskDescription ?? "No Description",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            if (task.attachments != null && task.attachments!.isNotEmpty)
              _buildAttachmentGrid(task.attachments!.map((url) => AttachmentData.fromUrl(url)).toList(), task: task),
            if (task.appAnalysis != null && task.appAnalysis!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Analysis: ${task.appAnalysis!}",
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Supervisor's Approval Status: ",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        task.taskStatus ?? "Pending",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4.0),
                      _getTaskStatusIcon(task.taskStatus ?? "Pending"),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _editTaskOnMainPage(task);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit", style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8.0),
                TextButton.icon(
                  onPressed: () {
                    _deleteTask(task);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  label: const Text("Delete",
                      style: TextStyle(fontSize: 14, color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }


// Function to edit task directly on the main page
  void _editTaskOnMainPage(Task taskToEdit) {
    _taskTitleController.text = taskToEdit.taskTitle ?? '';
    _taskDescriptionController.text = taskToEdit.taskDescription ?? '';
    _taskBottomSheetAttachmentsData = _taskCardAttachmentsData[taskToEdit.id ?? -1] ?? []; // _taskBottomSheetAttachmentsData is now used for main page task input
    _taskBeingEdited = taskToEdit;
    _isEditingTask = true; // Set edit mode to true
    // Set reviewer if available
    if (taskToEdit.reviewedBy != null) {
      for (var staff in _staffList) {
        if (staff.name == taskToEdit.reviewedBy) {
          _selectedReviewer = staff;
          break;
        }
      }
    }
    setState(() {}); // Rebuild the UI to reflect changes in controllers and attachments
  }

  // After editing is done or cancelled, reset _isEditingTask
  void _resetTaskEditState() {
    _isEditingTask = false;
    _taskBeingEdited = null;
    _taskTitleController.clear();
    _taskDescriptionController.clear();
    _taskBottomSheetAttachmentsData.clear();
    setState(() {});
  }



  //  _processImageWithMachineLearning using google_mlkit_image_labeling
  Future<String?> _processImageWithMachineLearning(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7)); // Adjust confidenceThreshold as needed
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
      imageLabeler.close(); // Close the labeler

      if (labels.isNotEmpty) {
        String description = "Image Analysis:\n";
        for (ImageLabel label in labels) {
          final String text = label.label;
          final double confidence = label.confidence;
          description += "- $text (Confidence: ${(confidence * 100).toStringAsFixed(2)}%)\n";
        }
        return description;
      } else {
        return "No labels found in the image.";
      }
    } catch (e) {
      print("Error processing image with ML Kit Image Labeling: $e");
      return "Error analyzing image.";
    }
  }

  // Resets the TextEditingControllers and associated usernames for a given report section.
  void _resetControllers(
      Map<String, TextEditingController> controllers,
      List<String> indicators,
      Map<String, String?> usernames,
      Map<String, String?> editedUsernames) {
    for (String indicator in indicators) {
      controllers[indicator]!.clear();
      usernames[indicator] = null;
      editedUsernames[indicator] = null;
    }
    setState(() {});
  }

  // Save functions for each report type, now dynamically calling _saveReportToFirestore
  Future<void> _saveDynamicReport(String reportTypeKey, List<String> indicators) async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Please select a Reviewer for ${titleCase(reportTypeKey.replaceAll('_', ' '))} Report')));
      return;
    }

    print("_saveDynamicReport: Starting save for reportTypeKey: $reportTypeKey"); // ADDED LOG
    print("_saveDynamicReport: _reportAttachmentsData for $reportTypeKey: ${_reportAttachmentsData[reportTypeKey]}"); // ADDED LOG - Inspect attachments list

    await _saveReportToFirestore(
        reportTypeKey, reportControllers[reportTypeKey]!, indicators, reportEditedUsernames[reportTypeKey]!);
  }

  //Check if current user has entries
  bool _hasCurrentUserEntries(Report? loadedReport) {
    if (loadedReport == null || loadedReport.reportEntries == null) {
      return false;
    }
    return loadedReport.reportEntries!.containsKey(_currentUsername);
  }

  Widget _buildDesignationExpandable(
      String designationName, List<String> indicators, String reportTypeKey) {
    bool isReadOnlySection = _loadedReports[reportTypeKey] != null &&
        (_isEditingReportSection[reportTypeKey] ?? true);
    bool hasEntries = _hasCurrentUserEntries(_loadedReports[reportTypeKey]);

    Report? loadedReport = _loadedReports[reportTypeKey];
    List<AttachmentData> allReportEntryAttachments = [];

    if (isReadOnlySection && loadedReport != null && loadedReport.reportEntries != null) {
      loadedReport.reportEntries!.forEach((username, indicatorMap) {
        indicatorMap.forEach((indicator, entryList) {
          for (var entry in entryList) {
            if (entry.attachments != null && entry.attachments!.isNotEmpty) {
              allReportEntryAttachments.addAll(entry.attachments!.map((url) => AttachmentData.fromUrl(url)));
            }
          }
        });
      });
    }


    return ExpansionTile(
      title: Text(designationName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _genericFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (rest of your form elements - Reporting Date, Report Type, Dropdowns, Reviewer, Supervisor) ...
                Row(
                  children: [
                    const Text("Reporting Date: ",
                        style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedReportingDate),
                      style: const TextStyle(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Report Type*'),
                  value: _selectedReportType,
                  items: ["Daily"].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  validator: (value) =>
                  value == null ? 'Report Type is required' : null,
                  onChanged: isReadOnlySection
                      ? null
                      : (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedReportType = newValue;
                        _updateReportPeriodOptions(_selectedReportType);
                      });
                    }
                  },
                  disabledHint: _selectedReportType != null
                      ? Text(_selectedReportType)
                      : null,
                ),
                const SizedBox(height: 10),
                if (_selectedReportType == "Daily")
                // ... (rest of your Daily report type dropdowns - Reporting Month, Reporting Week) ...
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Reporting Month*'),
                        value: _selectedMonthForWeekly,
                        items: _monthlyOptions.map((String value) {
                          return DropdownMenuItem<String>(
                              value: value, child: Text(value));
                        }).toList(),
                        validator: (value) =>
                        value == null ? 'Reporting Month is required' : null,
                        onChanged: isReadOnlySection
                            ? null
                            : (newValue) {
                          setState(() {
                            _selectedMonthForWeekly = newValue;
                          });
                        },
                        disabledHint: _selectedMonthForWeekly != null
                            ? Text(_selectedMonthForWeekly!)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Reporting Week*'),
                        value: _selectedReportPeriod,
                        items: _reportPeriodOptions.map((String value) {
                          return DropdownMenuItem<String>(
                              value: value, child: Text(value));
                        }).toList(),
                        validator: (value) =>
                        value == null ? 'Reporting Week is required' : null,
                        onChanged: isReadOnlySection
                            ? null
                            : (newValue) {
                          setState(() {
                            _selectedReportPeriod = newValue;
                          });
                        },
                        disabledHint: _selectedReportPeriod != null
                            ? Text(_selectedReportPeriod!)
                            : null,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                _isLoadingStaffList
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<FacilityStaffModel>(
                  decoration:
                  const InputDecoration(labelText: 'Select Reviewer*'),
                  value: _selectedReviewer,
                  hint: const Text("Select Reviewer*"),
                  validator: (value) =>
                  value == null ? 'Reviewer is required' : null,
                  onChanged: isReadOnlySection
                      ? null
                      : (FacilityStaffModel? newValue) {
                    setState(() {
                      _selectedReviewer = newValue;
                    });
                  },
                  items: _staffList.map<DropdownMenuItem<FacilityStaffModel>>(
                          (FacilityStaffModel staff) {
                        return DropdownMenuItem<FacilityStaffModel>(
                            value: staff, child: Text(staff.name ?? 'Unnamed Staff'));
                      }).toList(),
                  disabledHint: _selectedReviewer != null
                      ? Text(_selectedReviewer!.name ?? 'Reviewer Selected')
                      : null,
                ),
                const SizedBox(height: 10),
                buildSupervisorDropdown(), // ADD BUILD SUPERVISOR DROPDOWN HERE
                const SizedBox(height: 20),
                ...indicators.map((indicator) {
                  return _buildIndicatorTextField(
                    controllers: reportControllers[reportTypeKey]!,
                    indicator: indicator,
                    usernames: reportUsernames[reportTypeKey]!,
                    editedUsernames: reportEditedUsernames[reportTypeKey]!,
                    isReadOnly: isReadOnlySection,
                    onEditPressed: () {
                      setState(() {
                        _isEditingReportSection[reportTypeKey] = false;
                      });
                    },
                    reportType: reportTypeKey,
                  );
                }),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Conditionally render the "Update" button based on edit mode
                      if (!isReadOnlySection)
                        ElevatedButton(
                          onPressed: _isSavingReport ? null : () { // Disable button when saving
                            if (_genericFormKey.currentState!.validate()) {
                              _saveDynamicReport(reportTypeKey, indicators);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please fill all required fields marked with *')));
                            }
                          },
                          child: Row( // Use Row to place indicator and text side by side
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadedReports[reportTypeKey] != null
                                  ? 'Update $designationName Report'
                                  : 'Save $designationName Report'),
                              if (_isSavingReport) // Show progress indicator if saving
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  width: 20,
                                  height: 20,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white, // Adjust color as needed
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (isReadOnlySection)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditingReportSection[reportTypeKey] = false;
                                    _resetIndicatorEditableState(reportTypeKey, indicators); // Reset indicator edit state when Edit is clicked
                                    _updateControllerValuesFromLoadedReports(); // Reload values based on new edit state.
                                  });
                                },
                                child: const Text("Edit"),
                              ),
                              const SizedBox(width: 10),
                              //Conditionally render "Send to Reviewer" button
                              if (hasEntries)
                                ElevatedButton(
                                  onPressed: () =>
                                      _sendReportToReviewer(reportTypeKey),
                                  child: const Text("Send To Reviewer"),
                                ),
                            ].whereType<Widget>().toList()
                        ),
                      const SizedBox(height: 8),
                      if (_loadedReports[reportTypeKey]?.reportStatus != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Supervisor's Approval Status: ",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_loadedReports[reportTypeKey]!.reportStatus!,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            _getReportStatusIcon(_loadedReports[reportTypeKey]!.reportStatus!),
                          ],
                        ),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('Click to Add Attachment -->',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Wrap(
                                children: <Widget>[
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose Image from Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _handleMedia(ImageSource.gallery,
                                          reportType: reportTypeKey);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take a Photo'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _handleMedia(ImageSource.camera,
                                          reportType: reportTypeKey);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.attach_file),
                                    title: const Text('Choose Document'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _handleMedia(null,
                                          reportType: reportTypeKey);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ]),
                      if (_reportAttachmentsData[reportTypeKey] != null &&
                          _reportAttachmentsData[reportTypeKey]!.isNotEmpty)
                        _buildAttachmentGrid(_reportAttachmentsData[reportTypeKey]!,
                            reportType: reportTypeKey),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          _getIndicatorCompletionStatus(
                              reportTypeKey, reportControllers[reportTypeKey]!, indicators),
                          _buildStatusDescription(_getIndicatorCompletionStatus(
                              reportTypeKey, reportControllers[reportTypeKey]!, indicators)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Show attachments from ReportEntry when in read-only mode
                if (isReadOnlySection && allReportEntryAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Report Attachments:", style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildAttachmentGrid(allReportEntryAttachments, reportType: reportTypeKey),
                      ],
                    ),
                  ),

                // Add the data table here, after the read-only report section
                _buildReportDataTable(reportTypeKey, indicators),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // Helper function to reset indicator editable state when "Edit" button is clicked
  void _resetIndicatorEditableState(String reportTypeKey, List<String> indicators) {
    if (_isIndicatorEditable.containsKey(reportTypeKey)) {
      for (var indicator in indicators) {
        _isIndicatorEditable[reportTypeKey]![indicator] = false;
      }
    }
  }

  // Builds expandable widget for each department
  Widget _buildDepartmentExpandable(
      String departmentName, List<Map<String, dynamic>> designationReports) {
    return ExpansionTile(
      title: Text(departmentName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      children: designationReports.map((designationReport) {
        String designationName = designationReport['designation'] as String;
        List<String> indicators =
        List<String>.from(designationReport['indicators'] as List);
        String reportTypeKey = "${designationReport['department']}_${designationReport['designation']}"
            .toLowerCase()
            .replaceAll(' ', '_');

        return _buildDesignationExpandable(designationName, indicators, reportTypeKey);
      }).toList(),
    );
  }

  // Initializes database watchers using StreamSubscriptions to listen for changes in reports for the selected date.
  void _initializeReportWatchers() {
    if (bioData == null || bioData!.state == null || bioData!.location == null) {
      print(
          "_initializeReportWatchers: BioData is incomplete, cannot initialize watchers.");
      return;
    }
    _reportWatchers.clear();

    // Watcher for TB Report
    _reportWatchers.add(_firestoreService._firestore
        .collection(FirestoreService().reportsCollection)
        .doc(bioData?.state) // State Document
        .collection(bioData?.state ?? '') // State Sub-collection
        .doc(bioData?.location) // Location Document
        .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
        .doc("Care and Treatment") // Department Document - TB Report is under Care and Treatment
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("TB Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for VL Report
    _reportWatchers.add(_firestoreService._firestore
        .collection(FirestoreService().reportsCollection)
        .doc(bioData?.state)
        .collection(bioData?.state ?? '')
        .doc(bioData?.location)
        .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
        .doc("Laboratory") // Department Document - VL Report is under Laboratory
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("VL Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for Pharmacy Report
    _reportWatchers.add(_firestoreService._firestore
        .collection(FirestoreService().reportsCollection)
        .doc(bioData?.state)
        .collection(bioData?.state ?? '')
        .doc(bioData?.location)
        .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
        .doc("Pharmacy and Logistics") // Department Document - Pharmacy Report is under Pharmacy and Logistics
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("Pharmacy Report");
      _loadReportsForSelectedDate();
    }));

    // Watchers for Prevention Reports (tracking_report, art_nurse_report, hts_report)
    final preventionDepartments = ["Prevention", "Prevention", "Prevention"];
    final reportTypes = ["tracking_report", "art_nurse_report", "hts_report"];

    for (int i = 0; i < reportTypes.length; i++) {
      _reportWatchers.add(_firestoreService._firestore
          .collection(FirestoreService().reportsCollection)
          .doc(bioData?.state)
          .collection(bioData?.state ?? '')
          .doc(bioData?.location)
          .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
          .doc(preventionDepartments[i]) // All Prevention reports are under Prevention Department
          .snapshots()
          .listen((_) {
        _showDatabaseChangeDialog(
            "${titleCase(reportTypes[i].replaceAll('_', ' '))} Report");
        _loadReportsForSelectedDate();
      }));
    }

    // Watcher for SI Report
    _reportWatchers.add(_firestoreService._firestore
        .collection(FirestoreService().reportsCollection)
        .doc(bioData?.state)
        .collection(bioData?.state ?? '')
        .doc(bioData?.location)
        .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
        .doc("Strategic Information") // Department Document - SI Report is under Strategic Information
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("SI Report");
      _loadReportsForSelectedDate();
    }));
  }

  // Shows an AlertDialog to notify the user that a report has been updated in the database.
  void _showDatabaseChangeDialog(String reportName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Database Change Detected"),
          content: Text("$reportName has been updated in the database."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Shows an AlertDialog to notify the user that future dates are not allowed.
  void _showFutureDateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Invalid Date"),
          content: const Text("You cannot fill a report for a future date."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildSupervisorDropdown() {
    return StreamBuilder<List<String?>>(
      stream: (selectedBioDepartment != null && selectedBioState != null)
          ? getSupervisorsFromFirestore(selectedBioDepartment!, selectedBioState!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<String?> supervisorNames = snapshot.data ?? [];

          return SizedBox(
            width: double.infinity,
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _selectedSupervisor,
              items: supervisorNames.map((supervisorName) {
                return DropdownMenuItem<String?>(
                  value: supervisorName,
                  child: Text(
                    supervisorName ?? 'No Supervisor',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                setState(() {
                  _selectedSupervisor = newValue;
                });
                print("Selected Caritas Supervisor: $newValue");

                if (newValue != null) {
                  String? supervisorEmail =
                  await getSupervisorEmailFromFirestore(selectedBioState!, newValue);
                  setState(() {
                    _selectedSupervisorEmail = supervisorEmail;
                  });
                  print("Caritas Supervisor Email: $_selectedSupervisorEmail");
                }
              },
              hint: const Text('Select Supervisor'),
            ),
          );
        }
      },
    );
  }

  Future<String?> getSupervisorEmailFromFirestore(
      String state, String supervisorName) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot =
      await FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(state)
          .collection(state)
          .doc(supervisorName)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final emailField = data['email'];

        // If emailField is a list and not empty, return the first email
        if (emailField is List && emailField.isNotEmpty) {
          return emailField[0] as String;
        }
        // If emailField is already a String, return it directly
        else if (emailField is String) {
          return emailField;
        }
      }
      return null;
    } catch (e) {
      print("Error fetching supervisor email: $e");
      return null;
    }
  }

  Stream<List<String?>> getSupervisorsFromFirestore(
      String department, String state) {
    return FirebaseFirestore.instance
        .collection('Supervisors')
        .doc(state)
        .collection(state)
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => doc['supervisor'] as String?)
        .toList());
  }



  // AppBar for the page.
  AppBar _appBar() {
    return AppBar(
      title: Text('Task Manager', style: TextStyle(color: Colors.white, fontSize: 20 * max(0.8, min(1.2, MediaQuery.of(context).size.shortestSide / 600)))),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF722F37), Color(0xFFB34A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),),
      ),
      actions: [
        _isPDFLoading
            ? CircularProgressIndicator()
            : Row(
            children:[
              IconButton(
                icon: const Icon(Icons.save_alt),
                onPressed: _createTaskSummaryPDF,
              ),
              const Icon(Icons.picture_as_pdf),

            ]
        ),

        const SizedBox(width: 15),

        Container(
          margin: const EdgeInsets.only(top: 15, right: 15, bottom: 15),
          child: Image.asset("assets/image/ccfn_logo.png"),
        )
      ],

    );
  }

  // Date Bar
  _addDateBar() {
    DateTime threeYearsAgo = DateTime.now().subtract(const Duration(days: 3 * 365));
    DateTime now = DateTime.now();
    DateTime tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    DateTime endDate = threeYearsAgo.add(const Duration(days: 365 * 3 + 30));

    List<DateTime> futureDates = [];
    for (DateTime date = tomorrow;
    date.isBefore(endDate.add(const Duration(days: 1)));
    date = date.add(const Duration(days: 1))) {
      futureDates.add(DateTime(date.year, date.month, date.day));
    }

    return Container(
      margin: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: "${DateFormat('d').format(_selectedReportingDate)},",
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: MediaQuery.of(context).size.width *
                                  (MediaQuery.of(context).size.shortestSide < 600
                                      ? 0.080
                                      : 0.060),
                              fontFamily: "NexaBold"),
                          children: [
                            TextSpan(
                              text: DateFormat(" MMMM, yyyy").format(_selectedReportingDate),
                              style: TextStyle(
                                  color: Get.isDarkMode ? Colors.white : Colors.black,
                                  fontSize: MediaQuery.of(context).size.width *
                                      (MediaQuery.of(context).size.shortestSide < 600
                                          ? 0.050
                                          : 0.020),
                                  fontFamily: "NexaBold"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                      child: Text(
                        "Reporting Date",
                        style: TextStyle(
                          fontFamily: "NexaBold",
                          fontSize: MediaQuery.of(context).size.width *
                              (MediaQuery.of(context).size.shortestSide < 600
                                  ? 0.050
                                  : 0.020),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(children: [
                const Text(
                  "Change Date HERE -->",
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.red),
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedReportingDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      selectableDayPredicate: (day) {
                        return day.isBefore(DateTime.now().add(const Duration(days: 1)));
                      },
                    );
                    if (pickedDate != null && pickedDate != _selectedReportingDate) {
                      if (pickedDate.isAfter(DateTime.now())) {
                        _showFutureDateDialog();
                        return;
                      }
                      setState(() {
                        _summaryDataCache = null;
                        _selectedReportingDate = pickedDate;
                        _datePickerSelectionColor = Colors.red;
                        _datePickerSelectedTextColor = Colors.white;
                        _loadReportsForSelectedDate();
                        _loadTasksForSelectedDate();
                        _initializeReportWatchers();
                      });
                    }
                  },
                ),
              ]),
            ],
          ),
          DatePicker(
            _selectedReportingDate,
            key: UniqueKey(),
            controller: DatePickerController(),
            width: 70,
            height: 90,
            monthTextStyle: const TextStyle(
                fontSize: 12, fontFamily: "NexaBold", color: Colors.black),
            dayTextStyle: const TextStyle(
                fontSize: 13, fontFamily: "NexaLight", color: Colors.black),
            dateTextStyle: const TextStyle(
                fontSize: 18, fontFamily: "NexaBold", color: Colors.black),
            selectedTextColor: _datePickerSelectedTextColor,
            selectionColor: _datePickerSelectionColor,
            deactivatedColor: Colors.grey.shade400,
            initialSelectedDate: _selectedReportingDate,
            activeDates: null,
            inactiveDates: futureDates,
            daysCount: 365 * 3 + 30,
            locale: "en_US",
            calendarType: CalendarType.gregorianDate,
            directionality: null,
            onDateChange: (date) {
              if (date.isAfter(DateTime.now())) {
                _showFutureDateDialog();
                return;
              }
              setState(() {
                _selectedReportingDate = date;
                _datePickerSelectionColor = Colors.red;
                _datePickerSelectedTextColor = Colors.white;
                _loadReportsForSelectedDate();
                _loadTasksForSelectedDate();
                _initializeReportWatchers();
              });
            },
          ),
        ],
      ),
    );
  }

  _addTaskBar1() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20),
      child: const SizedBox.shrink(),
    );
  }
  _addTaskBar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20),
      child:  Column( // Task input section moved to main page
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Other Tasks",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontFamily: "NexaBold",
              color: Get.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _taskTitleController,
            style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
            decoration: const InputDecoration(
              hintText: "Task Title",
              hintStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _taskDescriptionController,
            maxLines: 3,
            style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
            decoration: const InputDecoration(
              hintText: "Report of Other Tasks",
              hintStyle: TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("To Be Reviewed By: ",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              _isLoadingStaffList
                  ? const CircularProgressIndicator()
                  :
              // Expanded(
              //   child:
                DropdownButton<FacilityStaffModel>(
                value: _selectedReviewer,
                hint: const Text("Select Reviewer"),
                onChanged: (FacilityStaffModel? newValue) {
                  setState(() {
                    _selectedReviewer = newValue;
                  });
                },
                items: _staffList
                    .map<DropdownMenuItem<FacilityStaffModel>>(
                        (FacilityStaffModel staff) {
                      return DropdownMenuItem<FacilityStaffModel>(
                        value: staff,
                        child: Text(staff.name ?? 'Unnamed Staff'),
                      );
                    }).toList(),
              ),
              //),
            ],
          ),
          Row(
            children: [

              const Text("Select Supervisor's Name: ",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 20),
              Expanded(
                child: buildSupervisorDropdown(),
              ),

            ],
          ),
          // ADD BUILD SUPERVISOR DROPDOWN HERE
          Center(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Click to Add Attachment -->',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Wrap(
                          children: <Widget>[
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choose from Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _handleMedia(ImageSource.gallery);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Take a Photo'),
                              onTap: () {
                                Navigator.pop(context);
                                _handleMedia(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.attach_file),
                              title: const Text('Choose Document'),
                              onTap: () {
                                Navigator.pop(context);
                                _handleMedia(null); // null imgSource for document selection
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ]),
          ),
          if (_taskBottomSheetAttachmentsData.isNotEmpty) // _taskBottomSheetAttachmentsData is now used for main page task input
            _buildAttachmentGrid(_taskBottomSheetAttachmentsData),
          const SizedBox(height: 20),
          MyButton(
            label: _isEditingTask ? "Edit Other Task" : "Add Other Task", // Conditional button label
            onTap: () {
              _addTaskToIsar(isEditing: _isEditingTask); // Pass isEditing state
              _resetTaskEditState(); // Reset state after add/edit
            },
          ),
        ],
      ),
    );
  }







  _showAddTaskBottomSheet(BuildContext context, {Task? taskToEdit}) {
    bool isEditing = taskToEdit != null;
    if (isEditing) {
      _taskTitleController.text = taskToEdit.taskTitle ?? '';
      _taskDescriptionController.text = taskToEdit.taskDescription ?? '';
      _taskBottomSheetAttachmentsData = _taskCardAttachmentsData[taskToEdit.id ?? -1] ?? [];
      _taskBeingEdited = taskToEdit;
    } else {
      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _taskBottomSheetAttachmentsData = [];
      _taskBeingEdited = null;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Get.isDarkMode ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? "Edit Task" : "Add New Task",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: "NexaBold",
                  color: Get.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _taskTitleController,
                style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  hintText: "Task Title",
                  hintStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _taskDescriptionController,
                maxLines: 3,
                style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  hintText: "Report of Activity / Task",
                  hintStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Other Activities To Be Reviewed By: ",
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  _isLoadingStaffList
                      ? const CircularProgressIndicator()
                      : DropdownButton<FacilityStaffModel>(
                    value: _selectedReviewer,
                    hint: const Text("Select Reviewer"),
                    onChanged: (FacilityStaffModel? newValue) {
                      setState(() {
                        _selectedReviewer = newValue;
                      });
                    },
                    items: _staffList
                        .map<DropdownMenuItem<FacilityStaffModel>>(
                            (FacilityStaffModel staff) {
                          return DropdownMenuItem<FacilityStaffModel>(
                            value: staff,
                            child: Text(staff.name ?? 'Unnamed Staff'),
                          );
                        }).toList(),
                  ),
                ],
              ),
              Center(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Click to Add Attachment -->',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Wrap(
                              children: <Widget>[
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Take a Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.attach_file),
                                  title: const Text('Choose Document'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(null); // null imgSource for document selection
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ]),
              ),
              if (_taskBottomSheetAttachmentsData.isNotEmpty)
                _buildAttachmentGrid(_taskBottomSheetAttachmentsData),
              const SizedBox(height: 20),
              MyButton(
                label: isEditing ? "Update Task" : "Add Task",
                onTap: () {
                  _addTaskToIsar(isEditing: isEditing);
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTaskCard1(Task task) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.taskTitle ?? "No Title",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              task.taskDescription ?? "No Description",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            if (_taskCardAttachmentsData[task.id ?? -1] != null &&
                _taskCardAttachmentsData[task.id ?? -1]!.isNotEmpty)
              _buildAttachmentGrid(_taskCardAttachmentsData[task.id ?? -1]!, task: task),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Supervisor's Approval Status: ",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        task.taskStatus ?? "Pending",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4.0),
                      _getTaskStatusIcon(task.taskStatus ?? "Pending"),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _showAddTaskBottomSheet(context, taskToEdit: task);
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit", style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8.0),
                TextButton.icon(
                  onPressed: () {
                    _deleteTask(task);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  label: const Text("Delete",
                      style: TextStyle(fontSize: 14, color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _getTaskStatusIcon(String status) {
    if (status == "Pending") {
      return const Icon(Icons.pending, color: Colors.orange);
    } else if (status == "Approved") {
      return const Icon(Icons.check_circle_outline, color: Colors.green);
    } else if (status == "Rejected") {
      return const Icon(Icons.cancel_outlined, color: Colors.red);
    }
    return const Icon(Icons.help_outline);
  }


  _deleteTask(Task task) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this task?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await deleteTask1(task.firestoreId!, bioData, selectedFirebaseId!, _selectedReportingDate); // Call deleteTask1 with correct parameters
      _loadTasksForSelectedDate(); // Refresh task list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task deleted successfully!')));
    }
  }

  // Helper function to title case a string.
  String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double fontSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    double paddingFactor = max(0.8, min(1.2, screenWidth / 800));
    double marginFactor = max(0.8, min(1.2, screenWidth / 800));
    double iconSizeFactor = max(0.8, min(1.2, screenWidth / 800));
    // Group thematic report definitions by department (same as before)
    Map<String, List<Map<String, dynamic>>> departmentGroupedReports = {};
    for (var definition in _thematicReportDefinitions) {
      String departmentName = definition['department'];
      if (!departmentGroupedReports.containsKey(departmentName)) {
        departmentGroupedReports[departmentName] = [];
      }
      departmentGroupedReports[departmentName]!.add(definition);
    }

    return Scaffold(
      drawer: drawer(
        context,
      ),
      appBar: _appBar(),
      backgroundColor: Colors.white,
      body: Stack( // Wrap body in Stack
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack( // Use IndexedStack to manage different tabs
            index: _selectedIndex,
            children: [
              SingleChildScrollView( // Daily Activity Monitoring Tab Content
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[

                    _addDateBar(),
                    const SizedBox(height: 30),
                    const Divider(),
                    const Divider(),
                    Text(
                      "Routine Tasks For ( ${_selectedReportingDate.toLocal().toString().split(' ')[0]} )",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    const Divider(),
                    const SizedBox(height: 10),

                    const SizedBox(height: 20),
                    // Dynamically build department expandable widgets (same as before)
                    ...departmentGroupedReports.entries.map((entry) {
                      String departmentName = entry.key;
                      List<Map<String, dynamic>> designationReports = entry.value;
                      return _buildDepartmentExpandable(departmentName, designationReports);
                    }),

                    const Divider(),
                    const Divider(),
                    Text(
                      "Other Tasks For ( ${_selectedReportingDate.toLocal().toString().split(' ')[0]} )",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    const Divider(),

                    const SizedBox(height: 10),
                    _addTaskBar(),
                    const SizedBox(height: 10),
                    if (_tasksForDate.isEmpty)
                      const Text("No tasks added for this date.",
                          style: TextStyle(fontWeight: FontWeight.bold))
                    else
                      Column(
                        children:
                        _tasksForDate.map((task) => _buildTaskCard(task)).toList(),
                      ),
                    const Divider(),
                    const Divider(),
                    const SizedBox(height: 20),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _buildReviewListTab(), // Review List Tab Content
              _buildTaskSummaryTab(),
            ],
          ),
          if (_isValidating) // Validation progress bar overlay
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_isAnalyzingImage) // Gemini analysis progress bar overlay
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      // floatingActionButton: _selectedIndex == 0 ? FloatingActionButton.extended( // Show FAB only on Daily Activity Tab
      //   onPressed: () {
      //     _showAddTaskBottomSheet(context);
      //   },
      //   label: const Text(
      //     "Click to Add Extra Task",
      //     style: TextStyle(color: Colors.white, fontSize: 14.0),
      //   ),
      //   icon: const Icon(Icons.add, color: Colors.white),
      //   backgroundColor: Colors.red,
      // ) : null, // No FAB on Review List Tab
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Daily Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Review List',
          ),
          BottomNavigationBarItem( // ADDED: Task Summary Tab
            icon: Icon(Icons.summarize),
            label: 'Task Summary',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }



  Future<void> _submitActivityToSupervisor() async {
    if (_selectedSupervisor == null || _selectedSupervisor!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Supervisor')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Activity submitted to supervisor!')));

    _loadReportsForSelectedDate();
    _loadTasksForSelectedDate();
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({required this.imagePath, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: kIsWeb // Conditional Image widget for FullScreenImage
              ? Image.network(imagePath,
              fit: BoxFit.cover) // Use Image.network for web
              : Image.file(File(imagePath),
              fit: BoxFit.cover), // Use Image.file for non-web
        ),
      ),
    );
  }
}

class FullScreenImageFromMemory extends StatelessWidget {
  final AspectRatio imageData; // Receive AspectRatio with Image.memory

  const FullScreenImageFromMemory({required this.imageData, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: imageData, // Display the Image.memory widget
        ),
      ),
    );
  }
}

class PdfPreviewScreen extends StatelessWidget {
  final String pdfPath;

  const PdfPreviewScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Preview')),
      body: SfPdfViewer.file(File(pdfPath)),
    );
  }
}

class FullScreenVideo extends StatelessWidget {
  final String videoPath;

  const FullScreenVideo({required this.videoPath, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Center(
          child: VideoPlayerWidget(videoPath: videoPath),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const VideoPlayerWidget({required this.videoPath, super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const CircularProgressIndicator();
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
          _isPlaying = !_isPlaying;
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!_isPlaying)
              const Icon(
                Icons.play_arrow,
                size: 50,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Helper class to hold attachment data, including upload progress
class AttachmentData {
  XFile? file;
  Stream<double>? progressStream;
  double uploadProgress;
  bool isUploading;
  String? downloadUrl;
  String fileName;

  AttachmentData({
    this.file,
    this.progressStream,
    this.uploadProgress = 0,
    this.isUploading = false,
    this.downloadUrl,
    required this.fileName,
  });

  // Factory constructor to create AttachmentData from a URL (for existing attachments)
  factory AttachmentData.fromUrl(String url) {
    String fileNameFromUrl = url.split('/').last; // Extract filename from URL
    return AttachmentData(downloadUrl: url, isUploading: false, uploadProgress: 1.0, fileName: fileNameFromUrl);
  }
}