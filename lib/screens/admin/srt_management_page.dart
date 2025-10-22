import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:service_delivery_workspace/widgets/drawer3.dart';

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
         title: const Text(
            'SRT Management - HQ',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        backgroundColor: const Color(0xFF722F37),
        elevation: 0,
      ),
      drawer: drawer3(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.white, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _buildAdminView(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF722F37),
        icon: const Icon(Icons.add),
        label: const Text('Add Assignment'),
        elevation: 8,
      ),
    );
  }

  Widget _buildAdminView() {
    return StreamBuilder<QuerySnapshot>(
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
          padding: const EdgeInsets.all(16),
          itemCount: stateLocations.keys.length,
          itemBuilder: (context, index) {
            final state = stateLocations.keys.elementAt(index);
            final locations = stateLocations[state]!.toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ExpansionTile(
                  title: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF722F37),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${locations.length} locations',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: locations.map((location) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('SRTAssignments').doc('$state-$location').snapshots(),
                        builder: (context, srtSnapshot) {
                          String currentSRT = 'Not Assigned';
                          if (srtSnapshot.hasData && srtSnapshot.data!.exists) {
                            final data = srtSnapshot.data!.data() as Map<String, dynamic>;
                            currentSRT = data['srt'] ?? 'Not Assigned';
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF722F37),
                              ),
                            ),
                            subtitle: Text(
                              'Current SRT: $currentSRT',
                              style: TextStyle(
                                fontSize: 14,
                                color: currentSRT == 'Not Assigned' ? Colors.grey : _getSRTColor(currentSRT),
                                fontWeight: currentSRT == 'Not Assigned' ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            trailing: DropdownButton<String>(
                              value: currentSRT == 'Not Assigned' ? null : currentSRT,
                              items: _srtOptions.map((srt) {
                                return DropdownMenuItem(
                                  value: srt,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _getSRTColor(srt),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getSRTColor(srt).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      srt,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _updateSRT(state, location, value);
                                }
                              },
                              hint: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Select',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Color _getSRTColor(String srt) {
    switch (srt) {
      case 'A': return Colors.red.shade600;
      case 'B': return Colors.blue.shade600;
      case 'C': return Colors.green.shade600;
      case 'D': return Colors.orange.shade600;
      default: return Colors.grey;
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
        String selectedState = '';
        String selectedLocation = '';
        String selectedSRT = 'A';

        return AlertDialog(
          title: const Text('Add SRT Assignment'),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('Staff').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final states = snapshot.data!.docs.map((doc) => doc['state'] as String).toSet().toList();
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: states.map((state) {
                        return DropdownMenuItem(value: state, child: Text(state));
                      }).toList(),
                      onChanged: (value) {
                        selectedState = value ?? '';
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    selectedLocation = value;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'SRT',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  value: selectedSRT,
                  items: _srtOptions.map((srt) {
                    return DropdownMenuItem(
                      value: srt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getSRTColor(srt),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          srt,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF722F37),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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