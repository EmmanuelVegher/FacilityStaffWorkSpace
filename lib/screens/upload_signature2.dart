import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
// Ensure Firebase Core is imported

import '../../widgets/drawer.dart';

class UploadSignaturePage2 extends StatefulWidget {
  const UploadSignaturePage2({super.key});

  @override
  _UploadSignaturePage2State createState() => _UploadSignaturePage2State();
}

class _UploadSignaturePage2State extends State<UploadSignaturePage2> {
  final SignatureController _signatureController = SignatureController(
    penColor: Colors.black,
    penStrokeWidth: 3,
  );
  Uint8List? _currentSignatureBytes;
  String? _signatureLink; // To store the link from Firebase Storage
  final ImagePicker _picker = ImagePicker();
  FirebaseStorage storage = FirebaseStorage.instance; // Firebase Storage instance
  FirebaseFirestore firestore = FirebaseFirestore.instance; // Firestore instance
  final FirebaseAuth auth = FirebaseAuth.instance; // Firebase Auth instance
  String? _userId; // To store the fetched userId
  static const Color wineColor = Color(0xFF722F37); // Deep wine color
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [wineColor, Color(0xFFB34A5A)], // Wine to lighter wine shade
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  @override
  void initState() {
    super.initState();
    _fetchUserId(); // Fetch user ID on initialization
  }

  Future<void> _fetchUserId() async {
    User? user = auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadSignatureLink(); // Load signature link after getting userId
    } else {
      // Handle case where user is not logged in
      // For example, navigate to login page or show an error message
      print("User not logged in.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in. Please log in to continue.")),
        );
        // Optionally navigate to login page:
        // Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }


  Future<void> _loadSignatureLink() async {
    if (_userId == null) return; // Ensure userId is available

    try {
      DocumentSnapshot<Map<String, dynamic>> staffDoc = await firestore
          .collection('Staff')
          .doc(_userId)
          .get();

      if (staffDoc.exists) {
        setState(() {
          _signatureLink = staffDoc.data()?['signatureLink'];
        });
      }
    } catch (e) {
      print("Error loading signature link: $e");
      // Handle error appropriately, maybe show a snackbar to the user
    }
  }

  Future<String?> _uploadImageToFirebaseStorage(Uint8List? imageBytes, String imageName) async {
    if (imageBytes == null) return null;
    if (_userId == null) return null; // Ensure userId is available

    try {
      final Reference storageRef = storage.ref().child('signatures/$_userId/$imageName'); // Include userId in path
      // Upload raw data.
      SettableMetadata metadata = SettableMetadata(contentType: 'image/png'); // Adjust content type if needed
      UploadTask uploadTask = storageRef.putData(imageBytes, metadata);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading signature to Firebase Storage: $e');
      // Handle error appropriately, maybe show a snackbar to the user
      return null;
    }
  }

  Future<void> _updateSignatureLinkInFirestore(String? signatureLink) async {
    if (_userId == null) return; // Ensure userId is available

    try {
      await firestore
          .collection('Staff')
          .doc(_userId)
          .update({'signatureLink': signatureLink});
      print('Signature link updated in Firestore successfully!');
    } catch (e) {
      print('Error updating signature link in Firestore: $e');
      // Handle error appropriately, maybe show a snackbar to the user
    }
  }


  Future<void> _pickAndUploadSignature() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not available. Please try again.")),
      );
      return;
    }
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        Uint8List imageBytes = await pickedFile.readAsBytes();
        String fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png'; // Unique file name
        String? downloadUrl = await _uploadImageToFirebaseStorage(imageBytes, fileName);

        if (downloadUrl != null) {
          await _updateSignatureLinkInFirestore(downloadUrl);
          setState(() {
            _signatureLink = downloadUrl;
            _currentSignatureBytes = imageBytes; // Optionally update local preview
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error picking and uploading signature.")),
      );
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
          content: SizedBox(
            height: 300,
            width: 300, // Added width for web responsiveness
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)), // Visual border for signature area
                    child: Signature(
                      controller: _signatureController,
                      backgroundColor: Colors.grey[200]!,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => _signatureController.clear(),
                      child: const Text("Clear"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_signatureController.isNotEmpty) {
                          final signature = await _signatureController.toPngBytes();
                          if (signature != null) {
                            String fileName = 'drawn_signature_${DateTime.now().millisecondsSinceEpoch}.png'; // Unique file name
                            String? downloadUrl = await _uploadImageToFirebaseStorage(signature, fileName);
                            if (downloadUrl != null) {
                              await _updateSignatureLinkInFirestore(downloadUrl);
                              setState(() {
                                _signatureLink = downloadUrl;
                                _currentSignatureBytes = signature; // Optionally update local preview
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Drawn signature saved successfully!")),
                              );
                            } else {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Failed to save drawn signature.")),
                              );
                            }
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to capture signature.")),
                            );
                          }
                        } else {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please draw your signature.")),
                          );
                        }
                      },
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer(context,), // You might need to adjust drawer for web if IsarService is removed
      appBar: AppBar(
        title: const Text('Upload Signature', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white), // Makes the drawer icon white
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),

      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator until userId is fetched
          : Center( // Center the content for better web layout
        child: ConstrainedBox( // Limit width for larger screens on web
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => _signatureLink == null ? _showSignaturePad() : null, // Only show signature pad if no signature yet
                  child: Container(
                    height: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.5 : 300, // Responsive height
                    width: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.5 : 300, // Responsive width
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _signatureLink != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network( // Use Image.network to display from Firebase Storage
                        _signatureLink!,
                        fit: BoxFit.contain,
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: MediaQuery.of(context).size.width * 0.15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Tap to Upload or Draw Signature",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
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
                      onPressed: () => _showSignaturePad(),
                      icon: const Icon(Icons.create),
                      label: const Text("Draw Signature"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickAndUploadSignature(),
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text(
                        "Upload Signature",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Removed the "Save Signature" button as it's now saved automatically on upload/draw
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }
}