import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../../models/staff.dart'; // Ensure this path is correct

class UserFormScreen extends StatefulWidget {
  final Staff? staff;

  const UserFormScreen({
    super.key,
    this.staff,
  });

  @override
  _UserFormScreenState createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  bool get _isEditMode => widget.staff != null;

  // --- STATE MANAGEMENT ---

  // Controllers for text fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _supervisorNameController = TextEditingController();
  final _supervisorEmailController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _sortCodeController = TextEditingController();

  // State for UI and data
  bool _isLoading = false; // For the save button's spinner
  bool _isInitializing = true; // For the initial page load spinner
  Uint8List? _profileImageBytes;
  String? _existingPhotoUrl;

  // State for dropdown selections (holds IDs or direct values)
  String? _selectedCategory;
  String? _selectedProject;
  String? _selectedStateId;
  String? _selectedLocationId;
  String? _selectedDepartmentName;
  String? _selectedDesignationName;
  String? _selectedSupervisorId;
  String? _selectedSupervisorEmail;
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _selectedRole;
  String? _selectedBankName;
  String? _selectedProgramManagerId;
  String? _selectedProgramManagerEmail;

  // State to hold the pre-fetched lists of items for our dropdowns
  List<String> _staffCategoryOptions = [];
  List<String> _projectOptions = [];
  List<DropdownMenuItem<String>> _statesList = [];
  List<DropdownMenuItem<String>> _locationsList = [];
  List<DropdownMenuItem<String>> _departmentsList = [];
  List<DropdownMenuItem<String>> _designationsList = [];
  List<DropdownMenuItem<String>> _supervisorsList = [];
  List<DropdownMenuItem<String>> _supervisorEmailsList = [];
  List<DropdownMenuItem<String>> _banksList = [];
  // ADD these two new lists for the Program Manager dropdowns
  List<DropdownMenuItem<String>> _programManagersList = [];
  List<DropdownMenuItem<String>> _programManagerEmailsList = [];
  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _maritalStatusOptions = ['Single', 'Married', 'Divorced', 'Widowed'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _initializeEditForm();
    } else {
      _isInitializing = false;
    }
  }

  /// Fetches supervisors specifically from the "Program Management" department.
  Future<List<DropdownMenuItem<String>>> _fetchProgramManagers() async {
    if (_selectedStateId == null) return [];

    try {
      final snapshot = await _firestore
          .collection("Supervisors")
          .doc(_selectedStateId)
          .collection(_selectedStateId!)
          .where("department", isEqualTo: "Program Management")
          .get();

      if (snapshot.docs.isEmpty) return [];

      final managers = snapshot.docs.map((doc) {
        final supervisorName = doc.id;
        return DropdownMenuItem<String>(
          value: supervisorName,
          child: Text(supervisorName),
        );
      }).toList();

      managers.sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!));
      return managers;
    } catch (e) {
      debugPrint("Error fetching program managers: $e");
      return [];
    }
  }

  /// Fetches the email for the selected Program Manager.
  Future<List<DropdownMenuItem<String>>> _fetchProgramManagerEmails() async {
    if (_selectedProgramManagerId == null || _selectedStateId == null) return [];

    try {
      final snapshot = await _firestore
          .collection("Supervisors")
          .doc(_selectedStateId)
          .collection(_selectedStateId!)
          .doc(_selectedProgramManagerId)
          .get();

      if (!snapshot.exists) return [];

      final email = snapshot.data()?['email'] as String?;

      return email == null
          ? []
          : [DropdownMenuItem<String>(value: email, child: Text(email))];
    } catch (e) {
      debugPrint("Error fetching program manager email: $e");
      return [];
    }
  }

  /// The main function to pre-fetch all data and set initial values for Edit Mode.
  Future<void> _initializeEditForm() async {
    final staff = widget.staff!;

    // 1. Populate simple fields immediately
    _firstNameController.text = staff.firstName;
    _lastNameController.text = staff.lastName;
    _emailController.text = staff.emailAddress;
    _mobileNumberController.text = staff.mobile;
    _accountNumberController.text = staff.accountNumber;
    _sortCodeController.text = staff.sortCode;
    _existingPhotoUrl = staff.photoUrl;
    _selectedGender = staff.gender;
    _selectedMaritalStatus = staff.maritalStatus;
    _selectedCategory = staff.staffCategory;
    _selectedProject = staff.project;
    _selectedRole = staff.role;
    _selectedDepartmentName = staff.department;
    _selectedDesignationName = staff.designation;
    _selectedProgramManagerId = staff.programManager;
    _selectedProgramManagerEmail = staff.programManagerEmail;
    _selectedBankName = staff.bankName;

    // 2. Fetch all top-level (non-dependent) dropdown lists
    _staffCategoryOptions = await _fetchStringList('StaffCategory', 'name');
    _projectOptions = await _fetchStringList('Project', 'name');
    _departmentsList = await _fetchDepartments();
    _designationsList = await _fetchDesignations();
    _banksList = await _fetchBanks();

    // 3. Waterfall dependent dropdowns
    if (_selectedCategory != null) {
      _statesList = await _fetchStatesBasedOnCategory();
      final foundStateId = await _reverseLookupId('Location', 'name', staff.state);
      if (foundStateId != null) {
        _selectedStateId = foundStateId;
        _programManagersList = await _fetchProgramManagers();
        _locationsList = await _fetchLocations();
        final foundLocationId = await _reverseLookupId(
          'Location/$_selectedStateId/$_selectedStateId',
          'LocationName',
          staff.location,
        );
        if (foundLocationId != null) {
          _selectedLocationId = foundLocationId;
        }
      }
    }

    // Program manager email pre-populate
    if (_selectedProgramManagerId != null) {
      _programManagerEmailsList = await _fetchProgramManagerEmails();
    }

    // Supervisors (depends on state and department)
    if (staff.supervisor.isNotEmpty && _selectedDepartmentName != null) {
      _supervisorsList = await _fetchSupervisors();

      String? supervisorToFind;
      final stateSupDoc = _selectedStateId != null
          ? await _firestore
          .collection("Supervisors")
          .doc(_selectedStateId)
          .collection(_selectedStateId!)
          .doc(staff.supervisor)
          .get()
          : null;
      if (stateSupDoc?.exists ?? false) {
        supervisorToFind = staff.supervisor;
      } else {
        final hqStateQuery = await _firestore
            .collection("Location")
            .where("name", isEqualTo: "Federal Capital Territory")
            .limit(1)
            .get();
        if (hqStateQuery.docs.isNotEmpty) {
          final hqStateId = hqStateQuery.docs.first.id;
          final hqSupDoc = await _firestore
              .collection("Supervisors")
              .doc(hqStateId)
              .collection(hqStateId)
              .doc(staff.supervisor)
              .get();
          if (hqSupDoc.exists) {
            supervisorToFind = "${staff.supervisor}|$hqStateId";
          }
        }
      }

      if (supervisorToFind != null) {
        _selectedSupervisorId = supervisorToFind;
        _supervisorEmailsList = await _fetchSupervisorEmails();
        _selectedSupervisorEmail = staff.supervisorEmail;
      } else {
        _supervisorNameController.text = staff.supervisor;
        _supervisorEmailController.text = staff.supervisorEmail;
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // --- NEW: FETCH BANKS METHOD ---
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

  /// Helper to find a document's ID from its human-readable name field.
  Future<String?> _reverseLookupId(
      String collectionPath, String field, String value) async {
    if (value.isEmpty) return null;
    try {
      final snapshot = await _firestore
          .collection(collectionPath)
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null;
    } catch (e) {
      return null;
    }
  }

  // --- DATA FETCHING METHODS ---
  Future<List<String>> _fetchStringList(String collection, String field) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      return snapshot.docs.map((doc) => doc[field] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchStatesBasedOnCategory() async {
    if (_selectedCategory == null) return [];
    try {
      Query query = _firestore.collection("Location");
      if (_selectedCategory == "Facility Staff" ||
          _selectedCategory == "State Office Staff" ||
          _selectedCategory == "Facility Supervisor") {
        query = query.where('name', isNotEqualTo: "Federal Capital Territory");
      } else if (_selectedCategory == "HQ Staff") {
        query = query.where('name', isEqualTo: "Federal Capital Territory");
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => DropdownMenuItem<String>(
        value: doc.id,
        child: Text(doc['name'] as String? ?? ''),
      ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchLocations() async {
    if (_selectedStateId == null || _selectedCategory == null) return [];
    try {
      String cat =
      (_selectedCategory == "Facility Staff" || _selectedCategory == "Facility Supervisor")
          ? "Facility"
          : (_selectedCategory == "State Office Staff" ? "State Office" : "HQ");
      final snapshot = await _firestore
          .collection("Location")
          .doc(_selectedStateId)
          .collection(_selectedStateId!)
          .where("category", isEqualTo: cat)
          .get();
      return snapshot.docs
          .map((doc) => DropdownMenuItem<String>(
        value: doc.id,
        child: Text(doc['LocationName'] as String? ?? ''),
      ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchDepartments() async {
    if (_selectedCategory == null) return [];
    try {
      final snapshot = await _firestore.collection("Designation").get();
      List<String> allowedForFacility = [
        "Care and Treatment",
        "Preventions",
        "Admin",
        "Laboratory",
        "Strategic Information",
        "Pharmacy and Logistics",
        "Orphan and Vulnerable Children (OVC)"
      ];
      return snapshot.docs
          .where((doc) =>
      _selectedCategory != "Facility Staff" &&
          _selectedCategory != "Facility Supervisor" ||
          allowedForFacility.contains(doc.id))
          .map((doc) =>
          DropdownMenuItem<String>(value: doc.id, child: Text(doc.id)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchDesignations() async {
    if (_selectedDepartmentName == null) return [];
    try {
      String designationCategory =
      (_selectedCategory == "Facility Staff" || _selectedCategory == "Facility Supervisor")
          ? "Facility Staff"
          : "Office Staff";
      final snapshot = await _firestore
          .collection("Designation")
          .doc(_selectedDepartmentName)
          .collection(_selectedDepartmentName!)
          .where("category", isEqualTo: designationCategory)
          .get();
      return snapshot.docs
          .map((doc) =>
          DropdownMenuItem<String>(value: doc.id, child: Text(doc.id)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchSupervisors() async {
    if (_selectedDepartmentName == null) return [];
    if (_selectedStateId == null && _selectedCategory != 'HQ Staff') return [];

    try {
      final Set<DropdownMenuItem<String>> allSupervisors = {};

      if (_selectedStateId != null) {
        final stateSupervisorsSnapshot = await _firestore
            .collection("Supervisors")
            .doc(_selectedStateId)
            .collection(_selectedStateId!)
            .where("department", isEqualTo: _selectedDepartmentName)
            .get();

        for (var doc in stateSupervisorsSnapshot.docs) {
          allSupervisors.add(DropdownMenuItem<String>(
            value: doc.id,
            child: Text(doc.id),
          ));
        }
      }

      if (_selectedCategory == "State Office Staff") {
        final hqStateQuery = await _firestore
            .collection("Location")
            .where("name", isEqualTo: "Federal Capital Territory")
            .limit(1)
            .get();

        if (hqStateQuery.docs.isNotEmpty) {
          final hqStateId = hqStateQuery.docs.first.id;
          final hqSupervisorsSnapshot = await _firestore
              .collection("Supervisors")
              .doc(hqStateId)
              .collection(hqStateId)
              .where("department", isEqualTo: _selectedDepartmentName)
              .get();

          for (var doc in hqSupervisorsSnapshot.docs) {
            allSupervisors.add(DropdownMenuItem<String>(
              value: "${doc.id}|$hqStateId",
              child: Text("${doc.id} (HQ)"),
            ));
          }
        }
      }

      final sortedList = allSupervisors.toList()
        ..sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!));

      return sortedList;
    } catch (e) {
      return [];
    }
  }

  Future<List<DropdownMenuItem<String>>> _fetchSupervisorEmails() async {
    if (_selectedSupervisorId == null || _selectedDepartmentName == null) return [];

    try {
      String supervisorIdToQuery;
      String stateIdToQuery;

      if (_selectedSupervisorId!.contains('|')) {
        final parts = _selectedSupervisorId!.split('|');
        supervisorIdToQuery = parts[0];
        stateIdToQuery = parts[1];
      } else {
        supervisorIdToQuery = _selectedSupervisorId!;
        stateIdToQuery = _selectedStateId!;
      }

      final snapshot = await _firestore
          .collection("Supervisors")
          .doc(stateIdToQuery)
          .collection(stateIdToQuery)
          .doc(supervisorIdToQuery)
          .get();

      if (!snapshot.exists) return [];
      final email = snapshot.data()?['email'] as String?;
      return email == null
          ? []
          : [DropdownMenuItem<String>(value: email, child: Text(email))];
    } catch (e) {
      return [];
    }
  }

  // --- ACTIONS ---

  Future<void> _pickProfileImage() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _profileImageBytes = result.files.first.bytes);
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      _showResultDialog(title: 'Validation Error', content: "Please fix the errors above.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      // --- NEW: Get logged-in user details for tracking ---
      String createdBy = 'Unknown User';
      String createdByEmail = 'Unknown Email';
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && currentUser.email != null) {
        createdByEmail = currentUser.email!;
        final staffDoc = await _firestore
            .collection('Staff')
            .where('emailAddress', isEqualTo: currentUser.email!)
            .limit(1)
            .get();
        if (staffDoc.docs.isNotEmpty) {
          final staffData = staffDoc.docs.first.data();
          createdBy = '${staffData['firstName']} ${staffData['lastName']}';
        } else {
          createdBy = currentUser.displayName ?? currentUser.email!;
        }
      }

      String? finalPhotoUrl = _existingPhotoUrl;
      if (_profileImageBytes != null) {
        String userId = widget.staff!.id;
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('profile_pics/$userId/profile.jpg');
        await ref.putData(_profileImageBytes!);
        finalPhotoUrl = await ref.getDownloadURL();
      }

      String finalStateName = '';
      if (_selectedStateId != null) {
        final doc =
        await _firestore.collection('Location').doc(_selectedStateId).get();
        finalStateName = doc.data()?['name'] as String? ?? '';
      }
      String finalLocationName = '';
      if (_selectedStateId != null && _selectedLocationId != null) {
        final doc = await _firestore
            .collection('Location')
            .doc(_selectedStateId)
            .collection(_selectedStateId!)
            .doc(_selectedLocationId)
            .get();
        finalLocationName = doc.data()?['LocationName'] as String? ?? '';
      }

      final dataToSave = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'mobile': _mobileNumberController.text.trim(),
        'bankName': _selectedBankName ?? '',
        'accountNumber': _accountNumberController.text.trim(),
        'sortCode': _sortCodeController.text.trim(),
        'staffCategory': _selectedCategory ?? '',
        'project': _selectedProject ?? '',
        'state': finalStateName,
        'location': finalLocationName,
        'department': _selectedDepartmentName ?? '',
        'designation': _selectedDesignationName ?? '',
        'supervisor': (_selectedSupervisorId?.contains('|') ?? false)
            ? _selectedSupervisorId!.split('|')[0]
            : (_selectedSupervisorId ?? _supervisorNameController.text.trim()),
        'supervisorEmail':
        _selectedSupervisorEmail ?? _supervisorEmailController.text.trim(),
        'role': _selectedRole ?? '',
        'gender': _selectedGender ?? '',
        'maritalStatus': _selectedMaritalStatus ?? '',
        'photoUrl': finalPhotoUrl ?? '',
        'lastUpdateDate': FieldValue.serverTimestamp(),
        'programManager': _selectedProgramManagerId ?? '',
        'programManagerEmail': _selectedProgramManagerEmail ?? '',
        'lastUpdatedBy': createdBy,
        'lastUpdatedByEmail': createdByEmail,
      };

      final staffDocRef =
      _firestore.collection('Staff').doc(widget.staff!.id);
      final currentStaffDoc = await staffDocRef.get();
      if (!currentStaffDoc.exists || currentStaffDoc.data()?['createdBy'] == null) {
        dataToSave['createdBy'] = createdBy;
        dataToSave['createdByEmail'] = createdByEmail;
      }

      await staffDocRef.update(dataToSave);

      await _showResultDialog(
          title: 'Success',
          content: 'User profile has been updated successfully.',
          onOkPressed: () => Navigator.of(context).pop());
    } catch (e) {
      await _showResultDialog(
          title: 'Error', content: 'An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResultDialog(
      {required String title,
        required String content,
        VoidCallback? onOkPressed}) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                onOkPressed?.call();
              },
            ),
          ],
        );
      },
    );
  }

  List<String> _getRoleOptions(String? staffCategory) {
    if (staffCategory == 'Facility Supervisor') return ['Facility Supervisor'];
    if (staffCategory == 'Facility Staff') return ['User'];
    if (staffCategory == 'State Office Staff') return ['State Office Staff'];
    if (staffCategory == 'HQ Staff') return ['HQ Staff'];
    return [];
  }

  // --- UI BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_profileImageBytes != null) {
      avatarImage = MemoryImage(_profileImageBytes!);
    } else if ((_existingPhotoUrl ?? '').isNotEmpty) {
      avatarImage = NetworkImage(_existingPhotoUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Staff Profile' : 'Create Staff'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.black87,
              Colors.white,
              Colors.yellow.shade600
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isInitializing
            ? const Center(
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 4))
            : Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                vertical: 32.0, horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 760;
                final containerWidth =
                isDesktop ? 800.0 : constraints.maxWidth;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  child: Container(
                    width: containerWidth,
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isEditMode
                                ? 'Update Details for\n${widget.staff!.fullName}'
                                : 'New Account',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Icon(Icons.camera_alt,
                                  size: 40,
                                  color: Colors.grey.shade700)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (isDesktop)
                            _buildDesktopLayout()
                          else
                            _buildMobileLayout(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Text(
                                'Save Changes',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
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
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildStyledTextField(
                    controller: _firstNameController,
                    label: "First Name",
                    icon: Icons.person)),
            const SizedBox(width: 20),
            Expanded(
                child: _buildStyledTextField(
                    controller: _lastNameController,
                    label: "Last Name",
                    icon: Icons.person)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildStyledTextField(
                    controller: _emailController,
                    label: "Email Address",
                    icon: Icons.email,
                    enabled: false)),
            const SizedBox(width: 20),
            Expanded(
                child: _buildStyledTextField(
                    controller: _mobileNumberController,
                    label: "Mobile Number",
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildStyledDropdown<String>(
                label: "Gender",
                value: _selectedGender,
                items: _genderOptions
                    .map((g) =>
                    DropdownMenuItem<String>(value: g, child: Text(g)))
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _selectedGender = v),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStyledDropdown<String>(
                label: "Marital Status",
                value: _selectedMaritalStatus,
                items: _maritalStatusOptions
                    .map((s) =>
                    DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _selectedMaritalStatus = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Banking Information",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildStyledDropdown<String>(
                label: "Bank Name",
                value: _selectedBankName,
                items: _banksList,
                onChanged: (String? v) => setState(() => _selectedBankName = v),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _buildStyledTextField(
                  controller: _accountNumberController,
                  label: "Account Number",
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _buildStyledTextField(
                  controller: _sortCodeController,
                  label: "Sort Code",
                  icon: Icons.pin,
                  keyboardType: TextInputType.number,
                  validator: (v) => null),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Professional Information",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        _buildDependentFields(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildStyledTextField(
            controller: _firstNameController,
            label: "First Name",
            icon: Icons.person),
        const SizedBox(height: 20),
        _buildStyledTextField(
            controller: _lastNameController, label: "Last Name", icon: Icons.person),
        const SizedBox(height: 20),
        _buildStyledTextField(
            controller: _emailController,
            label: "Email Address",
            icon: Icons.email,
            enabled: false),
        const SizedBox(height: 20),
        _buildStyledTextField(
            controller: _mobileNumberController,
            label: "Mobile Number",
            icon: Icons.phone_android,
            keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        _buildStyledDropdown<String>(
          label: "Gender",
          value: _selectedGender,
          items: _genderOptions
              .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
              .toList(),
          onChanged: (String? v) => setState(() => _selectedGender = v),
        ),
        const SizedBox(height: 20),
        _buildStyledDropdown<String>(
          label: "Marital Status",
          value: _selectedMaritalStatus,
          items: _maritalStatusOptions
              .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
              .toList(),
          onChanged: (String? v) => setState(() => _selectedMaritalStatus = v),
        ),
        const SizedBox(height: 20),
        const Text("Banking Information",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        _buildStyledDropdown<String>(
          label: "Bank Name",
          value: _selectedBankName,
          items: _banksList,
          onChanged: (String? v) => setState(() => _selectedBankName = v),
        ),
        const SizedBox(height: 20),
        _buildStyledTextField(
            controller: _accountNumberController,
            label: "Account Number",
            icon: Icons.numbers,
            keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        _buildStyledTextField(
            controller: _sortCodeController,
            label: "Sort Code (Optional)",
            icon: Icons.pin,
            keyboardType: TextInputType.number,
            validator: (v) => null),
        const SizedBox(height: 20),
        const Text("Professional Information",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const Divider(),
        const SizedBox(height: 10),
        _buildDependentFields(),
      ],
    );
  }

  Widget _buildDependentFields() {
    return Column(
      children: [
        _buildStyledDropdown<String>(
          label: "Staff Category",
          value: _selectedCategory,
          items: _staffCategoryOptions
              .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
              .toList(),
          onChanged: (String? value) async {
            setState(() {
              _selectedCategory = value;
              _selectedRole = null;
              _selectedStateId = null;
              _selectedLocationId = null;
              _selectedDepartmentName = null;
              _selectedDesignationName = null;
              _selectedSupervisorId = null;
              _selectedSupervisorEmail = null;
              _statesList = [];
              _locationsList = [];
              _departmentsList = [];
              _designationsList = [];
              _supervisorsList = [];
              _supervisorEmailsList = [];
            });
            _statesList = await _fetchStatesBasedOnCategory();
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 20),
        _buildStyledDropdown<String>(
          label: "Project",
          value: _selectedProject,
          items: _projectOptions
              .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
              .toList(),
          onChanged: (String? value) =>
              setState(() => _selectedProject = value),
        ),
        if (_selectedCategory != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "State",
            value: _selectedStateId,
            items: _statesList,
            onChanged: (String? value) async {
              setState(() {
                _selectedStateId = value;
                _selectedLocationId = null;
                _selectedDepartmentName = null;
                _selectedDesignationName = null;
                _selectedSupervisorId = null;
                _selectedSupervisorEmail = null;
                _locationsList = [];
                _departmentsList = [];
                _designationsList = [];
                _supervisorsList = [];
                _supervisorEmailsList = [];
              });
              _locationsList = await _fetchLocations();
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedStateId != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Location",
            value: _selectedLocationId,
            items: _locationsList,
            onChanged: (String? value) async {
              setState(() {
                _selectedLocationId = value;
                _selectedDepartmentName = null;
                _selectedDesignationName = null;
                _selectedSupervisorId = null;
                _selectedSupervisorEmail = null;
                _departmentsList = [];
                _designationsList = [];
                _supervisorsList = [];
                _supervisorEmailsList = [];
              });
              _departmentsList = await _fetchDepartments();
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedLocationId != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Department",
            value: _selectedDepartmentName,
            items: _departmentsList,
            onChanged: (String? value) async {
              setState(() {
                _selectedDepartmentName = value;
                _selectedDesignationName = null;
                _selectedSupervisorId = null;
                _selectedSupervisorEmail = null;
                _designationsList = [];
                _supervisorsList = [];
                _supervisorEmailsList = [];
              });
              _designationsList = await _fetchDesignations();
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedDepartmentName != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Designation",
            value: _selectedDesignationName,
            items: _designationsList,
            onChanged: (String? value) async {
              setState(() {
                _selectedDesignationName = value;
                _selectedSupervisorId = null;
                _selectedSupervisorEmail = null;
                _supervisorsList = [];
                _supervisorEmailsList = [];
              });
              _supervisorsList = await _fetchSupervisors();
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedDesignationName != null &&
            _selectedCategory != 'Facility Supervisor') ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Supervisor Name",
            value: _selectedSupervisorId,
            items: _supervisorsList,
            onChanged: (String? value) async {
              setState(() {
                _selectedSupervisorId = value;
                _selectedSupervisorEmail = null;
                _supervisorEmailsList = [];
              });
              _supervisorEmailsList = await _fetchSupervisorEmails();
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedSupervisorId != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Supervisor Email",
            value: _selectedSupervisorEmail,
            items: _supervisorEmailsList,
            onChanged: (String? value) =>
                setState(() => _selectedSupervisorEmail = value),
          ),
        ],
        // Program manager dropdowns
        if (_selectedDesignationName != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Program Manager Name",
            value: _selectedProgramManagerId,
            items: _programManagersList,
            onChanged: (String? value) async {
              setState(() {
                _selectedProgramManagerId = value;
                _selectedProgramManagerEmail = null;
                _programManagerEmailsList = [];
              });
              _programManagerEmailsList = await _fetchProgramManagerEmails();
              if (_programManagerEmailsList.isNotEmpty) {
                _selectedProgramManagerEmail =
                    _programManagerEmailsList.first.value;
              }
              if (mounted) setState(() {});
            },
          ),
        ],
        if (_selectedProgramManagerId != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Program Manager Email",
            value: _selectedProgramManagerEmail,
            items: _programManagerEmailsList,
            onChanged: (String? value) =>
                setState(() => _selectedProgramManagerEmail = value),
          ),
        ],
        if (_selectedCategory == 'Facility Supervisor') ...[
          const SizedBox(height: 20),
          _buildStyledTextField(
              controller: _supervisorNameController,
              label: 'Supervisor Name (Manual)',
              icon: Icons.person_search,
              validator: (v) => null),
          const SizedBox(height: 20),
          _buildStyledTextField(
              controller: _supervisorEmailController,
              label: 'Supervisor Email (Manual)',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => null),
        ],
        if (_selectedCategory != null) ...[
          const SizedBox(height: 20),
          _buildStyledDropdown<String>(
            label: "Role",
            value: _selectedRole,
            items: _getRoleOptions(_selectedCategory)
                .map((role) =>
                DropdownMenuItem<String>(value: role, child: Text(role)))
                .toList(),
            onChanged: (String? value) =>
                setState(() => _selectedRole = value),
          ),
        ]
      ],
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator ??
              (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: enabled ? Colors.grey.shade100 : Colors.grey.shade200,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    String? hint,
  }) {
    final bool isValueInItems =
        value != null && items.any((item) => item.value == value);

    final T? dropdownValue = (isValueInItems ? value : null) as T?;

    return DropdownButtonFormField<T>(
      initialValue: dropdownValue,
      items: items,
      onChanged: onChanged,
      validator: (val) => val == null ? 'Please select an option' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      ),
      isExpanded: true,
    );
  }
}
