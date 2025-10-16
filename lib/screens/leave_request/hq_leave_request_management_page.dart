// A NATIONWIDE PAGE FOR MANAGING STAFF LEAVE REQUESTS (CORRECTED)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../widgets/drawer3.dart'; // Assuming a generic app drawer

// --- DATA MODEL (Unchanged, as it already handles string parsing) ---

// --- DATA MODEL (UPDATED) ---
class LeaveRequest {
  final String id; // Document ID for updates
  final String staffId;
  final String staffName;
  final String staffEmail; // NEW
  final String staffState;
  final String staffLocation;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  String status; // Made non-final to allow in-app state changes
  final String? reason;
  final String supervisorName; // NEW
  final String supervisorEmail; // NEW

  LeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.staffEmail, // NEW
    required this.staffState,
    required this.staffLocation,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    required this.supervisorName, // NEW
    required this.supervisorEmail, // NEW
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
      staffEmail: map['staffEmail'] ?? 'N/A', // NEW
      staffState: map['staffState'] ?? 'N/A',
      staffLocation: map['staffLocation'] ?? 'N/A',
      leaveType: map['type'] ?? 'N/A',
      startDate: parseFirestoreDate(map['startDate']),
      endDate: parseFirestoreDate(map['endDate']),
      status: map['status'] ?? 'Pending',
      reason: map['reason'] as String?,
      supervisorName: map['selectedSupervisor'] ?? 'N/A', // NEW
      supervisorEmail: map['selectedSupervisorEmail'] ?? 'N/A', // NEW
    );
  }
}
// --- MAIN WIDGET ---
class LeaveRequestManagementPage extends StatefulWidget {
  const LeaveRequestManagementPage({super.key});

  @override
  _LeaveRequestManagementPageState createState() => _LeaveRequestManagementPageState();
}

class _LeaveRequestManagementPageState extends State<LeaveRequestManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<LeaveRequest> _masterLeaveList = [];
  List<LeaveRequest> _filteredLeaveList = [];
  bool _isFilterLoading = true;
  bool _isLoading = false;
  String? _errorMessage;

  List<String> _availableStates = [];
  List<String> _availableFacilities = [];
  final List<String> _availableLeaveTypes = ['All Types', 'Holiday', 'Annual', 'Sick', 'Maternity', 'Paternity', 'Unpaid', 'Other'];
  final List<String> _availableStatuses = ['All Statuses', 'Pending', 'Approved', 'Declined'];

  List<String> _selectedStates = ['All States'];
  List<String> _selectedFacilities = ['All Facilities'];
  List<String> _selectedLeaveTypes = ['All Types'];
  List<String> _selectedStatuses = ['Pending'];

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _initializeFilters();
  }

  Future<void> _initializeFilters() async {
    // Use the main page loader for the entire initialization process.
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('Location').get();
      final states = snapshot.docs.map((doc) => doc.id).where((id) => id.isNotEmpty).toList();

      if (mounted) {
        // 1. Set the available states. The default selection is already set.
        setState(() {
          _availableStates = ['All States', ...states..sort()];
        });

        // 2. Await the population of the dependent facility filter based on the default state.
        await _onStateSelectionChange(_selectedStates);

        if (!mounted) return;

        // 3. With default filters now ready, trigger the initial data load.
        await _loadLeaveRequests();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error initializing page: $e");
    } finally {
      // 4. Turn off the main loader when all startup tasks are complete.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFilterLoading = false; // Also ensure the filter-specific loader is off.
        });
      }
    }
  }

  Future<void> _onStateSelectionChange(List<String> selected) async {
    setState(() {
      _selectedStates = selected;
      _isFilterLoading = true;
      _selectedFacilities = ['All Facilities'];
      _availableFacilities = ['All Facilities'];
      _masterLeaveList.clear();
      _applyFilters();
    });

    List<String> statesToQuery = _selectedStates.contains('All States')
        ? _availableStates.where((s) => s != 'All States').toList()
        : _selectedStates;

    if (statesToQuery.isNotEmpty) {
      try {
        final Set<String> facilityNames = {};
        for (var i = 0; i < statesToQuery.length; i += 30) {
          final chunk = statesToQuery.sublist(i, min(i + 30, statesToQuery.length));
          final locationDocs = await _firestore.collection('Location').where(FieldPath.documentId, whereIn: chunk).get();
          for (final doc in locationDocs.docs) {
            final facilitiesSnapshot = await doc.reference.collection(doc.id).get();
            for (final facilityDoc in facilitiesSnapshot.docs) {
              final locationName = facilityDoc.data()['LocationName'] as String?;
              if (locationName != null && locationName.isNotEmpty) {
                facilityNames.add(locationName);
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _availableFacilities.addAll(facilityNames.toList()..sort());
          });
        }
      } catch (e) {
        if (mounted) setState(() => _errorMessage = "Error updating facility filter: $e");
      }
    }
    if (mounted) setState(() => _isFilterLoading = false);
  }

  // --- MODIFIED: This function is completely rewritten ---
  Future<void> _loadLeaveRequests() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a valid date range.")));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _masterLeaveList.clear();
    });

    try {
      // Step 1: Build the base query without date filters.
      // We can still filter by state as that's an exact match.
      Query query = _firestore.collectionGroup('Leave Request');

      List<String> statesToQuery = _selectedStates.contains('All States')
          ? _availableStates.where((s) => s != 'All States').toList()
          : _selectedStates;

      if (statesToQuery.isNotEmpty) {
        // This query requires a Firestore Index on 'staffState' for the 'Leave Request' collection group.
        query = query.where('staffState', whereIn: statesToQuery);
      }

      final snapshot = await query.get();

      // Step 2: Manually filter the fetched results in the app.
      if (mounted) {
        List<LeaveRequest> allFetchedRequests = snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList();

        // Perform date filtering client-side
        final clientFilteredRequests = allFetchedRequests.where((req) {
          final reqStartDate = DateUtils.dateOnly(req.startDate);
          final filterStartDate = DateUtils.dateOnly(_startDate!);
          final filterEndDate = DateUtils.dateOnly(_endDate!);

          return (reqStartDate.isAfter(filterStartDate) || reqStartDate.isAtSameMomentAs(filterStartDate)) &&
              (reqStartDate.isBefore(filterEndDate) || reqStartDate.isAtSameMomentAs(filterEndDate));
        }).toList();

        setState(() {
          _masterLeaveList = clientFilteredRequests;
          _applyFilters(); // This will apply the rest of the dropdown filters
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading leave requests: $e\n$stack');
      if (mounted) {
        if (e is FirebaseException && e.code == 'failed-precondition') {
          _errorMessage = 'Firestore Index Required: An index on "staffState" for the "Leave Request" collection group is needed. Please check your debug console for a link to create it.';
        } else {
          _errorMessage = "Failed to load leave requests: $e";
        }
        _isLoading = false;
      }
    }
  }

  void _applyFilters() {
    List<LeaveRequest> filtered = List.from(_masterLeaveList);

    // State filter is already applied in the Firestore query, but we re-apply for consistency
    if (!_selectedStates.contains('All States')) {
      filtered = filtered.where((req) => _selectedStates.contains(req.staffState)).toList();
    }
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

  Future<void> _updateLeaveStatus(LeaveRequest request, String newStatus) async {
    try {
      await _firestore
          .collection('Staff')
          .doc(request.staffId)
          .collection('Leave Request')
          .doc(request.id)
          .update({'status': newStatus});

      setState(() {
        request.status = newStatus;
        // Optionally, re-apply filters if the list should hide the updated item
        if (!_selectedStatuses.contains('All Statuses') && !_selectedStatuses.contains(newStatus)) {
          _masterLeaveList.removeWhere((item) => item.id == request.id);
          _applyFilters();
        }
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

  // --- UI BUILDER METHODS (Unchanged from here down) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Request Management", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: drawer3(context),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_errorMessage != null) Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,))),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLeaveList.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text("No leave requests match the selected criteria.", style: TextStyle(color: Colors.grey.shade600))))
                : _buildLeaveRequestList(),
          ),
        ],
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
              _buildMultiSelectDialogButton("State", _selectedStates, _availableStates, _onStateSelectionChange),
              _buildMultiSelectDialogButton("Facility", _selectedFacilities, _availableFacilities, (results) => setState(() => _selectedFacilities = results)),
              _buildMultiSelectDialogButton("Leave Type", _selectedLeaveTypes, _availableLeaveTypes, (results) => setState(() => _selectedLeaveTypes = results)),
              _buildMultiSelectDialogButton("Status", _selectedStatuses, _availableStatuses, (results) => setState(() => _selectedStatuses = results)),
            ],
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply Filter'),
              onPressed: _isLoading || _isFilterLoading ? null : _loadLeaveRequests,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }


// --- UI BUILDER METHOD (UPDATED) ---
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
                    _buildStatusChip(request.status),
                  ],
                ),
                const Divider(height: 16),
                // --- NEW FIELDS DISPLAYED HERE ---
                _buildInfoRow(Icons.email_outlined, "Staff Email:",
                    request.staffEmail),
                _buildInfoRow(Icons.person_outline, "Supervisor:", request.supervisorName),
                _buildInfoRow(Icons.alternate_email, "Supervisor Email:", request.supervisorEmail),
                const SizedBox(height: 4),
                // --- END OF NEW FIELDS ---
                _buildInfoRow(Icons.calendar_today_outlined, "Leave Type:", request.leaveType),
                _buildInfoRow(Icons.date_range, "Dates:", '${DateFormat.yMMMMd().format(request.startDate)} to ${DateFormat.yMMMMd().format(request.endDate)}'),
                if (request.reason != null && request.reason!.isNotEmpty)
                  _buildInfoRow(Icons.notes, "Reason:", request.reason!),
                const SizedBox(height: 8),
                // if (request.status == 'Pending')
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.end,
                //     children: [
                //       TextButton.icon(
                //         icon: const Icon(Icons.close, color: Colors.red),
                //         label: const Text("Decline", style: TextStyle(color: Colors.red)),
                //         onPressed: () => _updateLeaveStatus(request, 'Declined'),
                //       ),
                //       const SizedBox(width: 8),
                //       ElevatedButton.icon(
                //         icon: const Icon(Icons.check, color: Colors.white),
                //         label: const Text("Approve"),
                //         style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                //         onPressed: () => _updateLeaveStatus(request, 'Approved'),
                //       ),
                //     ],
                //   ),
              ],
            ),
          ),
        );
      },
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
      case 'Declined': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: SizedBox(
          width: 350,
          height: 400,
          child: SfDateRangePicker(
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: PickerDateRange(_startDate, _endDate),
            showActionButtons: true,
            onSubmit: (Object? value) {
              if (value is PickerDateRange && value.startDate != null) {
                setState(() {
                  _startDate = value.startDate;
                  _endDate = value.endDate ?? value.startDate;
                });
              }
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectDialogButton(String title, List<String> selectedOptions, List<String> allOptions, Function(List<String>) onConfirm) {
    String getButtonText() {
      final allKeyword = "All ${title}s";
      if (selectedOptions.contains(allKeyword) || selectedOptions.isEmpty) return allKeyword;
      if (selectedOptions.length == 1) return selectedOptions.first;
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
    final allKeyword = "All ${title}s";

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Select $title'),
            content: SizedBox(
              width: 350,
              child: ListView(
                shrinkWrap: true,
                children: allOptions.map((option) {
                  return CheckboxListTile(
                    title: Text(option, style: option == allKeyword ? const TextStyle(fontWeight: FontWeight.bold) : null),
                    value: tempSelected.contains(option),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          if (option == allKeyword) {
                            tempSelected.clear();
                            tempSelected.add(allKeyword);
                          } else {
                            tempSelected.remove(allKeyword);
                            tempSelected.add(option);
                          }
                        } else {
                          tempSelected.remove(option);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(child: const Text('CANCEL'), onPressed: () => Navigator.pop(context)),
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () {
                  if (tempSelected.isEmpty && allOptions.contains(allKeyword)) {
                    tempSelected.add(allKeyword);
                  }
                  // This is a special case for the state filter
                  if (title == "State") {
                    onConfirm(tempSelected);
                  } else {
                    setState(() => onConfirm(tempSelected));
                    _applyFilters();
                  }
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