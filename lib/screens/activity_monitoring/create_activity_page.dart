import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../widgets/button.dart';
import '../../widgets/drawer.dart';
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
  TextEditingController _indicatorController = TextEditingController();
  String _selectedResponseType = 'Input Box';
  String? _selectedThematicDepartment; // For Thematic Activity Department Dropdown
  List<String> _departments = []; // To store departments from "Designation"
  String? _selectedAssignedDepartment; // For Other Activity Department Dropdown
  DateTime? _selectedDate; // For Date Picker in Other Activity
  TextEditingController _activityNameController = TextEditingController(); // For Activity Name in Other Activity
  List<Map<String, dynamic>> _selectedAssignedUsers = []; // Modified to store full name also
  List<Map<String, dynamic>> _staffListForDepartment = []; // To store staff based on selected department
  int _selectedIndex = 0; // For bottom navigation bar
  late String _loggedInUserFullName = '';
  late String _loggedInUserId = '';
  String? _currentUserState;
  String? _selectedFacilityName;
  List<String> _facilityNames = [];

  List<String> _reportTypes = ['Daily', 'Weekly', 'Monthly'];
  List<String> _responseTypes = ['Input Box', 'Numerator/Denominator'];

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

  Future<void> _fetchStaffForDepartmentAndFacility(String department, String? facilityName) async {
    setState(() {
      _staffListForDepartment = []; // Clear previous staff list
      _selectedAssignedUsers = []; // Clear selected users when department changes
    });
    if (department.isNotEmpty) {
      try {
        Query<Map<String, dynamic>> staffQuery = FirebaseFirestore.instance.collection('Staff') as CollectionReference<Map<String, dynamic>>;
        staffQuery = staffQuery.where('department', isEqualTo: department);
        if (facilityName != null && facilityName.isNotEmpty) {
          staffQuery = staffQuery.where('location', isEqualTo: facilityName);
        }

        final QuerySnapshot<Map<String, dynamic>> staffSnapshot = await staffQuery.get() as QuerySnapshot<Map<String, dynamic>>;

        setState(() {
          _staffListForDepartment = staffSnapshot.docs.map((doc) {
            final data = doc.data()!;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text("Thematic Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(child: ThematicReportsScreen()),
          const SizedBox(height: 20),
          const Text("Other Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: 'For which Department'),
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
                  });
                },
                validator: (value) => value == null ? 'Please select a department' : null,
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
                controller: _indicatorController,
                decoration: const InputDecoration(labelText: 'Indicator'),
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
                  label: _isEditThematicMode ? 'Update Thematic Activity' : 'Create Thematic Activity',
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
    String indicator = _indicatorController.text.trim();
    String responseType = _selectedResponseType;
    String? department = _selectedThematicDepartment;

    if (indicator.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indicator cannot be empty')),
      );
      return;
    }
    if (department == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    try {
      final thematicReportRef = FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('ThematicReport')
          .collection(department);

      if (_isEditThematicMode && _thematicReportDocId != null) {
        // Update existing document
        await thematicReportRef.doc(_thematicReportDocId).update({
          'reportType': reportType,
          'indicator': indicator,
          'responseType': responseType,
          'department': department,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thematic Activity Updated!')),
        );
      } else {
        // Create new document
        final docId = const Uuid().v4(); // Generate UUID for sub-document
        await thematicReportRef.doc(docId).set({
          'reportType': reportType,
          'indicator': indicator,
          'responseType': responseType,
          'department': department,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thematic Activity Created!')),
        );
      }


      _indicatorController.clear();
      setState(() {
        _selectedThematicDepartment = null;
        _isEditThematicMode = false;
        _thematicReportDocId = null;
      });


    } catch (e) {
      print("Error creating/updating thematic activity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create/update Thematic Activity: $e')),
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
  // Stream to fetch Thematic Reports
  Stream<List<Map<String, dynamic>>> _thematicReportsStream() {
    return FirebaseFirestore.instance.collection('Designation').snapshots().asyncMap((departmentSnapshots) async {
      List<Map<String, dynamic>> allReports = [];
      for (QueryDocumentSnapshot departmentDocSnap in departmentSnapshots.docs) {
        QuerySnapshot thematicSnapshots = await FirebaseFirestore.instance
            .collection('CreateReport')
            .doc('ThematicReport')
            .collection(departmentDocSnap.id)
            .get();

        for (QueryDocumentSnapshot reportDocSnap in thematicSnapshots.docs) {
          Map<String, dynamic> reportData = reportDocSnap.data() as Map<String, dynamic>;
          reportData['docId'] = reportDocSnap.id; // Include document ID
          reportData['department'] = departmentDocSnap.id; // Include department name
          allReports.add(reportData);
        }
      }
      return allReports;
    });
  }

  Future<void> _deleteThematicReport(BuildContext context, String department, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('CreateReport')
          .doc('ThematicReport')
          .collection(department)
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thematic Report deleted successfully!')),
      );
      // Add this line to trigger a rebuild of the widget tree
      if (context.mounted) { // Check if context is still valid
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      print("Error deleting thematic report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete Thematic Report: $e')),
      );
    }
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
                          Text('Report Type: ${data['reportType'] ?? 'N/A'}'),
                          Text('Indicator: ${data['indicator'] ?? 'N/A'}'),
                          Text('Response Type: ${data['responseType'] ?? 'N/A'}'),
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
                                builder: (context) => CreateActivityPage(thematicReportToEdit: data),
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
                                  content: const Text("Are you sure you want to delete this thematic report?"),
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
                                        _deleteThematicReport(context, data['department'], data['docId']);
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