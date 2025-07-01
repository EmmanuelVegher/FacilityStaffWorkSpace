import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/staff.dart';
import '../../models/staff_model.dart';
import 'location_staff_list_screen.dart'; // We will create this next

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
      // A beautiful gradient background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.white, Colors.teal.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text('$stateName Dashboard'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Icon(Icons.business_outlined, size: 50, color: Colors.blueGrey.withOpacity(0.5)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Staff')
                    .where('state', isEqualTo: stateId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No staff found for this state.', style: TextStyle(fontSize: 18)),
                      ),
                    );
                  }

                  // Group staff by their category
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
                  final icons = {
                    "Facility Staff": Icons.local_hospital,
                    "State Office Staff": Icons.corporate_fare,
                    "Facility Supervisor": Icons.supervisor_account,
                    "HQ Staff": Icons.assured_workload,
                  };
                  final colors = [
                    Colors.indigo, Colors.green, Colors.orange, Colors.purple,
                    Colors.red, Colors.blue
                  ];

                  return GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 350,
                      childAspectRatio: 4 / 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: categories.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final staffCount = groupedByCategory[category]!.length;
                      final iconData = icons[category] ?? Icons.person;

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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              color: colors[index % colors.length].withOpacity(0.85),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(iconData, size: 40, color: Colors.white),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$staffCount Staff',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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