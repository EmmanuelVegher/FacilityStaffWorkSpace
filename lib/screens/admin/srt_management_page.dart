import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SRTManagementPage extends StatefulWidget {
  const SRTManagementPage({super.key});

  @override
  _SRTManagementPageState createState() => _SRTManagementPageState();
}

class _SRTManagementPageState extends State<SRTManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _srtOptions = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRT Management'),
        backgroundColor: const Color(0xFF722F37),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Staff').snapshots(),
        builder: (context, staffSnapshot) {
          if (staffSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (staffSnapshot.hasError) {
            return Center(child: Text('Error: ${staffSnapshot.error}'));
          }

          final staffDocs = staffSnapshot.data?.docs ?? [];
          final Map<String, Set<String>> stateLocations = {};

          for (var doc in staffDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final state = data['state'] ?? 'Unknown';
            final location = data['location'] ?? 'Unknown';
            stateLocations.putIfAbsent(state, () => {}).add(location);
          }

          return ListView.builder(
            itemCount: stateLocations.keys.length,
            itemBuilder: (context, index) {
              final state = stateLocations.keys.elementAt(index);
              final locations = stateLocations[state]!.toList();

              return ExpansionTile(
                title: Text(state),
                children: locations.map((location) {
                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('SRTAssignments').doc('$state-$location').snapshots(),
                    builder: (context, srtSnapshot) {
                      String currentSRT = 'Not Assigned';
                      if (srtSnapshot.hasData && srtSnapshot.data!.exists) {
                        final data = srtSnapshot.data!.data() as Map<String, dynamic>;
                        currentSRT = data['srt'] ?? 'Not Assigned';
                      }

                      return ListTile(
                        title: Text(location),
                        subtitle: Text('SRT: $currentSRT'),
                        trailing: DropdownButton<String>(
                          value: currentSRT == 'Not Assigned' ? null : currentSRT,
                          items: _srtOptions.map((srt) {
                            return DropdownMenuItem(value: srt, child: Text(srt));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _updateSRT(state, location, value);
                            }
                          },
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF722F37),
      ),
    );
  }

  void _updateSRT(String state, String location, String srt) async {
    await _firestore.collection('SRTAssignments').doc('$state-$location').set({
      'state': state,
      'location': location,
      'srt': srt,
    });
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String selectedState = '';
        String selectedLocation = '';
        String selectedSRT = 'A';

        return AlertDialog(
          title: const Text('Add SRT Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('Staff').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final states = snapshot.data!.docs.map((doc) => doc['state'] as String).toSet().toList();
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'State'),
                    items: states.map((state) {
                      return DropdownMenuItem(value: state, child: Text(state));
                    }).toList(),
                    onChanged: (value) {
                      selectedState = value ?? '';
                    },
                  );
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Location'),
                onChanged: (value) {
                  selectedLocation = value;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'SRT'),
                value: selectedSRT,
                items: _srtOptions.map((srt) {
                  return DropdownMenuItem(value: srt, child: Text(srt));
                }).toList(),
                onChanged: (value) {
                  selectedSRT = value ?? 'A';
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedState.isNotEmpty && selectedLocation.isNotEmpty) {
                  _updateSRT(selectedState, selectedLocation, selectedSRT);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}