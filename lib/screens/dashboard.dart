import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart'; // Add flutter_map package for map functionality
import 'package:latlong2/latlong.dart'; // For map coordinates

class DashboardPage extends StatelessWidget {
  final String staffID; // Accept staffID as a parameter

  // Constructor
  const DashboardPage({super.key, required this.staffID});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("Attendance Dashboard"),
      //   backgroundColor: Colors.red.shade700,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Title
              const Text(
                "Dashboard Overview",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Welcome, your staff ID is: $staffID'),

              // Analytics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAnalyticsCard("Total Staff", Icons.people, Colors.blue),
                  _buildAnalyticsCard("Attendance Rate", Icons.check_circle, Colors.green),
                  _buildAnalyticsCard("Absentees", Icons.error, Colors.red),
                ],
              ),

              const SizedBox(height: 20),

              // Attendance Chart
              const Text(
                "Attendance Over Time",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          const FlSpot(1, 1),
                          const FlSpot(2, 2),
                          const FlSpot(3, 1.5),
                          const FlSpot(4, 2.2),
                          const FlSpot(5, 1.8),
                          const FlSpot(6, 2.8),
                        ],
                        isCurved: true,
                        color: Colors.red,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Map Section
              const Text(
                "Map Highlight",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('Staff').doc(staffID).get(),
                  builder: (context, staffSnapshot) {
                    if (staffSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (staffSnapshot.hasError) {
                      return Center(child: Text("Error: ${staffSnapshot.error}"));
                    }

                    if (!staffSnapshot.hasData || !staffSnapshot.data!.exists) {
                      return const Center(child: Text("No staff data found"));
                    }

                    // Staff data retrieved
                    final staffData = staffSnapshot.data!.data() as Map<String, dynamic>;
                    final String state = staffData['state'];

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('Location')
                          .where('name', isEqualTo: state)
                          .get(),
                      builder: (context, locationSnapshot) {
                        if (locationSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (locationSnapshot.hasError) {
                          return Center(child: Text("Error: ${locationSnapshot.error}"));
                        }

                        if (!locationSnapshot.hasData || locationSnapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No matching location found"));
                        }

                        // Get latitude and longitude from the matched location
                        final locationData = locationSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final double latitude = locationData['latitude'];
                        final double longitude = locationData['longitude'];

                        // Now use this latitude and longitude to plot the map
                        return FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude, longitude),
                            initialZoom: 7,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: LatLng(latitude, longitude),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            "100+", // Placeholder for dynamic data
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
