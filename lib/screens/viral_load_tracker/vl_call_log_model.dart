// in vl_call_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class VlCallLogModel {
  final String id;
  final String? clientName;
  final String? artId;
  final String? phoneNumberCalled;
  final DateTime? callDateTime;
  final String? callStatus;
  final int? callDurationInSeconds;
  final String? trackedBy;
  final String? trackerFacility;
  final String? trackerState;
  final String? firebaseAuthId;
  final bool isSyncedToFirebase;
  final int? vlEligibleRecordId; // Assuming this might be an old field

  VlCallLogModel({
    required this.id,
    this.clientName,
    this.artId,
    this.phoneNumberCalled,
    this.callDateTime,
    this.callStatus,
    this.callDurationInSeconds,
    this.trackedBy,
    this.trackerFacility,
    this.trackerState,
    this.firebaseAuthId,
    this.isSyncedToFirebase = false,
    this.vlEligibleRecordId,
  });

  // --- THIS IS THE CRITICAL FIX ---
  // This factory can now handle both Timestamps and ISO-8601 Strings for the date.
  factory VlCallLogModel.fromMap(String id, Map<String, dynamic> data) {
    dynamic callDateValue = data['callDateTime'];
    DateTime? parsedDateTime;

    if (callDateValue is Timestamp) {
      // Best case: It's a Firestore Timestamp
      parsedDateTime = callDateValue.toDate();
    } else if (callDateValue is String) {
      // Fallback: It's a String, try to parse it
      parsedDateTime = DateTime.tryParse(callDateValue);
    }
    // If it's neither, parsedDateTime will remain null.

    return VlCallLogModel(
      id: id,
      clientName: data['clientName'] as String?,
      artId: data['artId'] as String?,
      phoneNumberCalled: data['phoneNumberCalled'] as String?,
      callDateTime: parsedDateTime, // Use the safely parsed date
      callStatus: data['callStatus'] as String?,
      callDurationInSeconds: data['callDurationInSeconds'] as int?,
      trackedBy: data['trackedBy'] as String?,
      trackerFacility: data['trackerFacility'] as String?,
      trackerState: data['trackerState'] as String?,
      firebaseAuthId: data['firebaseAuthId'] as String?,
      isSyncedToFirebase: data['isSyncedToFirebase'] as bool? ?? false,
      vlEligibleRecordId: data['vlEligibleRecordId'] as int?,
    );
  }

  // --- SEE STEP 2 FOR FIXING THIS METHOD ---
  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'artId': artId,
      'phoneNumberCalled': phoneNumberCalled,
      // IMPORTANT: Store as a Timestamp, not a String!
      'callDateTime': callDateTime, // Pass the DateTime object directly
      'callStatus': callStatus,
      'callDurationInSeconds': callDurationInSeconds,
      'trackedBy': trackedBy,
      'trackerFacility': trackerFacility,
      'trackerState': trackerState,
      'firebaseAuthId': firebaseAuthId,
      'isSyncedToFirebase': isSyncedToFirebase,
      'vlEligibleRecordId': vlEligibleRecordId,
    };
  }
}