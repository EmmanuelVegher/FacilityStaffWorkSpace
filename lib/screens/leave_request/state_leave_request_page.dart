// A STATE-LEVEL PAGE FOR MANAGING STAFF LEAVE REQUESTS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer2.dart'; // Assuming a state-level drawer (drawer2)

// --- DATA MODEL (Unchanged) ---
class LeaveRequest {
  final String id;
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String staffState;
  final String staffLocation;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  String status;
  final String? reason;
  String? reasonsForRejectedLeave;
  final String supervisorName;
  final String supervisorEmail;

  LeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.staffState,
    required this.staffLocation,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.reasonsForRejectedLeave,
    required this.supervisorName,
    required this.supervisorEmail,
  });

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    DateTime parseFirestoreDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is Timestamp) return dateValue.toDate();
      if (dateValue is String) return DateTime.tryParse(dateValue) ?? DateTime.now();
      return DateTime.now();
    }

    return LeaveRequest(
      id: doc.id,
      staffId: map['staffId'] ?? 'N/A',
      staffName: '${map['firstName'] ?? ''} ${map['lastName'] ?? 'Unknown'}'.trim(),
      staffEmail: map['staffEmail'] ?? 'N/A',
      staffState: map['staffState'] ?? 'N/A',
      staffLocation: map['staffLocation'] ?? 'N/A',
      leaveType: map['type'] ?? 'N/A',
      startDate: parseFirestoreDate(map['startDate']),
      endDate: parseFirestoreDate(map['endDate']),
      status: map['status'] ?? 'Pending',
      reason: map['reason'] as String?,
      reasonsForRejectedLeave: map['reasonsForRejectedLeave'] as String?,
      supervisorName: map['selectedSupervisor'] ?? 'N/A',
      supervisorEmail: map['selectedSupervisorEmail'] ?? 'N/A',
    );
  }
}

// --- MAIN WIDGET ---
class StateLeaveRequestManagementPage extends StatefulWidget {
  const StateLeaveRequestManagementPage({super.key});

  @override
  _StateLeaveRequestManagementPageState createState() => _StateLeaveRequestManagementPageState();
}

class _StateLeaveRequestManagementPageState extends State<StateLeaveRequestManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Core Data & UI State ---
  List<LeaveRequest> _masterLeaveList = [];
  List<LeaveRequest> _filteredLeaveList = [];
  bool _isFilterLoading = true;
  bool _isLoading = false;
  String? _errorMessage;

  String? _userState;
  String? _userDepartment;

  // --- Filter State ---
  List<String> _availableFacilities = [];
  final List<String> _availableLeaveTypes = ['All Types', 'Holiday', 'Annual', 'Sick', 'Maternity', 'Paternity', 'Unpaid', 'Other'];
  final List<String> _availableStatuses = ['All Statuses', 'Pending', 'Approved', 'Returned'];

  List<String> _selectedFacilities = ['All Facilities'];
  List<String> _selectedLeaveTypes = ['All Types'];
  List<String> _selectedStatuses = ['Pending'];


  @override
  void initState() {
    super.initState();
    _initializeUserStateAndFilters();
  }

  Future<void> _initializeUserStateAndFilters() async {
    setState(() => _isFilterLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      final userData = staffDoc.data();

      final userState = userData?['state'] as String?;
      final userDepartment = userData?['department'] as String?;

      if (userState == null || userState.isEmpty) {
        throw Exception("State not found in your user profile.");
      }

      _userState = userState;
      _userDepartment = userDepartment;

      await _loadFacilitiesForState(userState);
      await _loadLeaveRequests();

    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing page: $e");
    } finally {
      if (mounted) setState(() => _isFilterLoading = false);
    }
  }

  Future<void> _loadFacilitiesForState(String state) async {
    try {
      final Set<String> facilityNames = {'All Facilities'};
      final locationDoc = await _firestore.collection('Location').doc(state).get();
      if (locationDoc.exists) {
        final facilitiesSnapshot = await locationDoc.reference.collection(state).get();
        for (final facilityDoc in facilitiesSnapshot.docs) {
          final locationName = facilityDoc.data()['LocationName'] as String?;
          if (locationName != null && locationName.isNotEmpty) {
            facilityNames.add(locationName);
          }
        }
      }
      if (mounted) {
        setState(() {
          _availableFacilities = facilityNames.toList()..sort((a,b) {
            if (a == 'All Facilities') return -1;
            if (b == 'All Facilities') return 1;
            return a.compareTo(b);
          });
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error loading facilities: $e");
    }
  }

  Future<void> _loadLeaveRequests() async {
    if (_userState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User state not found. Cannot load requests.")));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _masterLeaveList.clear();
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in.")));
        return;
      }
      final userEmail = (user.email ?? '').toLowerCase();

      Query query = _firestore.collectionGroup('Leave Request').where('status', isEqualTo: 'Pending');

      final snapshot = await query.get();

      if (mounted) {
        List<LeaveRequest> allFetchedRequests = snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList();

        if (_userDepartment != 'Program Management') {
          allFetchedRequests = allFetchedRequests.where((req) {
            return req.supervisorEmail.toLowerCase() == userEmail;
          }).toList();
        }

        setState(() {
          _masterLeaveList = allFetchedRequests;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading leave requests: $e\n$stack');
      if (mounted) {
        if (e is FirebaseException && e.code == 'failed-precondition') {
          _errorMessage = 'Firestore Index Required: An index is needed for this query. Please check the Firestore console.';
        } else {
          _errorMessage = "Failed to load leave requests: $e";
        }
        _isLoading = false;
      }
    }
  }

  void _applyFilters() {
    List<LeaveRequest> filtered = List.from(_masterLeaveList);

    if (!_selectedFacilities.contains('All Facilities')) {
      filtered = filtered.where((req) => _selectedFacilities.contains(req.staffLocation)).toList();
    }
    if (!_selectedLeaveTypes.contains('All Types')) {
      filtered = filtered.where((req) => _selectedLeaveTypes.contains(req.leaveType)).toList();
    }
    if (!_selectedStatuses.contains('All Statuses')) {
      filtered = filtered.where((req) => _selectedStatuses.contains(req.status)).toList();
    }

    filtered.sort((a,b) => a.startDate.compareTo(b.startDate));

    setState(() {
      _filteredLeaveList = filtered;
    });
  }

  Future<void> _updateLeaveStatus(LeaveRequest request, String newStatus, {String? reasonForReturn}) async {
    try {
      final updateData = <String, dynamic>{'status': newStatus};
      if (reasonForReturn != null) {
        updateData['reasonsForRejectedLeave'] = reasonForReturn;
      }

      await _firestore
          .collection('Staff')
          .doc(request.staffId)
          .collection('Leave Request')
          .doc(request.id)
          .update(updateData);

      setState(() {
        request.status = newStatus;
        if (reasonForReturn != null) {
          request.reasonsForRejectedLeave = reasonForReturn;
        }

        if (!_selectedStatuses.contains('All Statuses') && !_selectedStatuses.contains(newStatus)) {
          _masterLeaveList.removeWhere((item) => item.id == request.id);
        }
        _applyFilters();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${request.staffName}'s leave has been ${newStatus.toLowerCase()}."), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating status: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showReturnReasonDialog(LeaveRequest request) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reason for Returning Leave'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: ListBody(
                children: <Widget>[
                  Text('Please provide a reason for returning this leave request for ${request.staffName}.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., conflicting dates, more info needed...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reason cannot be empty.';
                      }
                      return null;
                    },
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _updateLeaveStatus(request, 'Returned', reasonForReturn: reasonController.text.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Leave Request",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5C1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: drawer2(context),
      body: SelectionArea(
        child: Column(
          children: [
            _buildFilterBar(),
            if (_errorMessage != null)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ))),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLeaveList.isEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                  "No leave requests match the selected criteria.",
                                  style: TextStyle(
                                      color: Colors.grey.shade600))))
                      : _buildLeaveRequestList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (_isFilterLoading) const Text("Loading filters...") else ...[
              _buildMultiSelectDialogButton("Facility", _selectedFacilities, _availableFacilities, (results) { setState(() => _selectedFacilities = results); _applyFilters(); }),
              _buildMultiSelectDialogButton("Leave Type", _selectedLeaveTypes, _availableLeaveTypes, (results) { setState(() => _selectedLeaveTypes = results); _applyFilters(); }),
              _buildMultiSelectDialogButton("Status", _selectedStatuses, _availableStatuses, (results) { setState(() => _selectedStatuses = results); _applyFilters(); }),
            ],
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: Text('Apply Filter', style: GoogleFonts.poppins()),
              onPressed: _isLoading || _isFilterLoading ? null : _loadLeaveRequests,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C1A2E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _filteredLeaveList.length,
      itemBuilder: (context, index) {
        final request = _filteredLeaveList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.staffName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(request.staffLocation, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    _buildStatusWidget(request),
                  ],
                ),
                const Divider(height: 16),
                _buildInfoRow(Icons.email_outlined, "Staff Email:", request.staffEmail),
                _buildInfoRow(Icons.person_outline, "Supervisor:", request.supervisorName),
                _buildInfoRow(Icons.alternate_email, "Supervisor Email:", request.supervisorEmail),
                const SizedBox(height: 4),
                _buildInfoRow(Icons.calendar_today_outlined, "Leave Type:", request.leaveType),
                _buildInfoRow(Icons.date_range, "Dates:", '${DateFormat.yMMMMd().format(request.startDate)} to ${DateFormat.yMMMMd().format(request.endDate)}'),
                if (request.reason != null && request.reason!.isNotEmpty)
                  _buildInfoRow(Icons.notes, "Staff Reason:", request.reason!),
                if (request.reasonsForRejectedLeave != null && request.reasonsForRejectedLeave!.isNotEmpty)
                  _buildInfoRow(Icons.comment_bank_outlined, "Return Reason:", request.reasonsForRejectedLeave!),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HELPER & UI WIDGETS ---

  // MODIFIED: This widget now conditionally renders a clickable menu or a static chip
  // based on the user's department.
  Widget _buildStatusWidget(LeaveRequest request) {
    // Show a static (non-clickable) chip if:
    // 1. The status is anything other than 'Pending'.
    // 2. The logged-in user is from 'Program Management' (read-only view).
    if (request.status != 'Pending' || _userDepartment == 'Program Management') {
      return _buildStatusChip(request.status);
    }

    // Otherwise (status is 'Pending' AND user is a standard supervisor), show the clickable menu.
    return PopupMenuButton<String>(
      onSelected: (String result) {
        if (result == 'Approve') {
          _updateLeaveStatus(request, 'Approved');
        } else if (result == 'Return') {
          _showReturnReasonDialog(request);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'Approve',
          child: ListTile(
            leading: Icon(Icons.check_circle_outline, color: Colors.green),
            title: Text('Approve'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Return',
          child: ListTile(
            leading: Icon(Icons.undo_outlined, color: Colors.blueAccent),
            title: Text('Return'),
          ),
        ),
      ],
      child: Chip(
        label: const Text('Pending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        avatar: const Icon(Icons.arrow_drop_down, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch(status) {
      case 'Approved': color = Colors.green; break;
      case 'Returned': color = Colors.blue; break;
      case 'Declined': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }


  Widget _buildMultiSelectDialogButton(String title, List<String> selectedOptions, List<String> allOptions, Function(List<String>) onConfirm) {
    String getButtonText() {
      if (title == "Facility" && selectedOptions.contains("All Facilities")) return "All Facilities";
      if (title == "Leave Type" && selectedOptions.contains("All Types")) return "All Types";
      if (title == "Status" && selectedOptions.contains("All Statuses")) return "All Statuses";

      if (selectedOptions.length == 1) return selectedOptions.first;
      if (selectedOptions.isEmpty) return "Select $title";
      return '${selectedOptions.length} ${title}s Selected';
    }

    return OutlinedButton(
      onPressed: allOptions.length <= 1 ? null : () => _showMultiSelectDialog(title, selectedOptions, allOptions, onConfirm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(getButtonText()),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }

  Future<void> _showMultiSelectDialog(String title, List<String> selectedOptions, List<String> allOptions, Function(List<String>) onConfirm) async {
    List<String> tempSelected = List.from(selectedOptions);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isAllSelected = tempSelected.length == allOptions.length;

          return AlertDialog(
            title: Text('Select $title'),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Select All", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5C1A2E))),
                    value: isAllSelected,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelected = List.from(allOptions);
                        } else {
                          tempSelected.clear();
                        }
                      });
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: allOptions.map((option) {
                        bool isSpecialAll = option.startsWith("All");
                        return CheckboxListTile(
                          title: Text(option, style: isSpecialAll ? const TextStyle(fontWeight: FontWeight.bold) : null),
                          value: tempSelected.contains(option),
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                if (isSpecialAll) {
                                  tempSelected = List.from(allOptions);
                                } else {
                                  tempSelected.add(option);
                                  // If all individual items are selected, add the "All" item too
                                  if (tempSelected.length == allOptions.length - 1 && !tempSelected.any((o) => o.startsWith("All"))) {
                                    tempSelected.add(allOptions.firstWhere((o) => o.startsWith("All")));
                                  }
                                }
                              } else {
                                if (isSpecialAll) {
                                  tempSelected.clear();
                                } else {
                                  tempSelected.remove(option);
                                  // Remove the "All" item if any individual item is unchecked
                                  tempSelected.removeWhere((item) => item.startsWith("All"));
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("OK"),
                onPressed: () {
                  onConfirm(tempSelected);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}