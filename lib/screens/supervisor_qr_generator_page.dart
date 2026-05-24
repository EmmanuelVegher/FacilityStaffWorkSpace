import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SupervisorQRGeneratorPage extends StatefulWidget {
  const SupervisorQRGeneratorPage({super.key});

  @override
  State<SupervisorQRGeneratorPage> createState() => _SupervisorQRGeneratorPageState();
}

class _SupervisorQRGeneratorPageState extends State<SupervisorQRGeneratorPage> {
  String? _qrData;
  Timer? _refreshTimer;
  int _secondsRemaining = 300; // 5 minutes
  bool _isLoading = true;

  static const Color maroonPrimary = Color(0xFF5C1A2E);
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _generateData();
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _generateData();
      }
    });
  }

  Future<void> _generateData() async {
    setState(() {
      _isLoading = true;
      _secondsRemaining = 300;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      final userData = userDoc.data();
      
      final fullName = "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}".trim();
      final designation = userData?['designation'] ?? 'Supervisor';

      final data = {
        "userId": user.uid,
        "fullName": fullName,
        "designation": designation,
        "timestamp": DateTime.now().toIso8601String(),
        "type": "supervisor_verification",
        "role": userData?['staffCategory'] ?? 'Supervisor'
      };

      setState(() {
        _qrData = jsonEncode(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error generating QR data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error generating QR code. Please try again.")),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Supervisor QR Code", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
      ),
      body: SelectionArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Verification QR Code",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: maroonPrimary),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  "Staff members can scan this code to complete their verification.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: _isLoading || _qrData == null
                    ? const SizedBox(
                        width: 250,
                        height: 250,
                        child: Center(child: CircularProgressIndicator(color: maroonPrimary)),
                      )
                    : QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 250.0,
                        gapless: false,
                        embeddedImage: const AssetImage('assets/image/ccfn_logo.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(40, 40),
                        ),
                      ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: maroonPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: maroonPrimary),
                    const SizedBox(width: 8),
                    Text(
                      "Expires in: ${_formatTime(_secondsRemaining)}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: maroonPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateData,
                icon: const Icon(Icons.refresh),
                label: Text("Refresh Now", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: maroonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
