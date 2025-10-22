import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:service_delivery_workspace/widgets/drawer2.dart';

class SRTManagementStatePage extends StatefulWidget {
  const SRTManagementStatePage({super.key});

  @override
  _SRTManagementStatePageState createState() => _SRTManagementStatePageState();
}

class _SRTManagementStatePageState extends State<SRTManagementStatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _srtOptions = ['A', 'B', 'C', 'D'];
  String? _userState;

  @override
  void initState() {
    super.initState();
    _getUserState();
  }

  Future<void> _getUserState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('Staff').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _userState = data?['state'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userState == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'SRT Management',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF722F37),
        ),
        drawer: drawer2(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('SRT Management - ${_userState ?? 'Loading...'}'),
        backgroundColor: const Color(0xFF722F37),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('Staff').snapshots(),
          builder: (context, staffSnapshot) {
            if (staffSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (staffSnapshot.hasError) {
              return Center(child: Text('Error: ${staffSnapshot.error}'));
            }

            final staffDocs = staffSnapshot.data?.docs ?? [];
            final Set<String> locations = {};

            for (var doc in staffDocs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['state'] == _userState) {
                final location = data['location'] ?? 'Unknown';
                locations.add(location);
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations.elementAt(index);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('SRTAssignments')
                          .doc('$_userState-$location')
                          .snapshots(),
                      builder: (context, srtSnapshot) {
                        String currentSRT = 'Not Assigned';
                        if (srtSnapshot.hasData && srtSnapshot.data!.exists) {
                          final data =
                              srtSnapshot.data!.data() as Map<String, dynamic>;
                          currentSRT = data['srt'] ?? 'Not Assigned';
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF722F37),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Current SRT: $currentSRT',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: currentSRT == 'Not Assigned'
                                          ? Colors.grey
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: currentSRT == 'Not Assigned'
                                  ? null
                                  : currentSRT,
                              items: _srtOptions.map((srt) {
                                return DropdownMenuItem(
                                  value: srt,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _getSRTColor(srt),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      srt,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _updateSRT(_userState!, location, value);
                                }
                              },
                              hint: const Text('Select SRT'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF722F37),
        icon: const Icon(Icons.add),
        label: const Text('Add Assignment'),
      ),
    );
  }

  Color _getSRTColor(String srt) {
    switch (srt) {
      case 'A':
        return Colors.red;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.green;
      case 'D':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
        String selectedLocation = '';
        String selectedSRT = 'A';

        return AlertDialog(
          title: const Text('Add SRT Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  return DropdownMenuItem(
                    value: srt,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getSRTColor(srt),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        srt,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
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
                if (selectedLocation.isNotEmpty && _userState != null) {
                  _updateSRT(_userState!, selectedLocation, selectedSRT);
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
