import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:js/js.dart';
import 'dart:js_util' as js_util;
import 'package:fluttertoast/fluttertoast.dart';

import '../components/clock_attendance.dart';

// JS interop: functions defined in face_recognition.js
@JS('captureDescriptorFromVideo')
external Future<dynamic> captureDescriptorFromVideo(String videoElementId);

@JS('compareFaceFromVideo')
external Future<dynamic> compareFaceFromVideo(String videoElementId, dynamic trainingDescriptor, num threshold);

class FacialRecognitionPage extends StatefulWidget {
  const FacialRecognitionPage({super.key});

  @override
  _FacialRecognitionPageState createState() => _FacialRecognitionPageState();
}

class _FacialRecognitionPageState extends State<FacialRecognitionPage> {
  String _statusMessage = 'Checking training status...';
  bool _isTrainingRequired = false;
  bool _isLoading = false;
  List<double>? _storedFaceDescriptor;
  html.MediaStream? _videoStream;

  @override
  void initState() {
    super.initState();
    _registerCameraView();
    _fetchTrainingStatus();
  }

  void _registerCameraView() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory('webCamera', (int viewId) {
      final videoElement = html.VideoElement()
        ..id = 'webCamera'
        ..autoplay = true
        ..muted = true;
      videoElement.setAttribute('playsinline', 'true');
      videoElement.style.width = '320px';
      videoElement.style.height = '240px';
      // Request camera access and save the stream.
      html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((stream) {
        _videoStream = stream;
        videoElement.srcObject = stream;
      }).catchError((error) {
        print("Error accessing camera: $error");
        Fluttertoast.showToast(
          msg: "Error accessing camera: $error",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      });
      return videoElement;
    });
  }

  void _stopCamera() {
    if (_videoStream != null) {
      _videoStream!.getTracks().forEach((track) {
        track.stop();
      });
      _videoStream = null;
    }
  }

  Future<void> _fetchTrainingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _statusMessage = 'User not logged in';
      });
      return;
    }
    final snapshot =
    await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
    if (snapshot.exists && snapshot.data()!.containsKey('faceEmbedding')) {
      final embedding = snapshot.data()!['faceEmbedding'];
      // Check if the faceEmbedding is empty.
      if (embedding == null || (embedding as List).isEmpty) {
        setState(() {
          _isTrainingRequired = true;
          _statusMessage = 'No face data found. Please train your face.';
        });
      } else {
        _storedFaceDescriptor = List<double>.from(
            (embedding).map((e) => (e as num).toDouble()));
        print("Dart: _fetchTrainingStatus - _storedFaceDescriptor (from Firestore): $_storedFaceDescriptor");
        setState(() {
          _isTrainingRequired = false;
          _statusMessage = 'Face data found. Ready for verification.';
        });
      }
    } else {
      setState(() {
        _isTrainingRequired = true;
        _statusMessage = 'No face data found. Please train your face.';
      });
    }
  }


  Future<void> _captureAndTrain() async {
    setState(() => _isLoading = true);
    try {
      final descriptorPromise = captureDescriptorFromVideo("webCamera");
      final jsDescriptor = await js_util.promiseToFuture(descriptorPromise); // Get the raw JS descriptor

      if (jsDescriptor == null) {
        setState(() {
          _statusMessage = 'No face detected. Please try again.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "No face detected. Please ensure your face is clearly visible.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      // Convert JS descriptor (which should be a Float32Array or JS array) to Dart List<double>
      List<double> faceDescriptor = [];
      if (jsDescriptor != null) {
        if (jsDescriptor is List) { // Check if it's already a List (unlikely for Float32Array, but safe check)
          faceDescriptor = (jsDescriptor).cast<double>(); // Assuming it's already List<double> or can be cast
        } else {
          // Handle as JsObject (no need to cast, just use jsDescriptor directly)
          final jsArray = jsDescriptor; // No casting needed anymore
          if (js_util.hasProperty(jsArray, 'length')) {
            final length = js_util.getProperty(jsArray, 'length') as int;
            for (int i = 0; i < length; i++) {
              final value = js_util.getProperty(jsArray, i.toString());
              if (value is num) {
                faceDescriptor.add(value.toDouble());
              } else {
                print("Warning: Non-numeric value found in descriptor at index $i: $value");
                faceDescriptor.add(0.0); // Default to 0 or handle error as needed.
              }
            }
          } else {
            print("Warning: jsDescriptor does not have 'length' property, cannot convert to List<double>.");
          }
        }
      }


      // Check if the captured faceDescriptor is empty before saving.
      if (faceDescriptor.isEmpty) {
        setState(() {
          _statusMessage = 'Empty face embedding detected. Please try again.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Empty face embedding captured. Please ensure your face is clearly visible.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .set({'faceEmbedding': faceDescriptor}, SetOptions(merge: true));
        setState(() {
          _isTrainingRequired = false;
          _storedFaceDescriptor = faceDescriptor;
          _statusMessage = 'Training successful! Proceed to verification.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Face training successful!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error capturing face for training: $e");
      setState(() {
        _statusMessage = 'Error capturing face. Please try again.';
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error during face training. Please try again.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _verifyFace() async {
    if (_storedFaceDescriptor == null || _storedFaceDescriptor!.isEmpty) {
      setState(() {
        _statusMessage = 'No training data available. Please train first.';
      });
      return;
    }
    setState(() => _isLoading = true);
    dynamic verificationResult;
    try {
      final verificationResultPromise = compareFaceFromVideo(
          "webCamera", _storedFaceDescriptor, 0.4);
      verificationResult =
      await js_util.promiseToFuture(verificationResultPromise);
      print("Dart: _verifyFace - verificationResult (resolved) from JS: $verificationResult, type: ${verificationResult.runtimeType}");
      if (verificationResult == null) {
        setState(() {
          _statusMessage = 'No face detected in video feed. Please try again.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "No face detected in video feed.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else if (verificationResult == false) {
        setState(() {
          _statusMessage = 'Face Not Verified. Face does not match.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Face verification failed. Face does not match.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else if (verificationResult == true) {
        setState(() {
          _statusMessage = 'Face Verified';
        });
        _stopCamera();
        Fluttertoast.showToast(
          msg: "Face Verified! Logging you in...",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ClockAttendanceWeb()),
        );
      }
    } catch (e) {
      print("Error verifying face: $e");
      setState(() {
        _statusMessage = 'Error verifying face. Please try again.';
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Error during face verification.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.black87,
              Colors.white,
              Colors.yellow.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 320,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        )
                      ],
                      color: Colors.black12,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const HtmlElementView(viewType: 'webCamera'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _isTrainingRequired
                      ? ElevatedButton.icon(
                    onPressed: _isLoading ? null : _captureAndTrain,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('Capture Face for Training'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  )
                      : ElevatedButton.icon(
                    onPressed: _isLoading ? null : _verifyFace,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.verified_user, color: Colors.white),
                    label: const Text('Verify Face'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}