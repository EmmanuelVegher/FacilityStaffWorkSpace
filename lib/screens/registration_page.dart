import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

// Assuming you have this file for your styled input fields.
// If not, replace MyInputField with standard TextFormField or DropdownButtonFormField.
import 'login_screen.dart';


class RegistrationPageWeb extends StatefulWidget {
  const RegistrationPageWeb({super.key});

  @override
  _RegistrationPageWebState createState() => _RegistrationPageWebState();
}

class _RegistrationPageWebState extends State<RegistrationPageWeb> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supervisorNameController = TextEditingController(); // For manual entry
  final _supervisorEmailController = TextEditingController(); // For manual entry


  // --- ADD these new controllers ---
  final _accountNumberController = TextEditingController();
  final _sortCodeController = TextEditingController();

// --- ADD these new state variables for dropdowns ---
  String? _selectedBankName;
  String? _selectedProgramManagerId;
  String? _selectedProgramManagerEmail;

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPasswordObscured = true;
  bool _termsAgreed = false;

  Uint8List? _profileImageBytes;

  // --- State for Dropdowns (storing Document IDs) ---
  String? _selectedCategory;
  String? _selectedProject;
  String? stateName;
  String? locationName;
  String? departmentName;
  String? designation;
  String? supervisorName;
  String? supervisorEmail;
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _selectedRole;

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _maritalStatusOptions = ['Single', 'Married', 'Divorced', 'Widowed'];

  // In _RegistrationPageWebState class:

// --- ADD this new method to fetch bank names ---
  Future<List<DropdownMenuItem<String>>> _fetchBanks() async {
    try {
      final snapshot = await _firestore.collection("Bank").get();
      return snapshot.docs
          .map((doc) => DropdownMenuItem<String>(
        value: doc['name'] as String,
        child: Text(doc['name'] as String),
      ))
          .toList()
        ..sort((a, b) => a.value!.compareTo(b.value!));
    } catch (e) {
      debugPrint("Error fetching banks: $e");
      return [];
    }
  }

// --- ADD this new method to fetch Program Managers ---
  Future<List<DropdownMenuItem<String>>> _fetchProgramManagers() async {
    if (stateName == null) return []; // Depends on state
    try {
      final snapshot = await _firestore
          .collection("Supervisors")
          .doc(stateName)
          .collection(stateName!)
          .where("department", isEqualTo: "Program Management")
          .get();

      final managers = snapshot.docs
          .map((doc) => DropdownMenuItem<String>(
        value: doc.id, // Supervisor name is the document ID
        child: Text(doc.id),
      ))
          .toList();

      managers.sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!));
      return managers;
    } catch (e) {
      debugPrint("Error fetching program managers: $e");
      return [];
    }
  }

// --- ADD this new method to fetch Program Manager emails ---
  Future<List<DropdownMenuItem<String>>> _fetchProgramManagerEmails() async {
    if (stateName == null || _selectedProgramManagerId == null) return [];
    try {
      final snapshot = await _firestore
          .collection("Supervisors")
          .doc(stateName)
          .collection(stateName!)
          .doc(_selectedProgramManagerId)
          .get();

      if (!snapshot.exists) return [];
      final email = snapshot.data()?['email'] as String?;
      return email == null ? [] : [DropdownMenuItem(value: email, child: Text(email))];
    } catch (e) {
      debugPrint("Error fetching program manager email: $e");
      return [];
    }
  }

  // --- DATA FETCHING (Using your provided logic) ---

  Future<List<String>> _fetchStaffCategoryFromFirestore() async {
    try {
      final snapshot = await _firestore.collection('StaffCategory').get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching staff categories: $e');
      return [];
    }
  }

  Future<List<String>> _fetchProjectFromFirestore() async {
    try {
      final snapshot = await _firestore.collection('Project').get();
      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchStatesBasedOnCategory() async {
    try {
      Query query = _firestore.collection("Location");
      if (_selectedCategory == "Facility Staff" || _selectedCategory == "State Office Staff" || _selectedCategory == "Facility Supervisor") {
        query = query.where('name', isNotEqualTo: "Federal Capital Territory");
      } else if (_selectedCategory == "HQ Staff") {
        query = query.where('name', isEqualTo: "Federal Capital Territory");
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Value is the Document ID
          child: Text(doc['name'] as String? ?? 'No Name'),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching states: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchLocations() async {
    if (stateName == null) return [];
    try {
      String locationCategory;
      if (_selectedCategory == "Facility Staff" || _selectedCategory == "Facility Supervisor") {
        locationCategory = "Facility";
      } else if (_selectedCategory == "State Office Staff") {
        locationCategory = "State Office";
      } else {
        locationCategory = "HQ";
      }

      final snapshot = await _firestore.collection("Location").doc(stateName).collection(stateName!).where("category", isEqualTo: locationCategory).get();

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Value is the Document ID
          child: Text(doc['LocationName'] as String? ?? 'No Name'),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching locations: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchDepartments() async {
    try {
      final snapshot = await _firestore.collection("Designation").get();
      List<String> allowedForFacility = ["Care and Treatment", "Preventions","Admin", "Laboratory", "Strategic Information", "Pharmacy and Logistics", "Orphan and Vulnerable Children (OVC)"];

      return snapshot.docs
          .where((doc) => _selectedCategory != "Facility Staff" && _selectedCategory != "Facility Supervisor" || allowedForFacility.contains(doc.id))
          .map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Value is the Department Name (which is the Doc ID)
          child: Text(doc.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching departments: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchDesignations() async {
    if (departmentName == null) return [];
    try {
      String designationCategory = (_selectedCategory == "Facility Staff" || _selectedCategory == "Facility Supervisor") ? "Facility Staff" : "Office Staff";
      final snapshot = await _firestore.collection("Designation").doc(departmentName).collection(departmentName!).where("category", isEqualTo: designationCategory).get();

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Value is the Designation Name (which is the Doc ID)
          child: Text(doc.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching designations: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchSupervisors() async {
    if (stateName == null || departmentName == null) return [];
    try {
      final snapshot = await _firestore.collection("Supervisors").doc(stateName).collection(stateName!).where("department", isEqualTo: departmentName).get();
      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Value is the Supervisor Name (which is the Doc ID)
          child: Text(doc.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching supervisors: $e');
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchSupervisorEmails() async {
    if (stateName == null || departmentName == null || supervisorName == null) return [];
    try {
      final snapshot = await _firestore.collection("Supervisors").doc(stateName).collection(stateName!).where("department", isEqualTo: departmentName).where(FieldPath.documentId, isEqualTo: supervisorName).get();
      if(snapshot.docs.isEmpty) return [];
      final email = snapshot.docs.first.data()['email'] as String?;
      if (email == null) return [];
      return [ DropdownMenuItem(value: email, child: Text(email)) ];
    } catch (e) {
      debugPrint('Error fetching supervisor email: $e');
      return [];
    }
  }

  // Add this new helper method inside the _RegistrationPageWebState class
  Future<void> _showResultDialog({
    required String title,
    required String content,
    VoidCallback? onOkPressed,
  }) async {
    // Ensure we are on the right context if the widget is no longer mounted
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                onOkPressed?.call(); // Execute the callback if it exists
              },
            ),
          ],
        );
      },
    );
  }

  // --- ACTIONS ---


  Future<void> _pickProfileImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _profileImageBytes = result.files.first.bytes);
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImageBytes == null) return null;
    try {
      String fileName = 'profile_pics/$userId/profile.jpg';
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(_profileImageBytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      setState(() => _errorMessage = 'Error uploading profile image.');
      return null;
    }
  }

  // --- REGISTRATION LOGIC (THE MAIN FIX) ---


  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showResultDialog(
        title: 'Validation Error',
        content: "Please fix the errors above before proceeding.",
      );
      return;
    }
    if (!_termsAgreed) {
      _showResultDialog(
        title: 'Terms and Conditions',
        content: "You must agree to the terms and conditions to register.",
      );
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("User creation failed.");

      final photoUrl = await _uploadProfileImage(user.uid);

      String finalStateName = '';
      if (stateName != null) {
        final doc = await _firestore.collection('Location').doc(stateName).get();
        finalStateName = doc.data()?['name'] as String? ?? stateName!;
      }

      String finalLocationName = '';
      if (stateName != null && locationName != null) {
        final doc = await _firestore.collection('Location').doc(stateName).collection(stateName!).doc(locationName).get();
        finalLocationName = doc.data()?['LocationName'] as String? ?? locationName!;
      }

      final creatorName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

      await _firestore.collection('Staff').doc(user.uid).set({
        'id': user.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'emailAddress': _emailController.text.trim(),
        'mobile': _mobileNumberController.text.trim(),
        'staffCategory': _selectedCategory ?? '',
        'project': _selectedProject ?? '',
        'state': finalStateName,
        'location': finalLocationName,
        'department': departmentName ?? '',
        'designation': designation ?? '',
        'supervisor': supervisorName ?? _supervisorNameController.text.trim(),
        'supervisorEmail': supervisorEmail ?? _supervisorEmailController.text.trim(),
        'role': _selectedRole ?? '',
        'gender': _selectedGender ?? '',
        'maritalStatus': _selectedMaritalStatus ?? '',
        'photoUrl': photoUrl ?? '',
        'isVerified': user.emailVerified,
        'disabled': false,
        'createdDate': FieldValue.serverTimestamp(),
        'lastUpdateDate': FieldValue.serverTimestamp(),

        // --- ADDED FIELDS ---
        'bankName': _selectedBankName ?? '',
        'accountNumber': _accountNumberController.text.trim(),
        'sortCode': _sortCodeController.text.trim(),
        'programManager': _selectedProgramManagerId ?? '',
        'programManagerEmail': _selectedProgramManagerEmail ?? '',
        'createdBy': creatorName,
        'createdByEmail': _emailController.text.trim(),
      });

      await _showResultDialog(
        title: 'Registration Successful',
        content: 'Your account has been created. You will now be taken to the login page.',
        onOkPressed: () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
            );
          }
        },
      );

    } on FirebaseAuthException catch (e) {
      await _showResultDialog(
        title: 'Registration Failed',
        content: e.message ?? 'An unknown authentication error occurred.',
      );
    } catch (e) {
      await _showResultDialog(
        title: 'An Error Occurred',
        content: 'An unexpected error occurred during registration: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- WIDGET BUILDERS (Using your structure) ---

  List<String> _getRoleOptions(String? staffCategory) {
    if (staffCategory == 'Facility Supervisor') return ['Facility Supervisor'];
    if (staffCategory == 'Facility Staff') return ['User'];
    if (staffCategory == 'State Office Staff') return ['State Office Staff'];
    if (staffCategory == 'HQ Staff') return ['HQ Staff'];
    return []; // Return empty if no category is selected
  }

  @override
  Widget build(BuildContext context) {
    // Your entire build method, including desktop/mobile layouts, can remain the same.
    // The following is a simplified version for brevity, you should use your existing build method.
    // I am pasting your full build method here to ensure it's complete.
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
              padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth > 760;
                  final double containerWidth = isDesktop ? 800 : constraints.maxWidth;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    child: Container(
                      width: containerWidth,
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/image/caritaslogo1.png', height: 80),
                            const SizedBox(height: 16),
                            const Text('Create Your Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Fill in the details below to get started', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                            const SizedBox(height: 32),
                            GestureDetector(
                              onTap: _pickProfileImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                                child: _profileImageBytes == null ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade700) : null,
                              ),
                            ),
                            const SizedBox(height: 32),

                            if (isDesktop) _buildDesktopLayout() else _buildMobileLayout(),

                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Checkbox(
                                  value: _termsAgreed,
                                  onChanged: (bool? value) => setState(() => _termsAgreed = value ?? false),
                                ),
                                const Expanded(
                                  child: Text('I agree to the Terms and Conditions'),
                                ),
                              ],
                            ),
                            // if (_errorMessage.isNotEmpty)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 16.0),
                            //     child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),
                            //   ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ));
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // --- Personal Info Rows (No change) ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildStyledTextField(controller: _firstNameController, label: "First Name", icon: Icons.person)),
            const SizedBox(width: 20),
            Expanded(child: _buildStyledTextField(controller: _lastNameController, label: "Last Name", icon: Icons.person)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildStyledTextField(controller: _emailController, label: "Email Address", icon: Icons.email, keyboardType: TextInputType.emailAddress)),
            const SizedBox(width: 20),
            Expanded(child: _buildStyledTextField(controller: _mobileNumberController, label: "Mobile Number", icon: Icons.phone_android, keyboardType: TextInputType.number, validator: (v) {
              if (v == null || v.isEmpty) return 'Required'; if (v.length < 10) return 'Enter a valid number'; return null;
            })),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildStyledDropdown(label: "Gender", value: _selectedGender, items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => _selectedGender = v))),
            const SizedBox(width: 20),
            Expanded(child: _buildStyledDropdown(label: "Marital Status", value: _selectedMaritalStatus, items: _maritalStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedMaritalStatus = v))),
          ],
        ),
        const SizedBox(height: 20),

        // --- NEW: BANKING DETAILS ROW ---
        const Text("Banking Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildFutureDropdown(label: "Bank Name", future: _fetchBanks(), value: _selectedBankName, onChanged: (v) => setState(() => _selectedBankName = v))),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: _buildStyledTextField(controller: _accountNumberController, label: "Account Number", icon: Icons.numbers, keyboardType: TextInputType.number)),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildStyledTextField(controller: _sortCodeController, label: "Sort Code", icon: Icons.pin, keyboardType: TextInputType.number, validator: (v) => null)),
          ],
        ),
        const SizedBox(height: 20),

        const Text("Professional Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),

        _buildDependentFields(),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _passwordController, label: "Password", icon: Icons.lock, obscureText: _isPasswordObscured, suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured))),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // --- Personal Info (No change) ---
        _buildStyledTextField(controller: _firstNameController, label: "First Name", icon: Icons.person),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _lastNameController, label: "Last Name", icon: Icons.person),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _emailController, label: "Email Address", icon: Icons.email, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _mobileNumberController, label: "Mobile Number", icon: Icons.phone_android, keyboardType: TextInputType.number, validator: (v) {
          if (v == null || v.isEmpty) return 'Required'; if (v.length < 10) return 'Enter a valid number'; return null;
        }),
        const SizedBox(height: 20),
        _buildStyledDropdown(label: "Gender", value: _selectedGender, items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => _selectedGender = v)),
        const SizedBox(height: 20),
        _buildStyledDropdown(label: "Marital Status", value: _selectedMaritalStatus, items: _maritalStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedMaritalStatus = v)),
        const SizedBox(height: 20),

        // --- NEW: BANKING DETAILS FOR MOBILE ---
        const Text("Banking Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        _buildFutureDropdown(label: "Bank Name", future: _fetchBanks(), value: _selectedBankName, onChanged: (v) => setState(() => _selectedBankName = v)),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _accountNumberController, label: "Account Number", icon: Icons.numbers, keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _sortCodeController, label: "Sort Code (Optional)", icon: Icons.pin, keyboardType: TextInputType.number, validator: (v) => null),
        const SizedBox(height: 20),

        const Text("Professional Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),

        _buildDependentFields(),
        const SizedBox(height: 20),
        _buildStyledTextField(controller: _passwordController, label: "Password", icon: Icons.lock, obscureText: _isPasswordObscured, suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured))),
      ],
    );
  }

  Widget _buildDependentFields() {
    return Column(
      children: [
        FutureBuilder<List<String>>(
          future: _fetchStaffCategoryFromFirestore(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            return _buildStyledDropdown<String>(label: "Staff Category", value: _selectedCategory, items: (snapshot.data ?? []).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) => setState(() {
                _selectedCategory = value; _selectedRole = null; stateName = null; locationName = null; departmentName = null; designation = null; supervisorName = null; supervisorEmail = null;
              }),
            );
          },
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<String>>(
          future: _fetchProjectFromFirestore(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            return _buildStyledDropdown<String>(label: "Project", value: _selectedProject, items: (snapshot.data ?? []).map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => _selectedProject = value),
            );
          },
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "State", future: _fetchStatesBasedOnCategory(), value: stateName,
            onChanged: (v) => setState(() {
              stateName = v; locationName = null; departmentName = null; designation = null; supervisorName = null; supervisorEmail = null;
              // Reset program manager when state changes
              _selectedProgramManagerId = null;
              _selectedProgramManagerEmail = null;
            }),
          ),
        ],
        if (stateName != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Location", future: _fetchLocations(), value: locationName,
            onChanged: (v) => setState(() {
              locationName = v; departmentName = null; designation = null; supervisorName = null; supervisorEmail = null;
            }),
          ),
        ],
        if (locationName != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Department", future: _fetchDepartments(), value: departmentName,
            onChanged: (v) => setState(() {
              departmentName = v; designation = null; supervisorName = null; supervisorEmail = null;
            }),
          ),
        ],
        if (departmentName != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Designation", future: _fetchDesignations(), value: designation,
            onChanged: (v) => setState(() {
              designation = v; supervisorName = null; supervisorEmail = null;
            }),
          ),
        ],
        // --- NEW: ADD PROGRAM MANAGER DROPDOWNS ---
        if (designation != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Program Manager Name", future: _fetchProgramManagers(), value: _selectedProgramManagerId,
            onChanged: (v) async {
              setState(() {
                _selectedProgramManagerId = v;
                _selectedProgramManagerEmail = null; // Reset email
              });
              // Auto-fetch and select the email
              final emails = await _fetchProgramManagerEmails();
              if (emails.isNotEmpty) {
                setState(() => _selectedProgramManagerEmail = emails.first.value);
              }
            },
          ),
        ],
        if (_selectedProgramManagerId != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Program Manager Email", future: _fetchProgramManagerEmails(), value: _selectedProgramManagerEmail,
            onChanged: (v) => setState(() => _selectedProgramManagerEmail = v),
          ),
        ],
        if (designation != null && _selectedCategory != 'Facility Supervisor') ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Supervisor Name", future: _fetchSupervisors(), value: supervisorName,
            onChanged: (v) => setState(() {
              supervisorName = v; supervisorEmail = null;
            }),
          ),
        ],
        if (supervisorName != null) ...[
          const SizedBox(height: 20),
          _buildFutureDropdown(label: "Supervisor Email", future: _fetchSupervisorEmails(), value: supervisorEmail,
            onChanged: (v) => setState(() => supervisorEmail = v),
          ),
        ],
        if (_selectedCategory == 'Facility Supervisor') ...[
          const SizedBox(height: 20),
          _buildStyledTextField(controller: _supervisorNameController, label: 'Supervisor Name (Manual)', icon: Icons.person_search),
          const SizedBox(height: 20),
          _buildStyledTextField(controller: _supervisorEmailController, label: 'Supervisor Email (Manual)', icon: Icons.alternate_email, keyboardType: TextInputType.emailAddress),
        ],

        if (_selectedCategory != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(label: "Role", value: _selectedRole, items: _getRoleOptions(_selectedCategory).map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
        ]
      ],
    );
  }

  Widget _buildStyledTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, bool obscureText = false, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?)? onChanged, String? hint}) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select an option' : null,
      decoration: InputDecoration(
        labelText: label, hintText: hint, filled: true, fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      ),
      isExpanded: true,
    );
  }

  Widget _buildFutureDropdown({required String label, required Future<List<DropdownMenuItem<String>>> future, required String? value, required void Function(String?) onChanged}) {
    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildStyledDropdown<String>(label: label, value: null, items: [], onChanged: null, hint: 'No options available');
        }
        return _buildStyledDropdown<String>(label: label, value: value, items: snapshot.data!, onChanged: onChanged);
      },
    );
  }
}