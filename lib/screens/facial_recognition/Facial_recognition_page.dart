import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:js/js.dart';
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/clock_attendance.dart';

// JS interop: functions defined in face_recognition.js
@JS('captureDescriptorFromVideo')
external Future<dynamic> captureDescriptorFromVideo(String videoElementId);

@JS('compareFaceFromVideo')
external Future<dynamic> compareFaceFromVideo(
    String videoElementId, dynamic trainingDescriptor, num threshold);

@JS('startAutoVerification')
external Future<void> startAutoVerification(String videoElementId,
    dynamic trainingDescriptor, num threshold, Function callback);

@JS('stopAutoVerification')
external void stopAutoVerification();

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
  html.VideoElement? _videoElement;
  bool _isCameraReady = false;
  bool _isAutoVerificationEnabled = false;
  int _trainingAttempts = 0;
  Timer? _autoVerificationTimer;
  static const int _maxTrainingAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Ensure clean state on each page load
    _resetState();
    _checkModelsLoaded();
    _registerCameraView();
    _fetchTrainingStatus();
  }

  void _resetState() {
    // Reset all state variables to ensure clean initialization
    _isCameraReady = false;
    _isAutoVerificationEnabled = false;
    _trainingAttempts = 0;
    _videoStream = null;
    _videoElement = null;
  }

  Future<void> _checkModelsLoaded() async {
    // Wait for models to load
    for (int i = 0; i < 30; i++) {
      // Wait up to 30 seconds
      try {
        final isLoaded = await _checkModelsLoadedJS();
        if (isLoaded) {
          print("Face detection models loaded successfully");
          return;
        }
      } catch (e) {
        print("Error checking model status: $e");
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    print("Models may not have loaded properly");
  }

  Future<bool> _checkModelsLoadedJS() async {
    try {
      final result = await html.window.navigator.mediaDevices
          ?.getUserMedia({'video': true});
      if (result != null) {
        // Models are likely loaded if we can access camera
        return true;
      }
    } catch (e) {
      print("Camera access check failed: $e");
    }
    return false;
  }

  Future<void> _refreshModels() async {
    setState(() {
      _statusMessage = 'Refreshing models...';
    });

    try {
      // Reload the page to refresh models
      html.window.location.reload();

      Fluttertoast.showToast(
        msg: "Refreshing page to reload models...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print("Error refreshing models: $e");
      setState(() {
        _statusMessage =
            'Error refreshing models. Please refresh the page manually.';
      });
      Fluttertoast.showToast(
        msg: "Error refreshing models. Please refresh the page manually.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void dispose() {
    _stopAutoVerification();
    _stopCamera();
    super.dispose();
  }

  void _stopAutoVerification() {
    if (_autoVerificationTimer != null) {
      _autoVerificationTimer!.cancel();
      _autoVerificationTimer = null;
    }
    setState(() {
      _isAutoVerificationEnabled = false;
    });
    try {
      stopAutoVerification();
    } catch (e) {
      print("Error stopping auto verification: $e");
    }
  }

  void _registerCameraView() {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory('webCamera', (int viewId) {
      _videoElement = html.VideoElement()
        ..id = 'webCamera'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '320px'
        ..style.height = '240px';

      // Request camera access and save the stream.
      _requestCameraAccess();
      return _videoElement!;
    });
  }

  Future<void> _requestCameraAccess() async {
    try {
      print("Requesting camera access...");
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'facingMode': 'user' // Use front camera
        }
      });

      if (stream != null) {
        _videoStream = stream;
        _videoElement!.srcObject = stream;

        // Wait for video to be ready
        await _waitForVideoReady();

        setState(() {
          _isCameraReady = true;
          _statusMessage = 'Camera initialized successfully';
        });

        print("Camera access granted and video element ready");
      }
    } catch (error) {
      print("Error accessing camera: $error");
      setState(() {
        _isCameraReady = false;
        _statusMessage = 'Camera access failed. Please check permissions.';
      });
      Fluttertoast.showToast(
        msg: "Error accessing camera: $error",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _waitForVideoReady() async {
    if (_videoElement == null) return;

    // Wait for video metadata to load
    await _videoElement!.onLoadedMetadata.first;

    // Ensure video plays
    try {
      await _videoElement!.play();
      print("Video started playing successfully");
    } catch (e) {
      print("Error playing video: $e");
      // Try to play again
      try {
        await _videoElement!.play();
      } catch (e2) {
        print("Second attempt to play video failed: $e2");
      }
    }
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
    final snapshot = await FirebaseFirestore.instance
        .collection('Staff')
        .doc(user.uid)
        .get();
    if (snapshot.exists && snapshot.data()!.containsKey('faceEmbedding')) {
      final embedding = snapshot.data()!['faceEmbedding'];
      // Check if the faceEmbedding is empty.
      if (embedding == null || (embedding as List).isEmpty) {
        setState(() {
          _isTrainingRequired = true;
          _statusMessage = 'No face data found. Please train your face.';
        });
      } else {
        _storedFaceDescriptor =
            List<double>.from((embedding).map((e) => (e as num).toDouble()));
        print(
            "Dart: _fetchTrainingStatus - _storedFaceDescriptor (from Firestore): $_storedFaceDescriptor");
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
    if (!_isCameraReady) {
      setState(() {
        _statusMessage = 'Initializing camera... Please wait.';
      });
      // Wait a bit more for camera to be ready
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isCameraReady) break;
      }

      if (!_isCameraReady) {
        Fluttertoast.showToast(
          msg: "Camera not ready. Please refresh the page and try again.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _trainingAttempts++;
      _statusMessage =
          'Training in progress... Please keep your face centered and still.';
    });

    try {
      // Take multiple captures for better accuracy
      List<List<double>> faceDescriptors = [];
      const int numCaptures = 3;

      for (int i = 0; i < numCaptures; i++) {
        setState(() {
          _statusMessage = 'Capturing face ${i + 1} of $numCaptures...';
        });

        await Future.delayed(
            const Duration(milliseconds: 1500)); // Wait between captures

        final descriptorPromise = captureDescriptorFromVideo("webCamera");
        final jsDescriptor = await js_util.promiseToFuture(descriptorPromise);

        if (jsDescriptor == null) {
          if (i == 0) {
            setState(() {
              _statusMessage =
                  'No face detected. Please ensure your face is clearly visible.';
              _isLoading = false;
            });
            Fluttertoast.showToast(
              msg:
                  "No face detected. Please ensure your face is clearly visible and well-lit.",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.orangeAccent,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return;
          }
          continue; // Skip this capture but continue with others
        }

        // Convert JS descriptor to Dart List<double>
        List<double> faceDescriptor = [];
        if (jsDescriptor != null) {
          final jsArray = jsDescriptor;
          if (js_util.hasProperty(jsArray, 'length')) {
            final length = js_util.getProperty(jsArray, 'length') as int;
            for (int j = 0; j < length; j++) {
              final value = js_util.getProperty(jsArray, j.toString());
              if (value is num) {
                faceDescriptor.add(value.toDouble());
              } else {
                faceDescriptor.add(0.0);
              }
            }
          }
        }

        if (faceDescriptor.isNotEmpty && faceDescriptor.length == 128) {
          faceDescriptors.add(faceDescriptor);
        }
      }

      if (faceDescriptors.isEmpty) {
        setState(() {
          _statusMessage = 'No valid face captures. Please try again.';
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg:
              "No valid face captures. Please ensure good lighting and keep your face centered.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      // Average multiple descriptors for better accuracy
      List<double> averagedDescriptor = _averageDescriptors(faceDescriptors);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('Staff').doc(user.uid).set(
            {'faceEmbedding': averagedDescriptor}, SetOptions(merge: true));

        setState(() {
          _isTrainingRequired = false;
          _storedFaceDescriptor = averagedDescriptor;
          _statusMessage = 'Training successful! You can now verify your face.';
          _isLoading = false;
          _trainingAttempts = 0;
        });

        Fluttertoast.showToast(
          msg:
              "Face training successful! ${faceDescriptors.length} captures averaged for better accuracy.",
          toastLength: Toast.LENGTH_LONG,
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
        _statusMessage = 'Error during training. Please try again.';
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

  // Helper method to average multiple face descriptors
  List<double> _averageDescriptors(List<List<double>> descriptors) {
    if (descriptors.isEmpty) return [];

    int length = descriptors[0].length;
    List<double> averaged = List.filled(length, 0.0);

    for (int i = 0; i < length; i++) {
      double sum = 0.0;
      for (List<double> descriptor in descriptors) {
        sum += descriptor[i];
      }
      averaged[i] = sum / descriptors.length;
    }

    return averaged;
  }

  Future<void> _clearFaceData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(user.uid)
            .update({'faceEmbedding': FieldValue.delete()});

        setState(() {
          _isTrainingRequired = true;
          _storedFaceDescriptor = null;
          _statusMessage = 'Face data cleared. Please train your face again.';
          _isLoading = false;
        });

        Fluttertoast.showToast(
          msg: "Face data cleared successfully. Please train your face again.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print("Error clearing face data: $e");
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: "Error clearing face data. Please try again.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _startAutoVerification() async {
    if (_storedFaceDescriptor == null || _storedFaceDescriptor!.isEmpty) {
      Fluttertoast.showToast(
        msg: "No training data available. Please train your face first.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orangeAccent,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (!_isCameraReady) {
      Fluttertoast.showToast(
        msg: "Camera not ready. Please wait and try again.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orangeAccent,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() {
      _isAutoVerificationEnabled = true;
      _statusMessage =
          'Auto-verification enabled. Please look at the camera...';
    });

    // Start polling for face verification
    _startAutoVerificationPolling();
  }

  void _startAutoVerificationPolling() {
    // Auto-stop after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (_isAutoVerificationEnabled) {
        _stopAutoVerificationProcess();
        Fluttertoast.showToast(
          msg: "Auto-verification timed out. Please try manual verification.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orangeAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    });

    // Use Dart-based polling instead of JavaScript callbacks for better reliability
    _autoVerificationTimer =
        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      if (!_isAutoVerificationEnabled) {
        timer.cancel();
        return;
      }

      try {
        // Use more lenient threshold for auto-verification
        final verificationResultPromise =
            compareFaceFromVideo("webCamera", _storedFaceDescriptor, 0.5);
        final verificationResult =
            await js_util.promiseToFuture(verificationResultPromise);

        print("Auto verification check - result: $verificationResult");

        if (verificationResult == true) {
          timer.cancel();
          setState(() {
            _statusMessage = 'Face Verified Successfully!';
            _isAutoVerificationEnabled = false;
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
        } else if (verificationResult == null) {
          // No face detected, update status but continue
          setState(() {
            _statusMessage = 'No face detected. Please look at the camera...';
          });
        }
      } catch (e) {
        print("Error in auto verification polling: $e");
        // Continue polling even if there's an error
      }
    });
  }

  Future<void> _stopAutoVerificationProcess() async {
    setState(() {
      _isAutoVerificationEnabled = false;
      _statusMessage =
          'Auto-verification stopped. Ready for manual verification.';
    });
    try {
      stopAutoVerification();
    } catch (e) {
      print("Error stopping auto verification: $e");
    }
  }

  Future<void> _verifyFace() async {
    if (_storedFaceDescriptor == null || _storedFaceDescriptor!.isEmpty) {
      setState(() {
        _statusMessage = 'No training data available. Please train first.';
      });
      return;
    }

    if (!_isCameraReady) {
      Fluttertoast.showToast(
        msg: "Camera not ready. Please wait and try again.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orangeAccent,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Try verification multiple times with different thresholds
    const int maxAttempts = 3;
    const double initialThreshold = 0.6; // More lenient threshold
    const double minThreshold = 0.4; // Minimum threshold

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      setState(() {
        _statusMessage = 'Verification attempt $attempt of $maxAttempts...';
      });

      try {
        // Use progressively more lenient threshold
        double threshold = initialThreshold - ((attempt - 1) * 0.1);

        final verificationResultPromise =
            compareFaceFromVideo("webCamera", _storedFaceDescriptor, threshold);
        final verificationResult =
            await js_util.promiseToFuture(verificationResultPromise);

        print(
            "Dart: _verifyFace - Attempt $attempt, threshold: $threshold, result: $verificationResult");

        if (verificationResult == null) {
          if (attempt == maxAttempts) {
            setState(() {
              _statusMessage =
                  'No face detected. Please ensure good lighting and face visibility.';
              _isLoading = false;
            });
            Fluttertoast.showToast(
              msg:
                  "No face detected. Please ensure your face is clearly visible and well-lit.",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.orangeAccent,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return;
          }
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        if (verificationResult == true) {
          setState(() {
            _statusMessage = 'Face Verified Successfully!';
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
          return;
        }

        // If this was the last attempt and verification failed
        if (attempt == maxAttempts) {
          setState(() {
            _statusMessage =
                'Face verification failed. Please retrain your face or try again.';
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg:
                "Face verification failed after $maxAttempts attempts. Please retrain your face.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }

        // Wait before next attempt
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print("Error verifying face (attempt $attempt): $e");
        if (attempt == maxAttempts) {
          setState(() {
            _statusMessage = 'Error during verification. Please try again.';
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg: "Error during face verification. Please try again.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
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
          child: Container(
            width: _isAutoVerificationEnabled
                ? 500
                : double.infinity, // Use double.infinity for original width
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
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
                  const SizedBox(height: 16),

                  // Tutorial Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need help with face training and verification?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  const url = 'https://youtu.be/aslSbf-wPFE';
                                  if (await canLaunch(url)) {
                                    await launch(url);
                                  } else {
                                    Fluttertoast.showToast(
                                      msg: "Could not open tutorial link",
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.BOTTOM,
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                    );
                                  }
                                },
                                child: Text(
                                  'View Tutorial',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isCameraReady
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isCameraReady
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCameraReady ? Icons.videocam : Icons.videocam_off,
                          size: 16,
                          color: _isCameraReady
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCameraReady
                              ? 'Camera Ready'
                              : 'Initializing Camera...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isCameraReady
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isAutoVerificationEnabled) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.purple.shade300, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.purple),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Auto-verification active - Please look at the camera',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: !_isLoading ? _refreshModels : null,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'Refresh Models',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          backgroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      _isTrainingRequired
                          ? Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _captureAndTrain,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt,
                                          color: Colors.white),
                                  label: Text(
                                    _trainingAttempts > 0
                                        ? 'Retrain Face (Attempt ${_trainingAttempts + 1}/$_maxTrainingAttempts)'
                                        : 'Capture Face for Training',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    backgroundColor: Colors.red.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                ),
                                if (_trainingAttempts > 0) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _clearFaceData,
                                    icon: const Icon(Icons.delete,
                                        color: Colors.white),
                                    label: const Text(
                                        'Clear Face Data & Start Over'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      backgroundColor: Colors.orange.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Column(
                              children: [
                                if (!_isAutoVerificationEnabled) ...[
                                  ElevatedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _startAutoVerification,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome,
                                            color: Colors.white),
                                    label: const Text(
                                      'Auto-Verify Face',
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      backgroundColor: Colors.purple.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                ElevatedButton.icon(
                                  onPressed:
                                      _isLoading || _isAutoVerificationEnabled
                                          ? null
                                          : _verifyFace,
                                  icon: _isLoading || _isAutoVerificationEnabled
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.verified_user,
                                          color: Colors.white),
                                  label: Text(
                                    _isAutoVerificationEnabled
                                        ? 'Auto-Verification Running...'
                                        : 'Manual Verify Face',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    backgroundColor: _isAutoVerificationEnabled
                                        ? Colors.grey.shade700
                                        : Colors.green.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                ),
                                if (_isAutoVerificationEnabled) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _stopAutoVerificationProcess,
                                    icon: const Icon(Icons.stop,
                                        color: Colors.white),
                                    label: const Text('Stop Auto-Verification'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      backgroundColor: Colors.red.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: !_isLoading
                                        ? () {
                                            setState(() {
                                              _isTrainingRequired = true;
                                              _storedFaceDescriptor = null;
                                              _trainingAttempts = 0;
                                              _isAutoVerificationEnabled =
                                                  false;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.replay,
                                        color: Colors.white),
                                    label: const Text(
                                      'Retrain Face',
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 14),
                                      backgroundColor: Colors.blue.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ],
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
