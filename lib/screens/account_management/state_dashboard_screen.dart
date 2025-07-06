import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff.dart'; // Ensure this path is correct
import 'location_staff_list_screen.dart'; // Ensure this path is correct

class StateDashboardScreen extends StatelessWidget {
  final String stateName;
  final String stateId;

  const StateDashboardScreen({
    super.key,
    required this.stateName,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // The main container for the gradient background
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
        // CustomScrollView allows for a flexible app bar
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                '$stateName Dashboard',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              pinned: true, // Keeps the AppBar visible when scrolling
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            // This sliver will contain our main content, the centered grid
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                // --- CRITICAL FIX: Query by the state NAME, not its ID ---
                stream: FirebaseFirestore.instance
                    .collection('Staff')
                    .where('state', isEqualTo: stateName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No staff found for this state.',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    );
                  }

                  // Group staff by their category (this logic is good)
                  final Map<String, List<Staff>> groupedByCategory = {};
                  for (var doc in snapshot.data!.docs) {
                    final staff = Staff.fromFirestore(doc);
                    final category = staff.staffCategory.isEmpty ? 'Uncategorized' : staff.staffCategory;
                    if (groupedByCategory[category] == null) {
                      groupedByCategory[category] = [];
                    }
                    groupedByCategory[category]!.add(staff);
                  }

                  final categories = groupedByCategory.keys.toList()..sort();

                  // --- NEW: Layout to Center a Fixed 2-Column Grid ---
                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 700), // Max width for the grid area
                      child: GridView.builder(
                        padding: const EdgeInsets.all(24.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // Exactly two columns
                          childAspectRatio: 0.85, // Taller cards
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: categories.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(), // Important for nested scrolling
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final staffList = groupedByCategory[category]!;
                          // Pass the category and its staff list to the card widget
                          return _CategoryCard(
                            category: category,
                            staffList: staffList,
                            stateName: stateName,
                            stateId: stateId,
                          );
                        },
                      ),
                    ),
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

// Reusable "glassmorphism" card widget
class _CategoryCard extends StatelessWidget {
  final String category;
  final List<Staff> staffList;
  final String stateName;
  final String stateId;

  const _CategoryCard({
    required this.category,
    required this.staffList,
    required this.stateName,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    // Icon mapping for different staff categories
    final icons = {
      "Facility Staff": Icons.local_hospital_outlined,
      "State Office Staff": Icons.corporate_fare_outlined,
      "Facility Supervisor": Icons.supervisor_account_outlined,
      "HQ Staff": Icons.domain_verification_outlined,
    };

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LocationStaffListScreen(
            stateName: stateName,
            stateId: stateId,
            staffCategory: category,
          ),
        ));
      },
      borderRadius: BorderRadius.circular(20.0),
      child: Card(
        elevation: 8,
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icons[category] ?? Icons.people_outline,
                size: 48,
                color: Colors.red.shade700,
              ),
              const Spacer(),
              Text(
                '${staffList.length}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  height: 1,
                ),
              ),
              Text(
                category,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}