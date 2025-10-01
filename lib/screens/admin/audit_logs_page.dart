import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/drawer3.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  // Access guard
  Future<bool> _hasProgramManagementAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
      return dept == 'program management';
    } catch (_) {
      return false;
    }
  }

  // Filters
  final TextEditingController _actionCtrl = TextEditingController();
  final TextEditingController _actorCtrl = TextEditingController(); // actor email or uid
  final TextEditingController _targetCtrl = TextEditingController(); // target collection
  DateTime? _fromDate;
  DateTime? _toDate;
  String _actorField = 'actorEmail'; // 'actorEmail' or 'actorUid'
  bool _showFilters = true;

  @override
  void dispose() {
    _actionCtrl.dispose();
    _actorCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  // Build Firestore query based on filters
  Query _buildQuery() {
    Query q = FirebaseFirestore.instance.collection('AuditLogs');

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
    Timestamp? fromTs;
    Timestamp? toTs;
    if (_fromDate != null) {
      final startOfDay = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day, 0, 0, 0);
      fromTs = Timestamp.fromDate(startOfDay);
      q = q.where('timestamp', isGreaterThanOrEqualTo: fromTs);
    }
    if (_toDate != null) {
      final endOfDay = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59, 999);
      toTs = Timestamp.fromDate(endOfDay);
      q = q.where('timestamp', isLessThanOrEqualTo: toTs);
    }

    // Always order by timestamp desc for consistent display
    q = q.orderBy('timestamp', descending: true);

    // Limit to a reasonable number
    q = q.limit(500);
    return q;
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProgramManagementAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Audit Logs', style: TextStyle(color: Colors.white)),
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
              title: const Text('Access Denied', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF722F37),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            drawer: drawer3(context),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Access Denied: You do not have permission to view this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Audit Logs', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF722F37),
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
          drawer: drawer3(context),
          body: Column(
            children: [
              if (_showFilters) _buildFiltersCard(context),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _buildQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      // Print to console so you can click the "Create index" link if Firestore requires it
                      debugPrint('AuditLogsPage stream error (likely missing index): ${snapshot.error}');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error loading audit logs: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No audit logs match the current filters.'),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final action = (data['action'] as String? ?? 'N/A');
                        final targetCollection = (data['targetCollection'] as String? ?? 'N/A');
                        final targetDocId = (data['targetDocId'] as String? ?? 'N/A');
                        final actorEmail = (data['actorEmail'] as String? ?? '');
                        final actorUid = (data['actorUid'] as String? ?? '');
                        final details = data['details'];
                        final ts = data['timestamp'];
                        DateTime? timestamp;
                        if (ts is Timestamp) timestamp = ts.toDate();
                        if (ts is DateTime) timestamp = ts;

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.history, color: Colors.white),
                          ),
                          title: Text(
                            action,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target: $targetCollection / $targetDocId'),
                              if (actorEmail.isNotEmpty) Text('Actor: $actorEmail'),
                              if (actorEmail.isEmpty && actorUid.isNotEmpty) Text('Actor UID: $actorUid'),
                              if (timestamp != null) Text('Time: $timestamp'),
                              if (details != null) ...[
                                const SizedBox(height: 4),
                                _buildDetails(details),
                              ],
                            ],
                          ),
                          dense: false,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersCard(BuildContext context) {
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

  Widget _buildDetails(dynamic details) {
    if (details is String) {
      return Text(
        details,
        style: TextStyle(color: Colors.grey.shade700),
      );
    }
    if (details is Map) {
      final entries = details.entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
      return Text(entries, style: TextStyle(color: Colors.grey.shade700));
    }
    return Text(details.toString(), style: TextStyle(color: Colors.grey.shade700));
  }
}