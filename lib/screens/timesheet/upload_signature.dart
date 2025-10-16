import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/drawer.dart';

class UploadSignaturePage extends StatefulWidget {
  const UploadSignaturePage({super.key});

  @override
  _UploadSignaturePageState createState() => _UploadSignaturePageState();
}

class _UploadSignaturePageState extends State<UploadSignaturePage> {
  final SignatureController _signatureController = SignatureController(
    penColor: Colors.black,
    penStrokeWidth: 3,
  );
  Uint8List? _currentSignatureBytes;
  String? _signatureLink;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;

  // State variable to control the visibility of the progress indicator
  bool _isLoading = false;

  static const Color wineColor = Color(0xFF722F37);
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserId() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadSignatureLink();
    } else {
      print("User not logged in.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in. Please log in to continue.")),
        );
      });
    }
  }

  Future<void> _loadSignatureLink() async {
    if (_userId == null) return;
    try {
      DocumentSnapshot<Map<String, dynamic>> staffDoc = await _firestore
          .collection('Staff')
          .doc(_userId)
          .get();

      if (staffDoc.exists && mounted) {
        setState(() {
          _signatureLink = staffDoc.data()?['signatureLink'];
        });
      }
    } catch (e) {
      print("Error loading signature link: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading signature: $e")),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebaseStorage(Uint8List? imageBytes, String imageName) async {
    if (imageBytes == null || _userId == null) return null;
    try {
      final Reference storageRef = _storage.ref().child('signatures/$_userId/$imageName');
      SettableMetadata metadata = SettableMetadata(contentType: 'image/png');
      UploadTask uploadTask = storageRef.putData(imageBytes, metadata);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading signature to Firebase Storage: $e');
      return null;
    }
  }

  Future<void> _updateSignatureLinkInFirestore(String? signatureLink) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('Staff')
          .doc(_userId)
          .update({'signatureLink': signatureLink});
      print('Signature link updated in Firestore successfully!');
    } catch (e) {
      print('Error updating signature link in Firestore: $e');
      rethrow; // Rethrow to be caught in the calling function
    }
  }

  // Handles picking an image from the gallery and uploading it
  Future<void> _pickAndUploadSignature() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not available. Please try again.")),
      );
      return;
    }

    setState(() => _isLoading = true); // Show progress indicator

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        Uint8List imageBytes = await pickedFile.readAsBytes();
        String fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
        String? downloadUrl = await _uploadImageToFirebaseStorage(imageBytes, fileName);

        if (downloadUrl != null) {
          await _updateSignatureLinkInFirestore(downloadUrl);
          if (!mounted) return;
          setState(() {
            _signatureLink = downloadUrl;
            _currentSignatureBytes = imageBytes;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Signature uploaded and saved successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload signature.")),
          );
        }
      }
    } catch (e) {
      print("Error picking and uploading signature: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred during upload.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Hide progress indicator
      }
    }
  }

  // Handles saving the signature drawn on the signature pad
  Future<void> _saveDrawnSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please draw your signature first.")),
      );
      return;
    }

    setState(() => _isLoading = true); // Show progress indicator

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        String fileName = 'drawn_signature_${DateTime.now().millisecondsSinceEpoch}.png';
        String? downloadUrl = await _uploadImageToFirebaseStorage(signatureBytes, fileName);

        if (downloadUrl != null) {
          await _updateSignatureLinkInFirestore(downloadUrl);
          if (!mounted) return;
          setState(() {
            _signatureLink = downloadUrl;
            _currentSignatureBytes = signatureBytes;
          });
          _signatureController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Drawn signature saved successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save drawn signature.")),
          );
        }
      }
    } catch (e) {
      print("Error saving drawn signature: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred while saving.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Hide progress indicator
      }
    }
  }

  void _showSignaturePad() {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not available. Please try again.")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Draw Signature"),
          content: SizedBox(
            height: 300,
            width: 300,
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.grey[200]!,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _signatureController.clear(),
              child: const Text("Clear"),
            ),
            ElevatedButton(
              onPressed: () {
                // First, pop the dialog
                Navigator.of(context).pop();
                // Then, start the saving process which shows the indicator
                _saveDrawnSignature();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer(context),
      appBar: AppBar(
        title: const Text('Upload Signature', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
      ),
      body: Stack( // Use a Stack to overlay the progress indicator
        children: [
          // Main content
          _userId == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _showSignaturePad,
                      child: Container(
                        height: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.5 : 300,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _signatureLink != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.network(
                            _signatureLink!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.error, color: Colors.red));
                            },
                          ),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.draw,
                              size: MediaQuery.of(context).size.width * 0.15,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap to Draw or Upload Signature",
                              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showSignaturePad,
                          icon: const Icon(Icons.create),
                          label: const Text("Draw Signature"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickAndUploadSignature,
                          icon: const Icon(Icons.upload_file, color: Colors.white),
                          label: const Text("Upload Signature", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}