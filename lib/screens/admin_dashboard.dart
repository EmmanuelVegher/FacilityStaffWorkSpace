import 'package:flutter/material.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Dashboard"),
        actions: const [
          CircleAvatar(
            backgroundImage: AssetImage('assets/hr_profile.jpg'), // Replace with HR profile image
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilters(),
            _buildSummaryCards(),
            _buildDepartmentalAttendanceChart(),
            Expanded(child: _buildEmployeeList()),
          ],
        ),
      ),
    );
  }

  // Filter Widgets
  Widget _buildFilters() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          hint: const Text('Select Department'),
          items: ['IT', 'HR', 'Sales'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (_) {},
        ),
        DropdownButton<String>(
          hint: const Text('Select Facility'),
          items: ['Main Office', 'Remote'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (_) {},
        ),
      ],
    );
  }

  // Summary Cards
  Widget _buildSummaryCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard('Total Employees', '500'),
        _buildStatCard('On-Time', '450'),
        _buildStatCard('Late', '50'),
        _buildStatCard('Absent', '20'),
      ],
    );
  }

  // Departmental Attendance Chart (Placeholder)
  Widget _buildDepartmentalAttendanceChart() {
    return Container(
      height: 200.0,
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      color: Colors.grey[200],
      child: const Center(child: Text('Departmental Attendance Chart')),
    );
  }

  // Employee List with Attendance Status
  Widget _buildEmployeeList() {
    return ListView.builder(
      itemCount: 20, // Replace with actual data count
      itemBuilder: (context, index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundImage: AssetImage('assets/employee.jpg'), // Replace with employee profile
          ),
          title: Text('Employee Name'),
          subtitle: Text('Status: On Time'),
          trailing: Icon(Icons.check_circle, color: Colors.green),
        );
      },
    );
  }

  // Card Widget for Stats
  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8.0),
              Text(value, style: const TextStyle(fontSize: 24.0)),
            ],
          ),
        ),
      ),
    );
  }
}
