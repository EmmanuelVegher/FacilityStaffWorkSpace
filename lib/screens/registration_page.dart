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
  bool _isPasswordObscured = true; // Add this with your other state variables
  // Add this with your other state variables at the top of the class
  final _formKey = GlobalKey<FormState>();

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _maritalStatusOptions = ['Single', 'Married', 'Divorced', 'Widowed'];
  final List<String> _roleOptions = ["User", "Facility Supervisor", "State Office Staff", "HQ Staff"];

  final String _termsAndConditionsText = """
1. **Purpose:** The CARITAS Nigeria Service Delivery WorkSpace App ("App") is designed to streamline attendance tracking, timesheet management, leave requests, and task assignments for employees ("Users"). By accessing or using this App, Users agree to comply with the following terms and conditions.

2. **User Responsibilities:**
   - **Attendance and Timesheet Accuracy:** Users are responsible for accurately recording their attendance and work hours in the App. Any discrepancies should be reported to the immediate supervisor promptly.
   - **Leave Requests:** Users must submit leave requests through the App, adhering to company policies regarding notice periods and approval processes.
   - **Task Management:** Users are expected to update task statuses, track progress, and communicate effectively within the App's task management module.

3. **Privacy and Data Usage:**
   - **Data Collection:** The App collects data related to attendance, work hours, leave requests, and task management activities.
   - **Data Usage:** Collected data will be used for operational purposes, including performance evaluations, payroll processing, and project management.
   - **Data Protection:** The company is committed to safeguarding User data and will implement reasonable measures to protect it from unauthorized access or disclosure.

4. **Acceptable Use:**
   - **Prohibited Activities:** Users shall not use the App for fraudulent activities, misrepresent attendance or work hours, or engage in conduct that violates company policies or applicable laws.
   - **Monitoring:** The company reserves the right to monitor App usage to ensure compliance with company policies and to maintain operational efficiency.

5. **Location Check-ins:**
   - **Mandatory Check-ins:** Users agree to participate in location check-ins during work hours to verify presence at designated work locations, as required by certain tasks.
   - **Privacy Considerations:** Location data will be used exclusively for attendance verification and task management purposes and will not be shared with unauthorized third parties.

6. **App Updates and Maintenance:**
   - **Updates:** The App may receive periodic updates to enhance functionality and security. Users agree to install updates promptly to ensure optimal performance.
   - **Maintenance:** Scheduled maintenance may occur, during which App functionality may be limited or unavailable. Users will be notified in advance of such maintenance.

7. **Support and Assistance:**
   - **Technical Support:** For technical support or inquiries regarding App usage, Users should contact the designated technical support team in their respective department or region.
   - **Feedback:** Users are encouraged to provide feedback to improve App functionality and user experience.

8. **Disciplinary Actions:**
   - **Policy Violations:** Failure to comply with these terms and conditions may result in disciplinary action, up to and including termination of employment.
   - **Investigation:** The company will investigate reported violations and take appropriate action based on findings.

9. **Limitation of Liability:**
   - **Service Interruptions:** The company is not liable for any interruptions or errors in App service due to factors beyond its control, including but not limited to internet outages or third-party service failures.
   - **Data Accuracy:** While the company strives for accuracy, it does not guarantee the completeness or accuracy of data recorded through the App.

10. **Modifications to Terms:**
    - **Amendments:** The company reserves the right to modify these terms and conditions at any time. Users will be notified of significant changes, and continued use of the App constitutes acceptance of modified terms.
    - **Review:** Users are encouraged to review these terms periodically to stay informed of any updates.

11. **Governing Law:**
    - **Jurisdiction:** These terms and conditions are governed by the laws of the jurisdiction in which the company operates. Any disputes arising from App usage will be subject to the exclusive jurisdiction of the courts in that jurisdiction.

12. **Acknowledgment:**
    - By using the CARITAS Nigeria Service Delivery WorkSpace App, Users acknowledge that they have read, understood, and agree to these terms and conditions.

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
      } else if (staffCategory == "State Office Staff"){
        // Fetch all documents
        snapshot = await subCollectionRef.where("category", isEqualTo: "State Office").get();
      } else {
    // Fetch all documents
    snapshot = await subCollectionRef.where("category", isEqualTo: "HQ").get();
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
    // 1. Validate the form first
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = "Please fix the errors above before proceeding.";
      });
      return; // Stop if form is invalid
    }

    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear previous errors
    });

    final validRoles = _getRoleOptions(_selectedCategory);
    if (_selectedCategory == null || _selectedRole == null || !validRoles.contains(_selectedRole)) {
      setState(() {
        _errorMessage = "Inconsistent selection. Please re-select your Staff Category and then your Role.";
        _isLoading = false;
      });
      return;
    }

    String? profileImageUrl;
    try {
      profileImageUrl = await _uploadProfileImageToFirebase();
      if (profileImageUrl == null && _profileImageBytes != null) {
        setState(() {
          _errorMessage = _errorMessage.isNotEmpty ? _errorMessage : 'Failed to upload profile image.';
          _isLoading = false;
        });
        return;
      }

      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;

      if (user != null) {
        // --- FIX: Provide default empty strings for all potentially null values ---
        await FirebaseFirestore.instance.collection('Staff').doc(user.uid).set({
          'id': user.uid,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'emailAddress': _emailController.text.trim(),
          'mobile': _mobileNumberController.text.trim(),
          'staffCategory': _selectedCategory ?? '',
          'project': _selectedProject ?? '',
          'state': stateName ?? '',
          'location': locationName ?? '',
          'department': departmentName ?? '',
          'designation': designation ?? '',
          'supervisor': supervisorName ?? '',
          'supervisorEmail': supervisorEmail ?? '',
          'role': _selectedRole ?? '',
          'gender': _selectedGender ?? '',
          'maritalStatus': _selectedMaritalStatus ?? '',
          'photoUrl': profileImageUrl ?? '', // This one was already correct
        });
        // --- END OF FIX ---

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
                width: 600,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Form( // Wrap the input fields with a Form
                  key: _formKey,
                  child:
                Column(
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
                            // --- VALIDATION LOGIC START ---
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a mobile number.';
                              }
                              if (value.length != 11) {
                                return 'Mobile number must be exactly 11 digits.';
                              }
                              if (!RegExp(r'^[0-9]{11}$').hasMatch(value)) {
                                return 'Please enter a valid 11-digit number.';
                              }
                              return null; // Return null if the input is valid
                            },
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            // --- VALIDATION LOGIC END ---
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Gender Dropdown
                    MyInputField(
                      title: "Sex",
                      hint: '',
                      widget: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Sex"),
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
                              // --- UPDATED LOGIC IS HERE ---
                              onChanged: (value) async { // Make the function async
                                setState(() {
                                  _selectedCategory = value;
                                  // Reset all dependent fields first
                                  stateName = null;
                                  locationName = null;
                                  departmentName = null;
                                  designation = null;
                                  supervisorName = null;
                                  supervisorEmail = null;
                                });

                                // If HQ Staff is selected, automatically fetch and set the state
                                if (value == "HQ Staff") {
                                  try {
                                    // Query Firestore for the document ID of the FCT
                                    final querySnapshot = await FirebaseFirestore.instance
                                        .collection("Location")
                                        .where('name', isEqualTo: "Federal Capital Territory")
                                        .limit(1) // We only need one result
                                        .get();

                                    if (querySnapshot.docs.isNotEmpty) {
                                      // Get the document ID and set it as the state
                                      final hqStateId = querySnapshot.docs.first.id;
                                      setState(() {
                                        stateName = hqStateId;
                                      });
                                    }
                                  } catch (e) {
                                    print("Error auto-fetching HQ state: $e");
                                    // Optionally show an error message to the user
                                  }
                                }
                              },
                              // --- END OF UPDATED LOGIC ---
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
                            // Bind the obscureText property to our new state variable
                            obscureText: _isPasswordObscured,
                            decoration: InputDecoration(
                              labelText: "Enter your Password",
                              prefixIcon: const Icon(Icons.lock, color: Colors.black54),
                              // Add the visibility toggle icon here
                              suffixIcon: IconButton(
                                icon: Icon(
                                  // Change the icon based on the state
                                  _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.black54,
                                ),
                                onPressed: () {
                                  // Update the state to show/hide password
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Terms and Conditions Checkbox
                    // Terms and Conditions Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAgreed,
                          onChanged: (bool? value) {
                            // Only show the dialog if the user is trying to uncheck the box.
                            // If they are checking it, just accept the change.
                            if (value == true) {
                              setState(() {
                                _termsAgreed = value!;
                              });
                            } else {
                              // If they try to uncheck, they must re-read and agree/disagree.
                              _showTermsDialog();
                            }
                          },
                        ),
                        // Wrap the Text with a GestureDetector to make it tappable
                        GestureDetector(
                          // The action to perform when the child (Text) is tapped
                          onTap: _showTermsDialog,
                          child: const Text(
                            'I agree to the Terms and Conditions',
                            style: TextStyle(
                              color: Colors.black87,
                              // Optional: Add an underline to suggest it's clickable
                              decoration: TextDecoration.underline,
                            ),
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
      ),
    );
  }
}