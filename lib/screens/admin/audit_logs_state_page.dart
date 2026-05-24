import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/drawer2.dart';

class AuditLogsStatePage extends StatefulWidget {
  const AuditLogsStatePage({super.key});

  @override
  State<AuditLogsStatePage> createState() => _AuditLogsStatePageState();
}

class _AuditLogsStatePageState extends State<AuditLogsStatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State lock
  String? _userState;
  bool _loadingState = true;
  String? _stateError;

  // Filters
  final TextEditingController _actionCtrl = TextEditingController();
  final TextEditingController _actorCtrl = TextEditingController(); // actor email or uid
  final TextEditingController _targetCtrl = TextEditingController(); // target collection
  DateTime? _fromDate;
  DateTime? _toDate;
  String _actorField = 'actorEmail'; // 'actorEmail' or 'actorUid'
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  @override
  void dispose() {
    _actionCtrl.dispose();
    _actorCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserState() async {
    setState(() {
      _loadingState = true;
      _stateError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final doc = await _firestore.collection('Staff').doc(user.uid).get();
      final state = (doc.data()?['state'] as String? ?? '').trim();
      if (state.isEmpty) throw Exception('State not found on profile');
      setState(() => _userState = state);
    } catch (e, stack) {
      // Print to console so user can click the error if index creation is needed downstream
      debugPrint('AuditLogsStatePage _loadUserState error: $e');
      debugPrint('STACK: $stack');
      setState(() => _stateError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingState = false);
    }
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? now,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _actionCtrl.clear();
      _actorCtrl.clear();
      _targetCtrl.clear();
      _fromDate = null;
      _toDate = null;
      _actorField = 'actorEmail';
    });
  }

  // Build Firestore query based on filters and locked state
  Query _buildQuery() {
    // We assume audit log documents contain an "actorState" field to scope logs by state.
    // If your schema uses a different field (e.g., "targetState" or "state"), update below accordingly.
    Query q = _firestore
        .collection('AuditLogs')
        .where('actorState', isEqualTo: _userState);

    final action = _actionCtrl.text.trim();
    final actor = _actorCtrl.text.trim();
    final target = _targetCtrl.text.trim();

    if (action.isNotEmpty) {
      q = q.where('action', isEqualTo: action);
    }
    if (actor.isNotEmpty) {
      q = q.where(_actorField, isEqualTo: actor);
    }
    if (target.isNotEmpty) {
      q = q.where('targetCollection', isEqualTo: target);
    }

    // Date filters
    if (_fromDate != null) {
      final startOfDay = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day, 0, 0, 0);
      q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
    }
    if (_toDate != null) {
      final endOfDay = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59, 999);
      q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // This composite (actorState + timestamp desc) will likely require an index the first time
    q = q.orderBy('timestamp', descending: true).limit(500);
    return q;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingState) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Audit Logs (State)',
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
          title: Text('Audit Logs (State)',
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
              style: GoogleFonts.poppins(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Audit Logs ($_userState)',
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
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
            icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            tooltip: 'Clear Filters',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
          ),
        ],
      ),
      drawer: drawer2(context),
      body: SelectionArea(
        child: Column(
          children: [
            if (_showFilters) _buildFiltersCard(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    // Print to console so you can click to create the index if needed.
                    debugPrint(
                        'AuditLogsStatePage stream error (likely missing index): ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error loading audit logs: ${snapshot.error}',
                            style: GoogleFonts.poppins(color: Colors.red)),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                        child: Text('No logs found for your state and filters.',
                            style: GoogleFonts.poppins()));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>? ?? {};
                      final action = (data['action'] as String? ?? 'N/A');
                      final targetCollection =
                          (data['targetCollection'] as String? ?? 'N/A');
                      final targetDocId = (data['targetDocId'] as String? ?? 'N/A');
                      final actorEmail = (data['actorEmail'] as String? ?? '');
                      final actorUid = (data['actorUid'] as String? ?? '');
                      final ts = data['timestamp'];
                      DateTime? timestamp;
                      if (ts is Timestamp) timestamp = ts.toDate();
                      if (ts is DateTime) timestamp = ts;
  
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF5C1A2E),
                          child: Icon(Icons.history, color: Colors.white),
                        ),
                        title: Text(action,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target: $targetCollection / $targetDocId',
                                style: GoogleFonts.poppins()),
                            if (actorEmail.isNotEmpty)
                              Text('Actor: $actorEmail',
                                  style: GoogleFonts.poppins()),
                            if (actorEmail.isEmpty && actorUid.isNotEmpty)
                              Text('Actor UID: $actorUid',
                                  style: GoogleFonts.poppins()),
                            if (timestamp != null)
                              Text('Time: $timestamp',
                                  style: GoogleFonts.poppins()),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _actionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Action (exact)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt),
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _actorCtrl,
                decoration: InputDecoration(
                  labelText: _actorField == 'actorEmail' ? 'Actor Email (exact)' : 'Actor UID (exact)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) => setState(() => _actorField = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'actorEmail', child: Text('Filter by Actor Email')),
                      PopupMenuItem(value: 'actorUid', child: Text('Filter by Actor UID')),
                    ],
                  ),
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _targetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Collection (exact)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 180,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'From Date',
                  border: OutlineInputBorder(),
                ),
                child: InkWell(
                  onTap: _pickFromDate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fromDate == null ? 'Select' : '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}'),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'To Date',
                  border: OutlineInputBorder(),
                ),
                child: InkWell(
                  onTap: _pickToDate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_toDate == null ? 'Select' : '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}'),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.filter_list),
              label: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
