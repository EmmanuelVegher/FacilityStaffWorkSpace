import 'package:attendanceappmailtool/screens/account_management/state_dashboard_screen.dart';
import 'package:attendanceappmailtool/screens/account_management/state_staff_list_screen.dart';
import 'package:attendanceappmailtool/screens/account_management/user_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_firestore/cloud_firestore.dart';



class AccountManagementHubScreen extends StatelessWidget {
  const AccountManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management Hub'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Location').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No states found in the "Location" collection.'));
          }

          final states = snapshot.data!.docs;
          final colors = [
            Colors.teal.shade300, Colors.blue.shade300, Colors.orange.shade300,
            Colors.purple.shade300, Colors.green.shade300, Colors.red.shade300,
            Colors.indigo.shade300, Colors.amber.shade300,
          ];

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 3 / 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: states.length,
            itemBuilder: (context, index) {
              final stateDoc = states[index];
              final stateName = stateDoc['name'] as String;
              final stateId = stateDoc.id;
              final color = colors[index % colors.length];

              return InkWell(
                onTap: () {
                  // Navigator.of(context).push(MaterialPageRoute(
                  //   builder: (_) => StateStaffListScreen(stateName: stateName, stateId: stateId),
                  // ));

                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StateDashboardScreen(stateName: stateName, stateId: stateId),
                  ));

                },
                borderRadius: BorderRadius.circular(15.0),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_city, size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          stateName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 2.0, color: Colors.black26, offset: Offset(1, 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const UserFormScreen(),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('Create New User'),
      ),
    );
  }
}