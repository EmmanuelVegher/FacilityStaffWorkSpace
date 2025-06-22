// lib/model/contact_tracked.dart
import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';


@collection // <-- ADD THIS ANNOTATION
class ContactTracked {
  Id id = Isar.autoIncrement;


  String? uuid; // <-- ADD UUID FIELD

  String? name;
  String? phoneNumber;
  DateTime? lastVisitDate;
  DateTime? nextVisitDate;
  String? callStatus;
  int? callDuration;
  String? state;
  String? facilityName;
  String? uniqueID; // ART ID
  String? datimCode;
  String? supervisorName;
  String? supervisorEmail;
  String? firebaseAuthId;
  String? trackedBy;
  String? designation;
  String? trackerFacilityLocation;
  DateTime? dateTracked;
  int? patientId;
  DateTime? dateNextVisitChanged;
  DateTime? datePhoneNumberUpdated;
  DateTime? dateAddressChanged;
  String? artStatus;
  DateTime? dateOfTermination;
  DateTime? sampleCollectionDate;
  String? currentViralLoad;

  // Sync status fields for local database management
  bool isUpdated;
  bool isSynced;
  DateTime? syncedAt;

  // Constructor - Now includes UUID generation
  ContactTracked({
    this.name,
    this.phoneNumber,
    this.lastVisitDate,
    this.nextVisitDate,
    this.callDuration,
    this.callStatus,
    this.state,
    this.facilityName,
    this.uniqueID,
    this.datimCode,
    this.trackedBy,
    this.designation,
    this.firebaseAuthId,
    this.supervisorName,
    this.supervisorEmail,
    this.trackerFacilityLocation,
    this.dateTracked,
    this.patientId,
    this.dateNextVisitChanged,
    this.datePhoneNumberUpdated,
    this.dateAddressChanged,
    this.artStatus,
    this.dateOfTermination,
    this.sampleCollectionDate,
    this.currentViralLoad,
    this.isUpdated = false,
    this.isSynced = false,
    this.syncedAt,
    this.uuid,
  }) {
    // Ensure every record has a unique ID
    uuid ??= const Uuid().v4();
  }

  // --- Factory Constructor for Firestore Data ---
  // RENAMED from 'fromFirestore' to 'fromJson' for consistency
  factory ContactTracked.fromJson(Map<String, dynamic> data) {
    // Helper to safely convert Timestamps to DateTime
    DateTime? toDateTime(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp);
      return null;
    }

    return ContactTracked(
      uuid: data['uuid'] as String?, // Read the UUID from Firestore
      name: data['name'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      lastVisitDate: toDateTime(data['lastVisitDate']),
      nextVisitDate: toDateTime(data['nextVisitDate']),
      callDuration: data['callDuration'] as int?,
      callStatus: data['callStatus'] as String?,
      state: data['state'] as String?,
      facilityName: data['facilityName'] as String?,
      uniqueID: data['uniqueID'] as String?,
      datimCode: data['datimCode'] as String?,
      trackedBy: data['trackedBy'] as String?,
      designation: data['designation'] as String?,
      firebaseAuthId: data['firebaseAuthId'] as String?,
      supervisorName: data['supervisorName'] as String?,
      supervisorEmail: data['supervisorEmail'] as String?,
      trackerFacilityLocation: data['trackerFacilityLocation'] as String?,
      dateTracked: toDateTime(data['dateTracked']),
      patientId: data['patientId'] as int?,
      dateNextVisitChanged: toDateTime(data['dateNextVisitChanged']),
      datePhoneNumberUpdated: toDateTime(data['datePhoneNumberUpdated']),
      dateAddressChanged: toDateTime(data['dateAddressChanged']),
      artStatus: data['artStatus'] as String?,
      dateOfTermination: toDateTime(data['dateOfTermination']),
      sampleCollectionDate: toDateTime(data['sampleCollectionDate']),
      currentViralLoad: data['currentViralLoad'] as String?,
      // When reading from Firestore, we can consider it synced.
      isSynced: true,
      syncedAt: toDateTime(data['syncedAt']),
    );
  }

  // --- Method to convert to Map for Firestore ---
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid, // Include the UUID when writing to Firestore
      'name': name,
      'phoneNumber': phoneNumber,
      'lastVisitDate': lastVisitDate != null ? Timestamp.fromDate(lastVisitDate!) : null,
      'nextVisitDate': nextVisitDate != null ? Timestamp.fromDate(nextVisitDate!) : null,
      'callDuration': callDuration,
      'callStatus': callStatus,
      'state': state,
      'facilityName': facilityName,
      'uniqueID': uniqueID,
      'datimCode': datimCode,
      'trackedBy': trackedBy,
      'designation': designation,
      'firebaseAuthId': firebaseAuthId,
      'supervisorName': supervisorName,
      'supervisorEmail': supervisorEmail,
      'trackerFacilityLocation': trackerFacilityLocation,
      'dateTracked': dateTracked != null ? Timestamp.fromDate(dateTracked!) : null,
      'patientId': patientId,
      'dateNextVisitChanged': dateNextVisitChanged != null ? Timestamp.fromDate(dateNextVisitChanged!) : null,
      'datePhoneNumberUpdated': datePhoneNumberUpdated != null ? Timestamp.fromDate(datePhoneNumberUpdated!) : null,
      'dateAddressChanged': dateAddressChanged != null ? Timestamp.fromDate(dateAddressChanged!) : null,
      'artStatus': artStatus,
      'dateOfTermination': dateOfTermination != null ? Timestamp.fromDate(dateOfTermination!) : null,
      'sampleCollectionDate': sampleCollectionDate != null ? Timestamp.fromDate(sampleCollectionDate!) : null,
      'currentViralLoad': currentViralLoad,
      'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : null,
    };
  }
}