// services/firestore_service.dart (New File)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/contact.dart';

class LocationModel {
  String uuid; // Use UUID for Firestore ID or use datimCode if truly unique
  String? state;
  String? lga;
  String? locationName; // Facility Name
  String? datimCode;
  String? locationType; // e.g., "State", "LGA", "Facility"

  LocationModel({
    String? existingUuid,
    this.state,
    this.lga,
    this.locationName,
    this.datimCode,
    this.locationType,
  }) : uuid = existingUuid ?? const Uuid().v4();

  // Factory constructor from Firestore
  factory LocationModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return LocationModel(
      existingUuid: documentId,
      state: data['state'] as String?,
      lga: data['lga'] as String?,
      locationName: data['locationName'] as String?,
      datimCode: data['datimCode'] as String?,
      locationType: data['locationType'] as String?,
    );
  }

  // Method to convert to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      // 'uuid': uuid, // Optional: Only save if not using doc ID as UUID
      'state': state,
      'lga': lga,
      'locationName': locationName,
      'datimCode': datimCode,
      'locationType': locationType,
      'lastModified': Timestamp.now(),
    };
  }
}

class BioInfoModel {
  String firebaseAuthId; // Use Firebase Auth UID as the document ID
  String? firstName;
  String? lastName;
  String? designation;
  String? location; // Facility Name/Location
  String? state;
  String? supervisor;
  String? supervisorEmail;
  // Add any other fields stored in the 'Staff' collection

  BioInfoModel({
    required this.firebaseAuthId,
    this.firstName,
    this.lastName,
    this.designation,
    this.location,
    this.state,
    this.supervisor,
    this.supervisorEmail,
  });

  // Factory constructor from Firestore (documentId is the firebaseAuthId)
  factory BioInfoModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return BioInfoModel(
      firebaseAuthId: documentId, // The document ID IS the auth ID
      firstName: data['firstName'] as String?,
      lastName: data['lastName'] as String?,
      designation: data['designation'] as String?,
      location: data['location'] as String?,
      state: data['state'] as String?,
      supervisor: data['supervisor'] as String?,
      supervisorEmail: data['supervisorEmail'] as String?,
      // Map other fields
    );
  }

  // Method to convert to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      // Don't save firebaseAuthId in the map if it's the document ID
      'firstName': firstName,
      'lastName': lastName,
      'designation': designation,
      'location': location,
      'state': state,
      'supervisor': supervisor,
      'supervisorEmail': supervisorEmail,
      // Add other fields
      'lastModified': Timestamp.now(),
    };
  }

  // Helper getter for full name
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Define the collection path for contacts (adjust as needed)
  final String _contactsCollectionPath = 'contacts'; // Example path

  // Fetch all contacts (Consider pagination for large datasets)
  Future<List<Contact>> getAllContacts() async {
    try {
      QuerySnapshot snapshot = await _db.collection(_contactsCollectionPath).get();
      return snapshot.docs.map((doc) =>
          Contact.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }

  // Stream all contacts (Real-time updates) - Use with StreamBuilder
  Stream<List<Contact>> streamAllContacts() {
    return _db.collection(_contactsCollectionPath)
        .orderBy('name') // Example ordering
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) =>
        Contact.fromFirestore(doc.data(), doc.id)
    ).toList());
  }


  // Add/Update a contact (uses UUID as document ID)
  Future<void> saveContact(Contact contact) async {
    try {
      await _db.collection(_contactsCollectionPath)
          .doc(contact.uuid) // Use UUID as document ID
          .set(contact.toJson(), SetOptions(merge: true)); // Use merge to update existing
    } catch (e) {
      print("Error saving contact ${contact.uuid}: $e");
      rethrow; // Re-throw to handle in UI
    }
  }

  // Save multiple contacts (using Batch Write)
  Future<void> saveAllContacts(List<Contact> contacts) async {
    if (contacts.isEmpty) return;

    WriteBatch batch = _db.batch();
    int count = 0;
    for (var contact in contacts) {
      DocumentReference docRef = _db.collection(_contactsCollectionPath).doc(contact.uuid);
      batch.set(docRef, contact.toJson(), SetOptions(merge: true)); // Use merge: true for update/insert
      count++;
      // Firestore batch limit is 500 operations
      if (count == 499) {
        await batch.commit();
        batch = _db.batch(); // Start a new batch
        count = 0;
      }
    }
    // Commit any remaining operations
    if (count > 0) {
      await batch.commit();
    }
  }


  // Delete a contact
  Future<void> deleteContact(String uuid) async {
    try {
      await _db.collection(_contactsCollectionPath).doc(uuid).delete();
    } catch (e) {
      print("Error deleting contact $uuid: $e");
      rethrow;
    }
  }

  // Clear all contacts (USE WITH EXTREME CAUTION)
  Future<void> cleanContactCollection() async {
    try {
      QuerySnapshot snapshot = await _db.collection(_contactsCollectionPath).get();
      WriteBatch batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        // Handle batch limits if necessary for very large collections
      }
      await batch.commit();
      print("Cleared collection: $_contactsCollectionPath");
    } catch (e) {
      print("Error clearing contacts collection: $e");
      rethrow;
    }
  }


  // --- Location/Bio Info Methods (Adapt from IsarService if needed) ---
  // Example: Fetching locations might now come from Firestore too
  // Example: Getting user bio info still likely uses FirebaseAuth + Firestore 'Staff' collection

  // ... Add methods for fetching LocationModel, BioInfoModel etc. from Firestore ...
  // Example:
  Future<LocationModel?> getLocationByDatimCode(String datimCode) async {
    // Assuming you have a 'locations' collection indexed by datimCode
    try {
      QuerySnapshot snapshot = await _db.collection('locations')
          .where('datimCode', isEqualTo: datimCode)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        // Need LocationModel.fromFirestore
        // return LocationModel.fromFirestore(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
        return null; // Placeholder - implement fromFirestore in LocationModel
      }
      return null;
    } catch (e) {
      print("Error fetching location by datimCode: $e");
      return null;
    }
  }

  // Get User Bio (Assuming BioInfoModel exists and has fromFirestore)
  Future<BioInfoModel?> getBioInfoWithFirebaseAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      DocumentSnapshot doc = await _db.collection('Staff').doc(user.uid).get();
      if (doc.exists) {
        // return BioInfoModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        return null; // Placeholder - implement fromFirestore in BioInfoModel
      }
      return null;
    } catch (e) {
      print("Error getting user bio: $e");
      return null;
    }
  }
}