import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../widgets/button.dart';
import '../../widgets/drawer2.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key, this.thematicReportToEdit, this.otherReportToEdit});

  final Map<String, dynamic>? thematicReportToEdit;
  final Map<String, dynamic>? otherReportToEdit;

  @override
  _CreateActivityPageState createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  String _userRole = 'User'; // Default role
  String _selectedReportType = 'Daily';
  final TextEditingController _indicatorController = TextEditingController();
  String _selectedResponseType = 'Input Box';
  String? _selectedThematicDepartment; // For Thematic Activity Department Dropdown
  String? _selectedThematicDesignation; // For Thematic Activity Department Dropdown
  List<String> _departments = []; // To store departments from "Designation"
  List<String> _designations = []; // To store designations for selected department
  String? _selectedAssignedDepartment; // For Other Activity Department Dropdown
  DateTime? _selectedDate; // For Date Picker in Other Activity
  final TextEditingController _activityNameController = TextEditingController(); // For Activity Name in Other Activity
  List<Map<String, dynamic>> _selectedAssignedUsers = []; // Modified to store full name also
  List<Map<String, dynamic>> _staffListForDepartment = []; // To store staff based on selected department
  int _selectedIndex = 0; // For bottom navigation bar
  late String _loggedInUserFullName = '';
  late String _loggedInUserId = '';
  String? _currentUserState;
  String? _selectedFacilityName;
  List<String> _facilityNames = [];
  List<String> _reportIndicators = []; // List to hold report indicators for the selected department
  final TextEditingController _reportIndicatorsController = TextEditingController(); // Controller for editing indicators

  final List<String> _reportTypes = ['Daily', 'Weekly', 'Monthly'];
  final List<String> _responseTypes = ['Input Box', 'Numerator/Denominator'];

  // Edit Mode Variables
  bool _isEditThematicMode = false;
  String? _thematicReportDocId;
  bool _isEditOtherMode = false;
  String? _otherReportDocId;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadDepartments();
    _loadLoggedInUserInfo();
    _loadCurrentUserStateAndFacilities();
    _initializeEditMode();
  }

  void _initializeEditMode() {
    if (widget.thematicReportToEdit != null) {
      _isEditThematicMode = true;
      _thematicReportDocId = widget.thematicReportToEdit!['docId'];
      _selectedThematicDepartment = widget.thematicReportToEdit!['department'];
      _selectedReportType = widget.thematicReportToEdit!['reportType'];
      _indicatorController.text = widget.thematicReportToEdit!['indicator'];
      _selectedResponseType = widget.thematicReportToEdit!['responseType'];
      _selectedThematicDesignation = widget.thematicReportToEdit!['designation'];
      _loadDesignationsForDepartment(widget.thematicReportToEdit!['department']);
      _loadReportIndicatorsForDepartment(widget.thematicReportToEdit!['department'], widget.thematicReportToEdit!['designation']); // Load indicators for edit
    }
    if (widget.otherReportToEdit != null) {
      _isEditOtherMode = true;
      _otherReportDocId = widget.otherReportToEdit!['docId'];
      _selectedDate = (widget.otherReportToEdit!['date'] as Timestamp?)?.toDate();
      _selectedAssignedDepartment = widget.otherReportToEdit!['department'];
      _selectedFacilityName = widget.otherReportToEdit!['facilityName'];
      _activityNameController.text = widget.otherReportToEdit!['activityName'];
      // For assigned users, you might need to refetch and pre-select them based on IDs if stored in report
      // Or if you passed user details directly, you can pre-select them.
      // For simplicity, pre-selection of users is skipped in this example, you might need to implement it based on your needs.
    }
  }

  Future<void> _loadReportIndicatorsForDepartment(String? department, String? designation) async {
    if (department != null && designation != null) {
      try {
        DocumentSnapshot reportDoc = await FirebaseFirestore.instance
            .collection('CreateReport')
            .doc('ThematicReport')
            .get();

        if (reportDoc.exists) {
          Map<String, dynamic> reportData = reportDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> thematicReportCategory = Map<String, dynamic>.from(reportData['ThematicReportIndicators'] ?? {});
          Map<String, dynamic> designationIndicators = Map<String, dynamic>.from(thematicReportCategory[department] ?? {});

          List<dynamic> indicatorsDynamic = designationIndicators[designation] ?? [];
          _reportIndicators = indicatorsDynamic.cast<String>().toList();
          _reportIndicatorsController.text = _reportIndicators.join('\n'); // Display in multiline text field
          setState(() {}); // Rebuild UI to show loaded indicators
        } else {
          _reportIndicators = [];
          _reportIndicatorsController.clear();
          setState(() {});
        }
      } catch (e) {
        print("Error loading report indicators: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report indicators: $e')),
        );
      }
    } else {
      _reportIndicators = [];
      _reportIndicatorsController.clear();
      setState(() {});
    }
  }


  Future<void> _loadCurrentUserStateAndFacilities() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final DocumentSnapshot<Map<String, dynamic>> staffSnapshot =
      await FirebaseFirestore.instance.collection('Staff').doc(userId).get();
      if (staffSnapshot.exists && staffSnapshot.data() != null) {
        final staffData = staffSnapshot.data()!;
        final state = staffData['state'] as String?;
        if (state != null) {
          setState(() {
            _currentUserState = state;
          });
          await _loadFacilityNames(state);
        }
      }
    }
  }

  Future<void> _loadFacilityNames(String state) async {
    if (state.isNotEmpty) {
      try {
        final QuerySnapshot<Map<String, dynamic>> facilitySnapshot = await FirebaseFirestore.instance
            .collection('Location')
            .doc(state)
            .collection(state)
            .get();
        List<String> facilities = facilitySnapshot.docs.map((doc) => doc.id).toList();
        setState(() {
          _facilityNames = facilities;
        });
      } catch (e) {
        print("Error loading facility names: $e");
      }
    }
  }

  Future<void> _loadLoggedInUserInfo() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance.collection('Staff').doc(userId).get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        setState(() {
          _loggedInUserFullName = '$firstName $lastName';
          _loggedInUserId = userId;
        });
      }
    }
  }

  Future<void> _loadUserRole() async {
    String role = 'User'; // Default role in case of errors or if role is not found
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('Staff').doc(userId).get();

        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          role = data['role'] as String? ?? 'User'; // Get role, default to 'User' if null or not string
        }
      }
    } catch (e) {
      print("Error loading user role: $e");
      // In case of error, default role 'User' will be used.
    } finally {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance.collection('Designation').get();
      List<String> departments = snapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      print("Error loading departments: $e");
    }
  }

  Future<void> _loadDesignationsForDepartment(String department1) async {
    setState(() {
      _designations = [];
      _selectedThematicDesignation = null;
    });
    if (department1 != null) {
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('Designation').doc(department1).collection(department1).get();
        List<String> designations = snapshot.docs.map((doc) => doc.id).toList();
        setState(() {
          _designations = designations;
        });
      } catch (e) {
        print("Error loading designations: $e");
      }
    }
  }

  Future<void> _fetchStaffForDepartmentAndFacility(String department, String? facilityName) async {
    setState(() {
      _staffListForDepartment = []; // Clear previous staff list
      _selectedAssignedUsers = []; // Clear selected users when department changes
    });
    if (department.isNotEmpty) {
      try {
        Query<Map<String, dynamic>> staffQuery = FirebaseFirestore.instance.collection('Staff');
        staffQuery = staffQuery.where('department', isEqualTo: department);
        if (facilityName != null && facilityName.isNotEmpty) {
          staffQuery = staffQuery.where('location', isEqualTo: facilityName);
        }

        final QuerySnapshot<Map<String, dynamic>> staffSnapshot = await staffQuery.get();

        setState(() {
          _staffListForDepartment = staffSnapshot.docs.map((doc) {
            final data = doc.data();
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final fullName = '$firstName $lastName';
            return {'id': data['id'], 'department': data['department'], 'fullName': fullName}; // Include fullName
          }).toList();
        });
      } catch (e) {
        print("Error fetching staff for department and facility: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer2(context),
      appBar: AppBar(
        title: Text(_isEditThematicMode || _isEditOtherMode ? 'Edit Activity' : 'Create Activity'),
      ),
      body: _getBodyWidget(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add_task),
            label: 'Create Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Reports',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _isEditThematicMode = false; //reset edit mode when navigating away from create activity
      _isEditOtherMode = false;
    });
  }

  Widget _getBodyWidget(int index) {
    switch (index) {
      case 0:
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userRole == 'Admin') _buildThematicActivitySection(),
                _buildOtherActivitySection(),
              ],
            ),
          ),
        );
      case 1:
        return _buildReportsSection();
      default:
        return const Center(child: Text('Invalid tab index'));
    }
  }

  Widget _buildReportsSection() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text("Thematic Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(child: ThematicReportsScreen()),
          SizedBox(height: 20),
          Text("Other Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(child: OtherReportsScreen()),
        ],
      ),
    );
  }

  Widget _buildThematicActivitySection() {
    return ExpansionTile(
      title: const Text('Thematic Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      initiallyExpanded: true, // Or false, depending on your preference
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'For which department'),
                value: _selectedThematicDepartment,
                items: _departments.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedThematicDepartment = newValue;
                    _designations = [];
                    _selectedThematicDesignation = null;
                    if (newValue != null) {
                      _loadDesignationsForDepartment(newValue);
                      _reportIndicators = [];
                      _reportIndicatorsController.clear();
                    }
                  });
                },
                validator: (value) => value == null ? 'Please select a department' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Designation'),
                value: _selectedThematicDesignation,
                items: _designations.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedThematicDesignation = newValue;
                    _loadReportIndicatorsForDepartment(_selectedThematicDepartment, newValue); // Load indicators when department and designation changes
                  });
                },
                validator: (value) => _selectedThematicDepartment == null ? 'Please select department first' : value == null ? 'Please select a designation' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Report Type'),
                value: _selectedReportType,
                items: _reportTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedReportType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reportIndicatorsController,
                decoration: const InputDecoration(labelText: 'Report Indicators (one per line)'),
                maxLines: 5, // Allow multiple lines for list input
                keyboardType: TextInputType.multiline,
                onChanged: (value) {
                  _reportIndicators = value.split('\n').where((line) => line.trim().isNotEmpty).toList();
                },
              ),

              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Response Type'),
                value: _selectedResponseType,
                items: _responseTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedResponseType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: MyButton(
                  label: _isEditThematicMode ? 'Update Report Indicators' : 'Create Report Indicators',
                  onTap: _createThematicActivity,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherActivitySection() {
    return ExpansionTile(
      title: const Text('Other Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      initiallyExpanded: true, // Or false
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'Select Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _selectedDate != null
                            ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                            : 'Select Date',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Assign Department'),
                value: _selectedAssignedDepartment,
                items: _departments.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedAssignedDepartment = newValue;
                    _selectedAssignedUsers = []; // Clear previous selected users
                    _fetchStaffForDepartmentAndFacility(newValue!, _selectedFacilityName);
                  });
                },
                validator: (value) => value == null ? 'Please select a department' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Facility'),
                value: _selectedFacilityName,
                items: _facilityNames.map((String facility) {
                  return DropdownMenuItem<String>(
                    value: facility,
                    child: Text(facility),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedFacilityName = newValue;
                    _selectedAssignedUsers = []; // Clear previous selected users
                    if (_selectedAssignedDepartment != null) {
                      _fetchStaffForDepartmentAndFacility(_selectedAssignedDepartment!, newValue);
                    }
                  });
                },
                validator: (value) => value == null ? 'Please select a facility' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _activityNameController,
                decoration: const InputDecoration(labelText: 'Activity Name'),
              ),
              const SizedBox(height: 20),
              const Text("Assign Staff:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_staffListForDepartment.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _staffListForDepartment.length,
                  itemBuilder: (context, index) {
                    final staff = _staffListForDepartment[index];
                    bool isSelected = _selectedAssignedUsers.any((user) => user['id'] == staff['id']);
                    return CheckboxListTile(
                      title: Text('${staff['fullName']} (${staff['department']})'), // Display full name and department
                      value: isSelected,
                      onChanged: (bool? newValue) {
                        setState(() {
                          if (newValue == true) {
                            _selectedAssignedUsers.add({
                              'id': staff['id'],
                              'department': staff['department'],
                              'fullName': staff['fullName'] // Store full name
                            });
                          } else {
                            _selectedAssignedUsers.removeWhere((user) => user['id'] == staff['id']);
                          }
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
              Center(
                child: MyButton(
                  label: _isEditOtherMode ? 'Update Other Activity' : 'Create Other Activity',
                  onTap: _createOtherActivity,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createThematicActivity() async {
    String reportType = _selectedReportType;
    String responseType = _selectedResponseType;
    String? department = _selectedThematicDepartment;
    String? designation = _selectedThematicDesignation;
    List<String> indicatorsToSave = _reportIndicators;
    String? categoryName = 'ThematicReportIndicators'; // Category name is now fixed 'ThematicReportIndicators'

    if (department == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }
    if (designation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a designation')),
      );
      return;
    }
    if (indicatorsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report Indicators cannot be empty')),
      );
      return;
    }

    try {
      final thematicReportRef = FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('ThematicReport');

      DocumentSnapshot reportDoc = await thematicReportRef.get();
      Map<String, dynamic> reportData = reportDoc.data() as Map<String, dynamic>? ?? {};

      Map<String, dynamic> categoryIndicators = Map<String, dynamic>.from(reportData[categoryName] ?? {});
      Map<String, dynamic> departmentIndicators = Map<String, dynamic>.from(categoryIndicators[department] ?? {});


      departmentIndicators[designation] = indicatorsToSave; // Save indicators under designation within department
      categoryIndicators[department] = departmentIndicators; // Update department indicators
      reportData[categoryName] = categoryIndicators; // Update category indicators in report data


      Map<String, dynamic> updateData = {
        categoryName: categoryIndicators,
        'reportType': reportType,
        'responseType': responseType,
        'department': department,
        'designation': designation,
        'updatedAt': FieldValue.serverTimestamp(),
      };


      if (_isEditThematicMode && _thematicReportDocId != null) {
        await thematicReportRef.update(updateData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report Indicators Updated!')),
        );
      } else {
        updateData['createdAt'] = FieldValue.serverTimestamp();
        await thematicReportRef.set(updateData, SetOptions(merge: true)); // Merge to keep existing data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report Indicators Created/Updated!')),
        );
      }

      _reportIndicatorsController.clear();
      setState(() {
        _selectedThematicDepartment = null;
        _selectedThematicDesignation = null;
        _reportIndicators = [];
        _isEditThematicMode = false;
        _thematicReportDocId = null;
      });

    } catch (e) {
      print("Error creating/updating thematic report indicators: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create/update Report Indicators: $e')),
      );
    }
  }

  Future<void> _createOtherActivity() async {
    DateTime? date = _selectedDate;
    String activityName = _activityNameController.text.trim();
    String? department = _selectedAssignedDepartment;
    List<Map<String, dynamic>> assignedUsers = _selectedAssignedUsers;
    String? facilityName = _selectedFacilityName;


    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }
    if (activityName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity Name cannot be empty')),
      );
      return;
    }
    if (department == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }
    if (facilityName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a facility')),
      );
      return;
    }
    if (assignedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign to at least one user')),
      );
      return;
    }

    try {
      final otherReportRef = FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('OtherReport')
          .collection(department);

      if (_isEditOtherMode && _otherReportDocId != null) {
        // Update existing document - assuming you want to update for all assigned users in edit mode.
        // You might need to adjust this logic based on how you want to handle updates for multi-user assignments.
        for (var user in assignedUsers) {
          await otherReportRef.doc(_otherReportDocId).update({ // Assuming _otherReportDocId is consistent for all users in edit
            'date': date,
            'activityName': activityName,
            'department': department,
            'facilityName': facilityName,
            'assignedToUserId': user['id'],
            'assignedToFullName': user['fullName'], // Save assigned user's full name
            'assignedToDepartment': user['department'],
            'activityCreatedBy': _loggedInUserFullName, // Save creator's full name
            'createdByUserId': _loggedInUserId, // Save creator's user ID
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other Activity Updated!')),
        );

      } else {
        // Create new document
        for (var user in assignedUsers) {
          await otherReportRef.doc(user['id']).set({
            'date': date,
            'activityName': activityName,
            'department': department,
            'facilityName': facilityName,
            'assignedToUserId': user['id'],
            'assignedToFullName': user['fullName'], // Save assigned user's full name
            'assignedToDepartment': user['department'],
            'activityCreatedBy': _loggedInUserFullName, // Save creator's full name
            'createdByUserId': _loggedInUserId, // Save creator's user ID
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other Activity Created!')),
        );
      }


      _activityNameController.clear();
      setState(() {
        _selectedDate = null;
        _selectedAssignedDepartment = null;
        _selectedAssignedUsers = [];
        _staffListForDepartment = [];
        _selectedFacilityName = null;
        _facilityNames = [];
        _isEditOtherMode = false;
        _otherReportDocId = null;
      });


    } catch (e) {
      print("Error creating other activity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create Other Activity: $e')),
      );
    }
  }
}

class ThematicReportsScreen extends StatelessWidget {
  const ThematicReportsScreen({super.key});

  // Stream to fetch Thematic Reports
  Stream<List<Map<String, dynamic>>> _thematicReportsStream() {
    return FirebaseFirestore.instance.collection('Designation').snapshots().asyncMap((departmentSnapshots) async { // Changed to departmentSnapshots to iterate departments
      List<Map<String, dynamic>> allReports = [];
      DocumentSnapshot thematicReportDoc = await FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('ThematicReport')
          .get();

      if (thematicReportDoc.exists) {
        Map<String, dynamic> reportData = thematicReportDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> thematicReportCategory = Map<String, dynamic>.from(reportData['ThematicReportIndicators'] ?? {});


        for (QueryDocumentSnapshot departmentDocSnap in departmentSnapshots.docs) { // Iterate through departments
          String departmentName = departmentDocSnap.id; // Department name is the doc id
          Map<String, dynamic> designationIndicators = Map<String, dynamic>.from(thematicReportCategory[departmentName] ?? {});


          for (var designationName in designationIndicators.keys) { // Iterate through designations within each department
            List<dynamic> indicatorsDynamic = designationIndicators[designationName] ?? [];
            List<String> indicatorsList = indicatorsDynamic.cast<String>().toList();

            if (indicatorsList.isNotEmpty) {
              allReports.add({
                'department': departmentName, // Include department in the report data
                'designation': designationName,
                'reportIndicators': indicatorsList,
                // You can add other relevant fields if needed, like report type, etc., if you decide to store them at this level.
              });
            }
          }
        }
      }
      return allReports;
    });
  }


  Future<void> _deleteThematicReport(BuildContext context, String department, String docId) async {
    // Deletion not directly applicable in this structure as we are updating a single document.
    // If you want to remove a department's indicators, you would update the 'ThematicReport' document,
    // setting the department's indicator field to null or deleting the field.
    // For now, a delete button here might not be the most appropriate action.
    // Consider revising the delete action based on your requirements.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete action is not directly supported in this format.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _thematicReportsStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No Thematic Reports created yet.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = snapshot.data![index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Department: ${data['department'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Designation: ${data['designation'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Text('Report Indicators:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (data['reportIndicators'] as List<String>).map((indicator) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text('- $indicator'),
                            )).toList(),
                          ),
                          // Add more fields as needed
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateActivityPage(thematicReportToEdit: {
                                  'department': data['department'],
                                  'designation': data['designation'],
                                  // You can pass other relevant data if needed for editing
                                }),
                              ),
                            );
                          },
                        ),
                        // Delete action might need revision as per comment in _deleteThematicReport
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  title: const Text("Confirm Delete"),
                                  content: const Text("Are you sure you want to delete this thematic report indicators for this department?"),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop(); // Dismiss the dialog
                                      },
                                    ),
                                    TextButton(
                                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      onPressed: () {
                                        // _deleteThematicReport(context, data['department'], data['docId']); // docId is not relevant here anymore
                                        Navigator.of(dialogContext).pop(); // Dismiss the dialog after delete
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OtherReportsScreen extends StatelessWidget {
  const OtherReportsScreen({super.key});


  Stream<List<Map<String, dynamic>>> _otherReportsStream() {
    return FirebaseFirestore.instance.collection('Designation').snapshots().asyncMap((departmentSnapshots) async {
      List<Map<String, dynamic>> allReports = [];
      for (QueryDocumentSnapshot departmentDocSnap in departmentSnapshots.docs) {
        QuerySnapshot otherSnapshots = await FirebaseFirestore.instance
            .collection('CreateReport')
            .doc('OtherReport')
            .collection(departmentDocSnap.id)
            .get();

        for (QueryDocumentSnapshot reportDocSnap in otherSnapshots.docs) {
          Map<String, dynamic> reportData = reportDocSnap.data() as Map<String, dynamic>;
          reportData['docId'] = reportDocSnap.id; // Include document ID
          reportData['department'] = departmentDocSnap.id; // Include department name
          allReports.add(reportData);
        }
      }
      return allReports;
    });
  }

  Future<void> _deleteOtherReport(BuildContext context, String department, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('OtherReport')
          .collection(department)
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Other Report deleted successfully!')),
      );
      // Add this line to trigger a rebuild of the widget tree
      if (context.mounted) { // Check if context is still valid
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      print("Error deleting other report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete Other Report: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _otherReportsStream(),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No Other Reports created yet.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = snapshot.data![index];
            Timestamp timestamp = data['createdAt'] as Timestamp? ?? Timestamp.now();
            DateTime dateTime = timestamp.toDate();
            String formattedDate = "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Department: ${data['department'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Facility Name: ${data['facilityName'] ?? 'N/A'}'),
                          Text('Activity Name: ${data['activityName'] ?? 'N/A'}'),
                          Text(
                              'Date: ${data['date'] != null ? "${(data['date'] as Timestamp).toDate().day}/${(data['date'] as Timestamp).toDate().month}/${(data['date'] as Timestamp).toDate().year}" : 'N/A'}'),
                          Text('Assigned To: ${data['assignedToFullName'] ?? 'N/A'} (${data['assignedToDepartment'] ?? 'N/A'})'),
                          Text('Created By: ${data['activityCreatedBy'] ?? 'N/A'}'),
                          Text('Created At: $formattedDate'),
                          // Add more fields as needed
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateActivityPage(otherReportToEdit: data),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  title: const Text("Confirm Delete"),
                                  content: const Text("Are you sure you want to delete this other report?"),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop(); // Dismiss the dialog
                                      },
                                    ),
                                    TextButton(
                                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      onPressed: () {
                                        _deleteOtherReport(context, data['department'], data['docId']);
                                        Navigator.of(dialogContext).pop(); // Dismiss the dialog after delete
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
