// A ROBUST PAGE FOR REVIEWING STAFF LEAVE REQUESTS STATE-WIDE

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../widgets/drawer2.dart'; // Assuming a state-level drawer

// --- DATA MODEL TO MATCH FIRESTORE STRUCTURE ---

class LeaveRequestModel {
  final String id; // Document ID
  final String path; // Full path to the document for updates
  final String staffName;
  final String staffLocation;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final num leaveDuration;
  final String reason;
  final String status;
  final String? rejectionReason;

  LeaveRequestModel({
    required this.id,
    required this.path,
    required this.staffName,
    required this.staffLocation,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.leaveDuration,
    required this.reason,
    required this.status,
    this.rejectionReason,
  });

  factory LeaveRequestModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    DateTime _parseDate(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    return LeaveRequestModel(
      id: snapshot.id,
      path: snapshot.reference.path,
      staffName: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
      staffLocation: data['staffLocation'] ?? 'N/A',
      leaveType: data['type'] ?? 'N/A',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      leaveDuration: data['leaveDuration'] ?? 0,
      reason: data['reason'] ?? 'No reason provided.',
      status: data['status'] ?? 'Pending',
      rejectionReason: data['reasonsForRejectedLeave'] as String?,
    );
  }
}

// --- MAIN WIDGET ---
class LeaveRequestReviewPage extends StatefulWidget {
  const LeaveRequestReviewPage({super.key});

  @override
  _LeaveRequestReviewPageState createState() => _LeaveRequestReviewPageState();
}

class _LeaveRequestReviewPageState extends State<LeaveRequestReviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Filter & Stream Controllers ---
  String? _userState;
  Stream<List<LeaveRequestModel>>? _leaveStream;

  final _statusController = BehaviorSubject<String>.seeded('Pending');
  final _facilityController = BehaviorSubject<String?>.seeded(null);
  final _dateRangeController = BehaviorSubject<DateTimeRange?>();

  List<String> _availableFacilities = [];

  @override
  void initState() {
    super.initState();
    _initializeFiltersAndStream();
  }

  @override
  void dispose() {
    _statusController.close();
    _facilityController.close();
    _dateRangeController.close();
    super.dispose();
  }

  Future<void> _initializeFiltersAndStream() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in.");
      final staffDoc = await _firestore.collection('Staff').doc(user.uid).get();
      _userState = staffDoc.data()?['state'] as String?;
      if (_userState == null) throw Exception("User state not found.");

      // Fetch facilities for the dropdown
      final staffSnapshot = await _firestore
          .collection('Staff')
          .where('state', isEqualTo: _userState)
          .where('staffCategory', isEqualTo: 'Facility Staff')
          .get();

      // NEW, CORRECTED CODE
      final facilities = staffSnapshot.docs
          .map((doc) => doc.data()['location'] as String?)
          .whereType<String>() // This filters nulls AND returns an Iterable<String>
          .toSet().toList()..sort();

      _availableFacilities = ['All Facilities', ...facilities];
      _facilityController.add('All Facilities');

      // Combine all filter streams to create the main data stream
      _leaveStream = Rx.combineLatest3(
          _statusController.stream,
          _facilityController.stream,
          _dateRangeController.stream,
              (status, facility, dateRange) => {'status': status, 'facility': facility, 'range': dateRange}
      ).switchMap((filters) => _fetchLeaveRequests(filters));

      if(mounted) setState(() {});

    } catch (e, s) {
      debugPrint("Error initializing leave review page: $e\n$s");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error initializing: $e")));
    }
  }

  Stream<List<LeaveRequestModel>> _fetchLeaveRequests(Map<String, dynamic> filters) {
    if (_userState == null) return Stream.value([]);

    Query query = _firestore.collectionGroup('Leave Request')
        .where('staffState', isEqualTo: _userState);

    // Apply filters
    if (filters['status'] != null && filters['status'] != 'All') {
      query = query.where('status', isEqualTo: filters['status']);
    }
    if (filters['facility'] != null && filters['facility'] != 'All Facilities') {
      query = query.where('staffLocation', isEqualTo: filters['facility']);
    }
    if (filters['range'] != null) {
      final range = filters['range'] as DateTimeRange;
      query = query.where('startDate', isGreaterThanOrEqualTo: range.start.toIso8601String())
          .where('startDate', isLessThanOrEqualTo: range.end.toIso8601String());
    }

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs.map((doc) => LeaveRequestModel.fromSnapshot(doc)).toList();
      requests.sort((a,b) => a.startDate.compareTo(b.startDate));
      return requests;
    });
  }

  // --- ACTION METHODS ---

  Future<void> _updateLeaveStatus(String docPath, String newStatus, {String? reason}) async {
    try {
      final updateData = {'status': newStatus};
      if (newStatus == 'Rejected' && reason != null) {
        updateData['reasonsForRejectedLeave'] = reason;
      }
      await _firestore.doc(docPath).update(updateData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave request has been $newStatus."), backgroundColor: Colors.green,));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update status: $e"), backgroundColor: Colors.red,));
    }
  }

  void _showRejectionDialog(String docPath) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reason for Rejection"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Enter reason..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                _updateLeaveStatus(docPath, 'Rejected', reason: reasonController.text);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reason cannot be empty.")));
              }
            },
            child: const Text("Reject"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDateRange: _dateRangeController.value,
    );
    if (range != null) {
      _dateRangeController.add(range);
    }
  }

  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Leave Request Management")),
      drawer: drawer2(context),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<LeaveRequestModel>>(
              stream: _leaveStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Leave Stream Error: ${snapshot.error}");
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                final leaveRequests = snapshot.data ?? [];
                if (leaveRequests.isEmpty) {
                  return const Center(child: Text("No leave requests found for the selected criteria."));
                }
                return _buildLeaveRequestList(leaveRequests);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Status Filter
            DropdownButtonFormField<String>(
              value: _statusController.value,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: ['All', 'Pending', 'Approved', 'Rejected'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) => _statusController.add(value!),
            ),
            // Facility Filter
            if (_availableFacilities.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _facilityController.value,
                decoration: const InputDecoration(labelText: 'Facility', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: _availableFacilities.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (value) => _facilityController.add(value!),
              ),
            // Date Range Filter
            OutlinedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range),
              label: Text(_dateRangeController.hasValue
                  ? '${DateFormat('dd/MM/yy').format(_dateRangeController.value!.start)} - ${DateFormat('dd/MM/yy').format(_dateRangeController.value!.end)}'
                  : 'Select Date Range'
              ),
            ),
            if (_dateRangeController.hasValue)
              IconButton(onPressed: () => _dateRangeController.add(null), icon: const Icon(Icons.clear), tooltip: "Clear Date Filter"),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestList(List<LeaveRequestModel> requests) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            leading: CircleAvatar(child: Text(request.leaveDuration.toString())),
            title: Text(request.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${request.leaveType} @ ${request.staffLocation}'),
            trailing: _buildStatusChip(request.status),
            children: [_buildExpansionDetails(request)],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Approved': color = Colors.green; break;
      case 'Rejected': color = Colors.red; break;
      case 'Pending':
      default: color = Colors.orange; break;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildExpansionDetails(LeaveRequestModel request) {
    final df = DateFormat('EEE, dd MMM yyyy');
    return Padding(
      padding: const EdgeInsets.all(16.0).copyWith(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Dates: ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: '${df.format(request.startDate)} to ${df.format(request.endDate)}'),
          ])),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Reason: ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: request.reason),
          ])),
          if (request.status == 'Rejected' && request.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Rejection Reason: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              TextSpan(text: request.rejectionReason!, style: const TextStyle(color: Colors.red)),
            ])),
          ],
          if (request.status == 'Pending') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  onPressed: () => _showRejectionDialog(request.path),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  onPressed: () => _updateLeaveStatus(request.path, 'Approved'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                )
              ],
            )
          ]
        ],
      ),
    );
  }
}