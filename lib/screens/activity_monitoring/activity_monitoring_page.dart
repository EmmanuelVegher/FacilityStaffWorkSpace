import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_picker_timeline/date_picker_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:mime_type/mime_type.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
//import 'package:firebase_ml_vision/firebase_ml_vision.dart'; // Import Firebase ML Vision
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../../widgets/button.dart';
import '../../widgets/drawer.dart';

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
  List<String>? attachments; // ADDED: Attachments field in ReportEntry

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
    this.attachments, // Initialize attachments
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
      attachments: (map['attachments'] as List<dynamic>?)?.cast<String>().toList(), // Deserialize attachments

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
      if (attachments != null) 'attachments': attachments, // Serialize attachments
    };
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

// task.dart
class Task {
  int? id; // Not used in Firestore, Firestore generates document IDs
  DateTime? date;
  String? taskTitle;
  String? taskDescription;
  bool? isSynced;
  String? taskStatus;
  List<String>? attachments;
  String? reviewedBy; // ADDED: Field to store the reviewer's name

  Task({
    this.id,
    this.date,
    this.taskTitle,
    this.taskDescription,
    this.isSynced,
    this.taskStatus,
    this.attachments,
    this.reviewedBy, // ADDED: Include in constructor
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
      taskStatus: data?['taskStatus'],
      attachments:
      (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      reviewedBy: data?['reviewedBy'], // ADDED: Retrieve from Firestore data
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (date != null) 'date': date,
      if (taskTitle != null) 'taskTitle': taskTitle,
      if (taskDescription != null) 'taskDescription': taskDescription,
      if (isSynced != null) 'isSynced': isSynced,
      if (taskStatus != null) 'taskStatus': taskStatus,
      if (attachments != null) 'attachments': attachments,
      if (reviewedBy != null) 'reviewedBy': reviewedBy, // ADDED: Include in Firestore data
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
  Future<List<Task>> getTasksByDate(DateTime date) async {
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

  Future<void> saveTask(Task task) async {
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

  Future<void> pushTaskToFirebase(Task task) async {
    try {
      await saveTask(task); // Save task to Firestore
      await updateTaskSyncStatus(task.id.toString(), true);
    } catch (e) {
      print("Error pushing task to Firebase: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

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

  Future<void> deleteTask(String taskId) async {
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

  String _selectedReportType = "Daily"; // Default report type.
  String? _selectedReportPeriod; // Selected reporting week (Week 1, Week 2, etc.)
  String? _selectedMonthForWeekly; // Selected month for weekly report.
  List<String> _reportPeriodOptions = []; // Options for report period dropdown.
  List<String> _monthlyOptions = []; // Options for month dropdown.
  final Map<String, bool> _isEditingReportSection =
  {}; // Tracks if a report section is in editing mode.
  final Map<String, Report?> _loadedReports =
  {}; // Stores loaded reports for the selected date.
  List<Task> _tasksForDate = []; // Stores tasks for the selected date.
  Map<String, List<Report>> _allReportsForDate = {}; // Stores all reports for the selected date, grouped by department

  Task? _taskBeingEdited; // Track the task being edited

  //final TaskController _taskController = Get.put(TaskController());
  //late NotifyHelper notifyHelper;
  final DateTime _selectedDate =
  DateTime.now(); // Currently selected date (not used for reporting date).
  DateTime _selectedReportingDate =
  DateTime.now(); // Date for which reports are being viewed/entered.
  bool _isLoading = true; // Loading indicator flag.
  Color _datePickerSelectionColor = Colors.red;
  Color _datePickerSelectedTextColor = Colors.white;

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
    if (pickedFile == null) return;

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


  // New Widget to build the report data table
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
        child: Text("Indicator", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      ...usernames.map((username) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
      )),
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
    tableRows.add(TableRow(children: headerCells));

    // Data rows
    for (String indicator in indicators) {
      List<Widget> dataCells = [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(indicator)),
      ];
      int indicatorTotal = 0;
      for (String username in usernames) {
        String value = loadedReport.reportEntries![username]![indicator]?.first.value ?? "0";
        dataCells.add(Padding(padding: const EdgeInsets.all(8.0), child: Text(value)));
        indicatorTotal += int.tryParse(value) ?? 0;
      }
      dataCells.add(Padding(padding: const EdgeInsets.all(8.0), child: Text(indicatorTotal.toString(), style: const TextStyle(fontWeight: FontWeight.bold))));
      tableRows.add(TableRow(children: dataCells));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Table(
        border: TableBorder.all(),
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(250), // Indicator column width
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    );
  }


  // Widget to display attachments in a grid view
// Widget to display attachments in a grid view (Progress bar removed)
  Widget _buildAttachmentGrid(List<AttachmentData> attachmentsData, {String? reportType, Task? task}) {
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
        bool isVideo = mimeType != null && mimeType.startsWith('video/');
        bool isImage = mimeType != null && mimeType.startsWith('image/');
        bool isDocument = !isImage && !isVideo; // Treat everything else as document

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
            child: FutureBuilder<Uint8List>(
              future: attachmentData.file!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
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
                if (isVideo) {
                  // For web, video preview might need different approach
                  // For now, just show a message or handle as needed
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video preview not fully implemented in web yet.')));
                } else if (isImage) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageFromMemory(imageData: thumbnailWidget as AspectRatio), // Pass Image.memory widget
                    ),
                  );
                } else if (isDocument) {
                  // For web, document open might need different approach
                  // For now, just show a message or handle as needed
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document open not fully implemented in web yet.')));
                  //_openDocument(attachmentPath); // Open document on tap - Original implementation for file path
                }
              },
              child: thumbnailWidget,
            ),
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

  // Updates the TextEditingController values from the loaded reports. (Modified to be dynamic)
  void _updateControllerValuesFromLoadedReports() {
    _thematicReportDefinitions.forEach((definition) {
      String reportTypeKey = "${definition['department']}_${definition['designation']}"
          .toLowerCase()
          .replaceAll(' ', '_');
      List<String> indicators =
      List<String>.from(definition['indicators'] ?? []); // Ensure indicators are loaded

      if (!_isControllerMapInitialized(reportTypeKey)) {
        _initializeControllerMap(reportTypeKey, indicators);
      }
      _updateControllersFromReport(
          _loadedReports[reportTypeKey],
          reportControllers[reportTypeKey]!,
          indicators,
          reportUsernames[reportTypeKey]!,
          reportEditedUsernames[reportTypeKey]!);
    });
  }

  bool _isControllerMapInitialized(String reportTypeKey) {
    return reportControllers.containsKey(reportTypeKey);
  }


  // Helper function to update controllers for a specific report type from a loaded report. (Modified to be dynamic)
  void _updateControllersFromReport(
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
  void _updateReportPeriodOptions(String reportType) {
    setState(() {
      _selectedReportPeriod = null;
      _selectedMonthForWeekly = null;
      _reportPeriodOptions =
      reportType == "Daily" ? ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"] : [];
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

// Builds a single indicator text field, either as read-only text or editable TextFormField.
  Widget _buildIndicatorTextField({
    required Map<String, TextEditingController> controllers,
    required String indicator,
    required Map<String, String?> usernames,
    required Map<String, String?> editedUsernames, // Map to hold edited by usernames
    required bool isReadOnly,
    required VoidCallback onEditPressed,
    required String reportType, // Add reportType here
  }) {
    TextInputType keyboardType = indicator == "Comments"
        ? TextInputType.multiline
        : TextInputType.number; // Set keyboard type based on indicator.

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isReadOnly
          ? Column(
        // Display as Text widgets when read-only
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
              children: <TextSpan>[
                TextSpan(text: "$indicator: "),
                TextSpan(
                  text: controllers[indicator]!.text.isNotEmpty
                      ? controllers[indicator]!.text
                      : 'Not Entered', // Display value or "Not Entered"
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: controllers[indicator]!.text.isNotEmpty
                        ? Colors.black
                        : Colors.red, // Conditional color
                  ),
                ),
              ],
            ),
          ),
          if (usernames[indicator] != null &&
              usernames[indicator]!.isNotEmpty)
          // Display "Entered by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null &&
              editedUsernames[indicator]!.isNotEmpty)
          // Display "Edited by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Edited by: ${editedUsernames[indicator]}",
                style: const TextStyle(color: Colors.blue, fontSize: 12.0),
              ),
            ),
          // Display review fields when in ReadOnly mode
          if (isReadOnly)
            _buildReviewFieldsReadOnly(
                indicator: indicator,
                reportType:
                reportType), // Call helper function to build review fields
        ],
      )
          : Column(
        // Display as TextFormField when editable
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
                  readOnly: isReadOnly, // Set readOnly based on isReadOnly flag.
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    suffixIcon: isReadOnly
                        ? IconButton(
                      // Show edit icon only in read-only mode.
                      icon: const Icon(Icons.edit),
                      onPressed: onEditPressed, // Callback to switch to edit mode.
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    // Set onChanged to track entered/edited by usernames
                    setState(() {
                      if (value.isNotEmpty &&
                          (usernames[indicator] == null ||
                              usernames[indicator]!.isEmpty)) {
                        usernames[indicator] = _currentUsername; // Update Entered By username on first change if empty
                        editedUsernames[indicator] =
                        null; // Reset edited by if newly entered
                      } else if (value.isNotEmpty &&
                          value != controllers[indicator]!.text) {
                        editedUsernames[indicator] = _currentUsername; // Update Edited By username on subsequent change
                      } else if (value.isEmpty) {
                        usernames[indicator] =
                        null; // Clear usernames when field is cleared
                        editedUsernames[indicator] =
                        null; // Clear edited usernames when field is cleared
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          if (usernames[indicator] != null &&
              usernames[indicator]!.isNotEmpty)
          // Display "Entered by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null &&
              editedUsernames[indicator]!.isNotEmpty)
          // Display "Edited by" username if available.
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

        if (reportEntry != null) {
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

  // Saves the report data to Firestore database. (Modified for dynamic indicators and Firebase Storage)
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

    // Restructure reportEntries as per requirement
    Map<String, Map<String, List<ReportEntry>>> structuredReportEntries = {};
    String currentUsername = _currentUsername; // Get current username

    Map<String, List<ReportEntry>> indicatorMap = {}; // Map for indicators
    Report? existingReport = _loadedReports[reportType];
    Map<String, String?> currentEnteredBy = {};
    Map<String, String?> currentEditedBy = {};

    List<String> reportAttachmentUrls = []; // List to hold report-level attachment URLs
    List<AttachmentData> reportAttachmentsToUpload = _reportAttachmentsData[reportType] ?? [];

    // Upload attachments and collect URLs
    for (var attachmentData in reportAttachmentsToUpload) {
      if (attachmentData.file != null && attachmentData.downloadUrl == null) {
        String fileExtension = attachmentData.fileName.split('.').last.toLowerCase();
        String fileName = (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension))
            ? 'image_${currentUsername}_$reportType.$fileExtension'
            : 'document_${currentUsername}_$reportType.$fileExtension';

        // String? url = await uploadFileToStorage(
        //   kIsWeb ? attachmentData.file!.path : attachmentData.file!.path,
        //   fileName,
        // );
        // Ensure Web uploads handle XFile properly
        String? url = await uploadFileToStorage(
          attachmentData.file!.path,
          fileName,
          xFile: kIsWeb ? attachmentData.file : null,
        );

        if (url != null) {
          reportAttachmentUrls.add(url);
          attachmentData.downloadUrl = url;
          _processImageWithMachineLearning(attachmentData.file!.path);
          print("File uploaded successfully: $fileName");
        } else {
          print("Upload failed for ${attachmentData.fileName}");
        }
      } else if (attachmentData.downloadUrl != null) {
        reportAttachmentUrls.add(attachmentData.downloadUrl!);
      }
    }

    for (String indicator in indicators) {
      // ... (Data processing logic for each indicator - same as before) ...
      String? existingValue = existingReport?.reportEntries
          ?.containsKey(currentUsername) == true && existingReport?.reportEntries![currentUsername]!.containsKey(indicator) == true
          ? existingReport!.reportEntries![currentUsername]![indicator]!.isNotEmpty ? existingReport.reportEntries![currentUsername]![indicator]!.first.value : null
          : null;


      String currentValue = controllers[indicator]!.text.trim();
      String? enteredByUser = existingReport?.reportEntries
          ?.containsKey(currentUsername) == true && existingReport?.reportEntries![currentUsername]!.containsKey(indicator) == true
          ? existingReport!.reportEntries![currentUsername]![indicator]!.isNotEmpty ? existingReport.reportEntries![currentUsername]![indicator]!.first.enteredBy : null
          : null;


      String? finalEnteredBy = enteredByUser;
      String? finalEditedBy = editedUsernames[indicator];

      if (currentValue.isNotEmpty && (existingValue == null || existingValue.isEmpty)) {
        finalEnteredBy = _currentUsername;
        finalEditedBy = null;
      } else if (currentValue.isNotEmpty && currentValue != existingValue) {
        finalEditedBy = _currentUsername;
        finalEnteredBy = enteredByUser;
        if (finalEnteredBy == null || finalEnteredBy.isEmpty) {
          finalEnteredBy = _currentUsername;
        }
      } else {
        if (existingValue != null && existingValue.isNotEmpty) {
          finalEnteredBy = enteredByUser;
          finalEditedBy = editedUsernames[indicator];
        } else {
          finalEnteredBy = null;
          finalEditedBy = null;
        }
      }

      List<ReportEntry> entryList = []; // List for ReportEntry
      entryList.add(ReportEntry( // Add ReportEntry to the list
        key: indicator,
        value: currentValue,
        enteredBy: finalEnteredBy,
        editedBy: finalEditedBy,
        reviewedBy: _selectedReviewer?.name,
        reviewStatus: "Pending",
        attachments: indicator == indicators.last ? reportAttachmentUrls : null, // Attach report-level attachments only to the last indicator's entry to avoid duplication - adjust if needed.
      ));
      indicatorMap[indicator] = entryList; // Assign list to indicator key
      currentEnteredBy[indicator] = finalEnteredBy;
      currentEditedBy[indicator] = finalEditedBy;
    }
    structuredReportEntries[currentUsername] = indicatorMap; // Assign indicator map to username

    // Show a loading dialog
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);


    try {


      final report = Report(
        reportType: reportType,
        date: _selectedReportingDate,
        reportingWeek: _selectedReportPeriod!,
        reportingMonth: _selectedMonthForWeekly!,
        reportEntries: structuredReportEntries, // Use structured report entries
        isSynced: false,
        reportStatus: "Pending",
        attachments: null, // Attachments are now inside ReportEntry
      );


      String department = reportType.split('_')[0]; // Extract department from reportType
      String designation = reportType.split('_')[1]; // Extract designation from reportType
      await saveReport(report, bioData, reportType);
      Get.back(); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${titleCase(reportType.replaceAll('_', ' '))} Report saved successfully!')));
      setState(() {
        reportUsernames[reportType] = currentEnteredBy; // Update usernames dynamically
        reportEditedUsernames[reportType] = currentEditedBy;
        _isEditingReportSection[reportType] = true;
        _loadReportsForSelectedDate();
      });
    } catch (e) {
      Get.back(); // Dismiss loading dialog in case of error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Error saving ${titleCase(reportType.replaceAll('_', ' '))} Report.')));
      print("Error saving report to Firestore: $e");
    }
  }

  // _addTaskToIsar (Modified for Firestore and editing logic and Firebase Storage)
  _addTaskToIsar({bool isEditing = false}) async {
    String title = _taskTitleController.text;
    String description = _taskDescriptionController.text;
    FacilityStaffModel? reviewer = _selectedReviewer;

    if (title.isNotEmpty && description.isNotEmpty && reviewer != null) {
      Task task;
      // Show a loading dialog
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);


      List<String> attachmentUrls = [];
      List<AttachmentData> attachmentsToUpload = _taskBottomSheetAttachmentsData;

      try {

        for (var attachmentData in attachmentsToUpload) {
          if (attachmentData.file != null && attachmentData.downloadUrl == null) {
            String fileName = 'task_attachment_${DateTime.now().millisecondsSinceEpoch}_${attachmentData.fileName}';
            String? url = await _firestoreService.uploadFileToStorage(
              kIsWeb ? attachmentData.file!.path : attachmentData.file!.path,
              fileName,
            );
            if (url != null) {
              attachmentUrls.add(url);
              attachmentData.downloadUrl = url;
              if (attachmentData.file!.mimeType != null && attachmentData.file!.mimeType!.startsWith('image/')) {
                // Simulate Machine Learning processing for images
                String? imageDescription = await _processImageWithMachineLearning(attachmentData.file!.path); // Pass local file path for ML
                print("Image Description (Task): $imageDescription");
              }
            } else {
              // Handle upload error for a specific file
              print("Upload failed for ${attachmentData.fileName}");
              // Optionally: decide how to handle partial failures. For now, continue saving task data.
            }
          } else if (attachmentData.downloadUrl != null) {
            attachmentUrls.add(attachmentData.downloadUrl!); // Use existing URL if already uploaded
          }
        }


        if (isEditing && _taskBeingEdited != null) {
          task = _taskBeingEdited!
            ..taskDescription = description
            ..taskStatus = _taskBeingEdited!.taskStatus ?? "Pending"
            ..attachments = _taskCardAttachmentsData[_taskBeingEdited!.id ?? -1]?.where((ad) => ad.downloadUrl != null).map((ad) => ad.downloadUrl!).toList() ?? [];

          if (_taskBeingEdited!.id != null) {
            await deleteTask(_taskBeingEdited!.id.toString()); // Delete old task for update
          }
          Task newTask = Task() // Create new task with updated info
            ..date = _selectedReportingDate
            ..taskTitle = title
            ..taskDescription = description
            ..isSynced = false
            ..taskStatus = "Pending"
            ..attachments = _taskCardAttachmentsData[_taskBeingEdited!.id ?? -1]?.where((ad) => ad.downloadUrl != null).map((ad) => ad.downloadUrl!).toList() ?? []
            ..reviewedBy = reviewer.name; // Add reviewer info
          await saveTask(newTask);
          Get.back(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Task updated successfully!')));
        } else {

          Task newTask = Task()
            ..date = _selectedReportingDate
            ..taskTitle = title
            ..taskDescription = description
            ..isSynced = false
            ..taskStatus = "Pending"
            ..attachments = attachmentUrls // Use uploaded URLs
            ..reviewedBy = reviewer.name; // Add reviewer info

          await saveTask(newTask);
          Get.back(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Task added successfully!')));
        }


        Task? savedTask = await getTaskByTitleAndDate(title, _selectedReportingDate);
        if (savedTask != null) {
          _taskCardAttachmentsData[savedTask.id ?? -1] =
              List.from(_taskBottomSheetAttachmentsData);
          _taskBottomSheetAttachmentsData.clear();
        }

        _taskTitleController.clear();
        _taskDescriptionController.clear();
        _taskBeingEdited = null;
        _loadTasksForSelectedDate();
        _selectedReviewer = null; // Reset Reviewer after save/update
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

// Builds expandable widget for each designation (Modified to conditionally show "Send to Reviewer" button)
  Widget _buildDesignationExpandable(
      String designationName, List<String> indicators, String reportTypeKey) {
    bool isReadOnlySection = _loadedReports[reportTypeKey] != null &&
        (_isEditingReportSection[reportTypeKey] ?? true);
    bool hasEntries = _hasCurrentUserEntries(_loadedReports[reportTypeKey]); // Check if current user has entries

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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _genericFormKey, // Using a generic form key here
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (rest of your existing form elements - Reporting Date, Report Type, Dropdowns, Reviewer, Supervisor) ...
                Row(
                  children: [
                    const Text("Reporting Date: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                if ( _loadedReports[reportTypeKey]?.reportStatus == "Approved")
                  StreamBuilder<List<String?>>(
                    stream: selectedBioDepartment != null && selectedBioState != null
                        ? getSupervisorStream(selectedBioDepartment!, selectedBioState!)
                        : Stream.value([]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        List<String?> supervisorNames = snapshot.data ?? [];
                        return DropdownButtonFormField<String?>(
                          decoration:
                          const InputDecoration(labelText: 'Select Supervisor'),
                          value: _selectedSupervisor,
                          items: supervisorNames.map((supervisorName) {
                            return DropdownMenuItem<String?>(
                                value: supervisorName,
                                child: Text(supervisorName ?? 'No Supervisor'));
                          }).toList(),
                          onChanged: isReadOnlySection
                              ? null
                              : (String? newValue) async {
                            setState(() {
                              _selectedSupervisor = newValue;
                            });
                            if (newValue != null && bioData?.department != null) {
                              List<String?> supervisorsemail =
                              await getSupervisorEmailFromFirestore2(
                                  selectedBioDepartment!, newValue);
                              setState(() {
                                _selectedSupervisorEmail = supervisorsemail[0];
                              });
                            }
                          },
                          hint: const Text('Select Supervisor'),
                          disabledHint: _selectedSupervisor != null
                              ? Text(_selectedSupervisor!)
                              : null,
                        );
                      }
                    },
                  ),
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
                }).toList(),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Conditionally render the "Update" button based on edit mode
                      if (!isReadOnlySection)
                        ElevatedButton(
                          onPressed: () {
                            if (_genericFormKey.currentState!.validate()) { // Validate generic form
                              _saveDynamicReport(reportTypeKey, indicators);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please fill all required fields marked with *')));
                            }
                          },
                          child: Text(_loadedReports[reportTypeKey] != null
                              ? 'Update ${designationName} Report'
                              : 'Save ${designationName} Report'),
                        ),
                      if (isReadOnlySection)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  _isEditingReportSection[reportTypeKey] = false;
                                }),
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
                            ].whereType<Widget>().toList() // Remove null if condition is false to avoid error
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



  // Builds expandable widget for each department
  Widget _buildDepartmentExpandable(
      String departmentName, List<Map<String, dynamic>> designationReports) {
    return ExpansionTile(
      title: Text(departmentName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
              value: selectedSupervisor,
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
                  selectedSupervisor = newValue;
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
      backgroundColor: Colors.white,
      title: Text(
        "Task Management",
        style: TextStyle(
            color: Get.isDarkMode ? Colors.white : Colors.grey[600],
            fontFamily: "NexaBold"),
      ),
      elevation: 0.5,
      iconTheme: IconThemeData(color: Get.isDarkMode ? Colors.white : Colors.black87),
      actions: [
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
                                          : 0.030),
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
                                  : 0.030),
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

  _addTaskBar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20),
      child: const SizedBox.shrink(),
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
      await deleteTask(task.id.toString());
      _loadTasksForSelectedDate();
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
    // Group thematic report definitions by department
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
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _addTaskBar(),
                  const SizedBox(height: 10),
                  _addDateBar(),
                  const SizedBox(height: 30),
                  const Divider(),
                  const Divider(),
                  Text(
                    "Thematic Reports for ${_selectedReportingDate.toLocal().toString().split(' ')[0]}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const Divider(),
                  const SizedBox(height: 10),

                  const SizedBox(height: 20),
                  // Dynamically build department expandable widgets
                  ...departmentGroupedReports.entries.map((entry) {
                    String departmentName = entry.key;
                    List<Map<String, dynamic>> designationReports = entry.value;
                    return _buildDepartmentExpandable(departmentName, designationReports);
                  }).toList(),

                  const Divider(),
                  const Divider(),
                  Text(
                    "Other Activities / Tasks for ${_selectedReportingDate.toLocal().toString().split(' ')[0]}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  const Divider(),
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
                  Row(
                    children: [
                      Expanded(
                        child: buildSupervisorDropdown(),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: _submitActivityToSupervisor,
                        child: const Text("Submit Activity Report to Supervisor"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddTaskBottomSheet(context);
        },
        label: const Text(
          "Click to Add Extra Task",
          style: TextStyle(color: Colors.white, fontSize: 14.0),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red,
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