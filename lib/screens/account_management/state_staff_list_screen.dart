import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff.dart';
import '../../models/staff_model.dart';
import 'user_form_screen.dart';

class StateStaffListScreen extends StatefulWidget {
  final String stateName;
  final String stateId;

  const StateStaffListScreen({
    super.key,
    required this.stateName,
    required this.stateId,
  });

  @override
  State<StateStaffListScreen> createState() => _StateStaffListScreenState();
}

class _StateStaffListScreenState extends State<StateStaffListScreen> {

  void _showDeleteConfirmation(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the account for ${staff.fullName}? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              // This deletes from Firestore. A secure app would use a Cloud Function
              // to also delete from Firebase Auth.
              FirebaseFirestore.instance.collection('Staff').doc(staff.id).delete();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${staff.fullName} has been deleted.'), backgroundColor: Colors.red),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, List<Staff>> _groupStaffByCategory(List<Staff> staffList) {
    final Map<String, List<Staff>> grouped = {};
    for (var staff in staffList) {
      final category = staff.staffCategory.isEmpty ? 'Uncategorized' : staff.staffCategory;
      if (grouped[category] == null) {
        grouped[category] = [];
      }
      grouped[category]!.add(staff);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stateName} Staff'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Staff')
            .where('state', isEqualTo: widget.stateId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No staff found for ${widget.stateName}.'));
          }

          final allStaff = snapshot.data!.docs.map((doc) => Staff.fromFirestore(doc)).toList();
          final groupedStaff = _groupStaffByCategory(allStaff);
          final categories = groupedStaff.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final staffInCategory = groupedStaff[category]!;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  title: Text(
                    '$category (${staffInCategory.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  children: staffInCategory.map((staff) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Card(
                        color: Colors.grey.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundImage: staff.photoUrl.isNotEmpty ? NetworkImage(staff.photoUrl) : null,
                            child: staff.photoUrl.isEmpty ? Text(staff.firstName.isNotEmpty ? staff.firstName[0] : '') : null,
                          ),
                          title: Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${staff.emailAddress}'),
                              Text('Location: ${staff.location}'),
                              Text('Supervisor: ${staff.supervisor}'),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => UserFormScreen(staff: staff),
                                  ));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirmation(context, staff),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UserFormScreen(initialStateId: widget.stateId, initialStateName: widget.stateName),
          ));
        },
        icon: const Icon(Icons.add),
        label: Text('New Staff in ${widget.stateName}'),
      ),
    );
  }
}