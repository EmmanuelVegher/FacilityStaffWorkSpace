import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QRVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> generateQRData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    final date = DateFormat('dd-MMMM-yyyy').format(now);

    // Get current user's attendance data
    final userId = user.uid;
    final attendanceDoc = await _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date)
        .get();

    String clockInTime = "--/--";
    String clockOutTime = "--/--";
    String clockInLocation = "";
    String clockOutLocation = "";

    if (attendanceDoc.exists) {
      final data = attendanceDoc.data();
      clockInTime = data?['clockIn'] ?? "--/--";
      clockOutTime = data?['clockOut'] ?? "--/--";
      clockInLocation = data?['clockInLocation'] ?? "";
      clockOutLocation = data?['clockOutLocation'] ?? "";
    }

    // Get user designation from profile
    final userDoc = await _firestore.collection('Staff').doc(userId).get();
    final designation = userDoc.data()?['designation'] ?? 'Staff';

    final qrData = {
      "userId": user.uid,
      "fullName": user.displayName ?? "Unknown User",
      "firstName": user.displayName?.split(' ').first ?? "Unknown",
      "lastName": user.displayName?.split(' ').last ?? "User",
      "designation": designation,
      "attendanceData": {
        "date": date,
        "clockInTime": clockInTime,
        "clockOutTime": clockOutTime,
        "clockInLocation": clockInLocation,
        "clockOutLocation": clockOutLocation
      },
      "uuid": _uuid.v4(),
      "timestamp": now.millisecondsSinceEpoch
    };

    return jsonEncode(qrData);
  }

  Future<Map<String, dynamic>> processQRVerification(String qrData) async {
    try {
      final now = DateTime.now();
      final decodedData = jsonDecode(qrData) as Map<String, dynamic>;

      // Validate QR code structure
      if (!_isValidQRStructure(decodedData)) {
        return {'success': false, 'message': 'Invalid QR code format'};
      }

      // Check expiry (30 seconds)
      // Check expiry (30 seconds)
      DateTime qrTime;
      final timestampRaw = decodedData['timestamp'];
      if (timestampRaw is int) {
        qrTime = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
      } else if (timestampRaw is String) {
        qrTime = DateTime.parse(timestampRaw);
      } else {
        return {'success': false, 'message': 'Invalid timestamp format'};
      }
      
      final isSupervisor = decodedData['type'] == 'supervisor_verification';
      final expirySeconds = isSupervisor ? 300 : 30; // 5 mins for supervisor, 30s for colleague

      if (now.difference(qrTime).inSeconds > expirySeconds) {
        return {'success': false, 'message': 'QR code has expired'};
      }

      // Check date matches today (only for colleague verification which has attendanceData)
      if (decodedData.containsKey('attendanceData')) {
        final qrDate = decodedData['attendanceData']['date'] as String;
        final today = DateFormat('dd-MMMM-yyyy').format(now);
        if (qrDate != today) {
          return {'success': false, 'message': 'QR code is not for today'};
        }
      }

      // Prevent self-verification
      final scannerUserId = _auth.currentUser?.uid;
      final targetUserId = decodedData['userId'] as String;

      if (scannerUserId == targetUserId) {
        return {'success': false, 'message': 'Cannot verify your own QR code'};
      }

      // Check if already verified today
      final alreadyVerified =
          await _hasAlreadyVerifiedToday(scannerUserId!, targetUserId);
      if (alreadyVerified) {
        return {
          'success': false,
          'message': 'Already verified this person today'
        };
      }

      // Perform mutual verification
      await _performMutualVerification(
          scannerUserId, targetUserId, decodedData);

      return {'success': true, 'message': 'Verification successful!'};
    } catch (e) {
      return {'success': false, 'message': 'Error processing QR code: $e'};
    }
  }

  bool _isValidQRStructure(Map<String, dynamic> data) {
    final isSupervisor = data['type'] == 'supervisor_verification';
    
    if (isSupervisor) {
      return data.containsKey('userId') &&
          data.containsKey('fullName') &&
          data.containsKey('timestamp');
    }

    return data.containsKey('userId') &&
        data.containsKey('fullName') &&
        data.containsKey('attendanceData') &&
        data.containsKey('timestamp') &&
        data.containsKey('uuid');
  }

  Future<bool> _hasAlreadyVerifiedToday(
      String scannerUserId, String targetUserId) async {
    final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());

    // Check scanner's record
    final scannerDoc = await _firestore
        .collection('Staff')
        .doc(scannerUserId)
        .collection('Record')
        .doc(today)
        .get();

    if (scannerDoc.exists) {
      final verifiedIds =
          List<String>.from(scannerDoc.data()?['verifiedByUserIds'] ?? []);
      if (verifiedIds.contains(targetUserId)) {
        return true;
      }
    }

    // Check target's record
    final targetDoc = await _firestore
        .collection('Staff')
        .doc(targetUserId)
        .collection('Record')
        .doc(today)
        .get();

    if (targetDoc.exists) {
      final verifiedIds =
          List<String>.from(targetDoc.data()?['verifiedByUserIds'] ?? []);
      if (verifiedIds.contains(scannerUserId)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _performMutualVerification(String scannerUserId,
      String targetUserId, Map<String, dynamic> qrData) async {
    final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
    final now = DateTime.now();
    final timestamp = DateFormat('dd-MMMM-yyyy \'at\' hh:mm a').format(now);

    // Get user details
    final scannerDoc =
        await _firestore.collection('Staff').doc(scannerUserId).get();
    final targetDoc =
        await _firestore.collection('Staff').doc(targetUserId).get();

    final scannerName = scannerDoc.data()?['firstName'] +
            ' ' +
            scannerDoc.data()?['lastName'] ??
        'Unknown';
    final targetName = qrData['fullName'] as String;

    final scannerVerificationName = '$scannerName $timestamp';
    final targetVerificationName = '$targetName $timestamp';

    // Update scanner's record
    await _updateVerificationRecord(
        scannerUserId, today, targetUserId, scannerVerificationName);

    // Update target's record
    await _updateVerificationRecord(
        targetUserId, today, scannerUserId, targetVerificationName);

    // Create verification request record
    await _createVerificationRequest(
        scannerUserId, targetUserId, scannerName, targetName, now);

    // Save pending verification request for sync
    final pendingRequest = {
      'scannerUserId': scannerUserId,
      'scannerUserName': scannerVerificationName,
      'targetUserId': targetUserId,
      'targetUserName': targetVerificationName,
      'timestamp': now.toIso8601String(),
      'date': today,
      'latitude': 0.0,
      'longitude': 0.0,
      'locationName': 'Office Location',
      'status': 'pending'
    };

    await savePendingVerificationRequest(pendingRequest);
  }

  Future<void> _updateVerificationRecord(String userId, String date,
      String verifiedUserId, String verifiedUserName) async {
    final docRef = _firestore
        .collection('Staff')
        .doc(userId)
        .collection('Record')
        .doc(date);

    final doc = await docRef.get();
    if (doc.exists) {
      final currentIds =
          List<String>.from(doc.data()?['verifiedByUserIds'] ?? []);
      final currentNames =
          List<String>.from(doc.data()?['verifiedByUserNames'] ?? []);
      final currentCount =
          (doc.data()?['verificationCount'] as num?)?.toInt() ?? 0;

      currentIds.add(verifiedUserId);
      currentNames.add(verifiedUserName);

      await docRef.update({
        'verifiedByUserIds': currentIds,
        'verifiedByUserNames': currentNames,
        'verificationCount': currentCount + 1,
      });
    }
  }

  Future<void> _createVerificationRequest(
      String scannerUserId,
      String targetUserId,
      String scannerName,
      String targetName,
      DateTime timestamp) async {
    final verificationData = {
      'scannerUserId': scannerUserId,
      'scannerUserName':
          '$scannerName ${DateFormat('dd-MMMM-yyyy \'at\' hh:mm a').format(timestamp)}',
      'targetUserId': targetUserId,
      'targetUserName':
          '$targetName ${DateFormat('dd-MMMM-yyyy \'at\' hh:mm a').format(timestamp)}',
      'timestamp': timestamp.toIso8601String(),
      'date': DateFormat('dd-MMMM-yyyy').format(timestamp),
      'latitude': 0.0, // Would be actual location
      'longitude': 0.0,
      'locationName': 'Office Location',
      'status': 'completed'
    };

    await _firestore
        .collection('verificationRequests')
        .doc(targetUserId)
        .set(verificationData);
  }

  // Method to sync pending verifications when online
  Future<void> syncPendingVerifications() async {
    // Implementation for offline sync would go here
    // This would process any queued verifications from local storage
    // For now, this is a placeholder
  }

  // Method to save pending verification request
  Future<void> savePendingVerificationRequest(
      Map<String, dynamic> requestData) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore
          .collection('Staff')
          .doc(userId)
          .collection('PendingVerifications')
          .add(requestData);
    }
  }

  // Check if user has minimum required verifications for the day
  Future<bool> hasMinimumVerifications(String userId, String date,
      {int minimumRequired = 2}) async {
    try {
      final doc = await _firestore
          .collection('Staff')
          .doc(userId)
          .collection('Record')
          .doc(date)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final count = (data?['verificationCount'] as num?)?.toInt() ?? 0;
        return count >= minimumRequired;
      }
      return false;
    } catch (e) {
      print('Error checking verification count: $e');
      return false;
    }
  }
}
