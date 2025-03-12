import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_picker_timeline/date_picker_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../widgets/button.dart';
import '../../widgets/drawer.dart'; // Import async for StreamSubscription


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

  factory BioModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
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
      if (supervisorApprovalStatus != null) 'supervisorApprovalStatus': supervisorApprovalStatus,
      if (supervisorFeedBackComment != null) 'supervisorFeedBackComment': supervisorFeedBackComment,
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
  List<ReportEntry>? reportEntries;

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

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    return Report(
      id: snapshot.id,
      reportType: data?['reportType'],
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      reportingWeek: data?['reportingWeek'],
      reportingMonth: data?['reportingMonth'],
      reportStatus: data?['reportStatus'],
      reportFeedbackComment: data?['reportFeedbackComment'],
      attachments: (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
      isSynced: data?['isSynced'],
      reportEntries: (data?['reportEntries'] as List<dynamic>?)?.map((entryData) => ReportEntry.fromMap(entryData as Map<String, dynamic>)).toList(),
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
      if (reportEntries != null) 'reportEntries': reportEntries!.map((e) => e.toMap()).toList(),
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

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    return Task(
      id: null, // Firestore doesn't use integer IDs, document ID is used instead
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      taskTitle: data?['taskTitle'],
      taskDescription: data?['taskDescription'],
      isSynced: data?['isSynced'],
      taskStatus: data?['taskStatus'],
      attachments: (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
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

  factory FacilityStaffModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
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

  String? getUserId() {
    print("Current UUID === ${_auth.currentUser?.uid}");
    return _auth.currentUser?.uid;
  }

  // BioData Operations (same as before)
  Future<BioModel?> getBioData() async {
    try {
      final snapshot = await _firestore.collection(staffCollection) // Use staffCollection here
          .where('firebaseAuthId', isEqualTo: getUserId())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first,null);
      } else {
        print("_FirestoreService: getBioData: No documents found for firebaseAuthId: ${getUserId()} in ${staffCollection} collection."); // More specific log
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
      final snapshot = await _firestore.collection(staffCollection) // Use staffCollection here
          .where('firebaseAuthId', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first,null);
      } else {
        print("_FirestoreService: getBioInfoWithFirebaseAuth: No documents found for firebaseAuthId: $firebaseAuthUid in ${staffCollection} collection."); // More specific log
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
          .collection(formattedDate) as CollectionReference<Map<String, dynamic>>; // Explicit cast here


      final QuerySnapshot<Map<String, dynamic>> snapshot = await reportCollectionRef.get();
      List<Report> reports = [];
      for (var doc in snapshot.docs) {
        final reportData = doc.data();
        if (reportData != null && reportData['reportType'] != null) {
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


      await reportDocRef.set(report.toFirestore(), SetOptions(merge: true)); // Use set with merge to update or create

    } catch (e) {
      print("Error saving report: $e");
      print("Error details: $e"); // More detailed error log
    }
  }


  Future<void> pushReportToFirebase1(Report report) async {
    // Logic for pushing report, if needed, might be similar to saveReport but ensure sync status update
    // For this example, saveReport handles both save and update.
    print("Push to Firebase function is not directly applicable in Firestore's set operation. Using saveReport.");
  }

  Future<void> updateReportSyncStatus1(String reportId, bool isSynced) async {
    // Firestore handles sync implicitly with offline capabilities, explicit sync status might not be needed
    print("Update sync status function is not directly applicable in Firestore. Sync is handled automatically.");
  }

  Future<List<Report>> getUnsyncedReports1() async {
    // Firestore handles sync implicitly, getting unsynced reports might not be directly applicable
    print("Get unsynced reports function is not directly applicable in Firestore. Sync is handled automatically.");
    return []; // Return empty list as Firestore handles sync
  }


  // Task Operations
  Future<List<Task>> getTasksByDate1(DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc,null)).toList();
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
        return Task.fromFirestore(snapshot.docs.first,null);
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
      await _firestore.collection(tasksCollection).doc(taskId).update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating task sync status: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<List<Task>> getUnsyncedTasks1() async {
    // Firestore handles sync implicitly, getting unsynced tasks might not be directly applicable
    print("Get unsynced tasks function is not directly applicable in Firestore. Sync is handled automatically.");
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
          .where('facilityName', isEqualTo: 'Your Facility Name') // Replace with actual facility name logic
          .get();
      return snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching facility staff list: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Supervisor Operations (same as before)
  Stream<List<String?>> getSupervisorStream1(String department, String state) {
    return _firestore.collection(staffCollection)
        .where('department', isEqualTo: department)
        .where('state', isEqualTo: state)
        .where('designation', isEqualTo: 'Supervisor')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null).name).toList());
  }

  Future<List<String?>> getSupervisorEmailFromFirestore1(String department, String supervisorName) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore.collection(staffCollection)
          .where('department', isEqualTo: department)
          .where('name', isEqualTo: supervisorName)
          .where('designation', isEqualTo: 'Supervisor')
          .limit(1)
          .get();
      return snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null).email).toList();
    } catch (e) {
      print("Error fetching supervisor email from Firestore: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }
}


class DailyActivityMonitoringPage extends StatefulWidget {
  const DailyActivityMonitoringPage({super.key});

  @override
  _DailyActivityMonitoringPageState createState() => _DailyActivityMonitoringPageState();
}

class _DailyActivityMonitoringPageState extends State<DailyActivityMonitoringPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String reportsCollection = 'Reports'; // Updated Collection Name - singular
  final String tasksCollection = 'Tasks';
  final String staffCollection = 'Staff';
  final String bioCollection = 'BioData';
  final FirebaseAuth _auth = FirebaseAuth.instance;



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
          .collection(formattedDate) as CollectionReference<Map<String, dynamic>>; // Explicit cast here


      final QuerySnapshot<Map<String, dynamic>> snapshot = await reportCollectionRef.get();
      List<Report> reports = [];
      for (var doc in snapshot.docs) {
        final reportData = doc.data();
        if (reportData != null && reportData['reportType'] != null) {
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
    print("Push to Firebase function is not directly applicable in Firestore's set operation. Using saveReport.");
  }

  Future<void> updateReportSyncStatus(String reportId, bool isSynced) async {
    // Firestore handles sync implicitly with offline capabilities, explicit sync status might not be needed
    print("Update sync status function is not directly applicable in Firestore. Sync is handled automatically.");
  }

  Future<List<Report>> getUnsyncedReports() async {
    // Firestore handles sync implicitly, getting unsynced reports might not be directly applicable
    print("Get unsynced reports function is not directly applicable in Firestore. Sync is handled automatically.");
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
        return Task.fromFirestore(snapshot.docs.first,null);
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
      await _firestore.collection(tasksCollection).doc(taskId).update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating task sync status: $e");
      print("Error details: $e"); // More detailed error log
    }
  }

  Future<List<Task>> getUnsyncedTasks() async {
    // Firestore handles sync implicitly, getting unsynced tasks might not be directly applicable
    print("Get unsynced tasks function is not directly applicable in Firestore. Sync is handled automatically.");
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


  // Facility Staff Operations (same as before)
  Future<List<FacilityStaffModel>> getFacilityListForSpecificFacility() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('facilityName', isEqualTo: 'Your Facility Name') // Replace with actual facility name logic
          .get();
      return snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching facility staff list: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }

  // Supervisor Operations (same as before)
  Stream<List<String?>> getSupervisorStream(String department, String state) {
    return _firestore.collection(staffCollection)
        .where('department', isEqualTo: department)
        .where('state', isEqualTo: state)
        .where('designation', isEqualTo: 'Supervisor')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null).name).toList());
  }

  Future<List<String?>> getSupervisorEmailFromFirestore2(String department, String supervisorName) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore.collection(staffCollection)
          .where('department', isEqualTo: department)
          .where('name', isEqualTo: supervisorName)
          .where('designation', isEqualTo: 'Supervisor')
          .limit(1)
          .get();
      return snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null).email).toList();
    } catch (e) {
      print("Error fetching supervisor email from Firestore: $e");
      print("Error details: $e"); // More detailed error log
      return [];
    }
  }
  // Define lists of report indicators for each report type
  List<String> tbReportIndicators = [
    "Total Number Newly Tested HIV Positive (HTS TST POSITIVE)",
    "TX NEW (Tx New is the number of new patients COMMENCED on ARVs during the week)",
    "No of new ART patients (TX NEW) clinically screened for TB",
    "Number of Presumptive cases Identified (among those TESTED Positive) (Subset of indicator 'Newly Tested HIV Positive')",
    "Number of Presumptive cases evaluated for LF LAM, GeneXpert, or other Test (among the HTS TST POS)",
    "Number of Patients with MTB detected or confirmed TB Positive Including LF LAM or other test",
    "Number of patients Commenced on TB treatment after GeneXpert or LF LAM Diagnosis",
    "Number of patients Less than 5 Years of age commenced on TB treatment after GeneXpert or LF LAM Diagnosis",
    "Total Number of Tx_New screened Negative",
    "Total Number of Tx New Eligible for TPT (INH)",
    "Total Number of Tx New Commenced on TPT (INH)",
    "ART patients already on treatment who came for drug refill ( Facility and other streams)",
    "ART patients already on treatment who came for drug refill ( Facility and other streams) screened for TB",
    "ART patients already on treatment who came for drug refill ( Facility and other streams) Screened positive ( Presumptive TB )",
    "ART patients already on treatment who came for drug refill ( Facility and other streams) evaluated for TB",
    "Number of ART Patients already on treatment tested positive for TB",
    "Number of ART Patients already on treatment started TB Treatment",
    "Number of ART patients Less than 5 Years already on treatment started TB Treatment",
    "ART patients already on treatment who came for drug refill ( Facility and other streams) Screened Negative ( Non presumptive Presumptive TB )",
    "ART patients already on treatment Completed IPT or already commenced IPT ( Subset of the Indicator above)",
    "ART patients already on treatment Eligible for IPT",
    "ART patients already on treatment Started on IPT",
    "TB STAT for the week (Number of Client started on TB treatment both HIV POS & Negative)",
    "Comments"
  ];

  List<String> vlReportIndicators = [
    "Number of clients that had their samples collected and documented in the Lab VL register",
    "Number of samples logged in through LIMS NMRS with generated manifest sent to the PCR lab",
    "Number of viral load results entered into the VL Register",
    "Comments"
  ];

  List<String> pharmTechReportIndicators = [
    "Number of Drug pickup as documented in the Daily Pharmacy worksheet",
    "Number of clients that had completed Tuberculosis Preventive Therapy (TPT)",
    "Number of commodity consumption data entered into NMRS commodity module",
    "Number of Patients with completed Adverse Drug Reaction screening form",
    "Comments"
  ];

  List<String> trackingAssistantReportIndicators = [
    "Number of Clients with a scheduled appointment",
    "Number of clients with a scheduled appointment given a reminder call of the expected appointment",
    "Number of clients with a scheduled appointment who missed appointment",
    "Number of clients with same day tracking for missed appointment",
    "Number of patient who are IIT that were tracked back",
    "Number of verbal autopsy done",
    "Comments"
  ];

  List<String> artNurseReportIndicators = [
    "proportion of Newly Diagnosed patients with baseline CD4 Test done (Denominator is 'Number of the Newly Diagnosed HIV Positive Clients')",
    "Number of those with baseline CD4 with CD4<200 cells/mm3",
    "Proportion of TB LF-LAM Screening done on individuals with CD4<200 cells/mm3 (Denominator is 'Number of those with baseline CD4 with CD4<200 cells/mm3')",
    "Number of TB LF-LAM Positive",
    "Proportion of Xpert Testing done for all TB LF-Lam positives individuals (Denominator is 'Number of TB LF-LAM Positive')",
    "Number of TB LF-LAM/Xpert testing Concurrence",
    "Proportion of CrAg Screening done for individual with CD4<200 cells/mm3 (Denominator is 'Number of TB LF-LAM/Xpert testing Concurrence')",
    "Number of CrAg Screening Positive",
    "Proportion of CrAg CSF done (Denominator is 'Number of CrAg Screening Positive')",
    "Number of diagnosed CCM",
    "Number of un-suppressed clients commenced on EAC",
    "Number of Unsuppressed clients in a cohort completing EAC",
    "Number of EID sample collected for eligible infants within 2 months of birth",
    "Number of AYP (Adolescents and Young Persons) enrolled into OTZ program",
    "Comments"
  ];

  List<String> htsReportIndicators = [
    "Number of the Newly Diagnosed HIV Positive Clients",
    "Number of Index clients with partners and family members tested",
    "Comments"
  ];

  List<String> siReportIndicators = [
    "Number of Tx_New Clients Entries entered on NMRS (EMR)",
    "Number of Existing Clients Entries entered on NMRS (EMR)",
    "Number of Viral Load results Entry on NMRS (EMR)",
    "Number of ANC Records Entry on NMRS (EMR)",
    "Number of Data entry for HTS on NMRS (EMR)",
    "Number of patients on ART having fingerprints captured on NMRS (EMR)",
    "Comments"
  ];

  // Initialize TextEditingControllers for each indicator for each report type.
  // These controllers will hold the values entered by the user and will be populated when editing a record.
  final Map<String, TextEditingController> tbReportControllers = {};
  final Map<String, TextEditingController> vlReportControllers = {};
  final Map<String, TextEditingController> pharmTechReportControllers = {};
  final Map<String, TextEditingController> trackingAssistantReportControllers = {};
  final Map<String, TextEditingController> artNurseReportControllers = {};
  final Map<String, TextEditingController> htsReportControllers = {};
  final Map<String, TextEditingController> siReportControllers = {};

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
  final Map<String, bool> _isEditingReportSection = {}; // Tracks if a report section is in editing mode.
  final Map<String, Report?> _loadedReports = {}; // Stores loaded reports for the selected date.
  List<Task> _tasksForDate = []; // Stores tasks for the selected date.

  Task? _taskBeingEdited; // Track the task being edited

  //final TaskController _taskController = Get.put(TaskController());
  //late NotifyHelper notifyHelper;
  final DateTime _selectedDate = DateTime.now(); // Currently selected date (not used for reporting date).
  DateTime _selectedReportingDate = DateTime.now(); // Date for which reports are being viewed/entered.
  bool _isLoading = true; // Loading indicator flag.
  Color _datePickerSelectionColor = Colors.red;
  Color _datePickerSelectedTextColor = Colors.white;

  final FirestoreService _firestoreService = FirestoreService(); // Initialize FirestoreService

  // Global keys for form validation for each report section.
  final GlobalKey<FormState> _htsFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _artNurseFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _trackingAssistantFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _tbFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _vlFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _pharmacyFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _siFormKey = GlobalKey<FormState>();

  // Track StreamSubscriptions for database watchers to refresh data on changes.
  final List<StreamSubscription> _reportWatchers = [];


  //Controllers for Task BottomSheet
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  String? _selectedSupervisor;
  final List<String> _supervisorOptions = ["Supervisor 1", "Supervisor 2", "Supervisor 3"]; // Example options


  String? _selectedCaritasSupervisor; // Renamed to be specific to Caritas Supervisor
  String? _selectedCaritasSupervisorEmail;
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
  final Map<String, List<String>> _reportAttachments = {}; // Key is reportType, Value is list of file paths
  List<String> _taskBottomSheetAttachments = []; // Attachments for task in bottom sheet
  final Map<int, List<String>> _taskCardAttachments = {}; // Key is task ID, Value is list of file paths

  List<FacilityStaffModel> _staffList = []; // For staff list dropdown
  bool _isLoadingStaffList = true; // Track loading state of staff list
  FacilityStaffModel? _selectedReviewer; // To store selected reviewer from dropdown




  @override
  void initState() {
    super.initState();

    _loadBioData().then((_){
      _loadStaffList1();
      _initializeAsync();
    });

    _monthlyOptions = _generateMonthlyOptions();
    _updateReportPeriodOptions(_selectedReportType);

    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _isLoading = false;
      });
    });
  }


  @override
  void dispose() {
    for (var watcher in _reportWatchers) {
      watcher.cancel();
    }
    super.dispose();
  }

  // Future<void> _loadStaffList() async {
  //   try {
  //     final List<FacilityStaffModel> staff =
  //     await _firestoreService.getFacilityListForSpecificFacility();
  //     setState(() {
  //       _staffList1 = staff;
  //       _isLoadingStaffList = false;
  //     });
  //   } catch (error) {
  //     print('Error loading staff list: $error');
  //     setState(() {
  //       _isLoadingStaffList = false;
  //     });
  //   }
  // }


  // Function to handle media picking (image or video)
  Future<void> _handleMedia(ImageSource source, {bool isVideo = false, String? reportType, Task? task}) async {
    final XFile? pickedFile = isVideo
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source,maxWidth: 800, maxHeight: 800); // added maxWidth and maxHeight for better memory management
    if (pickedFile != null) {
      setState(() {
        if (reportType != null) {
          _reportAttachments[reportType] = (_reportAttachments[reportType] ?? [])..add(pickedFile.path);
        } else if (task == null) { // Assuming task == null means it's for the task bottom sheet
          _taskBottomSheetAttachments.add(pickedFile.path);
        } else        _taskCardAttachments[task.id ?? -1] = (_taskCardAttachments[task.id ?? -1] ?? [])..add(pickedFile.path);

      });
    }
  }

  // Widget to display attachments in a grid view
// Widget to display attachments in a grid view
  Widget _buildAttachmentGrid(List<String> attachments, {String? reportType, Task? task}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachmentPath = attachments[index];
        bool isVideo = attachmentPath.toLowerCase().endsWith('.mp4') || attachmentPath.toLowerCase().endsWith('.mov'); // Basic video check

        Widget thumbnailWidget; // Widget for thumbnail

        if (isVideo) {
          thumbnailWidget = AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.black, // Placeholder for video thumbnail
              child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
            ),
          );
        } else if (kIsWeb) {
          thumbnailWidget = Image.network(attachmentPath, fit: BoxFit.cover); // Use Image.network for web images
        } else {
          thumbnailWidget = Image.file(File(attachmentPath), fit: BoxFit.cover); // Use Image.file for non-web images
        }


        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                // Implement full-screen view or preview if needed
                isVideo?Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenVideo(videoPath: attachmentPath),
                  ),
                ):
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImage(imagePath: attachmentPath),
                  ),
                );
              },
              child: thumbnailWidget, // Use the determined thumbnailWidget here
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
              _replaceAttachment(index, ImageSource.gallery, isVideo: false, reportType: reportType, task: task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, ImageSource.camera, isVideo: false, reportType: reportType, task: task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Record Video'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, ImageSource.camera, isVideo: true, reportType: reportType, task: task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Choose Video from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _replaceAttachment(index, ImageSource.gallery, isVideo: true, reportType: reportType, task: task);
            },
          ),
        ],
      ),
    );
  }


  Future<void> _replaceAttachment(int index, ImageSource source, {bool isVideo = false, String? reportType, Task? task}) async {
    final XFile? pickedFile = isVideo
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source,maxWidth: 800, maxHeight: 800); // added maxWidth and maxHeight for better memory management

    if (pickedFile != null) {
      setState(() {
        if (reportType != null) {
          if (_reportAttachments[reportType] != null && _reportAttachments[reportType]!.length > index) {
            _reportAttachments[reportType]![index] = pickedFile.path;
          }
        } else if (task == null) {
          if (_taskBottomSheetAttachments.length > index) {
            _taskBottomSheetAttachments[index] = pickedFile.path;
          }
        } else        if (_taskCardAttachments[task.id ?? -1] != null && _taskCardAttachments[task.id ?? -1]!.length > index) {
          _taskCardAttachments[task.id ?? -1]![index] = pickedFile.path;
        }

      });
    }
  }

  void _handleDeleteAttachment(int index, {String? reportType, Task? task}) {
    setState(() {
      if (reportType != null) {
        if (_reportAttachments[reportType] != null && _reportAttachments[reportType]!.length > index) {
          _reportAttachments[reportType]!.removeAt(index);
          if (_reportAttachments[reportType]!.isEmpty) {
            _reportAttachments.remove(reportType); // Remove the list if it becomes empty
          }
        }
      } else if (task == null) {
        if (_taskBottomSheetAttachments.length > index) {
          _taskBottomSheetAttachments.removeAt(index);
        }
      } else      if (_taskCardAttachments[task.id ?? -1] != null && _taskCardAttachments[task.id ?? -1]!.length > index) {
        _taskCardAttachments[task.id ?? -1]!.removeAt(index);
        if (_taskCardAttachments[task.id ?? -1]!.isEmpty) {
          _taskCardAttachments.remove(task.id ?? -1); // Remove the list if it becomes empty
        }
      }

    });
  }


  // Async initialization to ensure controllers are initialized before loading reports.
  Future<void> _initializeAsync() async {
    print("_initializeAsync: Starting initialization");
    await _loadBioDataForSupervisor();
    await _initializeControllers();
    await _fetchUsername();
    await _loadReportsForSelectedDate();
    await _loadTasksForSelectedDate();

    print("_initializeAsync: Reports and Tasks loaded, initializing controllers");
    if (selectedBioState != null && selectedBioLocation != null) {
      _initializeReportWatchers();
    } else {
      print("_initializeAsync: BioData is not fully loaded, skipping report watchers initialization.");
    }

    print("_initializeAsync: Controllers initialized");
  }

  Future<void> _loadBioDataForSupervisor() async {
    print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Loading bio data for supervisor");
    await _loadBioData().then((_) async {
      if (
      selectedBioDepartment != null &&
          selectedBioState != null) {
        print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data loaded, loading supervisor names - Department: ${selectedBioDepartment}, State: ${selectedBioState}");
        await _loadSupervisorNames(selectedBioDepartment!, selectedBioState!);
      } else {
        print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data or department/state is missing for supervisor loading!");
        if (bioData == null) {
          print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: bioData is NULL");
        } else {
          print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Department: ${selectedBioDepartment}, State: ${selectedBioState}");
        }
      }
    });
  }


  Future<void> _loadSupervisorNames(String department, String state) async {
    print("_DailyActivityMonitoringPageState: _loadSupervisorNames: Fetching supervisor names for department: $department, state: $state");
    supervisorNames =
    await _firestoreService.getSupervisorEmailFromFirestore1(department, 'Supervisor Name');
    print("_DailyActivityMonitoringPageState: _loadSupervisorNames: Supervisor names list after fetch: $supervisorNames");
    if (supervisorNames.isNotEmpty) {
      setState(() {
        print("_DailyActivityMonitoringPageState: _loadSupervisorNames: setState called to rebuild UI with supervisor names - List is NOT empty");
      });
    } else {
      print("_DailyActivityMonitoringPageState: _loadSupervisorNames: No supervisors found for department: $department, state: $state - List is empty");
    }
  }

  BioModel? bioData;

  Future<void> _loadBioData1() async {
    print("_DailyActivityMonitoringPageState: _loadBioData: Loading bio data");

    bioData = await _firestoreService.getBioData();
    if (bioData != null) {
      print("_DailyActivityMonitoringPageState: _loadBioData: Bio data loaded: ${bioData!.firstName} ${bioData!.lastName}, Department: ${bioData!.department}, State: ${bioData!.state}");
      setState(() {
        selectedBioFirstName = bioData!.firstName;
        selectedBioLastName = bioData!.lastName;
        selectedBioDepartment = bioData!.department;
        selectedBioState = bioData!.state;
        selectedBioDesignation = bioData!.designation;
        selectedBioLocation = bioData!.location;
        selectedBioStaffCategory = bioData!.staffCategory;
        selectedSignatureLink = bioData!.signatureLink;
        selectedBioEmail = bioData!.emailAddress;
        selectedBioPhone = bioData!.mobile;

        selectedFirebaseId = bioData!.firebaseAuthId;
      });
    } else {
      print("_DailyActivityMonitoringPageState: _loadBioData: No bio data found!");
      print("No bio data found!");
      // **DEBUGGING SUGGESTION:** After "No bio data found!" log, add the following to check Firestore directly:
      // 1. Verify if the 'Staff' collection exists in your Firebase project.
      // 2. Check if there are any documents in the 'Staff' collection.
      // 3. Confirm if any document has 'firebaseAuthId' field matching the 'Current UUID' logged earlier.
      // 4. Double-check Firestore security rules to ensure read access is allowed for your user.
    }
  }

  Future<void> _loadBioData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid; // Get the user UUID

    if (userId == null) {
      print("User is not authenticated.");
      return;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .get();

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



  Future<void> _loadStaffList1() async {
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
    _reportAttachments.clear();
    _isEditingReportSection.clear();
    await _loadBioData(); // Ensure bioData is loaded before fetching reports
    // if (bioData == null) {
    //   print("_loadReportsForSelectedDate: BioData is null, cannot load reports.");
    //   return;
    // }

    List<Report> reports = await getReportsByDate(_selectedReportingDate, bioData);
    print("_loadReportsForSelectedDate: Fetched reports count: ${reports.length}");
    print("Loaded Reports: $reports");

    setState(() {
      for (var report in reports) {
        print("_loadReportsForSelectedDate: Processing report type: ${report.reportType}");
        _loadedReports[report.reportType!] = report;
        _isEditingReportSection[report.reportType!] = true;
        if (report.attachments != null) {
          _reportAttachments[report.reportType!] = List<String>.from(report.attachments!);
        }
        print("_loadReportsForSelectedDate: Loaded report for ${report.reportType}: ${_loadedReports[report.reportType!]}");
      }
      _updateControllerValuesFromLoadedReports();
    });
    print("_loadReportsForSelectedDate: Report loading and controller update complete.");
  }


  Future<void> _loadTasksForSelectedDate() async {
    print("_loadTasksForSelectedDate: Loading tasks for date: $_selectedReportingDate");
    List<Task> tasks = await getTasksByDate(_selectedReportingDate);
    print("Loaded Tasks === $tasks");
    setState(() {
      _tasksForDate = tasks;
      _taskCardAttachments.clear();
      for (var task in tasks) {
        if (task.attachments != null) {
          _taskCardAttachments[task.id ?? -1] = List<String>.from(task.attachments!);
        }
      }
    });
    print("_loadTasksForSelectedDate: Fetched tasks count: ${_tasksForDate.length}");
  }


  // Updates the TextEditingController values from the loaded reports.
  void _updateControllerValuesFromLoadedReports() {
    print("_updateControllerValuesFromLoadedReports: Updating controllers from loaded reports");
    _updateControllersFromReport(_loadedReports["tb_report"], tbReportControllers, tbReportIndicators, tbReportUsernames, tbReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["vl_report"], vlReportControllers, vlReportIndicators, vlReportUsernames, vlReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["pharmacy_report"], pharmTechReportControllers, pharmTechReportIndicators, pharmTechReportUsernames, pharmTechReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["tracking_report"], trackingAssistantReportControllers, trackingAssistantReportIndicators, trackingAssistantReportUsernames, trackingAssistantReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["art_nurse_report"], artNurseReportControllers, artNurseReportIndicators, artNurseReportUsernames, artNurseReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["hts_report"], htsReportControllers, htsReportIndicators, htsReportUsernames, htsReportEditedUsernames);
    _updateControllersFromReport(_loadedReports["si_report"], siReportControllers, siReportIndicators, siReportUsernames, siReportEditedUsernames);
    print("_updateControllerValuesFromLoadedReports: Controller update process completed.");
  }

  // Helper function to update controllers for a specific report type from a loaded report.
  void _updateControllersFromReport(Report? report, Map<String, TextEditingController> controllers, List<String> indicators, Map<String, String?> usernames, Map<String, String?> editedUsernames) {
    String reportType = report?.reportType ?? 'unknown';
    print("_updateControllersFromReport: Updating controllers for report type: $reportType");
    if (report != null && report.reportEntries != null) {
      print("_updateControllersFromReport: Report entries found, processing entries.");
      for (var entry in report.reportEntries!) {
        print("_updateControllersFromReport: Entry Key from report: ${entry.key}");
        if (controllers.containsKey(entry.key)) {
          print("_updateControllersFromReport: Found controller for key: ${entry.key}");
          print("_updateControllersFromReport: Current controller value for ${entry.key}: '${controllers[entry.key]!.text}'");
          print("_updateControllersFromReport: Setting controller value for ${entry.key} to: '${entry.value}'");
          controllers[entry.key]!.text = entry.value;
          usernames[entry.key] = entry.enteredBy;
          editedUsernames[entry.key] = entry.editedBy;
          print("_updateControllersFromReport: Controller value for ${entry.key} updated to: '${controllers[entry.key]!.text}'");
        } else {
          print("_updateControllersFromReport: No controller found for key: ${entry.key}");
        }
      }
      print("_updateControllersFromReport: All report entries processed for report type: $reportType");
    } else {
      print("_updateControllersFromReport: No report found or report entries are null for report type: $reportType. Resetting controllers.");
      _resetControllers(controllers, indicators, usernames, editedUsernames);
    }
    print("_updateControllersFromReport: Controller update for report type: $reportType finished.");
  }


  // Initializes all TextEditingControllers for all report types and indicators.
  Future<void> _initializeControllers() async {
    print("_initializeControllers: Initializing all controllers");
    _initializeControllerMap(tbReportIndicators, tbReportControllers);
    _initializeControllerMap(vlReportIndicators, vlReportControllers);
    _initializeControllerMap(pharmTechReportIndicators, pharmTechReportControllers);
    _initializeControllerMap(trackingAssistantReportIndicators, trackingAssistantReportControllers);
    _initializeControllerMap(artNurseReportIndicators, artNurseReportControllers);
    _initializeControllerMap(htsReportIndicators, htsReportControllers);
    _initializeControllerMap(siReportIndicators, siReportControllers);
    print("_initializeControllers: All controllers initialized.");
  }

  // Helper function to initialize a map of TextEditingControllers for a given list of indicators.
  void _initializeControllerMap(List<String> indicators, Map<String, TextEditingController> controllers) {
    for (String indicator in indicators) {
      controllers[indicator] = TextEditingController();
    }
  }


  // Updates the report period options based on the selected report type (currently only "Daily").
  void _updateReportPeriodOptions(String reportType) {
    setState(() {
      _selectedReportPeriod = null;
      _selectedMonthForWeekly = null;
      _reportPeriodOptions = reportType == "Daily" ? ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"] : [];
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
    TextInputType keyboardType = indicator == "Comments" ? TextInputType.multiline : TextInputType.number; // Set keyboard type based on indicator.

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isReadOnly
          ? Column( // Display as Text widgets when read-only
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
              children: <TextSpan>[
                TextSpan(text: "$indicator: "),
                TextSpan(
                  text: controllers[indicator]!.text.isNotEmpty ? controllers[indicator]!.text : 'Not Entered', // Display value or "Not Entered"
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: controllers[indicator]!.text.isNotEmpty ? Colors.black : Colors.red, // Conditional color
                  ),
                ),
              ],
            ),
          ),
          if (usernames[indicator] != null && usernames[indicator]!.isNotEmpty) // Display "Entered by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null && editedUsernames[indicator]!.isNotEmpty) // Display "Edited by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Edited by: ${editedUsernames[indicator]}",
                style: const TextStyle(color: Colors.blue, fontSize: 12.0),
              ),
            ),
          // Display review fields when in ReadOnly mode
          if (isReadOnly)
            _buildReviewFieldsReadOnly(indicator: indicator, reportType: reportType), // Call helper function to build review fields
        ],
      )
          : Column( // Display as TextFormField when editable
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(indicator, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixIcon: isReadOnly ? IconButton( // Show edit icon only in read-only mode.
                      icon: const Icon(Icons.edit),
                      onPressed: onEditPressed, // Callback to switch to edit mode.
                    ) : null,
                  ),
                  onChanged: (value) { // Set onChanged to track entered/edited by usernames
                    setState(() {
                      if (value.isNotEmpty && (usernames[indicator] == null || usernames[indicator]!.isEmpty )) {
                        usernames[indicator] = _currentUsername; // Update Entered By username on first change if empty
                        editedUsernames[indicator] = null; // Reset edited by if newly entered
                      } else if (value.isNotEmpty && value != controllers[indicator]!.text) {
                        editedUsernames[indicator] = _currentUsername; // Update Edited By username on subsequent change
                      } else if (value.isEmpty) {
                        usernames[indicator] = null; // Clear usernames when field is cleared
                        editedUsernames[indicator] = null; // Clear edited usernames when field is cleared
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          if (usernames[indicator] != null && usernames[indicator]!.isNotEmpty) // Display "Entered by" username if available.
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 10.0),
              child: Text(
                "Entered by: ${usernames[indicator]}",
                style: const TextStyle(color: Colors.red, fontSize: 12.0),
              ),
            ),
          if (editedUsernames[indicator] != null && editedUsernames[indicator]!.isNotEmpty) // Display "Edited by" username if available.
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
      ReportEntry? reportEntry = loadedReport.reportEntries?.firstWhere(
            (entry) => entry.key == indicator,
        orElse: () => ReportEntry(key: indicator, value: ''), // Provide a default ReportEntry
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
              if (reportEntry.supervisorApprovalStatus != null && reportEntry.supervisorApprovalStatus!.isNotEmpty)
                _buildReadOnlyField("Supervisor Approval Status", reportEntry.supervisorApprovalStatus!),
              if (reportEntry.supervisorFeedBackComment != null && reportEntry.supervisorFeedBackComment!.isNotEmpty)
                _buildReadOnlyField("Supervisor Feedback Comment", reportEntry.supervisorFeedBackComment!),
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
        const SnackBar(content: Text('Report not found!')),
      );
      return;
    }

    // Update report status to 'Pending Review'
    existingReport.reportStatus = 'Pending Review';
    try {
      await saveReport(existingReport, bioData, reportType); // Save updated report status to Firestore
      // Push report to Firebase (already saved in Firestore, so this might be redundant or can be adjusted based on your sync needs)
      // await _firestoreService.pushReportToFirebase(existingReport); // Consider if you need a separate 'push' step
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${titleCase(reportType.replaceAll('_', ' '))} Report sent for review!')),
      );
      setState(() {
        _isEditingReportSection[reportType] = true; // Keep in read-only mode after sending for review
        _loadReportsForSelectedDate(); // Refresh report to update status in UI
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending ${titleCase(reportType.replaceAll('_', ' '))} Report for review.')),
      );
      print("Error sending report to Firestore: $e");
    }
  }



// _buildReportSection (Modified for Save, Edit, Update buttons)
  Widget _buildReportSection({
    required GlobalKey<FormState> formKey,
    required String title,
    required List<String> indicators,
    required Map<String, TextEditingController> controllers,
    required Map<String, String?> usernames,
    required Map<String, String?> editedUsernames,
    required String reportType,
    required Future<void> Function() onSubmit,
    String? selectedReportPeriodValue,
    String? selectedMonthForWeeklyValue,
  }) {
    bool isReadOnlySection = _loadedReports[reportType] != null && (_isEditingReportSection[reportType] ?? true);
    String buttonText = isReadOnlySection ? 'Edit $title' : _loadedReports[reportType] != null ? 'Update $title' : 'Save $title';
    String reportStatus = _loadedReports[reportType]?.reportStatus ?? 'Pending';
    String? statusText = _loadedReports[reportType] != null ? _getReportStatusText(reportStatus) : null;

    return ExpansionTile(
      leading: _getIndicatorCompletionStatus(reportType, controllers, indicators),
      title: statusText != null ? Text("$title - $statusText", style: const TextStyle(fontWeight: FontWeight.bold,fontSize:24,color:Colors.green)) : Text(title, style: const TextStyle(fontWeight: FontWeight.bold,fontSize:24)),
      onExpansionChanged: (expanded) { /* ... same as before ... */ },
      initiallyExpanded: false,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (Reporting Date, Report Type, Dropdowns, Reviewer Dropdown - same as before) ...
                Row(children: [ /* ... */ ]),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Report Type*'), value: _selectedReportType, items: ["Daily"].map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(), validator: (value) => value == null ? 'Report Type is required' : null, onChanged: isReadOnlySection ? null : (newValue) { if (newValue != null) { setState(() { _selectedReportType = newValue; _updateReportPeriodOptions(_selectedReportType); }); } }, disabledHint: _selectedReportType != null ? Text(_selectedReportType) : null,),
                const SizedBox(height: 10),
                if (_selectedReportType == "Daily") Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Reporting Month*'), value: selectedMonthForWeeklyValue, items: _monthlyOptions.map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(), validator: (value) => value == null ? 'Reporting Month is required' : null, onChanged: isReadOnlySection ? null : (newValue) { setState(() { _selectedMonthForWeekly = newValue; }); }, disabledHint: selectedMonthForWeeklyValue != null ? Text(selectedMonthForWeeklyValue) : (_selectedMonthForWeekly != null? Text(_selectedMonthForWeekly!) : null),), const SizedBox(height: 10), DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Reporting Week*'), value: selectedReportPeriodValue, items: _reportPeriodOptions.map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(), validator: (value) => value == null ? 'Reporting Week is required' : null, onChanged: isReadOnlySection ? null : (newValue) { setState(() { _selectedReportPeriod = newValue; }); }, disabledHint: selectedReportPeriodValue != null ? Text(selectedReportPeriodValue) : (_selectedReportPeriod != null ? Text(_selectedReportPeriod!) : null),), const SizedBox(height: 20), ],),
                _isLoadingStaffList ? const CircularProgressIndicator() : DropdownButtonFormField<FacilityStaffModel>(decoration: const InputDecoration(labelText: 'Select Reviewer*'), value: _selectedReviewer, hint: const Text("Select Reviewer*"), validator: (value) => value == null ? 'Reviewer is required' : null, onChanged: isReadOnlySection ? null : (FacilityStaffModel? newValue) { setState(() { _selectedReviewer = newValue; }); }, items: _staffList.map<DropdownMenuItem<FacilityStaffModel>>((FacilityStaffModel staff) { return DropdownMenuItem<FacilityStaffModel>(value: staff, child: Text(staff.name ?? 'Unnamed Staff')); }).toList(), disabledHint: _selectedReviewer != null ? Text(_selectedReviewer!.name ?? 'Reviewer Selected') : null,),
                const SizedBox(height: 10),
                if (reportStatus == "Approved") StreamBuilder<List<String?>>(stream: selectedBioDepartment != null && selectedBioState != null ? getSupervisorStream(selectedBioDepartment!, selectedBioState!) : Stream.value([]), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const CircularProgressIndicator(); } else if (snapshot.hasError) { return Text('Error: ${snapshot.error}'); } else { List<String?> supervisorNames = snapshot.data ?? []; return DropdownButtonFormField<String?>(decoration: const InputDecoration(labelText: 'Select Supervisor'), value: _selectedSupervisor, items: supervisorNames.map((supervisorName) { return DropdownMenuItem<String?>(value: supervisorName, child: Text(supervisorName ?? 'No Supervisor')); }).toList(), onChanged: isReadOnlySection ? null : (String? newValue) async { setState(() { _selectedSupervisor = newValue; }); if (newValue != null && bioData?.department != null) { List<String?> supervisorsemail = await getSupervisorEmailFromFirestore2(selectedBioDepartment!, newValue); setState(() { _selectedSupervisorEmail = supervisorsemail[0]; }); } }, hint: const Text('Select Supervisor'), disabledHint: _selectedSupervisor != null ? Text(_selectedSupervisor!) : null,); } },),
                const SizedBox(height: 20),
                ...indicators.map((indicator) => _buildIndicatorTextField(controllers: controllers, indicator: indicator, usernames: usernames, editedUsernames: editedUsernames, isReadOnly: isReadOnlySection, onEditPressed: () { setState(() { _isEditingReportSection[reportType] = false; }); }, reportType: reportType,)),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: ()  {
                          if (formKey.currentState!.validate()) {
                            onSubmit();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields marked with *')),
                            );
                          }
                        },
                        child: Text(buttonText), // Dynamic button text
                      ),
                      if (isReadOnlySection) // Conditionally show buttons in readOnly mode
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => setState(() {_isEditingReportSection[reportType] = false;}),
                              child: const Text("Edit"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _sendReportToReviewer(reportType), // Call send to reviewer function
                              child: const Text("Send To Reviewer"),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (statusText != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Supervisor's Approval Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(reportStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width:4),
                            _getReportStatusIcon(reportStatus),

                          ],
                        ),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            const Text('Click to Add Attachment -->', style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: () { /* ... Attachment Bottom Sheet ... */
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => Wrap(
                                    children: <Widget>[
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title: const Text('Choose Image from Gallery'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleMedia(ImageSource.gallery, reportType: reportType);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.videocam),
                                        title: const Text('Choose Video from Gallery'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleMedia(ImageSource.gallery, isVideo: true, reportType: reportType);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ]
                      ),
                      if (_reportAttachments[reportType] != null && _reportAttachments[reportType]!.isNotEmpty)
                        _buildAttachmentGrid(_reportAttachments[reportType]!, reportType: reportType),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          _getIndicatorCompletionStatus(reportType, controllers, indicators),
                          _buildStatusDescription(_getIndicatorCompletionStatus(reportType, controllers, indicators)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
    return Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey));
  }

  // Determines the report completion status based on whether indicators are filled and returns an appropriate icon.
  Widget _getIndicatorCompletionStatus(String reportType, Map<String, TextEditingController> controllers, List<String> indicators) {
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


  // Saves the report data to Firestore database. Handles both new saves and updates to existing reports.
  Future<void> _saveReportToFirestore(String reportType, Map<String, TextEditingController> controllers, List<String> indicators, Map<String, String?> editedUsernames) async {
    if (_selectedReportType.isEmpty || _selectedReportPeriod == null || _selectedMonthForWeekly == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Report Type, Reporting Week, and Reporting Month')),
      );
      return;
    }
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer')),
      );
      return;
    }
    if (selectedBioState == null || selectedBioLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BioData is incomplete, cannot save report.')),
      );
      return;
    }


    List<ReportEntry> reportDataEntries = [];
    Report? existingReport = _loadedReports[reportType];
    Map<String, String?> currentEnteredBy = {};
    Map<String, String?> currentEditedBy = {};

    for (String indicator in indicators) {
      String? existingValue = existingReport?.reportEntries?.firstWhere((entry) => entry.key == indicator, orElse: () => ReportEntry(key: indicator, value: '')).value;
      String currentValue = controllers[indicator]!.text.trim();
      String? enteredByUser = existingReport?.reportEntries?.firstWhere((entry) => entry.key == indicator, orElse: () => ReportEntry(key: indicator, value: '')).enteredBy;

      String? finalEnteredBy = enteredByUser;
      String? finalEditedBy = editedUsernames[indicator];

      if (currentValue.isNotEmpty && (existingValue == null || existingValue.isEmpty) ) {
        finalEnteredBy = _currentUsername;
        finalEditedBy = null;
      } else if (currentValue.isNotEmpty && currentValue != existingValue) {
        finalEditedBy = _currentUsername;
        finalEnteredBy = enteredByUser;
        if (finalEnteredBy == null || finalEnteredBy.isEmpty) {
          finalEnteredBy = _currentUsername;
        }
      } else {
        if(existingValue != null && existingValue.isNotEmpty){
          finalEnteredBy = enteredByUser;
          finalEditedBy = editedUsernames[indicator];
        } else {
          finalEnteredBy = null;
          finalEditedBy = null;
        }
      }


      reportDataEntries.add(
        ReportEntry(
          key: indicator,
          value: currentValue,
          enteredBy: finalEnteredBy,
          editedBy: finalEditedBy,
          reviewedBy: _selectedReviewer?.name,
          reviewStatus: "Pending",
        ),
      );
      currentEnteredBy[indicator] = finalEnteredBy;
      currentEditedBy[indicator] = finalEditedBy;
    }

    final report = Report(
      reportType: reportType,
      date: _selectedReportingDate,
      reportingWeek: _selectedReportPeriod!,
      reportingMonth: _selectedMonthForWeekly!,
      reportEntries: reportDataEntries,
      isSynced:false,
      reportStatus:"Pending",
      attachments: _reportAttachments[reportType] ?? [],
    );


    try {
      await saveReport(report, bioData, reportType); // Save to Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${titleCase(reportType.replaceAll('_', ' '))} Report saved successfully!')),
      );



      setState(() {
        if(reportType == "tb_report") tbReportUsernames = currentEnteredBy; tbReportEditedUsernames = currentEditedBy;
        if(reportType == "vl_report") vlReportUsernames = currentEnteredBy; vlReportEditedUsernames = currentEditedBy;
        if(reportType == "pharmacy_report") pharmTechReportUsernames = currentEnteredBy; pharmTechReportEditedUsernames = currentEditedBy;
        if(reportType == "tracking_report") trackingAssistantReportUsernames = currentEnteredBy; trackingAssistantReportEditedUsernames = currentEditedBy;
        if(reportType == "art_nurse_report") artNurseReportUsernames = currentEnteredBy; artNurseReportEditedUsernames = currentEditedBy;
        if(reportType == "hts_report") htsReportUsernames = currentEnteredBy; htsReportEditedUsernames = currentEditedBy;
        if(reportType == "si_report") siReportUsernames = currentEnteredBy; siReportEditedUsernames = currentEditedBy;

        _isEditingReportSection[reportType] = true;
        _loadReportsForSelectedDate();
      });


    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving ${titleCase(reportType.replaceAll('_', ' '))} Report.')),
      );
      print("Error saving report to Firestore: $e");
    }

  }


  // Resets the TextEditingControllers and associated usernames for a given report section.
  void _resetControllers(Map<String, TextEditingController> controllers, List<String> indicators, Map<String, String?> usernames, Map<String, String?> editedUsernames) {
    for (String indicator in indicators) {
      controllers[indicator]!.clear();
      usernames[indicator] = null;
      editedUsernames[indicator] = null;
    }
    setState(() {});
  }

  // Initializes database watchers using StreamSubscriptions to listen for changes in reports for the selected date.
  void _initializeReportWatchers() {
    if (bioData == null || bioData!.state == null || bioData!.location == null) {
      print("_initializeReportWatchers: BioData is incomplete, cannot initialize watchers.");
      return;
    }
    _reportWatchers.clear();

    // Watcher for TB Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .doc(bioData?.state) // State Document
        .collection(bioData?.state ?? '') // State Sub-collection
        .doc(bioData?.location) // Location Document
        .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate)) // Date Sub-collection
        .doc("Care and Treatment") // Department Document - TB Report is under Care and Treatment
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("TB Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for VL Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
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
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
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
      _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
          .doc(bioData?.state)
          .collection(bioData?.state ?? '')
          .doc(bioData?.location)
          .collection(DateFormat('dd-MMM-yyyy').format(_selectedReportingDate))
          .doc(preventionDepartments[i]) // All Prevention reports are under Prevention Department
          .snapshots()
          .listen((_) {
        _showDatabaseChangeDialog("${titleCase(reportTypes[i].replaceAll('_', ' '))} Report");
        _loadReportsForSelectedDate();
      }));
    }


    // Watcher for SI Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
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
                  String? supervisorEmail = await getSupervisorEmailFromFirestore(selectedBioState!, newValue);
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

  Future<String?> getSupervisorEmailFromFirestore(String state, String supervisorName) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> docSnapshot = await FirebaseFirestore.instance
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

  Stream<List<String?>> getSupervisorsFromFirestore(String department, String state) {
    return FirebaseFirestore.instance
        .collection('Supervisors')
        .doc(state)
        .collection(state)
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => doc['supervisor'] as String?).toList());
  }




  // Save functions for each report type, calling _saveReportToFirestore with correct parameters.
  Future<void> _saveHtsReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for HTS Report')),
      );
      return;
    }
    await _saveReportToFirestore("hts_report", htsReportControllers, htsReportIndicators, htsReportEditedUsernames);
  }

  Future<void> _saveArtNurseReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for ART Nurse Report')),
      );
      return;
    }
    await _saveReportToFirestore("art_nurse_report", artNurseReportControllers, artNurseReportIndicators, artNurseReportEditedUsernames);
  }

  Future<void> _saveTrackingAssistantReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for Tracking Assistant Report')),
      );
      return;
    }
    await _saveReportToFirestore("tracking_report", trackingAssistantReportControllers, trackingAssistantReportIndicators, trackingAssistantReportEditedUsernames);
  }

  Future<void> _saveTbReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for TB Report')),
      );
      return;
    }
    await _saveReportToFirestore("tb_report", tbReportControllers, tbReportIndicators, tbReportEditedUsernames);
  }

  Future<void> _saveVlReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for VL Report')),
      );
      return;
    }
    await _saveReportToFirestore("vl_report", vlReportControllers, vlReportIndicators, vlReportEditedUsernames);
  }

  Future<void> _savePharmacyReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for Pharmacy Report')),
      );
      return;
    }
    await _saveReportToFirestore("pharmacy_report", pharmTechReportControllers, pharmTechReportIndicators, pharmTechReportEditedUsernames);
  }

  Future<void> _saveSiReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for SI Report')),
      );
      return;
    }
    await _saveReportToFirestore("si_report", siReportControllers, siReportIndicators, siReportEditedUsernames);
  }


  // AppBar for the page.
  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Text(
        "Task Management",
        style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.grey[600], fontFamily: "NexaBold"),
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
    for (DateTime date = tomorrow; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
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
                              fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.080 : 0.060),
                              fontFamily: "NexaBold"),
                          children: [
                            TextSpan(
                              text: DateFormat(" MMMM, yyyy").format(_selectedReportingDate),
                              style: TextStyle(
                                  color: Get.isDarkMode ? Colors.white : Colors.black,
                                  fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.030),
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
                          fontSize: MediaQuery.of(context).size.width * (MediaQuery.of(context).size.shortestSide < 600 ? 0.050 : 0.030),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                  children:[
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
                  ]
              ),

            ],
          ),
          DatePicker(
            _selectedReportingDate,
            key: UniqueKey(),
            controller: DatePickerController(),
            width: 70,
            height: 90,
            monthTextStyle: const TextStyle(fontSize: 12, fontFamily: "NexaBold", color: Colors.black),
            dayTextStyle: const TextStyle(fontSize: 13, fontFamily: "NexaLight", color: Colors.black),
            dateTextStyle: const TextStyle(fontSize: 18, fontFamily: "NexaBold", color: Colors.black),
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
      _taskBottomSheetAttachments = _taskCardAttachments[taskToEdit.id ?? -1] ?? [];
      _taskBeingEdited = taskToEdit;
    } else {
      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _taskBottomSheetAttachments = [];
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
                  const Text("Other Activities To Be Reviewed By: ", style: TextStyle(fontSize: 16)),
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
                    items: _staffList.map<DropdownMenuItem<FacilityStaffModel>>((FacilityStaffModel staff) {
                      return DropdownMenuItem<FacilityStaffModel>(
                        value: staff,
                        child: Text(staff.name ?? 'Unnamed Staff'),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Center(
                child:  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      const Text('Click to Add Attachment -->', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  leading: const Icon(Icons.video_library),
                                  title: const Text('Choose Video from Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(ImageSource.gallery, isVideo: true);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ]
                ),

              ),
              if (_taskBottomSheetAttachments.isNotEmpty)
                _buildAttachmentGrid(_taskBottomSheetAttachments),
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


  // _addTaskToIsar (Modified for Firestore and editing logic)
  _addTaskToIsar({bool isEditing = false}) async {
    String title = _taskTitleController.text;
    String description = _taskDescriptionController.text;
    FacilityStaffModel? reviewer = _selectedReviewer;

    if (title.isNotEmpty && description.isNotEmpty && reviewer != null) {
      Task task;
      if (isEditing && _taskBeingEdited != null) {
        task = _taskBeingEdited!
          ..taskDescription = description
          ..taskStatus = _taskBeingEdited!.taskStatus ?? "Pending"
          ..attachments = _taskCardAttachments[_taskBeingEdited!.id ?? -1] ?? [];

        if (_taskBeingEdited!.id != null) {
          await deleteTask(_taskBeingEdited!.id.toString()); // Delete old task for update
        }
        Task newTask = Task() // Create new task with updated info
          ..date = _selectedReportingDate
          ..taskTitle = title
          ..taskDescription = description
          ..isSynced = false
          ..taskStatus = "Pending"
          ..attachments = _taskCardAttachments[_taskBeingEdited!.id ?? -1] ?? []
          ..reviewedBy = reviewer.name; // Add reviewer info
        await saveTask(newTask);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully!')),
        );

      } else {
        Task newTask = Task()
          ..date = _selectedReportingDate
          ..taskTitle = title
          ..taskDescription = description
          ..isSynced = false
          ..taskStatus = "Pending"
          ..attachments = _taskBottomSheetAttachments
          ..reviewedBy = reviewer.name; // Add reviewer info

        await saveTask(newTask);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!')),
        );
      }

      Task? savedTask = await getTaskByTitleAndDate(title, _selectedReportingDate);
      if (savedTask != null) {
        _taskCardAttachments[savedTask.id ?? -1] = List.from(_taskBottomSheetAttachments);
        _taskBottomSheetAttachments.clear();
      }

      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _taskBeingEdited = null;
      _loadTasksForSelectedDate();
      _selectedReviewer = null; // Reset Reviewer after save/update

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all task details and select a Reviewer')),
      );
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
            if (_taskCardAttachments[task.id ?? -1] != null && _taskCardAttachments[task.id ?? -1]!.isNotEmpty)
              _buildAttachmentGrid(_taskCardAttachments[task.id ?? -1]!, task: task),
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
                      const Text("Supervisor's Approval Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text("Delete", style: TextStyle(fontSize: 14, color: Colors.red)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully!')),
      );
    }
  }

  // Helper function to title case a string.
  String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1).toLowerCase();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer(context,),
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
                  _buildReportSection(
                    formKey: _htsFormKey,
                    title: 'HTS Report',
                    indicators: htsReportIndicators,
                    controllers: htsReportControllers,
                    usernames: htsReportUsernames,
                    editedUsernames: htsReportEditedUsernames,
                    reportType: "hts_report",
                    onSubmit: _saveHtsReport,
                    selectedReportPeriodValue: _loadedReports["hts_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["hts_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _artNurseFormKey,
                    title: 'ART Nurse Report',
                    indicators: artNurseReportIndicators,
                    controllers: artNurseReportControllers,
                    usernames: artNurseReportUsernames,
                    editedUsernames: artNurseReportEditedUsernames,
                    reportType: "art_nurse_report",
                    onSubmit: _saveArtNurseReport,
                    selectedReportPeriodValue: _loadedReports["art_nurse_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["art_nurse_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _trackingAssistantFormKey,
                    title: 'Tracking Assistant Report',
                    indicators: trackingAssistantReportIndicators,
                    controllers: trackingAssistantReportControllers,
                    usernames: trackingAssistantReportUsernames,
                    editedUsernames: trackingAssistantReportEditedUsernames,
                    reportType: "tracking_report",
                    onSubmit: _saveTrackingAssistantReport,
                    selectedReportPeriodValue: _loadedReports["tracking_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["tracking_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _tbFormKey,
                    title: 'TB Report (Care and Treatment)',
                    indicators: tbReportIndicators,
                    controllers: tbReportControllers,
                    usernames: tbReportUsernames,
                    editedUsernames: tbReportEditedUsernames,
                    reportType: "tb_report",
                    onSubmit: _saveTbReport,
                    selectedReportPeriodValue: _loadedReports["tb_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["tb_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _vlFormKey,
                    title: 'VL Report (Laboratory)',
                    indicators: vlReportIndicators,
                    controllers: vlReportControllers,
                    usernames: vlReportUsernames,
                    editedUsernames: vlReportEditedUsernames,
                    reportType: "vl_report",
                    onSubmit: _saveVlReport,
                    selectedReportPeriodValue: _loadedReports["vl_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["vl_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _pharmacyFormKey,
                    title: 'Pharmacy Report (Pharmacy and Logistics)',
                    indicators: pharmTechReportIndicators,
                    controllers: pharmTechReportControllers,
                    usernames: pharmTechReportUsernames,
                    editedUsernames: pharmTechReportEditedUsernames,
                    reportType: "pharmacy_report",
                    onSubmit: _savePharmacyReport,
                    selectedReportPeriodValue: _loadedReports["pharmacy_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["pharmacy_report"]?.reportingMonth,
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection(
                    formKey: _siFormKey,
                    title: 'SI Report (Strategic Information)',
                    indicators: siReportIndicators,
                    controllers: siReportControllers,
                    usernames: siReportUsernames,
                    editedUsernames: siReportEditedUsernames,
                    reportType: "si_report",
                    onSubmit: _saveSiReport,
                    selectedReportPeriodValue: _loadedReports["si_report"]?.reportingWeek,
                    selectedMonthForWeeklyValue: _loadedReports["si_report"]?.reportingMonth,
                  ),

                  const SizedBox(height: 30),
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
                    const Text("No tasks added for this date.",style: TextStyle(fontWeight: FontWeight.bold))
                  else
                    Column(
                      children: _tasksForDate.map((task) => _buildTaskCard(task)).toList(),
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
        const SnackBar(content: Text('Please select a Supervisor')),
      );
      return;
    }


    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity submitted to supervisor!')),
    );

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
              ? Image.network(imagePath, fit: BoxFit.cover) // Use Image.network for web
              : Image.file(File(imagePath), fit: BoxFit.cover), // Use Image.file for non-web
        ),
      ),
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