import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
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
class Report {
  String? id;
  String? reportType;
  DateTime? date;
  String? reportingWeek;
  String? reportingMonth;
  List<ReportEntry>? reportEntries;
  bool? isSynced;
  String? reportStatus;
  List<String>? attachments;

  Report({
    this.id,
    this.reportType,
    this.date,
    this.reportingWeek,
    this.reportingMonth,
    this.reportEntries,
    this.isSynced,
    this.reportStatus,
    this.attachments,
  });

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    return Report(
      id: snapshot.id,
      reportType: data?['reportType'],
      date: data?['date'] != null ? (data?['date'] as Timestamp).toDate() : null,
      reportingWeek: data?['reportingWeek'],
      reportingMonth: data?['reportingMonth'],
      reportEntries: (data?['reportEntries'] as List<dynamic>?)?.map((entryData) => ReportEntry.fromMap(entryData as Map<String, dynamic>)).toList(),
      isSynced: data?['isSynced'],
      reportStatus: data?['reportStatus'],
      attachments: (data?['attachments'] as List<dynamic>?)?.cast<String>().toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (reportType != null) 'reportType': reportType,
      if (date != null) 'date': date,
      if (reportingWeek != null) 'reportingWeek': reportingWeek,
      if (reportingMonth != null) 'reportingMonth': reportingMonth,
      if (reportEntries != null) 'reportEntries': reportEntries!.map((e) => e.toMap()).toList(),
      if (isSynced != null) 'isSynced': isSynced,
      if (reportStatus != null) 'reportStatus': reportStatus,
      if (attachments != null) 'attachments': attachments,
    };
  }
}

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
    required this.key,
    required this.value,
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


// task.dart
class Task {
  int? id; // Not used in Firestore, Firestore generates document IDs
  DateTime? date;
  String? taskTitle;
  String? taskDescription;
  bool? isSynced;
  String? taskStatus;
  List<String>? attachments;

  Task({
    this.id,
    this.date,
    this.taskTitle,
    this.taskDescription,
    this.isSynced,
    this.taskStatus,
    this.attachments,
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
    };
  }
}


// facility_staff_model.dart
class FacilityStaffModel {
  String? id;
  String? name;
  String? email;
  String? department;
  String? state;
  String? facilityName;
  String? designation;
  String? staffCategory;


  FacilityStaffModel({
    this.id,
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


// Firestore Service
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String reportsCollection = 'Reports';
  final String tasksCollection = 'Tasks';
  final String staffCollection = 'Staff';
  final String bioCollection = 'BioData';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getUserId() {
    print("Current UUID === ${_auth.currentUser?.uid}");
    return _auth.currentUser?.uid;
  }

  // BioData Operations
  Future<BioModel?> getBioData() async {
    try {
      final snapshot = await _firestore.collection("Staff").where('firebaseAuthId', isEqualTo: getUserId()).limit(1).get(); // Replace 'your_firebase_auth_uid' with actual user ID logic
      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first,null);
      }
      return null;
    } catch (e) {
      print("Error fetching BioData: $e");
      return null;
    }
  }

  Future<BioModel?> getBioInfoWithFirebaseAuth() async {
    // Implement logic to get current Firebase Auth UID
    // For now, using a placeholder, replace with actual auth logic
    String? firebaseAuthUid = getUserId(); // Replace with actual Firebase Auth UID retrieval
    if (firebaseAuthUid == null) return null;

    try {
      final snapshot = await _firestore.collection("Staff")
          .where('firebaseAuthId', isEqualTo: firebaseAuthUid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return BioModel.fromFirestore(snapshot.docs.first,null);
      }
      return null;
    } catch (e) {
      print("Error fetching BioData with FirebaseAuth: $e");
      return null;
    }
  }

  // Report Operations
  Future<List<Report>> getReportsByDate(DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(reportsCollection)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .get();
      return snapshot.docs.map((doc) => Report.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching reports by date: $e");
      return [];
    }
  }

  Future<void> saveReport(Report report) async {
    try {
      if (report.id == null) {
        await _firestore.collection(reportsCollection).add(report.toFirestore());
      } else {
        await _firestore.collection(reportsCollection).doc(report.id).update(report.toFirestore());
      }
    } catch (e) {
      print("Error saving report: $e");
    }
  }

  Future<void> pushReportToFirebase(Report report) async {
    try {
      await saveReport(report); // For Firestore, saveReport already handles both add and update
      await updateReportSyncStatus(report.id ?? '', true); // Assuming saveReport returns document ID or sets it in the report object
    } catch (e) {
      print("Error pushing report to Firebase: $e");
    }
  }

  Future<void> updateReportSyncStatus(String reportId, bool isSynced) async {
    try {
      await _firestore.collection(reportsCollection).doc(reportId).update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating report sync status: $e");
    }
  }

  Future<List<Report>> getUnsyncedReports() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(reportsCollection)
          .where('isSynced', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) => Report.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching unsynced reports: $e");
      return [];
    }
  }


  // Task Operations
  Future<List<Task>> getTasksByDate(DateTime date) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('date', isEqualTo: DateTime(date.year, date.month, date.day))
          .get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching tasks by date: $e");
      return [];
    }
  }

  Future<void> saveTask(Task task) async {
    try {
      if (task.id == null) {
        await _firestore.collection(tasksCollection).add(task.toFirestore());
      } else {
        // Firestore doesn't directly use integer IDs, you might need to adjust based on how you manage task IDs
        // If you're using Firestore's document IDs, you'd update based on that ID, not an integer ID.
        // For simplicity, assuming you want to add new tasks only for now.
        await _firestore.collection(tasksCollection).add(task.toFirestore());
      }
    } catch (e) {
      print("Error saving task: $e");
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
      return null;
    }
  }


  Future<void> pushTaskToFirebase(Task task) async {
    try {
      await saveTask(task); // Save task to Firestore
      await updateTaskSyncStatus(task.id.toString(), true); // Assuming saveTask returns document ID or sets it in the task object, you might need to adjust ID handling
    } catch (e) {
      print("Error pushing task to Firebase: $e");
    }
  }

  Future<void> updateTaskSyncStatus(String taskId, bool isSynced) async {
    // Firestore uses document IDs (strings), adjust taskId accordingly if needed
    try {
      await _firestore.collection(tasksCollection).doc(taskId).update({'isSynced': isSynced});
    } catch (e) {
      print("Error updating task sync status: $e");
    }
  }

  Future<List<Task>> getUnsyncedTasks() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(tasksCollection)
          .where('isSynced', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching unsynced tasks: $e");
      return [];
    }
  }


  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection(tasksCollection).doc(taskId).delete();
    } catch (e) {
      print("Error deleting task: $e");
    }
  }


  // Facility Staff Operations
  Future<List<FacilityStaffModel>> getFacilityListForSpecificFacility() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(staffCollection)
          .where('facilityName', isEqualTo: 'Your Facility Name') // Replace with actual facility name logic
          .get();
      return snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null)).toList();
    } catch (e) {
      print("Error fetching facility staff list: $e");
      return [];
    }
  }

  // Supervisor Operations
  Stream<List<String?>> getSupervisorStream(String department, String state) {
    return _firestore.collection(staffCollection)
        .where('department', isEqualTo: department)
        .where('state', isEqualTo: state)
        .where('designation', isEqualTo: 'Supervisor') // Assuming supervisors have 'Supervisor' designation
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FacilityStaffModel.fromFirestore(doc,null).name).toList());
  }

  Future<List<String?>> getSupervisorEmailFromFirestore(String department, String supervisorName) async {
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
    // notifyHelper = NotifyHelper();
    // notifyHelper.initializeNotification();
    // notifyHelper.requestIOSPermissions();
    //_taskController.getTasks();

    _initializeAsync(); // Initialize controllers, fetch username and load reports.
    _loadStaffList(); // Load staff list for reviewer dropdown

    _monthlyOptions = _generateMonthlyOptions(); // Generate monthly options for dropdown.
    _updateReportPeriodOptions(_selectedReportType); // Set initial report period options.

    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        _isLoading = false; // Hide loading indicator after 5 seconds (simulated loading).
      });
    });
  }


  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks when the widget is disposed.
    for (var watcher in _reportWatchers) {
      watcher.cancel();
    }
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    try {
      final List<FacilityStaffModel> staff =
      await _firestoreService.getFacilityListForSpecificFacility(); // Replace with your FirestoreService method
      setState(() {
        _staffList = staff;
        _isLoadingStaffList = false;
      });
    } catch (error) {
      print('Error loading staff list: $error');
      setState(() {
        _isLoadingStaffList = false;
      });
    }
  }


  // Function to handle media picking (image or video)
  Future<void> _handleMedia(ImageSource source, {bool isVideo = false, String? reportType, Task? task}) async {
    final XFile? pickedFile = isVideo
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source);

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
              child: isVideo
                  ? AspectRatio(
                aspectRatio: 1,
                child: Container(
                    color: Colors.black, // Placeholder for video thumbnail
                    child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
                ),
              )
                  : Image.file(File(attachmentPath), fit: BoxFit.cover),
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
                      Text('Change', style: TextStyle(fontSize: 10, color: Colors.blue[700])),
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
        : await _picker.pickImage(source: source);

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
    await _loadBioDataForSupervisor(); // Load bio data and supervisors
    await _initializeControllers(); // Initialize all TextEditingControllers.
    await _fetchUsername(); // Fetch current username.
    await _loadReportsForSelectedDate(); // Load reports from Firestore for the selected reporting date.
    await _loadTasksForSelectedDate(); // Load tasks for the selected reporting date.

    print("_initializeAsync: Reports and Tasks loaded, initializing controllers");
    _initializeReportWatchers(); // Setup watchers for database changes to auto-refresh data.

    print("_initializeAsync: Controllers initialized");
  }

  Future<void> _loadBioDataForSupervisor() async {
    print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Loading bio data for supervisor"); // DEBUG
    await _loadBioData().then((_) async {
      if (bioData != null &&
          bioData!.department != null &&
          bioData!.state != null) {
        print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data loaded, loading supervisor names - Department: ${bioData!.department}, State: ${bioData!.state}"); // DEBUG
        await _loadSupervisorNames(bioData!.department!, bioData!.state!);
      } else {
        print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Bio data or department/state is missing for supervisor loading!"); // DEBUG
        if (bioData == null) {
          print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: bioData is NULL");
        } else {
          print("_DailyActivityMonitoringPageState: _loadBioDataForSupervisor: Department: ${bioData!.department}, State: ${bioData!.state}");
        }
      }
    });
  }


  Future<void> _loadSupervisorNames(String department, String state) async {
    print("_DailyActivityMonitoringPageState: _loadSupervisorNames: Fetching supervisor names for department: $department, state: $state"); // DEBUG
    supervisorNames =
    await _firestoreService.getSupervisorEmailFromFirestore(department, 'Supervisor Name'); // Adjust 'Supervisor Name' to how supervisors are identified
    print("_DailyActivityMonitoringPageState: _loadSupervisorNames: Supervisor names list after fetch: $supervisorNames"); // DEBUG
    if (supervisorNames.isNotEmpty) {
      setState(() {
        print("_DailyActivityMonitoringPageState: _loadSupervisorNames: setState called to rebuild UI with supervisor names - List is NOT empty"); // DEBUG
      }); // Trigger a rebuild to update the UI
    } else {
      // Handle the case where no supervisors are found.
      // Maybe show a message or use a default value.
      print("_DailyActivityMonitoringPageState: _loadSupervisorNames: No supervisors found for department: $department, state: $state - List is empty"); // DEBUG
    }
  }

  BioModel? bioData;

  Future<void> _loadBioData() async {
    print("_DailyActivityMonitoringPageState: _loadBioData: Loading bio data"); // DEBUG

    bioData = await _firestoreService.getBioData();
    if (bioData != null) { // Check if bioData is not null before accessing its properties
      print("_DailyActivityMonitoringPageState: _loadBioData: Bio data loaded: ${bioData!.firstName} ${bioData!.lastName}, Department: ${bioData!.department}, State: ${bioData!.state}"); // DEBUG
      setState(() {
        selectedBioFirstName = bioData!.firstName;  // Use the null-aware operator (!)
        selectedBioLastName = bioData!.lastName;    // Use the null-aware operator (!)
        selectedBioDepartment = bioData!.department; // Initialize selectedBioDepartment
        selectedBioState = bioData!.state;
        selectedBioDesignation = bioData!.designation;
        selectedBioLocation = bioData!.location;
        selectedBioStaffCategory = bioData!.staffCategory;
        selectedSignatureLink = bioData!.signatureLink;
        selectedBioEmail = bioData!.emailAddress;
        selectedBioPhone = bioData!.mobile;

        selectedFirebaseId = bioData!.firebaseAuthId;// Initialize selectedBioState
      });
    } else {
      print("_DailyActivityMonitoringPageState: _loadBioData: No bio data found!"); // DEBUG
      // Handle case where no bio data is found
      print("No bio data found!");
    }
    // try{
    //   facilitySupervisorSignature = widget.timesheetData['facilitySupervisorSignature'];
    //   caritasSupervisorSignature = widget.timesheetData['caritasSupervisorSignature'];
    // }catch(e){}
  }

  // Fetches the username of the logged-in user from Firestore database (using BioData for now).
  Future<void> _fetchUsername() async {
    print("_fetchUsername: Fetching username");
    BioModel? bio = await _firestoreService.getBioInfoWithFirebaseAuth(); // Get BioModel using Firebase Auth.
    setState(() {
      if (bio != null && bio.firstName != null && bio.lastName != null) {
        _currentUsername = "${bio.firstName!} ${bio.lastName!}"; // Construct full name.
      } else {
        _currentUsername = "Unknown User"; // Default if no bio info found.
      }
    });
    print("_fetchUsername: Username fetched: $_currentUsername");
  }

  Future<void> _loadReportsForSelectedDate() async {
    print("_loadReportsForSelectedDate: Loading reports for date: $_selectedReportingDate");
    _loadedReports.clear();
    _reportAttachments.clear(); // Clear existing attachments when loading for new date
    _isEditingReportSection.clear(); // Clear editing state when loading new reports.
    List<Report> reports = await _firestoreService.getReportsByDate(_selectedReportingDate);
    print("_loadReportsForSelectedDate: Fetched reports count: ${reports.length}");
    print("Loaded Reports: $reports");

    setState(() {
      for (var report in reports) {
        print("_loadReportsForSelectedDate: Processing report type: ${report.reportType}");
        _loadedReports[report.reportType!] = report;
        _isEditingReportSection[report.reportType!] = true; // Initialize editing section to true (read-only) when report is loaded.
        if (report.attachments != null) {
          _reportAttachments[report.reportType!] = List<String>.from(report.attachments!); // Load attachments from database
        }


        print("_loadReportsForSelectedDate: Loaded report for ${report.reportType}: ${_loadedReports[report.reportType!]}");
      }


      _updateControllerValuesFromLoadedReports();
    });
    print("_loadReportsForSelectedDate: Report loading and controller update complete.");
  }


  Future<void> _loadTasksForSelectedDate() async {
    print("_loadTasksForSelectedDate: Loading tasks for date: $_selectedReportingDate");
    List<Task> tasks = await _firestoreService.getTasksByDate(_selectedReportingDate);
    setState(() {
      _tasksForDate = tasks;
      _taskCardAttachments.clear(); // Clear existing task card attachments
      for (var task in tasks) {
        if (task.attachments != null) {
          _taskCardAttachments[task.id ?? -1] = List<String>.from(task.attachments!); // Load task attachments
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
        print("_updateControllersFromReport: Entry Key from report: ${entry.key}"); // Print entry key
        if (controllers.containsKey(entry.key)) {
          print("_updateControllersFromReport: Found controller for key: ${entry.key}");
          print("_updateControllersFromReport: Current controller value for ${entry.key}: '${controllers[entry.key]!.text}'");
          print("_updateControllersFromReport: Setting controller value for ${entry.key} to: '${entry.value}'");
          controllers[entry.key]!.text = entry.value; // Set controller text to the value from the report.
          usernames[entry.key] = entry.enteredBy; // Populate Entered By username from report
          editedUsernames[entry.key] = entry.editedBy; // Populate Edited By username from report
          print("_updateControllersFromReport: Controller value for ${entry.key} updated to: '${controllers[entry.key]!.text}'");
        } else {
          print("_updateControllersFromReport: No controller found for key: ${entry.key}");
        }
      }
      print("_updateControllersFromReport: All report entries processed for report type: $reportType");
    } else {
      print("_updateControllersFromReport: No report found or report entries are null for report type: $reportType. Resetting controllers.");
      _resetControllers(controllers, indicators, usernames, editedUsernames); // Reset controllers if no report is loaded.
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
      controllers[indicator] = TextEditingController(); // Create a new controller for each indicator.
    }
  }


  // Updates the report period options based on the selected report type (currently only "Daily").
  void _updateReportPeriodOptions(String reportType) {
    setState(() {
      _selectedReportPeriod = null; // Reset selected period.
      _selectedMonthForWeekly = null; // Reset selected month.
      _reportPeriodOptions = reportType == "Daily" ? ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"] : []; // Set options for "Daily" type.
    });
  }

  // Generates a list of last 12 months for the monthly dropdown options.
  List<String> _generateMonthlyOptions() {
    List<String> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1); // Calculate date for each month.
      months.add(DateFormat("MMMM yyyy").format(monthDate)); // Format month and year.
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
      await _firestoreService.saveReport(existingReport); // Save updated report status to Firestore
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



// Modified _buildReportSection function
// Modified _buildReportSection function
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
      onExpansionChanged: (expanded) {
        if (expanded && isReadOnlySection) {
          // Do nothing, keep it read-only
        } else if (expanded && !isReadOnlySection) {
          setState(() {
            _isEditingReportSection[reportType] = false;
          });
        } else if (!expanded) {
          setState(() {
            _isEditingReportSection[reportType] = isReadOnlySection;
          });
        }
      },
      initiallyExpanded: false,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (rest of your form fields - Reporting Date, Report Type, Dropdowns etc.)
                Row(
                  children: [
                    const Text("Reporting Date: ", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  validator: (value) => value == null ? 'Report Type is required' : null,
                  onChanged: isReadOnlySection ? null : (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedReportType = newValue;
                        _updateReportPeriodOptions(_selectedReportType);
                      });
                    }
                  },
                  disabledHint: _selectedReportType != null ? Text(_selectedReportType) : null,
                ),
                const SizedBox(height: 10),
                if (_selectedReportType == "Daily")
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Reporting Month*'),
                        value: selectedMonthForWeeklyValue,
                        items: _monthlyOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        validator: (value) => value == null ? 'Reporting Month is required' : null,
                        onChanged: isReadOnlySection ? null : (newValue) {
                          setState(() {
                            _selectedMonthForWeekly = newValue;
                          });
                        },
                        disabledHint: selectedMonthForWeeklyValue != null ? Text(selectedMonthForWeeklyValue) : (_selectedMonthForWeekly != null? Text(_selectedMonthForWeekly!) : null),
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Reporting Week*'),
                        value: selectedReportPeriodValue,
                        items: _reportPeriodOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        validator: (value) => value == null ? 'Reporting Week is required' : null,
                        onChanged: isReadOnlySection ? null : (newValue) {
                          setState(() {
                            _selectedReportPeriod = newValue;
                          });
                        },
                        disabledHint: selectedReportPeriodValue != null ? Text(selectedReportPeriodValue) : (_selectedReportPeriod != null ? Text(_selectedReportPeriod!) : null),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                _isLoadingStaffList
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<FacilityStaffModel>(
                  decoration: const InputDecoration(labelText: 'Select Reviewer*'),
                  value: _selectedReviewer,
                  hint: const Text("Select Reviewer*"),
                  validator: (value) => value == null ? 'Reviewer is required' : null,
                  onChanged: isReadOnlySection ? null : (FacilityStaffModel? newValue) {
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
                  disabledHint: _selectedReviewer != null ? Text(_selectedReviewer!.name ?? 'Reviewer Selected') : null,
                ),
                const SizedBox(height: 10),

                if (reportStatus == "Approved")
                  StreamBuilder<List<String?>>(
                    stream: bioData != null && bioData!.department != null && bioData!.state != null
                        ? _firestoreService.getSupervisorStream(bioData!.department!, bioData!.state!)
                        : Stream.value([]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        List<String?> supervisorNames = snapshot.data ?? [];
                        return DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(labelText: 'Select Supervisor'),
                          value: _selectedSupervisor,
                          items: supervisorNames.map((supervisorName) {
                            return DropdownMenuItem<String?>(
                              value: supervisorName,
                              child: Text(supervisorName ?? 'No Supervisor'),
                            );
                          }).toList(),
                          onChanged: isReadOnlySection ? null : (String? newValue) async {
                            setState(() {
                              _selectedSupervisor = newValue;
                            });
                            if (newValue != null && bioData?.department != null) {
                              List<String?> supervisorsemail = await _firestoreService.getSupervisorEmailFromFirestore(bioData!.department!, newValue);
                              setState(() {
                                _selectedSupervisorEmail = supervisorsemail[0];
                              });
                            }
                          },
                          hint: const Text('Select Supervisor'),
                          disabledHint: _selectedSupervisor != null ? Text(_selectedSupervisor!) : null,
                        );
                      }
                    },
                  ),


                const SizedBox(height: 20),
                ...indicators.map((indicator) => _buildIndicatorTextField(
                  controllers: controllers,
                  indicator: indicator,
                  usernames: usernames,
                  editedUsernames: editedUsernames,
                  isReadOnly: isReadOnlySection,
                  onEditPressed: () {
                    setState(() {
                      _isEditingReportSection[reportType] = false;
                    });
                  },
                  reportType: reportType, // Pass reportType
                )),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      // ElevatedButton(
                      //   onPressed: isReadOnlySection ?  ()  =>  setState(() {_isEditingReportSection[reportType] = false;}) : ()  {
                      //     if (formKey.currentState!.validate()) {
                      //       if (_selectedReviewer == null) {
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           const SnackBar(content: Text('Please select a Reviewer')),
                      //         );
                      //         return;
                      //       }
                      //       onSubmit();
                      //     } else {
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         const SnackBar(content: Text('Please fill all required fields marked with *')),
                      //       );
                      //     }
                      //   },
                      //   child: Text(buttonText),
                      // ),
                      const SizedBox(height: 10),
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
                                          _handleMedia(ImageSource.gallery, reportType: reportType);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text('Take a Photo'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleMedia(ImageSource.camera, reportType: reportType);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.videocam),
                                        title: const Text('Record Video'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _handleMedia(ImageSource.camera, isVideo: true, reportType: reportType);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.video_library),
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
        allFilled = false; // If any indicator is empty, allFilled is false.
      } else {
        anyFilled = true; // If at least one indicator is filled, anyFilled is true.
      }
    }

    if (allFilled) {
      return const Icon(Icons.check_circle, color: Colors.green); // All indicators filled, return green check.
    } else if (anyFilled) {
      return const Icon(Icons.check, color: Colors.orange); // Some indicators filled, return orange check.
    } else {
      return const Icon(Icons.remove); // No indicators filled, return remove icon.
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
    return const Icon(Icons.pending, color: Colors.grey); // Default to pending grey if status is unknown or not set yet.
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
  Future<void> _saveReportToIsar(String reportType, Map<String, TextEditingController> controllers, List<String> indicators, Map<String, String?> editedUsernames) async {
    if (_selectedReportType.isEmpty || _selectedReportPeriod == null || _selectedMonthForWeekly == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Report Type, Reporting Week, and Reporting Month')),
      );
      return;
    }
    if (_selectedReviewer == null) { // Reviewer validation again just in case
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer')),
      );
      return;
    }

    List<ReportEntry> reportDataEntries = []; // List to hold report entries.
    Report? existingReport = _loadedReports[reportType]; // Check if a report already exists for this type and date.
    Map<String, String?> currentEnteredBy = {}; // Map to store entered by usernames for the current save operation.
    Map<String, String?> currentEditedBy = {}; // Map to store edited by usernames for the current save operation.

    for (String indicator in indicators) {
      String? existingValue = existingReport?.reportEntries?.firstWhere((entry) => entry.key == indicator, orElse: () => ReportEntry(key: indicator, value: '')).value; // Get existing value if report exists
      String currentValue = controllers[indicator]!.text.trim(); // Get current value from controller.
      String? enteredByUser = existingReport?.reportEntries?.firstWhere((entry) => entry.key == indicator, orElse: () => ReportEntry(key: indicator, value: '')).enteredBy; // Get existing enteredBy username

      String? finalEnteredBy = enteredByUser; // Initialize with existing or null
      String? finalEditedBy = editedUsernames[indicator]; // Initialize with current edited username

      // Logic to determine Entered By and Edited By usernames based on changes
      if (currentValue.isNotEmpty && (existingValue == null || existingValue.isEmpty) ) {
        finalEnteredBy = _currentUsername; // Set Entered By only if value is newly entered and was empty
        finalEditedBy = null; // Reset edited by if newly entered
      } else if (currentValue.isNotEmpty && currentValue != existingValue) {
        finalEditedBy = _currentUsername; // Set Edited By if value is changed
        finalEnteredBy = enteredByUser; // Keep original entered by, if available
        if (finalEnteredBy == null || finalEnteredBy.isEmpty) {
          finalEnteredBy = _currentUsername; //If original enteredBy is missing, use current user as enteredBy as well for edit case
        }
      } else {
        if(existingValue != null && existingValue.isNotEmpty){
          finalEnteredBy = enteredByUser; // Retain existing enteredBy if no changes
          finalEditedBy = editedUsernames[indicator]; // Retain existing editedBy if no changes
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
          reviewedBy: _selectedReviewer?.name, // Save selected reviewer name to each entry
          reviewStatus: "Pending", // Set review status to pending for each entry
        ),
      );
      currentEnteredBy[indicator] = finalEnteredBy; // Update current entered by map
      currentEditedBy[indicator] = finalEditedBy; // Update current edited by map
    }

    final report = Report(
      reportType: reportType,
      date: _selectedReportingDate,
      reportingWeek: _selectedReportPeriod!,
      reportingMonth: _selectedMonthForWeekly!,
      reportEntries: reportDataEntries,
      isSynced:false,
      reportStatus:"Pending", // Default reportStatus is Pending when saved
      attachments: _reportAttachments[reportType] ?? [], // Save attachments here
    );


    try {
      if (existingReport != null) {
        report.id = existingReport.id; // Keep the ID of the existing report for update
        report.reportStatus = existingReport.reportStatus; // Retain existing reportStatus on update
        await _firestoreService.saveReport(report); // Update the existing report
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${titleCase(reportType.replaceAll('_', ' '))} Report updated successfully!')),
        );
      } else {
        await _firestoreService.saveReport(report); // Save new report in Firestore.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${titleCase(reportType.replaceAll('_', ' '))} Report saved successfully!')),
        );
      }

      setState(() {
        // Update usernames maps to reflect saved EnteredBy and EditedBy in UI
        if(reportType == "tb_report") tbReportUsernames = currentEnteredBy; tbReportEditedUsernames = currentEditedBy;
        if(reportType == "vl_report") vlReportUsernames = currentEnteredBy; vlReportEditedUsernames = currentEditedBy;
        if(reportType == "pharmacy_report") pharmTechReportUsernames = currentEnteredBy; pharmTechReportEditedUsernames = currentEditedBy;
        if(reportType == "tracking_report") trackingAssistantReportUsernames = currentEnteredBy; trackingAssistantReportEditedUsernames = currentEditedBy;
        if(reportType == "art_nurse_report") artNurseReportUsernames = currentEnteredBy; artNurseReportEditedUsernames = currentEditedBy;
        if(reportType == "hts_report") htsReportUsernames = currentEnteredBy; htsReportEditedUsernames = currentEditedBy;
        if(reportType == "si_report") siReportUsernames = currentEnteredBy; siReportEditedUsernames = currentEditedBy;

        _isEditingReportSection[reportType] = true; // Lock inputs after saving, switch to read-only mode.
        _loadReportsForSelectedDate(); // Refresh the loaded reports after saving to reflect changes immediately.
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
      controllers[indicator]!.clear(); // Clear the text in the controller.
      usernames[indicator] = null; // Clear entered username.
      editedUsernames[indicator] = null; // Clear edited username.
    }
    setState(() {}); // Trigger UI refresh.
  }

  // Initializes database watchers using StreamSubscriptions to listen for changes in reports for the selected date.
  void _initializeReportWatchers() {
    _reportWatchers.clear(); // Clear existing watchers before re-initializing to avoid duplicates.

    // Watcher for TB Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "tb_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("TB Report"); // Show dialog when TB report changes.
      _loadReportsForSelectedDate(); // Refresh data to reflect changes.
    }));

    // Watcher for VL Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "vl_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("VL Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for Pharmacy Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "pharmacy_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("Pharmacy Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for Tracking Assistant Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "tracking_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("Tracking Assistant Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for ART Nurse Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "art_nurse_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("ART Nurse Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for HTS Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "hts_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
        .snapshots()
        .listen((_) {
      _showDatabaseChangeDialog("HTS Report");
      _loadReportsForSelectedDate();
    }));

    // Watcher for SI Report
    _reportWatchers.add(_firestoreService._firestore.collection(FirestoreService().reportsCollection)
        .where('reportType', isEqualTo: "si_report")
        .where('date', isEqualTo: DateTime(_selectedReportingDate.year, _selectedReportingDate.month, _selectedReportingDate.day))
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
                Navigator.of(context).pop(); // Close the dialog.
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
                Navigator.of(context).pop(); // Close the dialog.
              },
            ),
          ],
        );
      },
    );
  }


  // Save functions for each report type, calling _saveReportToIsar with correct parameters.
  Future<void> _saveHtsReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for HTS Report')),
      );
      return;
    }
    await _saveReportToIsar("hts_report", htsReportControllers, htsReportIndicators, htsReportEditedUsernames);
  }

  Future<void> _saveArtNurseReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for ART Nurse Report')),
      );
      return;
    }
    await _saveReportToIsar("art_nurse_report", artNurseReportControllers, artNurseReportIndicators, artNurseReportEditedUsernames);
  }

  Future<void> _saveTrackingAssistantReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for Tracking Assistant Report')),
      );
      return;
    }
    await _saveReportToIsar("tracking_report", trackingAssistantReportControllers, trackingAssistantReportIndicators, trackingAssistantReportEditedUsernames);
  }

  Future<void> _saveTbReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for TB Report')),
      );
      return;
    }
    await _saveReportToIsar("tb_report", tbReportControllers, tbReportIndicators, tbReportEditedUsernames);
  }

  Future<void> _saveVlReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for VL Report')),
      );
      return;
    }
    await _saveReportToIsar("vl_report", vlReportControllers, vlReportIndicators, vlReportEditedUsernames);
  }

  Future<void> _savePharmacyReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for Pharmacy Report')),
      );
      return;
    }
    await _saveReportToIsar("pharmacy_report", pharmTechReportControllers, pharmTechReportIndicators, pharmTechReportEditedUsernames);
  }

  Future<void> _saveSiReport() async {
    if (_selectedReviewer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Reviewer for SI Report')),
      );
      return;
    }
    await _saveReportToIsar("si_report", siReportControllers, siReportIndicators, siReportEditedUsernames);
  }


  // AppBar for the page.
  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Text(
        "Activity Monitoring",
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
                            _loadTasksForSelectedDate(); // Load tasks for the new date
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
                _loadTasksForSelectedDate(); // Load tasks for the new date
                _initializeReportWatchers();
              });
            },
          ),
        ],
      ),
    );
  }

  _addTaskBar() {
    return Container( // _addTaskBar is now just an empty container as its content is moved to _addDateBar
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20),
      child: const SizedBox.shrink(), // To keep the margin but not display anything
    );
  }

  _showAddTaskBottomSheet(BuildContext context, {Task? taskToEdit}) {
    bool isEditing = taskToEdit != null;
    if (isEditing) {
      _taskTitleController.text = taskToEdit.taskTitle ?? '';
      _taskDescriptionController.text = taskToEdit.taskDescription ?? '';
      _taskBottomSheetAttachments = _taskCardAttachments[taskToEdit.id ?? -1] ?? []; // Load existing attachments for edit
      _taskBeingEdited = taskToEdit;
    } else {
      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _taskBottomSheetAttachments = []; // Clear attachments for new task
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
              // "Report Reviewed By" Dropdown
              Row(
                children: [
                  const Text("Other Activities To Be Reviewed By: ", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  _isLoadingStaffList
                      ? const CircularProgressIndicator() // Show loading indicator
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
              // Attachment Button in Task Bottom Sheet
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
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Take a Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.videocam),
                                  title: const Text('Record Video'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handleMedia(ImageSource.camera, isVideo: true);
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
              // Attachment Grid in Task Bottom Sheet
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


  _addTaskToIsar({bool isEditing = false}) async {
    String title = _taskTitleController.text;
    String description = _taskDescriptionController.text;

    if (title.isNotEmpty && description.isNotEmpty) {
      Task task;
      if (isEditing && _taskBeingEdited != null) {
        task = _taskBeingEdited!
          ..taskDescription = description
          ..isSynced = false
          ..taskStatus = _taskBeingEdited!.taskStatus ?? "Pending"
          ..attachments = _taskCardAttachments[_taskBeingEdited!.id ?? -1] ?? []; // Save attachments for edited task

        // For Firestore update, you'd typically need the Firestore document ID.
        // If you retrieve tasks with Firestore document IDs and store them, you can use that ID for update.
        // For now, since Task model doesn't store Firestore ID and saveTask is designed for add,
        // we'll treat edit as delete and re-add (simplification, consider better ID management for real update).

        if (_taskBeingEdited!.id != null) { // Assuming _taskBeingEdited.id holds Firestore document ID if editing
          await _firestoreService.deleteTask(_taskBeingEdited!.id.toString()); // Delete existing task
        }
        Task newTask = Task() // Create new Task object with updated info
          ..date = _selectedReportingDate
          ..taskTitle = title
          ..taskDescription = description
          ..isSynced = false
          ..taskStatus = "Pending"
          ..attachments = _taskCardAttachments[_taskBeingEdited!.id ?? -1] ?? [];

        await _firestoreService.saveTask(newTask); // Re-add as new task
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
          ..attachments = _taskBottomSheetAttachments; // Save attachments for new task

        await _firestoreService.saveTask(newTask);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!')),
        );
      }

      // Save attachments to _taskCardAttachments after task is saved/updated
      Task? savedTask = await _firestoreService.getTaskByTitleAndDate(title, _selectedReportingDate); // Assuming you have a method to get task by title and date
      if (savedTask != null) {
        _taskCardAttachments[savedTask.id ?? -1] = List.from(_taskBottomSheetAttachments); // Copy attachments
        _taskBottomSheetAttachments.clear(); // Clear bottom sheet attachments
      }


      _taskTitleController.clear();
      _taskDescriptionController.clear();
      _taskBeingEdited = null;
      _loadTasksForSelectedDate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both task title and description')),
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
            // Attachment Grid in Task Card
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
    return const Icon(Icons.help_outline); // Default icon if status is unknown
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
              onPressed: () => Navigator.of(context).pop(false), // Cancel delete
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirm delete
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await _firestoreService.deleteTask(task.id.toString()); // Pass Firestore document ID as string
      _loadTasksForSelectedDate(); // Refresh task list
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
    // print("_DailyActivityMonitoringPageState: build: Building UI, supervisorNames: $supervisorNames"); // DEBUG
    return Scaffold(
      drawer: drawer(context,),
      appBar: _appBar(),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator()) // Show loading indicator while loading.
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // _addActivityBar(), // No longer used
                  _addTaskBar(), // Using _addTaskBar as Reporting Date section - now empty
                  const SizedBox(height: 10),
                  _addDateBar(), // Date picker timeline and date selection
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
                  _buildReportSection( // Build HTS Report section.
                    formKey: _htsFormKey,
                    title: 'HTS Report',
                    indicators: htsReportIndicators,
                    controllers: htsReportControllers, // Pass htsReportControllers
                    usernames: htsReportUsernames,
                    editedUsernames: htsReportEditedUsernames, // Pass editedUsernames map
                    reportType: "hts_report",
                    onSubmit: _saveHtsReport,
                    selectedReportPeriodValue: _loadedReports["hts_report"]?.reportingWeek, // Populate from loaded report if exists
                    selectedMonthForWeeklyValue: _loadedReports["hts_report"]?.reportingMonth, // Populate from loaded report if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build ART Nurse Report section.
                    formKey: _artNurseFormKey,
                    title: 'ART Nurse Report',
                    indicators: artNurseReportIndicators,
                    controllers: artNurseReportControllers, // Pass artNurseReportControllers
                    usernames: artNurseReportUsernames,
                    editedUsernames: artNurseReportEditedUsernames, // Pass editedUsernames map
                    reportType: "art_nurse_report",
                    onSubmit: _saveArtNurseReport,
                    selectedReportPeriodValue: _loadedReports["art_nurse_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["art_nurse_report"]?.reportingMonth, // Populate if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build Tracking Assistant Report section.
                    formKey: _trackingAssistantFormKey,
                    title: 'Tracking Assistant Report',
                    indicators: trackingAssistantReportIndicators,
                    controllers: trackingAssistantReportControllers, // Pass trackingAssistantReportControllers
                    usernames: trackingAssistantReportUsernames,
                    editedUsernames: trackingAssistantReportEditedUsernames, // Pass editedUsernames map
                    reportType: "tracking_report",
                    onSubmit: _saveTrackingAssistantReport,
                    selectedReportPeriodValue: _loadedReports["tracking_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["tracking_report"]?.reportingMonth, // Populate if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build TB Report section.
                    formKey: _tbFormKey,
                    title: 'TB Report',
                    indicators: tbReportIndicators,
                    controllers: tbReportControllers, // Pass tbReportControllers
                    usernames: tbReportUsernames,
                    editedUsernames: tbReportEditedUsernames, // Pass editedUsernames map
                    reportType: "tb_report",
                    onSubmit: _saveTbReport,
                    selectedReportPeriodValue: _loadedReports["tb_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["tb_report"]?.reportingMonth, // Populate if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build VL Report section.
                    formKey: _vlFormKey,
                    title: 'VL Report',
                    indicators: vlReportIndicators,
                    controllers: vlReportControllers, // Pass vlReportControllers
                    usernames: vlReportUsernames,
                    editedUsernames: vlReportEditedUsernames, // Pass editedUsernames map
                    reportType: "vl_report",
                    onSubmit: _saveVlReport,
                    selectedReportPeriodValue: _loadedReports["vl_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["vl_report"]?.reportingMonth, // Populate if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build Pharmacy Report section.
                    formKey: _pharmacyFormKey,
                    title: 'Pharmacy Report',
                    indicators: pharmTechReportIndicators,
                    controllers: pharmTechReportControllers, // Pass pharmTechReportControllers
                    usernames: pharmTechReportUsernames,
                    editedUsernames: pharmTechReportEditedUsernames, // Pass editedUsernames map
                    reportType: "pharmacy_report",
                    onSubmit: _savePharmacyReport,
                    selectedReportPeriodValue: _loadedReports["pharmacy_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["pharmacy_report"]?.reportingMonth, // Populate if exists
                  ),
                  const SizedBox(height: 20),
                  _buildReportSection( // Build SI Report section.
                    formKey: _siFormKey,
                    title: 'SI Report',
                    indicators: siReportIndicators,
                    controllers: siReportControllers, // Pass siReportControllers
                    usernames: siReportUsernames,
                    editedUsernames: siReportEditedUsernames, // Pass editedUsernames map
                    reportType: "si_report",
                    onSubmit: _saveSiReport,
                    selectedReportPeriodValue: _loadedReports["si_report"]?.reportingWeek, // Populate if exists
                    selectedMonthForWeeklyValue: _loadedReports["si_report"]?.reportingMonth, // Populate if exists
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
                  //
                  // const SizedBox(height: 20), // Add some space at the bottom
                  // Row(
                  //   children: [
                  //
                  //     Expanded(
                  //       child: _isLoadingStaffList
                  //           ? const CircularProgressIndicator() // Show loading indicator
                  //           : DropdownButton<FacilityStaffModel>(
                  //         value: _selectedReviewer,
                  //         hint: const Text("Select Reviewer"),
                  //         onChanged: (FacilityStaffModel? newValue) {
                  //           setState(() {
                  //             _selectedReviewer = newValue;
                  //           });
                  //         },
                  //         items: _staffList.map<DropdownMenuItem<FacilityStaffModel>>((FacilityStaffModel staff) {
                  //           return DropdownMenuItem<FacilityStaffModel>(
                  //             value: staff,
                  //             child: Text(staff.name ?? 'Unnamed Staff'),
                  //           );
                  //         }).toList(),
                  //       ),
                  //     ),
                  //
                  //     const SizedBox(width: 20),
                  //
                  //     ElevatedButton(
                  //       onPressed: _submitActivityToSupervisor,
                  //       child: const Text("Report Reviewed by"),
                  //     ),
                  //   ],
                  // ),



                  const SizedBox(height: 20), // Add some space at the bottom
                  Row(
                    children: [

                      Expanded(
                        child: StreamBuilder<DocumentSnapshot>(
                          // Stream the supervisor signature
                          stream: FirebaseFirestore.instance
                              .collection("Staff")
                              .doc(
                              selectedFirebaseId) // Replace with how you get the staff document ID
                              .collection("TimeSheets")
                              .doc(
                              DateFormat('MMMM_yyyy').format(
                                  DateTime.now())) // Replace monthYear with the timesheet document ID
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData &&
                                snapshot.data!.exists) {
                              final data = snapshot.data!
                                  .data() as Map<
                                  String,
                                  dynamic>;

                              final caritasSupervisor = data['caritasSupervisor']; // Assuming this stores the image URL
                              //final caritasSupervisorDate = data['date']; // Assuming you store the date

                              if (caritasSupervisor == null) {
                                // caritasSupervisorSignature is a URL/path to the image
                                return StreamBuilder<
                                    List<String?>>(
                                  stream: bioData != null &&
                                      bioData!.department !=
                                          null &&
                                      bioData!.state != null
                                      ? _firestoreService
                                      .getSupervisorStream(
                                    bioData!.department!,
                                    bioData!.state!,
                                  )
                                      : Stream.value([]),
                                  builder: (context,
                                      snapshot) {
                                    if (snapshot
                                        .connectionState ==
                                        ConnectionState
                                            .waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    } else
                                    if (snapshot.hasError) {
                                      return Text(
                                          'Error: ${snapshot
                                              .error}');
                                    } else {
                                      List<
                                          String?> supervisorNames = snapshot
                                          .data ?? [];

                                      return SizedBox(
                                        width: double
                                            .infinity,
                                        // Ensures the dropdown fits the container
                                        child: DropdownButton<
                                            String?>(
                                          isExpanded: true,
                                          // Allows the dropdown to fit the available width
                                          value: selectedSupervisor,
                                          // Use the state variable here!!!
                                          items: supervisorNames
                                              .map((
                                              supervisorName) {
                                            return DropdownMenuItem<
                                                String?>(
                                              value: supervisorName,
                                              child: Text(
                                                  supervisorName ??
                                                      'No Supervisor',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight
                                                          .bold)),
                                            );
                                          }).toList(),
                                          onChanged: (
                                              String? newValue) async {
                                            setState(() {
                                              selectedSupervisor =
                                                  newValue;
                                            });
                                            print(
                                                "Selected Supervisor: $newValue");

                                            List<
                                                String?> supervisorsemail = await _firestoreService
                                                .getSupervisorEmailFromFirestore(
                                                bioData!
                                                    .department!,
                                                newValue!);


                                            setState(() {
                                              _selectedSupervisorEmail =
                                              supervisorsemail[0];
                                            });
                                            print(
                                                _selectedSupervisorEmail);
                                          },
                                          hint: const Text(
                                              'Select Supervisor'),
                                        ),
                                      );
                                    }
                                  },
                                );
                              } else {
                                return Text(
                                    "$caritasSupervisor");
                              }
                            } else {
                              return StreamBuilder<
                                  List<String?>>(
                                stream: bioData != null &&
                                    bioData!.department !=
                                        null &&
                                    bioData!.state != null
                                    ? _firestoreService
                                    .getSupervisorStream(
                                  bioData!.department!,
                                  bioData!.state!,
                                )
                                    : Stream.value([]),
                                builder: (context, snapshot) {
                                  if (snapshot
                                      .connectionState ==
                                      ConnectionState
                                          .waiting) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else
                                  if (snapshot.hasError) {
                                    return Text(
                                        'Error: ${snapshot
                                            .error}');
                                  } else {
                                    List<
                                        String?> supervisorNames = snapshot
                                        .data ?? [];

                                    return SizedBox(
                                      width: double.infinity,
                                      // Ensures the dropdown fits the container
                                      child: DropdownButton<
                                          String?>(
                                        isExpanded: true,
                                        // Allows the dropdown to fit the available width
                                        value: selectedSupervisor,
                                        // Use the state variable here!!!
                                        items: supervisorNames
                                            .map((
                                            supervisorName) {
                                          return DropdownMenuItem<
                                              String?>(
                                            value: supervisorName,
                                            child: Text(
                                                supervisorName ??
                                                    'No Supervisor'),
                                          );
                                        }).toList(),
                                        onChanged: (
                                            String? newValue) async {
                                          setState(() {
                                            selectedSupervisor =
                                                newValue;
                                          });
                                          print(
                                              "Selected Supervisor: $newValue");

                                          List<
                                              String?> supervisorsemail = await _firestoreService
                                              .getSupervisorEmailFromFirestore(
                                              bioData!
                                                  .department!,
                                              newValue!);


                                          setState(() {
                                            _selectedSupervisorEmail =
                                            supervisorsemail[0];
                                          });
                                          print(
                                              _selectedSupervisorEmail);
                                        },
                                        hint: const Text(
                                            'Select Supervisor'),
                                      ),
                                    );
                                  }
                                },
                              );
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 20),

                      ElevatedButton(
                        onPressed: _submitActivityToSupervisor,
                        child: const Text("Submit Activity Report to Supervisor"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100), // Add some space at the bottom

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
    if (_selectedCaritasSupervisor == null || _selectedCaritasSupervisor!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a CARITAS Supervisor')),
      );
      return;
    }

    // Fetch unsynced reports and tasks
    List<Report> unsyncedReports = await _firestoreService.getUnsyncedReports();
    List<Task> unsyncedTasks = await _firestoreService.getUnsyncedTasks();

    // Simulate Firebase push and update isSynced status
    for (Report report in unsyncedReports) {
      print("Pushing Report to Firebase: ${report.reportType} for date ${report.date}");
      await _firestoreService.pushReportToFirebase(report); // Uncomment to actually push to Firebase
      await _firestoreService.updateReportSyncStatus(report.id ?? '', true);
    }

    for (Task task in unsyncedTasks) {
      print("Pushing Task to Firebase: ${task.taskTitle} for date ${task.date}");
      await _firestoreService.pushTaskToFirebase(task); // Uncomment to actually push to Firebase
      await _firestoreService.updateTaskSyncStatus(task.id.toString(), true); // Pass task.id as String
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity submitted to supervisor!')),
    );

    // Refresh data to reflect changes in UI (isSynced status won't be directly shown in this UI, but good practice)
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
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),
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