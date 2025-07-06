import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff.dart'; // Ensure this path is correct
import 'user_form_screen.dart'; // Ensure this path is correct

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
  // Helper to group staff by category
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '${widget.stateName} Staff',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.black87,
              Colors.white,
              Colors.yellow.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            // --- CORRECTED QUERY ---
            stream: FirebaseFirestore.instance
                .collection('Staff')
                .where('state', isEqualTo: widget.stateName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No staff found for ${widget.stateName}.', style: const TextStyle(color: Colors.white)));
              }

              final allStaff = snapshot.data!.docs.map((doc) => Staff.fromFirestore(doc)).toList();
              final groupedStaff = _groupStaffByCategory(allStaff);
              final categories = groupedStaff.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final staffInCategory = groupedStaff[category]!;
                  return _CategoryExpansionTile(
                    category: category,
                    staffInCategory: staffInCategory,
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UserFormScreen(),
          ));
        },
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Staff in ${widget.stateName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// Reusable "glassmorphism" ExpansionTile for categories (No changes needed here)
class _CategoryExpansionTile extends StatelessWidget {
  final String category;
  final List<Staff> staffInCategory;

  const _CategoryExpansionTile({required this.category, required this.staffInCategory});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          '$category (${staffInCategory.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 18),
        ),
        iconColor: Colors.red.shade700,
        collapsedIconColor: Colors.grey.shade700,
        children: staffInCategory.map((staff) => _StaffListTile(staff: staff)).toList(),
      ),
    );
  }
}

// --- NEW: Converted to a StatefulWidget to fetch attendance count ---
class _StaffListTile extends StatefulWidget {
  final Staff staff;
  const _StaffListTile({required this.staff});

  @override
  State<_StaffListTile> createState() => _StaffListTileState();
}

class _StaffListTileState extends State<_StaffListTile> {
  int? _attendanceCount; // Use nullable int to handle loading state

  @override
  void initState() {
    super.initState();
    _fetchAttendanceCount();
  }

  // Fetches the attendance count for this specific staff member
  Future<void> _fetchAttendanceCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Staff')
          .doc(widget.staff.id)
          .collection('Record')
          .count() // Use count() for efficiency
          .get();

      // Check if the widget is still in the tree before updating state
      if (mounted) {
        setState(() {
          _attendanceCount = snapshot.count;
        });
      }
    } catch (e) {
      // Handle potential errors, e.g., permissions
      if (mounted) {
        setState(() {
          _attendanceCount = 0; // Default to 0 on error
        });
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the account for ${staff.fullName}? This cannot be undone.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
            onPressed: () {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Material(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: widget.staff.photoUrl.isNotEmpty ? NetworkImage(widget.staff.photoUrl) : null,
            child: widget.staff.photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          title: Text(widget.staff.fullName, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: ${widget.staff.location}', style: TextStyle(color: Colors.grey.shade700)),
              // --- NEW: Dynamically display the attendance count ---
              if (_attendanceCount == null)
                Text('Loading attendance...', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic))
              else
                Text('Attendance Records: $_attendanceCount', style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
          isThreeLine: true, // Set to true to accommodate both lines of the subtitle
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
                tooltip: 'Edit User',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserFormScreen(staff: widget.staff),
                )),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete User',
                onPressed: () => _showDeleteConfirmation(context, widget.staff),
              ),
            ],
          ),
        ),
      ),
    );
  }
}