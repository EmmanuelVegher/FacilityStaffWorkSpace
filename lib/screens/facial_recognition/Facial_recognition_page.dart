// FacialRecognitionPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:js/js.dart';
import 'dart:js_util' as js_util;

import '../staff_dashboard.dart';

// JS interop declarations for functions defined in face_recognition.js
@JS('captureDescriptorFromVideo')
external Future<dynamic> captureDescriptorFromVideo(String videoElementId);

@JS('compareFaceFromVideo')
external Future<bool> compareFaceFromVideo(String videoElementId, dynamic trainingDescriptor, num threshold);

class FacialRecognitionPage extends StatefulWidget {
  @override
  _FacialRecognitionPageState createState() => _FacialRecognitionPageState();
}

class _FacialRecognitionPageState extends State<FacialRecognitionPage> {
  String _resultText = 'Checking training status...';
  bool _isTraining = false; // true if no face embedding exists for this user
  List<double>? _storedDescriptor;

  @override
  void initState() {
    super.initState();
    _registerCameraView();
    _checkTrainingStatus();
  }

// Register a view factory for the camera feed.
  void _registerCameraView() {
// ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('webCamera', (int viewId) {
      final video = html.VideoElement()
        ..id = 'webCamera'
        ..autoplay = true
        ..muted = true;
      // Use setAttribute to set playsinline
      video.setAttribute('playsinline', 'true');
      video.style.width = '320px';
      video.style.height = '240px';
      // Request camera access
      html.window.navigator.getUserMedia(video: true).then((stream) {
        video.srcObject = stream;
      }).catchError((e) {
        print("Error accessing camera: $e");
      });
      return video;
    });
  }


  // Checks the "Staff" collection for the current user's document and the field "faceEmbedding".
  Future<void> _checkTrainingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _resultText = 'User not logged in';
      });
      return;
    }
    final docSnapshot =
    await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('faceEmbedding')) {
      final embedding = docSnapshot.data()!['faceEmbedding'];
      // Convert the stored embedding (assumed to be a List<dynamic>) to List<double>
      _storedDescriptor =
      List<double>.from(embedding.map((e) => (e as num).toDouble()));
      setState(() {
        _isTraining = false;
        _resultText = 'Face data found. Ready for verification.';
      });
    } else {
      setState(() {
        _isTraining = true;
        _resultText = 'No face data found. Please train your face.';
      });
    }
  }

  List<double> _convertJsDescriptor(dynamic descriptor) {
    try {
      // Convert the descriptor to a string. For a typed array this should be comma-separated numbers.
      String descriptorStr = js_util.callMethod(descriptor, "toString", []);
      List<String> parts = descriptorStr.split(",");
      return parts.map((s) => double.parse(s.trim())).toList();
    } catch (e) {
      print("Error converting descriptor: $e");
      return [];
    }
  }




// Captures a face descriptor using the web camera and saves it to Firestore.
  Future<void> _captureAndTrain() async {
    // Capture face descriptor from video element with id "webCamera"
    final descriptor = await captureDescriptorFromVideo("webCamera");
    if (descriptor == null) {
      setState(() {
        _resultText = 'No face detected. Please try again.';
      });
      return;
    }
    // If the descriptor is a Promise, unwrap it.
    dynamic resolvedDescriptor = descriptor;
    try {
      resolvedDescriptor = await js_util.promiseToFuture(descriptor);
    } catch (e) {
      print("Descriptor is not a Promise: $e");
    }
    // Now convert the resolved descriptor into a Dart List<double>
    List<double> faceDescriptor = _convertJsDescriptor(resolvedDescriptor);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('Staff').doc(user.uid).set({
        'faceEmbedding': faceDescriptor,
      }, SetOptions(merge: true));
      setState(() {
        _isTraining = false;
        _storedDescriptor = faceDescriptor;
        _resultText = 'Training successful! Proceed to verification.';
      });
    }
  }


// Captures a live face and compares it to the stored training descriptor.
  Future<void> _verifyFace() async {
    if (_storedDescriptor == null) {
      setState(() {
        _resultText = 'No training data available. Please train first.';
      });
      return;
    }
    bool isMatch = await compareFaceFromVideo("webCamera", _storedDescriptor, 0.6);
    if (isMatch) {
      setState(() {
        _resultText = 'Face Verified';
      });
      // Navigate to the UserDashboardPage after a successful verification.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserDashboardPage()),
      );
    } else {
      setState(() {
        _resultText = 'Face Not Verified';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Facial Recognition'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display the live camera feed
              Container(
                width: 320,
                height: 240,
                color: Colors.black12,
                child: HtmlElementView(viewType: 'webCamera'),
              ),
              SizedBox(height: 20),
              Text(_resultText),
              SizedBox(height: 20),
              _isTraining
                  ? ElevatedButton(
                onPressed: _captureAndTrain,
                child: Text('Capture Face for Training'),
              )
                  : ElevatedButton(
                onPressed: _verifyFace,
                child: Text('Verify Face'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
