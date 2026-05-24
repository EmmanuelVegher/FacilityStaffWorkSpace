import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' as excel;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/drawer2.dart';

class StaffStatusReportStatePage extends StatefulWidget {
  const StaffStatusReportStatePage({super.key});

  @override
  State<StaffStatusReportStatePage> createState() => _StaffStatusReportStatePageState();
}

class _StaffStatusReportStatePageState extends State<StaffStatusReportStatePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User state lock
  String? _userState;
  bool _isLoadingState = true;
  String? _stateError;

  // Counts
  int _activeCount = 0;
  int _inactiveCount = 0;
  int _resignedCount = 0;
  int _terminatedCount = 0;
  bool _isLoadingCounts = true;

  // Tabs
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
    'Active': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Active').where('state', isEqualTo: 'userState').limit(500),
    'Inactive': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Inactive').where('state', isEqualTo: 'userState').limit(500),
    'Resigned': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Resigned').where('state', isEqualTo: 'userState').limit(500),
    'Terminated': FirebaseFirestore.instance.collection('Staff').where('accountStatus', isEqualTo: 'Terminated').where('state', isEqualTo: 'userState').limit(500),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserState();
    
    // Add listeners to search controllers
    for (final status in _searchControllers.keys) {
      _searchControllers[status]!.addListener(_updateSearchQuery);
    }
    
    // Initialize search queries after state is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onFilterChanged();
    });
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
    if (_userState != null) {
      baseQuery = baseQuery.where('state', isEqualTo: _userState);
    }
    
    if (searchTerm.isEmpty) {
      // No search term, just use base query
      _searchQueries[status] = baseQuery.orderBy('state').limit(500);
    } else {
      // Add search filter - search by fullName
      _searchQueries[status] = baseQuery
          .where('fullName', isGreaterThanOrEqualTo: searchTerm)
          .where('fullName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .orderBy('state')
          .limit(500);
    }
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
    _updateSearchQueryForStatus(currentStatus);
  }

  Future<void> _loadUserState() async {
    setState(() {
      _isLoadingState = true;
      _stateError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User is not logged in.');
      }
      final doc = await _firestore.collection('Staff').doc(user.uid).get();
      final state = (doc.data()?['state'] as String? ?? '').trim();
      if (state.isEmpty) {
        throw Exception('State not set on your profile.');
      }
      setState(() => _userState = state);
      await _loadCounts();
    } on FirebaseException catch (e, stack) {
      debugPrint('StaffStatusReportStatePage _loadUserState Firestore error: ${e.message}');
      debugPrint('STACK: $stack');
      setState(() => _stateError = e.message ?? e.code);
    } catch (e, stack) {
      debugPrint('StaffStatusReportStatePage _loadUserState error: $e');
      debugPrint('STACK: $stack');
      setState(() => _stateError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingState = false);
    }
  }

  Future<void> _loadCounts() async {
    if (_userState == null) return;
    setState(() => _isLoadingCounts = true);
    try {
      final active = await _countForStatus('Active');
      final inactive = await _countForStatus('Inactive');
      final resigned = await _countForStatus('Resigned');
      final terminated = await _countForStatus('Terminated');
      setState(() {
        _activeCount = active;
        _inactiveCount = inactive;
        _resignedCount = resigned;
        _terminatedCount = terminated;
      });
    } catch (_) {
      // Printed in _countForStatus
    } finally {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<int> _countForStatus(String status) async {
    try {
      Query q = _firestore
          .collection('Staff')
          .where('accountStatus', isEqualTo: status)
          .where('state', isEqualTo: _userState);
      final agg = await q.count().get();
      return agg.count ?? 0;
    } on FirebaseException catch (e, stack) {
      debugPrint('StaffStatusReportStatePage _countForStatus index error: ${e.message}');
      // If Firestore requires an index, this console error usually includes a "Create index" link.
      debugPrint('STACK: $stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('StaffStatusReportStatePage _countForStatus error: $e');
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
    // Composite query: accountStatus == status AND state == _userState, ordered by lastName or state to stabilize
    return _firestore
        .collection('Staff')
        .where('accountStatus', isEqualTo: status)
        .where('state', isEqualTo: _userState)
        .orderBy('state') // safe ordering; if index is required, error printed below in StreamBuilder
        .limit(500);
  }

  Future<void> _exportCurrentTabToExcel() async {
    final status = _currentStatus;
    if (_userState == null) return;
    try {
      Query q = _firestore
          .collection('Staff')
          .where('accountStatus', isEqualTo: status)
          .where('state', isEqualTo: _userState);
      final snap = await q.limit(2000).get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No staff found for $status in $_userState')),
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
          final safeState = (_userState ?? '').replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
          final filename = 'Staff_${status}_${safeState.isEmpty ? 'UnknownState' : safeState}.xlsx';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingState) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Staff Status (State)',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF5C1A2E),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: drawer2(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_stateError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Staff Status (State)',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF5C1A2E),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: drawer2(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading your state: $_stateError',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Status ($_userState)',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5C1A2E),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Export Current Tab',
            icon: const Icon(Icons.file_download),
            onPressed: _exportCurrentTabToExcel,
          ),
          IconButton(
            tooltip: 'Refresh Counts',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCounts,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFD4A03C),
          tabs: [
            Tab(child: Text('Active ($_activeCount)', style: GoogleFonts.poppins())),
            Tab(child: Text('Inactive ($_inactiveCount)', style: GoogleFonts.poppins())),
            Tab(child: Text('Resigned ($_resignedCount)', style: GoogleFonts.poppins())),
            Tab(child: Text('Terminated ($_terminatedCount)', style: GoogleFonts.poppins())),
          ],
        ),
      ),
      drawer: drawer2(context),
      body: SelectionArea(
        child: Column(
          children: [
            _buildCountsRow(context),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatusList('Active'),
                  _buildStatusList('Inactive'),
                  _buildStatusList('Resigned'),
                  _buildStatusList('Terminated'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
      child: _isLoadingCounts
          ? const LinearProgressIndicator()
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi('Active', _activeCount, Colors.green),
                _kpi('Inactive', _inactiveCount, Colors.blueGrey),
                _kpi('Resigned', _resignedCount, Colors.orange),
                _kpi('Terminated', _terminatedCount, Colors.red),
              ],
            ),
    );
  }

  Widget _kpi(String title, int value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.pie_chart, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Text(title, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusList(String status) {
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
                // Print to console so you can click to create missing index
                debugPrint('StaffStatusReportStatePage list stream error (likely missing index): ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(child: Text('No $status staff in $_userState.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final fullName = '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'.trim();
                  final name = fullName.isNotEmpty ? fullName : (data['fullName'] ?? 'N/A').toString();
                  final email = (data['emailAddress'] ?? 'N/A').toString();
                  final phone = (data['mobile'] ?? 'N/A').toString();
                  final state = (data['state'] ?? 'N/A').toString();
                  final location = (data['location'] ?? 'N/A').toString();
                  final dept = (data['department'] ?? 'N/A').toString();
                  final desig = (data['designation'] ?? 'N/A').toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey.shade100,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$dept • $desig'),
                          Text('$state • $location'),
                          Text('$email • $phone', overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: _statusColor(status),
                          ),
                          if (status.toLowerCase() != 'active')
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'reactivate') {
                                  await _reactivateAccount(doc.id, name);
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
        return Colors.blueGrey;
      case 'resigned':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}