// model/contact.dart (Web Version - No Isar)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // If using UUIDs

class Contact {
  // No Isar Id
  String uuid; // Use UUID for Firestore ID

  String? name;
  String? phoneNumber;
  String? address;
  DateTime? lastVisitDate;
  DateTime? nextVisitDate;
  String? callStatus; // Will likely be null or manually set on web
  int? callDuration; // Will likely be null on web
  String? appointmentStatus;
  bool? isUpdated; // Maybe relevant if syncing with mobile app?
  bool? isSyncedToNMRS; // Keep if NMRS sync logic remains (ideally via backend)
  int? patientId; // Keep if relevant from NMRS/CSV

  bool? isLastVisitDateUpdated; // Keep if relevant
  bool? isNextVisitDateUpdated; // Keep if relevant
  bool? isPhoneNumberUpdated; // Keep if relevant
  bool? isAddressUpdated; // Keep if relevant
  bool? isAddressSyncedToNMRS; // Keep if NMRS sync logic remains

  DateTime? dateNextVisitChanged; // Keep if relevant
  DateTime? datePhoneNumberUpdated; // Keep if relevant
  DateTime? dateAddressChanged; // Keep if relevant

  // New Fields
  String? state;
  String? facilityName;
  String? uniqueID; // Client ART ID
  String? datimCode;
  String? artStatus;
  DateTime? dateOfTermination;
  DateTime? sampleCollectionDate;
  String? currentViralLoad;

  Contact({
    String? existingUuid, // Add parameter for UUID
    this.name,
    this.phoneNumber,
    this.lastVisitDate,
    this.address,
    this.nextVisitDate,
    this.callStatus,
    this.callDuration,
    this.isAddressUpdated,
    this.isAddressSyncedToNMRS,
    this.dateNextVisitChanged,
    this.datePhoneNumberUpdated,
    this.dateAddressChanged,
    this.state,
    this.facilityName,
    this.uniqueID,
    this.datimCode,
    this.appointmentStatus,
    this.isUpdated,
    this.isSyncedToNMRS,
    this.patientId,
    this.isLastVisitDateUpdated,
    this.isNextVisitDateUpdated,
    this.isPhoneNumberUpdated,
    this.artStatus,
    this.dateOfTermination,
    this.sampleCollectionDate,
    this.currentViralLoad
  }) : uuid = existingUuid ?? const Uuid().v4(); // Initialize UUID

  // Helper to safely convert Timestamps or null
  static DateTime? _toDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  // Factory constructor from Firestore
  factory Contact.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Contact(
      existingUuid: documentId, // Use Firestore document ID as UUID
      name: data['name'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      address: data['address'] as String?,
      lastVisitDate: _toDateTime(data['lastVisitDate']),
      nextVisitDate: _toDateTime(data['nextVisitDate']),
      callStatus: data['callStatus'] as String?, // Likely null from Firestore unless set manually
      callDuration: data['callDuration'] as int?, // Likely null
      appointmentStatus: data['appointmentStatus'] as String?,
      isSyncedToNMRS: data['isSyncedToNMRS'] as bool?,
      patientId: data['patientId'] as int?,
      isLastVisitDateUpdated: data['isLastVisitDateUpdated'] as bool?,
      isNextVisitDateUpdated: data['isNextVisitDateUpdated'] as bool?,
      isPhoneNumberUpdated: data['isPhoneNumberUpdated'] as bool?,
      isAddressUpdated: data['isAddressUpdated'] as bool?,
      isAddressSyncedToNMRS: data['isAddressSyncedToNMRS'] as bool?,
      dateNextVisitChanged: _toDateTime(data['dateNextVisitChanged']),
      datePhoneNumberUpdated: _toDateTime(data['datePhoneNumberUpdated']),
      dateAddressChanged: _toDateTime(data['dateAddressChanged']),
      state: data['state'] as String?,
      facilityName: data['facilityName'] as String?,
      uniqueID: data['uniqueID'] as String?,
      datimCode: data['datimCode'] as String?,
      artStatus: data['artStatus'] as String?,
      dateOfTermination: _toDateTime(data['dateOfTermination']),
      sampleCollectionDate: _toDateTime(data['sampleCollectionDate']),
      currentViralLoad: data['currentViralLoad'] as String?,
    );
  }

  // Method to convert to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      // Don't usually save UUID field if it's the doc ID, but can if needed
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'lastVisitDate': lastVisitDate != null ? Timestamp.fromDate(lastVisitDate!) : null,
      'nextVisitDate': nextVisitDate != null ? Timestamp.fromDate(nextVisitDate!) : null,
      'callStatus': callStatus,
      'callDuration': callDuration,
      'appointmentStatus': appointmentStatus,
      'isSyncedToNMRS': isSyncedToNMRS,
      'patientId': patientId,
      'isLastVisitDateUpdated': isLastVisitDateUpdated,
      'isNextVisitDateUpdated': isNextVisitDateUpdated,
      'isPhoneNumberUpdated': isPhoneNumberUpdated,
      'isAddressUpdated': isAddressUpdated,
      'isAddressSyncedToNMRS': isAddressSyncedToNMRS,
      'dateNextVisitChanged': dateNextVisitChanged != null ? Timestamp.fromDate(dateNextVisitChanged!) : null,
      'datePhoneNumberUpdated': datePhoneNumberUpdated != null ? Timestamp.fromDate(datePhoneNumberUpdated!) : null,
      'dateAddressChanged': dateAddressChanged != null ? Timestamp.fromDate(dateAddressChanged!) : null,
      'state': state,
      'facilityName': facilityName,
      'uniqueID': uniqueID,
      'datimCode': datimCode,
      'artStatus': artStatus,
      'dateOfTermination': dateOfTermination != null ? Timestamp.fromDate(dateOfTermination!) : null,
      'sampleCollectionDate': sampleCollectionDate != null ? Timestamp.fromDate(sampleCollectionDate!) : null,
      'currentViralLoad': currentViralLoad,
      'lastModified': Timestamp.now(), // Add a timestamp for tracking
    };
  }
}