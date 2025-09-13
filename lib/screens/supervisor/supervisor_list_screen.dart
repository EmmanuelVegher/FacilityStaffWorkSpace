// lib/Pages/supervisor_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/metadata_trigger_service.dart';
import 'supervisor_form_screen.dart';

class SupervisorListScreen extends StatelessWidget {
  final String stateName;
  final String stateId;

  const SupervisorListScreen({
    super.key,
    required this.stateName,
    required this.stateId,
  });

  // <<<--- MODIFIED: This function now calls the metadata trigger ---<<<
  Future<void> _deleteSupervisor(BuildContext context, String supervisorId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(stateId)
          .collection(stateId)
          .doc(supervisorId)
          .delete();

      // After a successful deletion, trigger the metadata update.
      await MetadataTriggerService.triggerSupervisorUpdate();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor deleted successfully.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting supervisor: $e'), backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmation(BuildContext context, String supervisorName, String supervisorId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete supervisor "$supervisorName"? This action cannot be undone.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteSupervisor(context, supervisorId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('$stateName Supervisors', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade600, Colors.black87, Colors.white, Colors.yellow.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Supervisors')
                .doc(stateId)
                .collection(stateId)
                .orderBy('supervisor')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No supervisors found for $stateName.', style: const TextStyle(color: Colors.white, fontSize: 18)));
              }

              final supervisors = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: supervisors.length,
                itemBuilder: (context, index) {
                  final supervisorDoc = supervisors[index];
                  final supervisorData = supervisorDoc.data() as Map<String, dynamic>;
                  final supervisorName = supervisorData['supervisor'] ?? 'No Name';
                  final supervisorEmail = supervisorData['email'] ?? 'No Email';
                  final department = supervisorData['department'] ?? 'No Department';

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.blue.shade700,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(supervisorName, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                      subtitle: Text('Dept: $department\nEmail: $supervisorEmail', style: TextStyle(color: Colors.grey.shade600)),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SupervisorFormScreen(
                                  stateId: stateId,
                                  existingSupervisorData: supervisorData,
                                  existingSupervisorId: supervisorDoc.id,
                                  // <<<--- PASS the trigger function to the form screen ---<<<
                                  onSuccess: MetadataTriggerService.triggerSupervisorUpdate,
                                ),
                              ));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(context, supervisorName, supervisorDoc.id),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SupervisorFormScreen(
              stateId: stateId,
              // <<<--- PASS the trigger function to the form screen ---<<<
              onSuccess: MetadataTriggerService.triggerSupervisorUpdate,
            ),
          ));
        },
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}