import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:file_picker/file_picker.dart'; // For web file picking
import 'dart:typed_data'; // For Uint8List

import '../utils/my_input_field.dart'; // Ensure this is web-compatible or replace

class RegistrationPageWeb extends StatefulWidget {
  const RegistrationPageWeb({super.key});

  @override
  _RegistrationPageWebState createState() => _RegistrationPageWebState();
}

class _RegistrationPageWebState extends State<RegistrationPageWeb> {
  final _auth = FirebaseAuth.instance;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _passwordController = TextEditingController(); // Password Controller
  bool _isLoading = false;
  String _errorMessage = '';
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
  bool _termsAgreed = false;
  Uint8List? _profileImageBytes; // To store image bytes
  String? _profileImageUrl; // To store image URL after upload

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _maritalStatusOptions = ['Single', 'Married', 'Divorced', 'Widowed'];
  final List<String> _roleOptions = ["User", "Facility Supervisor", "State Office Staff", "HQ Staff"];

  final String _termsAndConditionsText = """
  1. **Purpose:** This Attendance App is designed to track and monitor staff attendance.  By using this app, you agree to abide by the following terms and conditions.
  2. **Accuracy:** You are responsible for ensuring the accuracy of your attendance records. Report any discrepancies to your supervisor immediately.
  3. **Privacy:**  Attendance data collected through this app will be used solely for monitoring attendance and will be treated confidentially.
  4. **Misuse:**  Do not use the app for fraudulent purposes or to misrepresent your attendance. Any such misuse may result in disciplinary action.
  5. **Updates:** The app may be updated periodically. You agree to install any updates to ensure proper functionality.
  6. **Random Check-ins:** You agree to participate in random location check-ins during work hours. These check-ins are solely for monitoring purposes and to verify your presence at your designated work location.
  7. **Support:** For technical support or questions about the app, please contact the technical teams in your individual state.
  """;

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Terms and Conditions"),
          content: SingleChildScrollView(
            child: Text(_termsAndConditionsText),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Disagree"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Agree"),
              onPressed: () {
                setState(() {
                  _termsAgreed = true;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<List<DropdownMenuItem<String>>> _fetchStatesBasedOnCategory() async {
    try {
      QuerySnapshot snapshot;
      if (_selectedCategory == "Facility Staff" || _selectedCategory == "State Office Staff" || _selectedCategory == "Facility Supervisor") {
        snapshot = await FirebaseFirestore.instance
            .collection("Location")
            .where('name', isNotEqualTo: "Federal Capital Territory")
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection("Location")
            .where('name', isEqualTo: "Federal Capital Territory")
            .get();
      }

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id,
          child: Text(doc['name'] ?? 'No Name'),
        );
      }).toList();
    } catch (e) {
      print('Error fetching states: $e');
      return [];
    }
  }



  Future<List<DropdownMenuItem<String>>> _fetchFirestoreData(String collection, {String? whereField, String? whereValue,String? staffCategory}) async {
    QuerySnapshot snapshot;
    try {

      CollectionReference subCollectionRef = FirebaseFirestore.instance
          .collection(collection)
          .doc(whereValue)
          .collection(whereValue!);

      QuerySnapshot snapshot;

      if (staffCategory == "Facility Staff") {
        // Fetch only documents where category == "Facility Staff"
        snapshot = await subCollectionRef.where("category", isEqualTo: "Facility").get();
      } else {
        // Fetch all documents
        snapshot = await subCollectionRef.where("category", isEqualTo: "State Office").get();
      }

      // if (whereField != null && whereValue != null) {
      //   snapshot = await FirebaseFirestore.instance
      //       .collection(collection)
      //       .doc(whereValue)
      //       .collection(whereValue)
      //      // .where(whereField, isEqualTo: whereValue)
      //       .get();
      // } else {
      //   snapshot = await FirebaseFirestore.instance.collection(collection).get();
      // }

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Using document ID as value
          child: Text(doc['LocationName'] ?? 'No Name'), // Assuming a 'name' field
        );
      }).toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }

  Widget _buildDropdown(String title, String collection,
      {String? whereField, String? whereValue,String? staffCategory, required ValueChanged<String?> onChanged, String? initialValue, Future<List<DropdownMenuItem<String>>>? futureItems}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: futureItems ?? _fetchFirestoreData(collection, whereField: whereField, whereValue: whereValue,staffCategory:staffCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent if needed for web styling
          title: title,
          hint: '',
          widget: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title),
            items: snapshot.data,
            value: initialValue,
            onChanged: onChanged,
          ),
        );
      },
    );
  }



  Widget _buildDropdownDepartment(String title, String collection,
      {String? whereField, String? whereValue,String? staffCategory, required ValueChanged<String?> onChanged, String? initialValue, Future<List<DropdownMenuItem<String>>>? futureItems}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: futureItems ?? _fetchFirestoreDataDepartment(collection, whereField: whereField, whereValue: whereValue,staffCategory:staffCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent if needed for web styling
          title: title,
          hint: '',
          widget: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title),
            items: snapshot.data,
            value: initialValue,
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  Future<List<DropdownMenuItem<String>>> _fetchFirestoreDataDepartment(
      String collection, {String? whereField, String? whereValue, String? staffCategory}) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection(collection).get();

      // List of allowed departments for Facility Staff
      List<String> allowedDepartments = [
        "Care and Treatment",
        "Preventions",
        "Laboratory",
        "Strategic Information",
        "Pharmacy and Logistics"
      ];

      return snapshot.docs
          .where((doc) =>
      staffCategory != "Facility Staff" || allowedDepartments.contains(doc.id))
          .map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Using document ID as value (department name)
          child: Text(doc.id), // Displaying the document ID as text
        );
      })
          .toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }


  Widget _buildDropdownDesignation(String title, String collection,
      {String? whereField, String? whereValue,String? staffCategory, required ValueChanged<String?> onChanged, String? initialValue, Future<List<DropdownMenuItem<String>>>? futureItems}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: futureItems ?? _fetchFirestoreDataDesignation(collection, whereField: whereField, whereValue: whereValue,staffCategory:staffCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent if needed for web styling
          title: title,
          hint: '',
          widget: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title),
            items: snapshot.data,
            value: initialValue,
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  // Example helper function to get role options based on staff category
  List<String> _getRoleOptions(String? staffCategory) {
    if (staffCategory == 'Facility Supervisor') {
      return ['Facility Supervisor'];
    } else if (staffCategory == 'Facility Staff') {
      return ['User'];
    } else if (staffCategory == 'State Office Staff') {
      return ['State Office Staff'];
    } else {
      return ['HQ Staff'];
    }
  }


  Future<List<DropdownMenuItem<String>>> _fetchFirestoreDataDesignation(
      String collection, {String? whereField, String? whereValue, String? staffCategory}) async {
    try {
      CollectionReference subCollectionRef = FirebaseFirestore.instance
          .collection(collection)
          .doc(whereValue)
          .collection(whereValue!);

      QuerySnapshot snapshot;

      if (staffCategory == "Facility Staff") {
        // Fetch only documents where category == "Facility Staff"
        snapshot = await subCollectionRef.where("category", isEqualTo: "Facility Staff").get();
      } else {
        // Fetch all documents
        snapshot = await subCollectionRef.where("category", isEqualTo: "Office Staff").get();
      }


      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Using document ID as value (designation name)
          child: Text(doc.id), // Displaying the document ID as text
        );
      }).toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }


  Widget _buildDropdownSupervisors(String title, String collection,
      {String? whereField, String? whereValue, required ValueChanged<String?> onChanged, String? initialValue, Future<List<DropdownMenuItem<String>>>? futureItems}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: futureItems ?? _fetchFirestoreDataSupervisors(collection, whereField: whereField, whereValue: whereValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent if needed for web styling
          title: title,
          hint: '',
          widget: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title),
            items: snapshot.data,
            value: initialValue,
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  Future<List<DropdownMenuItem<String>>> _fetchFirestoreDataSupervisors(
      String collection, {String? whereField, String? whereValue}) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .doc(whereField)
          .collection(whereField!)
          .where("department", isEqualTo: whereValue)
          .get();

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Using document ID as value (department name)
          child: Text(doc.id), // Displaying the document ID as text
        );
      }).toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }



  Widget _buildDropdownSupervisorsEmail(String title, String collection,
      {String? whereField, String? whereValue,String? supervisorValue, required ValueChanged<String?> onChanged, String? initialValue, Future<List<DropdownMenuItem<String>>>? futureItems}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: futureItems ?? _fetchFirestoreDataSupervisorsEmail(collection, whereField: whereField, whereValue: whereValue,supervisorValue: supervisorValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent if needed for web styling
          title: title,
          hint: '',
          widget: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: title),
            items: snapshot.data,
            value: initialValue,
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  Future<List<DropdownMenuItem<String>>> _fetchFirestoreDataSupervisorsEmail(
      String collection, {String? whereField, String? whereValue,String? supervisorValue}) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .doc(whereField)
          .collection(whereField!)
          .where("department", isEqualTo: whereValue)
          .where("supervisor", isEqualTo: supervisorValue)
          .get();


      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc['email'], // Using document ID as value (department name)
          child: Text(doc['email']), // Displaying the document ID as text
        );
      }).toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }

  // Fetching staff categories from Firestore
  Future<List<String>> _fetchStaffCategoryFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('StaffCategory')
          .get();

      List<String> categories = snapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();

      return categories;
    } catch (e) {
      print('Error fetching staff categories: $e');
      return [];
    }
  }

  Future<List<String>> _fetchProjectFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Project')
          .get();

      List<String> projects = snapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();

      return projects;
    } catch (e) {
      print('Error fetching staff projects: $e');
      return [];
    }
  }

  Future<void> _pickProfileImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // Ensure byte data is returned
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _profileImageBytes = result.files.first.bytes;
      });
    } else {
      // User canceled the picker
    }
  }

  Future<String?> _uploadProfileImageToFirebase() async {
    if (_profileImageBytes == null) return null;

    try {
      String fileName = 'profile_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      firebase_storage.Reference storageRef = firebase_storage.FirebaseStorage.instance.ref().child(fileName);

      firebase_storage.UploadTask uploadTask = storageRef.putData(_profileImageBytes!);
      firebase_storage.TaskSnapshot taskSnapshot = await uploadTask;

      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      _errorMessage = 'Error uploading profile image.'; // Set error message for UI display
      return null;
    }
  }


  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous errors
    });

    String? profileImageUrl;
    try {
      profileImageUrl = await _uploadProfileImageToFirebase(); // Upload image first
      if (profileImageUrl == null && _profileImageBytes != null) { // Image upload failed but image was selected
        setState(() {
          _errorMessage = _errorMessage.isNotEmpty ? _errorMessage : 'Failed to upload profile image.';
          _isLoading = false;
        });
        return; // Stop registration if image upload failed
      }

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('Staff').doc(user.uid).set({
          'id': user.uid,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'emailAddress': _emailController.text.trim(),
          'mobile': _mobileNumberController.text.trim(),
          'staffCategory': _selectedCategory,
          'project': _selectedProject,
          'state': stateName,
          'location': locationName,
          'department': departmentName,
          'designation': designation,
          'supervisor': supervisorName,
          'supervisorEmail': supervisorEmail,
          'role': _selectedRole,
          'gender': _selectedGender,
          'maritalStatus': _selectedMaritalStatus,
          'photoUrl': profileImageUrl ?? '', // Save image URL if available
          // ... other fields
        });
        Navigator.pushReplacementNamed(context, '/home'); // Replace with your home route
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Registration failed.';
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $error';
      });
    } finally {
      setState(() => _isLoading = false);
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
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 8,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/image/caritaslogo1.png',
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Registration',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile Image Upload
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                        child: _profileImageBytes == null ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade700) : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // First Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "First Name",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: "Enter your First Name",
                              prefixIcon: const Icon(Icons.person, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Last Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Last Name",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: "Enter your Last Name",
                              prefixIcon: const Icon(Icons.person, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Email Address
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Email Address",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: "Enter your email",
                              prefixIcon: const Icon(Icons.email, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Mobile Number
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Mobile Number",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _mobileNumberController,
                            decoration: InputDecoration(
                              labelText: "Enter your Mobile Number",
                              prefixIcon: const Icon(Icons.phone_android, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Gender Dropdown
                    MyInputField(
                      title: "Gender",
                      hint: '',
                      widget: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Gender"),
                        value: _selectedGender,
                        items: _genderOptions.map((gender) => DropdownMenuItem(value: gender, child: Text(gender))).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Marital Status Dropdown
                    MyInputField(
                      title: "Marital Status",
                      hint: '',
                      widget: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Marital Status"),
                        value: _selectedMaritalStatus,
                        items: _maritalStatusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMaritalStatus = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Staff Category Dropdown
                    FutureBuilder<List<String>>(
                      future: _fetchStaffCategoryFromFirestore(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return MyInputField(
                            title: "Staff Category",
                            hint: '',
                            widget: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: "Staff Category"),
                              value: _selectedCategory,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  // Reset state-dependent dropdowns when category changes
                                  stateName = null;
                                  locationName = null;
                                  departmentName = null;
                                  designation = null;
                                  supervisorName = null;
                                  supervisorEmail = null;
                                });
                              },
                              items: snapshot.data!.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                            ),
                          );
                        } else {
                          return const Text('No categories available.');
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    //// Container that displays State of Implementation,Location,Department and designation based on staff category selection
                    Container(
                      child: Column(
                        children: [
                          if (_selectedCategory != null) // Conditionally render the following dropdowns
                            ...[
                              _buildDropdown(
                                "State of Implementation",
                                "Location",
                                futureItems: _fetchStatesBasedOnCategory(),
                                onChanged: (value) {
                                  setState(() {
                                    stateName = value;
                                    locationName = null; // Reset location when state changes
                                    departmentName = null;
                                    designation = null;
                                    supervisorName = null;
                                    supervisorEmail = null;
                                  });
                                },
                                initialValue: stateName,
                              ),
                              if(stateName !=null )
                                ...[
                                  _buildDropdown("Location", "Location", whereField: "stateId", whereValue: stateName,staffCategory: _selectedCategory, onChanged: (value) {
                                    setState(() {
                                      locationName = value;
                                      departmentName = null;
                                      designation = null;
                                      supervisorName = null;
                                      supervisorEmail = null;
                                    });
                                  }, initialValue: locationName),

                                  if (locationName != null)
                                    ...[
                                      _buildDropdownDepartment("Department", "Designation", whereField: "locationId", whereValue: locationName,staffCategory: _selectedCategory, onChanged: (value) {
                                        setState(() {
                                          departmentName = value;
                                          designation = null;
                                          supervisorName = null;
                                          supervisorEmail = null;
                                        });
                                      },initialValue: departmentName,),
                                      if(departmentName != null)
                                        ...[
                                          _buildDropdownDesignation("Designation", "Designation", whereField: "departmentId", whereValue: departmentName,staffCategory: _selectedCategory, onChanged: (value) {
                                            setState(() {
                                              designation = value;
                                              supervisorName = null;
                                              supervisorEmail = null;
                                            });
                                          },initialValue: designation,),

                                          if(designation != null )
                                            ...[

                                              _buildDropdownSupervisors("Supervisor Name", "Supervisors", whereField: stateName, whereValue: departmentName,onChanged: (value) {
                                                setState(() {
                                                  supervisorName = value;
                                                  supervisorEmail = null;
                                                });
                                              }, initialValue: supervisorName,),

                                              if(supervisorName != null )
                                                ...[
                                                  _buildDropdownSupervisorsEmail("Supervisor Email", "Supervisors", whereField: stateName, whereValue: departmentName,supervisorValue: supervisorName, onChanged: (value) {
                                                    setState(() {
                                                      supervisorEmail = value;
                                                    });
                                                  },initialValue: supervisorEmail,),
                                                ]
                                            ]
                                        ]
                                    ]
                                ],
                            ],
                        ],
                      ),
                    ),

                    // Project Dropdown
                    FutureBuilder<List<String>>(
                      future: _fetchProjectFromFirestore(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return MyInputField(
                            title: "Project",
                            hint: '',
                            widget: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: "Project"),
                              value: _selectedProject,
                              onChanged: (value) {
                                setState(() {
                                  _selectedProject = value;
                                });
                              },
                              items: snapshot.data!.map((project) {
                                return DropdownMenuItem<String>(
                                  value: project,
                                  child: Text(project),
                                );
                              }).toList(),
                            ),
                          );
                        } else {
                          return const Text('No project available.');
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Role Dropdown
                    MyInputField(
                      title: "Role",
                      hint: '',
                      widget: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Role"),
                        value: _selectedRole,
                        // Generate items based on the current staff category
                        items: _getRoleOptions(_selectedCategory)
                            .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                          });
                        },
                      ),
                    ),


                    const SizedBox(height: 20),

                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Password",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: "Enter your Password",
                              prefixIcon: const Icon(Icons.lock, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            obscureText: true, // For password masking
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Terms and Conditions Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAgreed,
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() {
                                _termsAgreed = value!;
                              });
                            } else {
                              _showTermsDialog(); // Show dialog when unchecked to re-confirm
                            }
                          },
                        ),
                        GestureDetector(
                          onTap: _showTermsDialog,
                          child: const Text(
                            'I agree to the Terms and Conditions',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),


                    _errorMessage.isNotEmpty
                        ? Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    )
                        : const SizedBox.shrink(),
                    const SizedBox(height: 20),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _termsAgreed ? _register : null, // Enable button only if terms are agreed
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.orange.shade700),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 15)),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          )),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Register', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}