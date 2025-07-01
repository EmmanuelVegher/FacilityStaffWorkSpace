import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff.dart';
import '../../models/staff_model.dart';
import 'user_form_screen.dart';

class LocationStaffListScreen extends StatefulWidget {
  final String stateName;
  final String stateId;
  final String staffCategory;

  const LocationStaffListScreen({
    super.key,
    required this.stateName,
    required this.stateId,
    required this.staffCategory,
  });

  @override
  State<LocationStaffListScreen> createState() => _LocationStaffListScreenState();
}

class _LocationStaffListScreenState extends State<LocationStaffListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the account for ${staff.fullName}?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              FirebaseFirestore.instance.collection('Staff').doc(staff.id).delete();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Map<String, List<Staff>> _groupStaffByLocation(List<Staff> staffList) {
    final Map<String, List<Staff>> grouped = {};
    for (var staff in staffList) {
      final location = staff.location.isEmpty ? 'Unspecified Location' : staff.location;
      if (grouped[location] == null) {
        grouped[location] = [];
      }
      grouped[location]!.add(staff);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staffCategory),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade200, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Name, Email, Location...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                      : null,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Staff')
                    .where('state', isEqualTo: widget.stateId)
                    .where('staffCategory', isEqualTo: widget.staffCategory)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No staff found for ${widget.staffCategory} in ${widget.stateName}.'));
                  }

                  List<Staff> allStaff = snapshot.data!.docs.map((doc) => Staff.fromFirestore(doc)).toList();

                  if (_searchQuery.isNotEmpty) {
                    allStaff = allStaff.where((staff) =>
                    staff.fullName.toLowerCase().contains(_searchQuery) ||
                        staff.emailAddress.toLowerCase().contains(_searchQuery) ||
                        staff.location.toLowerCase().contains(_searchQuery)).toList();
                  }
                  if(allStaff.isEmpty) return const Center(child: Text('No users match your search.'));

                  final groupedStaff = _groupStaffByLocation(allStaff);
                  final locations = groupedStaff.keys.toList()..sort();

                  return ListView.builder(
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      final location = locations[index];
                      final staffInLocation = groupedStaff[location]!;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ExpansionTile(
                          title: Text('$location (${staffInLocation.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: staffInLocation.map((staff) => ListTile(
                            leading: CircleAvatar(
                              backgroundImage: staff.photoUrl.isNotEmpty ? NetworkImage(staff.photoUrl) : null,
                            ),
                            title: Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('Email: ${staff.emailAddress}\nSupervisor: ${staff.supervisor}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => UserFormScreen(staff: staff),
                                  )),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _showDeleteConfirmation(context, staff),
                                ),
                              ],
                            ),
                          )).toList(),
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
}