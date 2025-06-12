// model/contact_tracked.dart
import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore Timestamp



class ContactTracked {
  Id id = Isar.autoIncrement;


  String? name;
  String? phoneNumber;
  DateTime? lastVisitDate;
  DateTime? nextVisitDate;
  String? callStatus;
  int? callDuration;
  String? state;
  String? facilityName;
  String? uniqueID;
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

  // New fields
  bool isUpdated = false; // Set to true after Firestore sync
  bool isSynced = false;  // Set to true after Firestore sync

  // Constructor - Generate UUID here
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
    // Don't initialize isUpdated/isSynced here, keep defaults
  }); // Generate a v4 UUID automatically

  // --- Factory Constructor for Firestore Data ---
  // ***** ADD THIS METHOD *****
  factory ContactTracked.fromFirestore(Map<String, dynamic> data, [String? docId]) {
    // Helper to safely convert Timestamps or null
    DateTime? toDateTime(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }
      // Handle potential String dates if necessary (though Timestamp is standard)
      // if (timestamp is String) {
      //   return DateTime.tryParse(timestamp);
      // }
      return null;
    }

    // Use docId as UUID if it exists AND is intended to be the UUID,
    // otherwise try getting 'uuid' from the data, or generate as a last resort.
//    final String objectUuid = docId ?? data['uuid'] as String? ?? Uuid().v4();

    return ContactTracked(


      // Map fields from Firestore data map
      name: data['name'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      lastVisitDate: toDateTime(data['lastVisitDate']), // Ensure key matches 'toJson'
      nextVisitDate: toDateTime(data['nextVisitDate']), // Ensure key matches 'toJson' if you save it
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
      dateTracked: toDateTime(data['dateTracked']), // Key MUST match 'toJson' output
      patientId: data['patientId'] as int?,
      dateNextVisitChanged: toDateTime(data['dateNextVisitChanged']), // Ensure key matches 'toJson'
      datePhoneNumberUpdated: toDateTime(data['datePhoneNumberUpdated']), // Ensure key matches 'toJson'
      dateAddressChanged: toDateTime(data['dateAddressChanged']), // Ensure key matches 'toJson'
      artStatus: data['artStatus'] as String?,
      dateOfTermination: toDateTime(data['dateOfTermination']), // Ensure key matches 'toJson'
      sampleCollectionDate: toDateTime(data['sampleCollectionDate']), // Ensure key matches 'toJson'
      currentViralLoad: data['currentViralLoad'] as String?,

      // Sync status flags are generally NOT read from Firestore,
      // as fetching from Firestore implies it's synced.
      // isUpdated: data['isUpdated'] ?? false, // Example if you did save them
      // isSynced: data['isSynced'] ?? true,
    );
  }
  // ***** END OF METHOD TO ADD *****


  // --- Method to convert to Map for Firestore (Existing toJson) ---
  Map<String, dynamic> toJson() {
    // Make sure the keys here exactly match the keys used in fromFirestore
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'lastVisitDate': lastVisitDate != null ? Timestamp.fromDate(lastVisitDate!) : null,
      'nextVisitDate': nextVisitDate != null ? Timestamp.fromDate(nextVisitDate!) : null, // Save if needed
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
      'dateTracked': dateTracked != null ? Timestamp.fromDate(dateTracked!) : null, // This key is crucial
      'patientId': patientId,
      'dateNextVisitChanged': dateNextVisitChanged != null ? Timestamp.fromDate(dateNextVisitChanged!) : null,
      'datePhoneNumberUpdated': datePhoneNumberUpdated != null ? Timestamp.fromDate(datePhoneNumberUpdated!) : null,
      'dateAddressChanged': dateAddressChanged != null ? Timestamp.fromDate(dateAddressChanged!) : null,
      'artStatus': artStatus,
      'dateOfTermination': dateOfTermination != null ? Timestamp.fromDate(dateOfTermination!) : null,
      'sampleCollectionDate': sampleCollectionDate != null ? Timestamp.fromDate(sampleCollectionDate!) : null,
      'currentViralLoad': currentViralLoad,

      // Decide IF you need to save these sync statuses to Firestore. Usually not necessary for reads.
      'isUpdated': isUpdated,
      'isSynced': isSynced,
      'syncedAt': isSynced ? Timestamp.now() : null, // Optional: Timestamp of sync
      'clientWriteTime': Timestamp.now(), // Add a client timestamp for debugging potentially
    };
  }
}