import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../models/staff.dart';
import '../../models/staff_model.dart';
import '../../utils/my_input_field.dart';

// Helper class to manage dropdown data more effectively
class DropdownItem {
  final String id;
  final String name;
  DropdownItem({required this.id, required this.name});
}

class UserFormScreen extends StatefulWidget {
  final Staff? staff;
  final String? initialStateId;
  final String? initialStateName;

  const UserFormScreen({
    super.key,
    this.staff,
    this.initialStateId,
    this.initialStateName,
  });

  @override
  _UserFormScreenState createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  bool get _isEditMode => widget.staff != null;

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _passwordController = TextEditingController();

  // State variables for form fields and dropdowns
  bool _isLoading = false;
  String _errorMessage = '';

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedStateId;
  String? _selectedStateName;
  String? _selectedLocationId;
  String? _selectedLocationName;
  String? _selectedDepartmentId;
  String? _selectedDepartmentName;
  String? _selectedDesignationId;
  String? _selectedDesignationName;
  String? _selectedSupervisorId;
  String? _selectedSupervisorName;
  String? _selectedSupervisorEmailId;
  String? _selectedSupervisorEmailName;
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String? _selectedRoleId;
  String? _selectedRoleName;

  bool _termsAgreed = true;
  Uint8List? _profileImageBytes;
  String? _existingImageUrl;
  bool _isPasswordObscured = true;

  // Lists to hold fetched dropdown data
  List<DropdownItem> _categories = [];
  List<DropdownItem> _projects = [];
  List<DropdownItem> _states = [];
  List<DropdownItem> _locations = [];
  List<DropdownItem> _departments = [];
  List<DropdownItem> _designations = [];
  List<DropdownItem> _supervisors = [];
  List<DropdownItem> _supervisorEmails = [];
  List<DropdownItem> _roles = [];

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _maritalStatusOptions = ['Single', 'Married', 'Divorced', 'Widowed'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final staff = widget.staff!;
      _firstNameController.text = staff.firstName;
      _lastNameController.text = staff.lastName;
      _emailController.text = staff.emailAddress;
      _mobileNumberController.text = staff.mobile;
      _selectedCategoryName = staff.staffCategory;
      _selectedProjectName = staff.project;
      _selectedStateId = staff.stateId;
      _selectedStateName = staff.state;
      _selectedLocationId = staff.location; // Assuming location name is stored as ID here
      _selectedLocationName = staff.location;
      _selectedDepartmentId = staff.department;
      _selectedDepartmentName = staff.department;
      _selectedDesignationId = staff.designation;
      _selectedDesignationName = staff.designation;
      _selectedSupervisorId = staff.supervisor;
      _selectedSupervisorName = staff.supervisor;
      _selectedSupervisorEmailId = staff.supervisorEmail;
      _selectedSupervisorEmailName = staff.supervisorEmail;
      _selectedGender = staff.gender;
      _selectedMaritalStatus = staff.maritalStatus;
      _selectedRoleName = staff.role;
      _existingImageUrl = staff.photoUrl;

      _loadInitialData();
    } else {
      _selectedStateId = widget.initialStateId;
      _selectedStateName = widget.initialStateName;
      _termsAgreed = false;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final fetchedCategories = await _fetchCollection('StaffCategory', nameField: 'name');
    final fetchedProjects = await _fetchCollection('Project', nameField: 'name');
    if (mounted) {
      setState(() {
        _categories = fetchedCategories;
        _projects = fetchedProjects;
      });
      if (_isEditMode) {
        _resolveInitialIdsForEditMode();
        _loadDependentDataForEditMode();
      }
    }
  }

  void _resolveInitialIdsForEditMode() {
    if (_categories.isNotEmpty && _selectedCategoryName != null) {
      _selectedCategoryId = _categories.firstWhere((c) => c.name == _selectedCategoryName, orElse: () => DropdownItem(id: '', name: '')).id;
    }
    if (_projects.isNotEmpty && _selectedProjectName != null) {
      _selectedProjectId = _projects.firstWhere((p) => p.name == _selectedProjectName, orElse: () => DropdownItem(id: '', name: '')).id;
    }
    if (_selectedRoleName != null) {
      _roles = _getRoleOptions(_selectedCategoryName);
      _selectedRoleId = _roles.firstWhere((r) => r.name == _selectedRoleName, orElse: () => DropdownItem(id: '', name: '')).id;
    }
  }

  Future<void> _loadDependentDataForEditMode() async {
    if (_selectedCategoryName == null) return;
    final fetchedStates = await _fetchStatesBasedOnCategory(_selectedCategoryName!);
    if (mounted) setState(() => _states = fetchedStates);

    if (_selectedStateId != null) {
      final fetchedLocations = await _fetchLocationsForState(_selectedStateId!, _selectedCategoryName!);
      if (mounted) setState(() => _locations = fetchedLocations);
    }
    // Continue for other fields...
  }

  @override
  void dispose() {
    _firstNameController.dispose(); _lastNameController.dispose(); _emailController.dispose();
    _mobileNumberController.dispose(); _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) { setState(() => _errorMessage = "Please fix the errors above."); return; }
    if (!_termsAgreed && !_isEditMode) { setState(() => _errorMessage = 'You must agree to the Terms and Conditions.'); return; }
    if (!_isEditMode && _passwordController.text.trim().length < 6) { setState(() => _errorMessage = 'For new users, password must be at least 6 characters.'); return; }
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      String? imageUrl = _existingImageUrl;
      if (_profileImageBytes != null) {
        String fileName = 'profile_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = firebase_storage.FirebaseStorage.instance.ref().child(fileName);
        await ref.putData(_profileImageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      final dataToSave = Staff(
        id: _isEditMode ? widget.staff!.id : '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        emailAddress: _emailController.text.trim(),
        mobile: _mobileNumberController.text.trim(),
        staffCategory: _selectedCategoryName ?? '',
        project: _selectedProjectName ?? '',
        state: _selectedStateName ?? '',
        stateId: _selectedStateId ?? '',
        location: _selectedLocationName ?? '',
        department: _selectedDepartmentName ?? '',
        designation: _selectedDesignationName ?? '',
        supervisor: _selectedSupervisorName ?? '',
        supervisorEmail: _selectedSupervisorEmailName ?? '',
        role: _selectedRoleName ?? '',
        gender: _selectedGender ?? '',
        maritalStatus: _selectedMaritalStatus ?? '',
        photoUrl: imageUrl ?? '',
      ).toMap();

      if (_isEditMode) {
        await FirebaseFirestore.instance.collection('Staff').doc(widget.staff!.id).update(dataToSave);
      } else {
        final cred = await _auth.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
        await FirebaseFirestore.instance.collection('Staff').doc(cred.user!.uid).set(dataToSave);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User data saved successfully!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) { setState(() => _errorMessage = e.message ?? 'Authentication failed.');
    } catch (e) { setState(() => _errorMessage = 'An error occurred: $e');
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _pickProfileImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) setState(() => _profileImageBytes = result.files.first.bytes);
  }

  Future<List<DropdownItem>> _fetchCollection(String collectionName, {String nameField = 'name'}) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      return snapshot.docs.map((doc) => DropdownItem(id: doc.id, name: doc.data()[nameField] ?? doc.id)).toList();
    } catch (e) { return []; }
  }

  Future<List<DropdownItem>> _fetchStatesBasedOnCategory(String categoryName) async {
    try {
      Query q = FirebaseFirestore.instance.collection("Location");
      if (categoryName == "Facility Staff" || categoryName == "State Office Staff" || categoryName == "Facility Supervisor") {
        q = q.where('name', isNotEqualTo: "Federal Capital Territory");
      } else {
        q = q.where('name', isEqualTo: "Federal Capital Territory");
      }
      final snapshot = await q.get();
      return snapshot.docs.map((doc) => DropdownItem(id: doc.id, name: doc['name'] ?? '')).toList();
    } catch (e) { return []; }
  }

  Future<List<DropdownItem>> _fetchLocationsForState(String stateId, String categoryName) async {
    try {
      Query q = FirebaseFirestore.instance.collection('Location').doc(stateId).collection(stateId);
      if (categoryName == "Facility Staff") q = q.where("category", isEqualTo: "Facility");
      else if (categoryName == "State Office Staff") q = q.where("category", isEqualTo: "State Office");
      else q = q.where("category", isEqualTo: "HQ");
      final snapshot = await q.get();
      return snapshot.docs.map((doc) => DropdownItem(id: doc.id, name: doc['LocationName'] ?? '')).toList();
    } catch (e) { return []; }
  }

  List<DropdownItem> _getRoleOptions(String? categoryName) {
    if (categoryName == 'Facility Supervisor') return [DropdownItem(id: 'Facility Supervisor', name: 'Facility Supervisor')];
    if (categoryName == 'Facility Staff') return [DropdownItem(id: 'User', name: 'User')];
    if (categoryName == 'State Office Staff') return [DropdownItem(id: 'State Office Staff', name: 'State Office Staff')];
    if (categoryName == 'HQ Staff') return [DropdownItem(id: 'HQ Staff', name: 'HQ Staff')];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit User Profile' : 'Create New User')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isEditMode ? 'Update User Details' : 'Create a New Account', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      GestureDetector(onTap: _pickProfileImage, child: CircleAvatar(radius: 60, backgroundColor: Colors.grey.shade200, backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty ? NetworkImage(_existingImageUrl!) : null) as ImageProvider?, child: _profileImageBytes == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty) ? const Icon(Icons.camera_alt, size: 40) : null)),
                      const SizedBox(height: 24),

                      // All fields are now wrapped in MyInputField for consistent styling
                      MyInputField(title: "First Name", hint: "", widget: TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: "Enter first name"), validator: (v) => v!.isEmpty ? 'Required' : null)),
                      const SizedBox(height: 16),
                      MyInputField(title: "Last Name", hint: "", widget: TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: "Enter last name"), validator: (v) => v!.isEmpty ? 'Required' : null)),
                      const SizedBox(height: 16),
                      MyInputField(title: "Email Address", hint: "", widget: TextFormField(controller: _emailController, enabled: !_isEditMode, decoration: const InputDecoration(labelText: "Enter email"), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty || !v.contains('@') ? 'Invalid email' : null)),
                      const SizedBox(height: 16),
                      MyInputField(title: "Mobile Number", hint: "", widget: TextFormField(controller: _mobileNumberController, decoration: const InputDecoration(labelText: "Enter mobile number"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
                      const SizedBox(height: 16),
                      if (!_isEditMode) ...[
                        MyInputField(title: "Password", hint: "", widget: TextFormField(controller: _passwordController, obscureText: _isPasswordObscured, decoration: InputDecoration(labelText: "Enter password", suffixIcon: IconButton(icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured))), validator: (v) => v!.length < 6 ? 'Min 6 characters' : null)),
                        const SizedBox(height: 16),
                      ],
                      MyInputField(title: "Sex", hint: "", widget: DropdownButtonFormField<String>(value: _selectedGender, items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (v) => setState(() => _selectedGender = v), decoration: const InputDecoration(labelText: "Select Sex"))),
                      const SizedBox(height: 16),
                      MyInputField(title: "Marital Status", hint: "", widget: DropdownButtonFormField<String>(value: _selectedMaritalStatus, items: _maritalStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedMaritalStatus = v), decoration: const InputDecoration(labelText: "Select Marital Status"))),
                      const SizedBox(height: 16),

                      // --- CORRECTED AND DEFENSIVE DROPDOWNS ---
                      MyInputField(title: "Staff Category", hint: "", widget: DropdownButtonFormField<String>(
                          value: _categories.any((i) => i.id == _selectedCategoryId) ? _selectedCategoryId : null,
                          items: _categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                          decoration: InputDecoration(labelText: _categories.isEmpty ? "Loading..." : "Select Staff Category"),
                          onChanged: (value) async {
                            if(value == null) return;
                            final selected = _categories.firstWhere((c) => c.id == value);
                            setState(() {
                              _selectedCategoryId = value; _selectedCategoryName = selected.name;
                              _selectedStateId = _selectedStateName = _selectedLocationId = _selectedLocationName = _selectedRoleName = _selectedRoleId = null;
                              _states = _locations = _roles = [];
                            });
                            final newStates = await _fetchStatesBasedOnCategory(selected.name);
                            final newRoles = _getRoleOptions(selected.name);
                            if(mounted) setState(() { _states = newStates; _roles = newRoles; });
                          })),
                      const SizedBox(height: 16),

                      if (_selectedCategoryName != null) ...[
                        MyInputField(title: "State", hint: "", widget: DropdownButtonFormField<String>(
                            value: _states.any((i) => i.id == _selectedStateId) ? _selectedStateId : null,
                            items: _states.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                            decoration: InputDecoration(labelText: _states.isEmpty && _isEditMode ? "Loading..." : "Select State"),
                            onChanged: (value) async {
                              if(value == null) return;
                              final selected = _states.firstWhere((s) => s.id == value);
                              setState(() {
                                _selectedStateId = value; _selectedStateName = selected.name;
                                _selectedLocationId = _selectedLocationName = null; _locations = [];
                              });
                              final newLocs = await _fetchLocationsForState(value, _selectedCategoryName!);
                              if(mounted) setState(() => _locations = newLocs);
                            })),
                        const SizedBox(height: 16),
                      ],
                      if (_selectedStateId != null) ...[
                        MyInputField(title: "Location", hint: "", widget: DropdownButtonFormField<String>(
                            value: _locations.any((i) => i.id == _selectedLocationId) ? _selectedLocationId : null,
                            items: _locations.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                            decoration: InputDecoration(labelText: _locations.isEmpty && _isEditMode ? "Loading..." : "Select Location"),
                            onChanged: (value) async {
                              if(value == null) return;
                              final selected = _locations.firstWhere((l) => l.id == value);
                              setState(() { _selectedLocationId = value; _selectedLocationName = selected.name; });
                            })),
                        const SizedBox(height: 16),
                      ],

                      MyInputField(title: "Project", hint: "", widget: DropdownButtonFormField<String>(
                          value: _projects.any((i) => i.id == _selectedProjectId) ? _selectedProjectId : null,
                          items: _projects.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                          decoration: InputDecoration(labelText: _projects.isEmpty ? "Loading..." : "Select Project"),
                          onChanged: (value) {
                            if(value == null) return;
                            final selected = _projects.firstWhere((p) => p.id == value);
                            setState(() { _selectedProjectId = value; _selectedProjectName = selected.name; });
                          })),
                      const SizedBox(height: 16),

                      if (_selectedCategoryName != null) ...[
                        MyInputField(title: "Role", hint: "", widget: DropdownButtonFormField<String>(
                            value: _roles.any((i) => i.id == _selectedRoleId) ? _selectedRoleId : null,
                            items: _roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                            onChanged: (v) {
                              if(v == null) return;
                              final selected = _roles.firstWhere((r) => r.id == v);
                              setState(() { _selectedRoleId = v; _selectedRoleName = selected.name; });
                            },
                            decoration: const InputDecoration(labelText: "Select Role"))),
                        const SizedBox(height: 16),
                      ],

                      if (!_isEditMode) ...[
                        CheckboxListTile(title: const Text("I agree to the Terms and Conditions"), value: _termsAgreed, onChanged: (val) => setState(() => _termsAgreed = val ?? false), controlAffinity: ListTileControlAffinity.leading),
                        const SizedBox(height: 16),
                      ],
                      if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveForm,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isEditMode ? 'Save Changes' : 'Create User Account', style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}