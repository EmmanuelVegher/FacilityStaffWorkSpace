import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:service_delivery_workspace/services/qr_verification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final QRVerificationService _verificationService = QRVerificationService();
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _hasStarted = false;
  String _webStatus = "Idle";
  bool _isStarting = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      setState(() => _webStatus = "Checking Web Permissions...");
      try {
        // Attempt to check existing permission status
        final permissions = html.window.navigator.permissions;
        if (permissions != null) {
          final status = await permissions.query({'name': 'camera'});
          print("Web camera permission status: ${status.state}");
          setState(() => _webStatus = "Permission Status: ${status.state}");
          
          if (status.state == 'granted') {
            if (mounted) {
              setState(() {
                _hasPermission = true;
                _isCheckingPermission = false;
              });
              _startScanner();
            }
          } else {
            if (mounted) {
              setState(() {
                _hasPermission = false;
                _isCheckingPermission = false;
              });
            }
          }
        } else {
          // Fallback if permissions API is not available
          setState(() {
            _hasPermission = false;
            _isCheckingPermission = false;
            _webStatus = "Permissions API unavailable. Please click button.";
          });
        }
      } catch (e) {
        print("Error checking Web permission: $e");
        setState(() {
          _hasPermission = false;
          _isCheckingPermission = false;
          _webStatus = "Error checking permission. Please click button.";
        });
      }
      return;
    }

    try {
      final status = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          _isCheckingPermission = false;
        });
        if (status.isGranted) {
          _startScanner();
        }
      }
    } catch (e) {
      print("Error checking permission: $e");
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _requestWebPermission() async {
    setState(() => _webStatus = "Requesting Camera Access...");
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw "MediaDevices API not supported in this browser/context.";
      }
      
      // Standard way to trigger the browser's permission dialog
      final stream = await mediaDevices.getUserMedia({'video': true});
      
      // If successful, stop the tracks immediately (we just wanted the permission)
      stream.getTracks().forEach((track) => track.stop());
      
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _webStatus = "Permission Granted!";
        });
        _startScanner();
      }
    } catch (e) {
      print("Error requesting Web permission: $e");
      if (mounted) {
        setState(() {
          _webStatus = "Permission Denied or Error: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Camera access denied or device error. Please enable it in browser settings."), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startScanner() async {
    if (_hasStarted || _isStarting) return;
    
    setState(() {
      _isStarting = true;
      if (kIsWeb) _webStatus = "Starting Camera Hardware...";
    });

    try {
      if (kIsWeb) {
        // Add a delay before starting to ensure previous hardware access (from getUserMedia) is fully released
        // And to allow the platform channel to stabilize in release builds
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      await controller.start();
      if (mounted) {
        setState(() {
          _hasStarted = true;
          if (kIsWeb) _webStatus = "Camera Active";
        });
      }
    } catch (e) {
      print("Error starting scanner: $e");
      String errorStr = e.toString();
      if (kIsWeb) setState(() => _webStatus = "Start Error: $errorStr");
      
      // If it's already initialized, we can consider it "started" for our UI purposes
      if (errorStr.contains("controllerAlreadyInitialized")) {
         if (mounted) {
           setState(() {
             _hasStarted = true;
           });
         }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
    
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_hasStarted) {
        setState(() {
          // Force UI refresh to show retry button if not started after 8 seconds
          if (kIsWeb) _webStatus = "Initialization Timeout - Please try manual start";
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Scan QR Code",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF5C1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5C1A2E)));
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "Camera Permission Required",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Please grant camera access to scan QR codes.",
                style: GoogleFonts.poppins(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                Text(
                  "Status: $_webStatus",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: kIsWeb ? _requestWebPermission : () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(kIsWeb ? "Grant Camera Access" : "Open Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          fit: BoxFit.cover,
          placeholderBuilder: (context, child) => _buildStatusDisplay(),
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
               for (final barcode in barcodes) {
                 if (barcode.rawValue != null) {
                   _processCode(barcode.rawValue!);
                   break; 
                 }
               }
            }
          },
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    "Error starting camera: ${error.errorCode}",
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.start(),
                    child: const Text("Retry Camera"),
                  ),
                ],
              ),
            );
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "Align QR code within the frame",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  const Shadow(
                    blurRadius: 4,
                    color: Colors.black,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDisplay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              "Initializing Camera...",
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Text(
                "Status: $_webStatus",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isStarting ? null : () => _startScanner(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C1A2E),
                foregroundColor: Colors.white,
              ),
              child: Text(_isStarting ? "Processing..." : "Manually Start Camera", style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  void _processCode(String code) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final Map<String, dynamic> qrData = jsonDecode(code);
      
      // Basic Validation
      if (!qrData.containsKey('userId') || !qrData.containsKey('timestamp')) {
        throw Exception("Invalid QR Code Format");
      }

      final targetUserId = qrData['userId'];
      final timestampRaw = qrData['timestamp'];
      
      DateTime qrTime;
      if (timestampRaw is int) {
         qrTime = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
      } else {
         qrTime = DateTime.parse(timestampRaw.toString());
      }
       
      final isSupervisor = qrData['type'] == 'supervisor_verification';
      final expirySeconds = isSupervisor ? 300 : 30; // 5 mins for supervisor, 30s for colleague
      
      final diff = DateTime.now().difference(qrTime).inSeconds;
      if (diff > expirySeconds) {
        _showError(isSupervisor ? "Supervisor QR Code Expired" : "QR Code Expired");
        setState(() { _isProcessing = false; });
        return;
      }

       final currentUser = FirebaseAuth.instance.currentUser;
       if (currentUser == null) {
         _showError("You must be logged in");
         setState(() { _isProcessing = false; });
         return;
       }

       if (targetUserId == currentUser.uid) {
        _showError("You cannot verify your own QR code");
        setState(() { _isProcessing = false; });
        return;
       }

      // Read scanner details
      final userDoc = await FirebaseFirestore.instance.collection('Staff').doc(currentUser.uid).get();
      final scannerName = "${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}".trim();
      final finalScannerName = scannerName.isEmpty ? (currentUser.displayName ?? 'Unknown Scanner') : scannerName;

      // Check for duplicate verification BEFORE writing to verificationRequests
      final today = DateFormat('dd-MMMM-yyyy').format(DateTime.now());
      final scannerRecordRef = FirebaseFirestore.instance
          .collection('Staff')
          .doc(currentUser.uid)
          .collection('Record')
          .doc(today);

      final scannerRecord = await scannerRecordRef.get();
      if (scannerRecord.exists) {
        final currentData = scannerRecord.data()!;
        final verifiedIds = List<String>.from(currentData['verifiedByUserIds'] ?? []);
        
        // Check if already verified this colleague today
        if (verifiedIds.contains(targetUserId)) {
          _showError("You have already verified this colleague today");
          setState(() { _isProcessing = false; });
          return;
        }
      }

      await FirebaseFirestore.instance.collection('verificationRequests').doc(targetUserId).set({
        'scannerUserId': currentUser.uid,
        'scannerUserName': finalScannerName,
        'targetUserId': targetUserId,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
        'location': "Biometric Verification", 
        'verificationType': isSupervisor ? 'supervisor' : 'colleague',
      });

      // Update scanner's own attendance record
      try {
        if (scannerRecord.exists) {
          final currentData = scannerRecord.data()!;
          final verifiedIds = List<String>.from(currentData['verifiedByUserIds'] ?? []);
          final verifiedNames = List<String>.from(currentData['verifiedByUserNames'] ?? []);
          
          // Use data directly from QR code instead of querying Firestore
          final targetName = qrData['fullName'] ?? '${qrData['firstName'] ?? ''} ${qrData['lastName'] ?? ''}'.trim();
          final targetRole = isSupervisor ? (qrData['role'] ?? 'Supervisor') : (qrData['designation'] ?? 'Staff');
          final timestamp = DateFormat('d-MMM-yyyy \'at\' hh:mm a').format(DateTime.now());
          
          verifiedIds.add(targetUserId);
          verifiedNames.add(isSupervisor ? "$targetName ($targetRole) $timestamp" : "$targetName-$targetRole $timestamp");
          
          await scannerRecordRef.update({
            'verificationMethod': 'qr',
            'verificationRequired': true,
            'verificationCount': verifiedIds.length,
            'verifiedByUserIds': verifiedIds,
            'verifiedByUserNames': verifiedNames,
          });
        } else {
          // Scanner hasn't clocked in yet - log this
          print('Scanner has not clocked in today. Cannot update verification record.');
        }
      } catch (e) {
        print('Error updating scanner record: $e');
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification Sent!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }

    } catch (e) {
      _showError("Error: ${e.toString()}");
      setState(() { _isProcessing = false; });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
