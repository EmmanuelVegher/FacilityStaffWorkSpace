import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Import GetX
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class VerificationPage extends StatefulWidget {
  final String userId;

  VerificationPage({required this.userId});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  CameraController? _cameraController;
  File? _capturedImage;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    final image = await _cameraController!.takePicture();
    setState(() {
      _capturedImage = File(image.path);
    });
    await _verifyImage();
  }

  Future<void> _verifyImage() async {
    if (_capturedImage == null) return;

    try {
      // Upload the captured image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('temp_images/${widget.userId}.jpg');
      await storageRef.putFile(_capturedImage!);

      // Call Firebase Function to verify the image
      final url = Uri.parse('https://us-central1-attendanceapp-a6853.cloudfunctions.net/verifyImage');
      final response = await http.post(
        url,
        body: json.encode({'userId': widget.userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _isVerified = true;
        });
        Get.snackbar('Success', 'Verification successful!'); // Use GetX snackbar
      } else {
        Get.snackbar('Error', 'Verification failed. Please try again.'); // Use GetX snackbar
      }
    } catch (e) {
      Get.snackbar('Error', 'Error: $e'); // Use GetX snackbar
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text('Verification')),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_cameraController!),
          ),
          ElevatedButton(
            onPressed: _isVerified ? null : _captureImage,
            child: Text(_isVerified ? 'Verified' : 'Capture Image for Verification'),
          ),
        ],
      ),
    );
  }
}