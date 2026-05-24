import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/qr_verification_service.dart';
import 'clock_attendance.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final QRVerificationService _qrService = QRVerificationService();
  final TextEditingController _qrInputController = TextEditingController();
  bool _isScanning = false;
  int _pendingVerifications = 0;
  List<String> _verifiedBy = [];
  bool _isOnline = true;
  String? _currentUserId;
  String? _currentUserName;
  AttendanceModelFirestore? _lastAttendance;
  StreamSubscription<DocumentSnapshot>? _verificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _qrInputController.dispose();
    _verificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializePage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      _currentUserName = user.displayName ?? 'Unknown User';
    }

    await _loadLastAttendance();
    await _loadVerificationData();
    _checkInternetConnection();
    _startVerificationListener();
  }

  void _startVerificationListener() {
    if (_currentUserId != null) {
      _verificationSubscription = FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(_currentUserId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data()?['status'] == 'completed') {
          // Refresh verification data when a new verification is completed
          _loadVerificationData();
        }
      });
    }
  }

  Future<void> _loadLastAttendance() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
      final doc = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('Record')
          .doc(today)
          .get();

      if (doc.exists) {
        _lastAttendance = AttendanceModelFirestore.fromMap(doc.data()!);
      }
    }
  }

  Future<void> _loadVerificationData() async {
    // Load today's verifications from VerificationRecords sub-collection
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());

      // Load completed verifications for today from VerificationRecords
      final verificationRecords = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('VerificationRecords')
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'completed')
          .get();

      final verifiedNames = verificationRecords.docs
          .map(
              (doc) => doc.data()['verifiedByUserName'] as String? ?? 'Unknown')
          .toList();

      // Load pending verifications count from PendingVerifications
      final pendingRequests = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(userId)
          .collection('PendingVerifications')
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _verifiedBy = verifiedNames;
        _pendingVerifications = pendingRequests.docs.length;
      });
    }
  }

  void _checkInternetConnection() {
    // Simple internet check - in real app use connectivity package
    setState(() {
      _isOnline = true; // Assume online for now
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Verification'),
        backgroundColor: const Color(0xffeef444c),
        actions: [
          if (_pendingVerifications > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Badge(
                label: Text(_pendingVerifications.toString()),
                child: IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _syncPendingVerifications,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              color: Colors.orange,
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Offline Mode', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          Expanded(
            child: _isScanning ? _buildScannerView() : _buildScanOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOptions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _startScanning,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR for Verification'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showMyQRCode,
            icon: const Icon(Icons.qr_code),
            label: const Text('Show My QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 30),
          _buildVerifiedByList(),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.blue),
          const SizedBox(height: 20),
          const Text(
            'Scan QR Code',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Paste QR code data from a colleague\'s verification dialog',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue.shade50,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _qrInputController,
                  decoration: const InputDecoration(
                    labelText: 'Paste QR Code Data Here',
                    border: InputBorder.none,
                    hintText: 'Right-click and paste the QR data...',
                  ),
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _processManualQRInput,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _stopScanning,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For web compatibility, paste the QR code data from your colleague\'s "Generate QR" dialog.',
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedByList() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verified By Today:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _verifiedBy.isEmpty
              ? const Text('No verifications yet today')
              : Column(
                  children: _verifiedBy
                      .map((name) => ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text(name),
                            dense: true,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  void _startScanning() async {
    // QRView will be shown, scanning starts automatically
    setState(() {
      _isScanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _qrInputController.clear();
  }

  void _processManualQRInput() async {
    final qrData = _qrInputController.text.trim();
    if (qrData.isEmpty) {
      _showErrorDialog('Please paste QR code data');
      return;
    }
    _processQRCode(qrData);
  }

  void _processQRCode(String qrData) async {
    try {
      final result = await _qrService.processQRVerification(qrData);
      if (result['success']) {
        _stopScanning();
        _showSuccessDialog(result['message']);
        await _loadVerificationData(); // Refresh the list
      } else {
        _stopScanning();
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _stopScanning();
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _showMyQRCode() async {
    // Generate fresh QR data using the service
    final qrData = await _qrService.generateQRData();
    if (qrData == null) {
      _showErrorDialog('Failed to generate QR code data');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('verificationRequests')
              .doc(_currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            // Check if verification was received
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              final requestData = snapshot.data!.data() as Map<String, dynamic>;
              final status = requestData['status'] as String?;
              final timestamp = requestData['timestamp'] as String?;

              if (status == 'completed' && timestamp != null) {
                final qrTime = DateTime.parse(timestamp);
                final now = DateTime.now();
                final diff = now.difference(qrTime).inSeconds;

                if (diff <= 30) {
                  // Verification completed within 30 seconds, close dialog and show success
                  Future.microtask(() {
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop();
                      Fluttertoast.showToast(
                        msg: "Verification successful!",
                        toastLength: Toast.LENGTH_LONG,
                        backgroundColor: Colors.green,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      _loadVerificationData(); // Refresh the list
                    }
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Clock Confirmation QR Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Scan this QR code for verification.'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200.0,
                    height: 200.0,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(color: Colors.black),
                      dataModuleStyle:
                          const QrDataModuleStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Listening for verification...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<int>(
                    stream: Stream.periodic(
                            const Duration(seconds: 1), (count) => 30 - count)
                        .take(31),
                    builder: (context, snapshot) {
                      final remaining = snapshot.data ?? 30;
                      if (remaining <= 0) {
                        Future.microtask(() {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.of(dialogContext).pop();
                            _showQRExpiryDialog();
                          }
                        });
                        return const SizedBox.shrink();
                      }
                      return Text(
                        'Expires in: $remaining seconds',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQRExpiryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Code Expired'),
          content:
              const Text('The QR code has expired. Please generate a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _syncPendingVerifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());

        // Get pending verifications
        final pendingDocs = await FirebaseFirestore.instance
            .collection('Staff')
            .doc(userId)
            .collection('PendingVerifications')
            .where('date', isEqualTo: today)
            .where('status', isEqualTo: 'pending')
            .get();

        // Process each pending verification
        for (var doc in pendingDocs.docs) {
          await doc.reference.update({'status': 'synced'});
        }

        await _loadVerificationData(); // Refresh the data

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pending verifications synced successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing: $e')),
      );
    }
  }
}
