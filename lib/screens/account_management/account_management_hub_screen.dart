import 'package:service_delivery_workspace/screens/account_management/state_dashboard_screen.dart';
// IMPORTANT: Adjust this import path if your registration page is in a different directory.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../widgets/drawer3.dart';
import '../registration_page.dart';
import '../supervisor/supervisor_hub_screen.dart';

class AccountManagementHubScreen extends StatelessWidget {
  const AccountManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Direct rendering without lightweight guard to avoid unnecessary refreshes
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Account Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: drawer3(context),
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
          child: Column(
            children: [
              // Tutorial Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need help with account management?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              const url = 'https://youtu.be/dTBm7-FNI_g';
                              if (await canLaunch(url)) {
                                await launch(url);
                              } else {
                                Fluttertoast.showToast(
                                  msg: "Could not open tutorial link",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                            },
                            child: Text(
                              'View Tutorial',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('Location').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No states found.', style: TextStyle(color: Colors.white, fontSize: 18)));
                    }

                    final states = snapshot.data!.docs;

                    return Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(24.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: states.length,
                          itemBuilder: (context, index) {
                            final stateDoc = states[index];
                            final stateName = stateDoc['name'] as String;
                            final stateId = stateDoc.id;
                            return _StateCard(stateName: stateName, stateId: stateId);
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
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'fab_add_supervisor',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SupervisorHubScreen(),
                ));
              },
              backgroundColor: Colors.blue.shade700,
              icon: const Icon(Icons.supervisor_account, color: Colors.white),
              label: const Text('Manage Supervisors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              heroTag: 'fab_add_user',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RegistrationPageWeb(),
                ));
              },
              backgroundColor: Colors.red.shade700,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              label: const Text('Create New User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable card widget - Simplified to let the GridView control its size
class _StateCard extends StatelessWidget {
  final String stateName;
  final String stateId;

  const _StateCard({
    required this.stateName,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StateDashboardScreen(stateName: stateName, stateId: stateId),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.corporate_fare_rounded,
              size: 56,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                stateName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}