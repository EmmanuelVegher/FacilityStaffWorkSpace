import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

import '../widgets/drawer4.dart';

class UploadSignaturePage4 extends StatefulWidget {
  const UploadSignaturePage4({super.key});

  @override
  _UploadSignaturePage4State createState() => _UploadSignaturePage4State();
}

class _UploadSignaturePage4State extends State<UploadSignaturePage4> {
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

  // Define Maroon theme colors
  static const Color maroonPrimary = Color(0xFF5C1A2E); 
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [maroonPrimary, Color(0xFF2E0215)], // Consistent Maroon/Gold gradient
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not logged in. Please log in to continue.", style: GoogleFonts.poppins())),
        );
      }
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
          SnackBar(content: Text("Error loading signature: $e", style: GoogleFonts.poppins())),
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
      rethrow; 
    }
  }

  // Handles picking an image from the gallery and uploading it
  Future<void> _pickAndUploadSignature() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User ID not available. Please try again.", style: GoogleFonts.poppins())),
      );
      return;
    }

    setState(() => _isLoading = true); 

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
            SnackBar(content: Text("Signature uploaded and saved successfully!", style: GoogleFonts.poppins())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload signature.", style: GoogleFonts.poppins())),
          );
        }
      }
    } catch (e) {
      print("Error picking and uploading signature: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred during upload.", style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); 
      }
    }
  }

  // Handles saving the signature drawn on the signature pad
  Future<void> _saveDrawnSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please draw your signature first.", style: GoogleFonts.poppins())),
      );
      return;
    }

    setState(() => _isLoading = true); 

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
            SnackBar(content: Text("Drawn signature saved successfully!", style: GoogleFonts.poppins())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save drawn signature.", style: GoogleFonts.poppins())),
          );
        }
      }
    } catch (e) {
      print("Error saving drawn signature: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred while saving.", style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); 
      }
    }
  }

  void _showSignaturePad() {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User ID not available. Please try again.", style: GoogleFonts.poppins())),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Draw Signature", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: maroonPrimary)),
          content: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              border: Border.all(color: maroonPrimary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.grey[100]!,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _signatureController.clear(),
              child: Text("Clear", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveDrawnSignature();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: maroonPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Save Signature", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer4(context),
      appBar: AppBar(
        title: Text('Upload Signature', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: appBarGradient),
        ),
      ),
      body: SelectionArea( // Wrapped in SelectionArea for copyable text
        child: Stack( 
          children: [
            // Main content
            _userId == null
                ? const Center(child: CircularProgressIndicator(color: maroonPrimary))
                : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "My Core Signature",
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: maroonPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This signature will be used for your timesheets and official documents.",
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _showSignaturePad,
                        child: Container(
                          height: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.6 : 300,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: maroonPrimary.withOpacity(0.2), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: _signatureLink != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Image.network(
                              _signatureLink!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: maroonPrimary));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
                              },
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.draw_outlined,
                                size: 60,
                                color: maroonPrimary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Tap to Draw or Upload Signature",
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showSignaturePad,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text("Draw", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC09E5F), // Gold-ish color
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickAndUploadSignature,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text("Upload", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: maroonPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
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
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}