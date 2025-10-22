import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/drawer3.dart';

class StaffStatusReportPage extends StatefulWidget {
  const StaffStatusReportPage({super.key});

  @override
  State<StaffStatusReportPage> createState() => _StaffStatusReportPageState();
}

class _StaffStatusReportPageState extends State<StaffStatusReportPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Access guard
  Future<bool> _hasProgramManagementAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await _firestore.collection('Staff').doc(user.uid).get();
      final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
      return dept == 'program management';
    } catch (_) {
      return false;
    }
  }

  // Filters
  List<String> _availableStates = ['All States'];
  String _selectedState = 'All States';
  bool _isLoadingFilters = true;
  final List<String> _availableCategories = ['All Categories', 'Facility Staff', 'State Office Staff', 'Facility Supervisor', 'HQ Staff'];
  String _selectedCategory = 'All Categories';

  // Counts
  int _activeCount = 0;
  int _inactiveCount = 0;
  int _resignedCount = 0;
  int _terminatedCount = 0;

  // Tab controller
  late TabController _tabController;

  // Search controllers
  final Map<String, TextEditingController> _searchControllers = {
    'Active': TextEditingController(),
    'Inactive': TextEditingController(),
    'Resigned': TextEditingController(),
    'Terminated': TextEditingController(),
  };

  // Search queries
  final Map<String, Query> _searchQueries = {
    'Active': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Active').limit(500),
    'Inactive': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Inactive').limit(500),
    'Resigned': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Resigned').limit(500),
    'Terminated': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Terminated').limit(500),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadFilters();
    _loadCounts();
    
    // Add listeners to search controllers
    for (final status in _searchControllers.keys) {
      _searchControllers[status]!.addListener(_updateSearchQuery);
    }
    
    // Initialize search queries after filters are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onFilterChanged();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateSearchQuery() {
    final currentStatus = _currentStatus;
    final searchTerm = _searchControllers[currentStatus]!.text.toLowerCase();
    
    // Build base query with filters
    Query baseQuery = _firestore.collection('Staff').where('accountStatus', isEqualTo: currentStatus);
    if (_selectedState != 'All States') {
      baseQuery = baseQuery.where('state', isEqualTo: _selectedState);
    }
    if (_selectedCategory != 'All Categories') {
      baseQuery = baseQuery.where('staffCategory', isEqualTo: _selectedCategory);
    }
    
    if (searchTerm.isEmpty) {
      // No search term, just use base query
      _searchQueries[currentStatus] = baseQuery.orderBy('state').limit(500);
    } else {
      // Add search filter - search by fullName, firstName, lastName, and email
      _searchQueries[currentStatus] = baseQuery
          .where('fullName', isGreaterThanOrEqualTo: searchTerm)
          .where('fullName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .orderBy('state')
          .limit(500);
    }
    
    // Force rebuild of the list
    if (mounted) setState(() {});
  }

  void _onFilterChanged() {
    // Rebuild all search queries when filters change
    for (final status in _searchControllers.keys) {
      _updateSearchQueryForStatus(status);
    }
  }

  void _updateSearchQueryForStatus(String status) {
    final searchTerm = _searchControllers[status]!.text.toLowerCase();
    
    // Build base query with filters
    Query baseQuery = _firestore.collection('Staff').where('accountStatus', isEqualTo: status);
    if (_selectedState != 'All States') {
      baseQuery = baseQuery.where('state', isEqualTo: _selectedState);
    }
    if (_selectedCategory != 'All Categories') {
      baseQuery = baseQuery.where('staffCategory', isEqualTo: _selectedCategory);
    }
    
    if (searchTerm.isEmpty) {
      // No search term, just use base query
      _searchQueries[status] = baseQuery.orderBy('state').limit(500);
    } else {
      // Add search filter - search by fullName, firstName, lastName, and email
      _searchQueries[status] = baseQuery
          .where('fullName', isGreaterThanOrEqualTo: searchTerm)
          .where('fullName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .orderBy('state')
          .limit(500);
    }
  }

  Future<void> _reactivateAccount(String staffId, String staffName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate Account'),
        content: Text('Are you sure you want to reactivate $staffName? This will change their account status to Active.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('Staff').doc(staffId).update({
        'accountStatus': 'Active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$staffName has been reactivated successfully')),
        );
        _loadCounts(); // Refresh counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reactivate account: $e')),
        );
      }
    }
  }


  Future<void> _loadFilters() async {
    setState(() => _isLoadingFilters = true);
    try {
      // Load states
      final statesQuery = await _firestore.collection('Staff').where('accountStatus', isEqualTo: 'Active').get();
      final states = statesQuery.docs.map((doc) => (doc.data()['state'] as String? ?? '').trim()).toSet().where((s) => s.isNotEmpty).toList();
      states.sort();
      setState(() {
        _availableStates = ['All States', ...states];
        _selectedState = 'All States';
      });
    } catch (e) {
      debugPrint('StaffStatusReportPage _loadFilters error: $e');
    } finally {
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadCounts() async {
    try {
      final active = await _countForStatus('Active');
      final inactive = await _countForStatus('Inactive');
      final resigned = await _countForStatus('Resigned');
      final terminated = await _countForStatus('Terminated');

      if (mounted) {
        setState(() {
          _activeCount = active;
          _inactiveCount = inactive;
          _resignedCount = resigned;
          _terminatedCount = terminated;
        });
      }
    } catch (e) {
      debugPrint('StaffStatusReportPage _loadCounts error: $e');
    }
  }

  Future<int> _countForStatus(String status) async {
    try {
      Query q = _firestore.collection('Staff').where('accountStatus', isEqualTo: status);
      if (_selectedState != 'All States') {
        q = q.where('state', isEqualTo: _selectedState);
      }
      if (_selectedCategory != 'All Categories') {
        q = q.where('staffCategory', isEqualTo: _selectedCategory);
      }
      final snap = await q.count().get();
      return snap.count ?? 0;
    } catch (e, stack) {
      debugPrint('StaffStatusReportPage _countForStatus error: $e');
      debugPrint('STACK: $stack');
      rethrow;
    }
  }

  String get _currentStatus {
    switch (_tabController.index) {
      case 0:
        return 'Active';
      case 1:
        return 'Inactive';
      case 2:
        return 'Resigned';
      case 3:
        return 'Terminated';
      default:
        return 'Active';
    }
  }

  Query _buildListQueryForStatus(String status) {
    Query q = _firestore.collection('Staff')
        .where('accountStatus', isEqualTo: status);
    if (_selectedState != 'All States') {
      q = q.where('state', isEqualTo: _selectedState);
    }
    if (_selectedCategory != 'All Categories') {
      q = q.where('staffCategory', isEqualTo: _selectedCategory);
    }
    q = q.orderBy('state').limit(500);
    return q;
  }

  Future<void> _exportCurrentTabToExcel() async {
    final status = _currentStatus;
    try {
      Query q = _firestore.collection('Staff').where('accountStatus', isEqualTo: status);
      if (_selectedState != 'All States') {
        q = q.where('state', isEqualTo: _selectedState);
      }
      if (_selectedCategory != 'All Categories') {
        q = q.where('staffCategory', isEqualTo: _selectedCategory);
      }
      final snap = await q.limit(2000).get(); // reasonable cap

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No staff found for $status${_selectedState != 'All States' ? ' in $_selectedState' : ''}')),
        );
        return;
      }

      final excelInstance = excel.Excel.createExcel();
      final sheet = excelInstance['$status Staff'];
      // Header
      sheet.appendRow([
        excel.TextCellValue('Full Name'),
        excel.TextCellValue('Email'),
        excel.TextCellValue('Phone'),
        excel.TextCellValue('Department'),
        excel.TextCellValue('Designation'),
        excel.TextCellValue('State'),
        excel.TextCellValue('Location'),
        excel.TextCellValue('Status'),
        excel.TextCellValue('Account Number'),
        excel.TextCellValue('Bank Name'),
      ]);

      // Add data rows
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final fullName = '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'.trim();
        sheet.appendRow([
          excel.TextCellValue(fullName.isEmpty ? (data['fullName'] ?? 'N/A').toString() : fullName),
          excel.TextCellValue((data['emailAddress'] ?? 'N/A').toString()),
          excel.TextCellValue((data['mobile'] ?? 'N/A').toString()),
          excel.TextCellValue((data['department'] ?? 'N/A').toString()),
          excel.TextCellValue((data['designation'] ?? 'N/A').toString()),
          excel.TextCellValue((data['state'] ?? 'N/A').toString()),
          excel.TextCellValue((data['location'] ?? 'N/A').toString()),
          excel.TextCellValue((data['accountStatus'] ?? 'N/A').toString()),
          excel.TextCellValue((data['accountNumber'] ?? 'N/A').toString()),
          excel.TextCellValue((data['bankName'] ?? 'N/A').toString()),
        ]);
      }
      final bytes = excelInstance.save();
      if (bytes != null) {
        if (kIsWeb) {
          final safeState = _selectedState.replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
          final filename = 'Staff_${status}_${safeState.isEmpty ? 'AllStates' : safeState}.xlsx';
          final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = filename;
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        } else {
          // Mobile platform - show message that download is not supported
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel download is only supported on web platform'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProgramManagementAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Staff Status Report', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF722F37),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            drawer: drawer3(context),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final allowed = snapshot.data == true;
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Staff Status Report', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF722F37),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            drawer: drawer3(context),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You do not have permission to view this page.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Staff Status Report', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF722F37),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: _exportCurrentTabToExcel,
                tooltip: 'Export Current Tab to Excel',
              ),
            ],
          ),
          drawer: drawer3(context),
          body: Column(
            children: [
              // Summary cards
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard('Active', _activeCount, Colors.green),
                    _buildSummaryCard('Inactive', _inactiveCount, Colors.orange),
                    _buildSummaryCard('Resigned', _resignedCount, Colors.blue),
                    _buildSummaryCard('Terminated', _terminatedCount, Colors.red),
                  ],
                ),
              ),
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedState,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableStates.map((state) => DropdownMenuItem(
                          value: state,
                          child: Text(state),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedState = value ?? 'All States';
                            _loadCounts();
                            _onFilterChanged();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableCategories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value ?? 'All Categories';
                            _loadCounts();
                            _onFilterChanged();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: 'Active ($_activeCount)'),
                  Tab(text: 'Inactive ($_inactiveCount)'),
                  Tab(text: 'Resigned ($_resignedCount)'),
                  Tab(text: 'Terminated ($_terminatedCount)'),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStaffList('Active'),
                    _buildStaffList('Inactive'),
                    _buildStaffList('Resigned'),
                    _buildStaffList('Terminated'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String status, int count, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(String status) {
    final searchController = _searchControllers[status]!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search by name, email, or phone',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            onChanged: (value) {
              _updateSearchQuery();
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _searchQueries[status]!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No staff found'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final fullName = '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'.trim();
                  final email = data['emailAddress'] ?? 'N/A';
                  final phone = data['mobile'] ?? 'N/A';
                  final department = data['department'] ?? 'N/A';
                  final designation = data['designation'] ?? 'N/A';
                  final state = data['state'] ?? 'N/A';
                  final location = data['location'] ?? 'N/A';
                  final accountStatus = data['accountStatus'] ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      title: Text(fullName.isEmpty ? (data['fullName'] ?? 'N/A').toString() : fullName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: $email'),
                          Text('Phone: $phone'),
                          Text('Department: $department'),
                          Text('Designation: $designation'),
                          Text('State: $state'),
                          Text('Location: $location'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: _statusColor(accountStatus).withOpacity(0.1),
                              border: Border.all(
                                color: _statusColor(accountStatus),
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              accountStatus,
                              style: TextStyle(
                                color: _statusColor(accountStatus),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (status.toLowerCase() != 'active')
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'reactivate') {
                                  await _reactivateAccount(doc.id, fullName.isEmpty ? (data['fullName'] ?? 'N/A').toString() : fullName);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'reactivate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.refresh, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Reactivate Account'),
                                    ],
                                  ),
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
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'resigned':
        return Colors.blue;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}