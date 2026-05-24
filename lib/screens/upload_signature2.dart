import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_delivery_workspace/widgets/drawer2.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _signatureLink;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;

  // State variable to control the visibility of the progress indicator
  bool _isLoading = false;

  static const Color wineColor = Color(0xFF5C1A2E);
  static const Color goldColor = Color(0xFFD4A03C);

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
      rethrow;
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
        setState(() => _isLoading = false);
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
          if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog if open
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
        setState(() => _isLoading = false);
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
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Draw Signature", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: wineColor)),
          content: Container(
            height: 300,
            width: double.maxFinite,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => _signatureController.clear(),
              child: Text("Clear", style: GoogleFonts.poppins(color: wineColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveDrawnSignature();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: wineColor,
                foregroundColor: Colors.white,
              ),
              child: Text("Save", style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer2(context),
      appBar: AppBar(
        title: Text('Upload Signature',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: wineColor,
        elevation: 0,
      ),
      body: SelectionArea(
        child: Container(
          color: Colors.grey.shade50,
          child: Stack(
            children: [
              _userId == null
                  ? const Center(child: CircularProgressIndicator(color: wineColor))
                  : Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GestureDetector(
                                  onTap: _showSignaturePad,
                                  child: Container(
                                    height: 300,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: goldColor.withOpacity(0.5), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5))
                                      ],
                                    ),
                                    child: _signatureLink != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: Image.network(
                                              _signatureLink!,
                                              fit: BoxFit.contain,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                if (progress == null) return child;
                                                return const Center(
                                                    child:
                                                        CircularProgressIndicator(color: wineColor));
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return const Center(
                                                    child: Icon(Icons.error,
                                                        color: Colors.red));
                                              },
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.draw_rounded,
                                                size: 64,
                                                color: wineColor.withOpacity(0.3),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                "Tap to Draw or Upload Signature",
                                                style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    color: wineColor.withOpacity(0.7),
                                                    fontWeight: FontWeight.w500),
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
                                        icon: const Icon(Icons.create),
                                        label: Text("Draw New",
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: goldColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          elevation: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _pickAndUploadSignature,
                                        icon: const Icon(Icons.upload_file),
                                        label: Text("Upload Image",
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: wineColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          elevation: 2,
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
                    ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}