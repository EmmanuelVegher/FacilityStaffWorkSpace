import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supervisor_list_screen.dart'; // We will create this next

class SupervisorHubScreen extends StatelessWidget {
  const SupervisorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Supervisor Management', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
            stream: FirebaseFirestore.instance.collection('Location').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
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
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String stateName;
  final String stateId;
  const _StateCard({required this.stateName, required this.stateId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SupervisorListScreen(stateName: stateName, stateId: stateId),
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
          children: [
            Icon(Icons.location_city, size: 56, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                stateName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}