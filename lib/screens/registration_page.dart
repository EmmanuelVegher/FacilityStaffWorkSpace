import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:attendanceappmailtool/screens/registration_page.dart';

import '../utils/my_input_field.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _auth = FirebaseAuth.instance;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String? _selectedCategory;
  String? _selectedProject;
  bool _isCategorySelected = false;
  bool _isProjectSelected = false;
  String? stateName;
  String? locationName;
  String? departmentName;
  String? designation;
  String? supervisorName;
  String? supervisorEmail;

  Future<List<DropdownMenuItem<String>>> _fetchFirestoreData(String collection, {String? whereField, String? whereValue}) async {
    QuerySnapshot snapshot;
    try {
      if (whereField != null && whereValue != null) {
        snapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where(whereField, isEqualTo: whereValue)
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance.collection(collection).get();
      }

      return snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id, // Using document ID as value
          child: Text(doc['name'] ?? 'No Name'), // Assuming a 'name' field
        );
      }).toList();
    } catch (e) {
      print('Error fetching $collection: $e');
      return [];
    }
  }

  Widget _buildDropdown(String title, String collection,
      {String? whereField, String? whereValue, required ValueChanged<String?> onChanged, String? initialValue}) {

    return FutureBuilder<List<DropdownMenuItem<String>>>(
      future: _fetchFirestoreData(collection, whereField: whereField, whereValue: whereValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Text('No $title found'); //or simply an empty Container or SizedBox
        }

        return MyInputField( // Replace with your web MyInputField equivalent
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


  // Fetching staff categories from Firestore
  Future<List<String>> _fetchStaffCategoryFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('StaffCategory') // Assuming staff categories are stored here
          .get();

      List<String> categories = snapshot.docs
          .map((doc) => doc['name'] as String) // Assuming 'name' field in Firestore
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
          .collection('Project') // Assuming staff categories are stored here
          .get();

      List<String> projects = snapshot.docs
          .map((doc) => doc['name'] as String) // Assuming 'name' field in Firestore
          .toList();

      return projects;
    } catch (e) {
      print('Error fetching staff categories: $e');
      return [];
    }
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      // Registration logic here
      // Example: await _auth.createUserWithEmailAndPassword(...);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
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
                padding: EdgeInsets.all(20),
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
                    SizedBox(height: 16),
                    Text(
                      'Registration',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24),
                    // First Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "First Name",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
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
                              prefixIcon: Icon(Icons.person, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Last Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Last Name",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
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
                              prefixIcon: Icon(Icons.person, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Email Address
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Email Address",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
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
                              prefixIcon: Icon(Icons.email, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Mobile Number
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mobile Number",
                          style: TextStyle(color: Colors.black87, fontSize: 15),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
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
                              prefixIcon: Icon(Icons.phone_android, color: Colors.black54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Staff Category Dropdown
                    FutureBuilder<List<String>>(
                      future: _fetchStaffCategoryFromFirestore(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Staff Category", style: TextStyle(color: Colors.black87, fontSize: 15)),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    hintText: "Select Staff Category",
                                    prefixIcon: Icon(Icons.category, color: Colors.black54),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  value: _selectedCategory,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _isCategorySelected = true;
                                    });
                                  },
                                  items: snapshot.data!.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Text('No categories available.');
                        }
                      },
                    ),

                    SizedBox(height: 20),
                    //// Container that displays State of Implementation,Location,Department and designation based on staff category selection

                    Container(
                      child:Column(
                        children:[
                          _buildDropdown("Staff Category", "StaffCategory", onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }, initialValue: _selectedCategory),

                        if (_selectedCategory != null) // Conditionally render the following dropdowns
                  ...[
              if(_selectedCategory == "Facility Staff" || _selectedCategory == "State Office Staff" || _selectedCategory == "HQ Staff" )
                ...[
                _buildDropdown("State of Implementation", "Location", onChanged: (value) {
              setState(() {
                stateName = value;
              });
            }, initialValue: stateName),
              if(stateName !=null )
            ...[
            _buildDropdown("Location", "Location", whereField: "stateId", whereValue: stateName, onChanged: (value) {
          setState(() {
            locationName = value;
          });
        }, initialValue: locationName),

          if (locationName != null)
      ...[
      _buildDropdown("Department", "Departments", whereField: "locationId", whereValue: locationName, onChanged: (value) {
      setState(() {
        departmentName = value;
      });
    },initialValue: departmentName,),
    if(departmentName != null)
    ...[
    _buildDropdown("Designation", "Designations", whereField: "departmentId", whereValue: departmentName, onChanged: (value) {
    setState(() {
    designation = value;
    });
    },initialValue: designation,),

    if(designation != null )
    ...[

    _buildDropdown("Supervisor Name", "Supervisors", whereField: "designationId", whereValue: designation,onChanged: (value) {
    setState(() {
    supervisorName = value;
    });
    }, initialValue: supervisorName,),

    if(supervisorName != null )
    ...[
    _buildDropdown("Supervisor Email", "SupervisorEmails", whereField: "supervisorNameId", whereValue: supervisorName, onChanged: (value) {
    setState(() {
    supervisorEmail = value;
    });
    },initialValue: supervisorEmail,),
    ]
    ]
    ]
    ]
    ]
    ],



    ],


                        ]
                      )
                    ),




                    // Staff Projects Dropdown
                    FutureBuilder<List<String>>(
                      future: _fetchProjectFromFirestore(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Project", style: TextStyle(color: Colors.black87, fontSize: 15)),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    hintText: "Select Project Category",
                                    prefixIcon: Icon(Icons.category, color: Colors.black54),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  value: _selectedProject,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedProject = value;
                                      _isProjectSelected = true;
                                    });
                                  },
                                  items: snapshot.data!.map((project) {
                                    return DropdownMenuItem<String>(
                                      value: project,
                                      child: Text(project),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Text('No project available.');
                        }
                      },
                    ),
                    SizedBox(height: 20),
                    _errorMessage.isNotEmpty
                        ? Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    )
                        : SizedBox.shrink(),
                    SizedBox(height: 20),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCategorySelected ? _register : null,
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(Colors.orange.shade700),
                          padding: MaterialStateProperty.all(EdgeInsets.symmetric(vertical: 15)),
                          shape: MaterialStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          )),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Register', style: TextStyle(fontSize: 18)),
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
