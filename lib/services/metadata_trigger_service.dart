// lib/services/metadata_trigger_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';

class MetadataTriggerService {
  static final _firestore = FirebaseFirestore.instance;

  // You can add more trigger methods here for other lookup tables later.

  /// Updates the 'supervisorsTimestamp' in the Metadata document.
  /// This signals to all listening apps that the supervisors list has changed
  /// and they need to perform a full re-sync.
  static Future<void> triggerSupervisorUpdate() async {
    try {
      log("Triggering supervisor data update...");
      await _firestore.collection('Metadata').doc('LookupsLastModified').set({
        'supervisorsTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge to avoid overwriting other timestamps
      log("✅ Supervisors timestamp updated successfully.");
    } catch (e) {
      log("❌ Error updating supervisors timestamp: $e");
    }
  }
}