// lib/features/payroll/ui/salary_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/payroll_models.dart';

class SalaryManagementPage extends StatefulWidget {
  const SalaryManagementPage({super.key});

  @override
  _SalaryManagementPageState createState() => _SalaryManagementPageState();
}

class _SalaryManagementPageState extends State<SalaryManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showSalaryDialog({DesignationSalary? existingSalary}) {
    final designationController = TextEditingController(text: existingSalary?.designation);
    final salaryController = TextEditingController(text: existingSalary?.salary.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingSalary == null ? 'Add New Salary' : 'Edit Salary'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: designationController,
                  decoration: const InputDecoration(labelText: 'Designation'),
                  readOnly: existingSalary != null, // Cannot edit designation name
                  validator: (value) => value!.isEmpty ? 'Please enter a designation' : null,
                ),
                TextFormField(
                  controller: salaryController,
                  decoration: const InputDecoration(labelText: 'Monthly Salary (NGN)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) return 'Please enter a salary';
                    if (double.tryParse(value) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final designation = designationController.text.trim();
                  final salary = double.parse(salaryController.text.trim());

                  await _firestore.collection('DesignationSalaries').doc(designation).set({'salary': salary});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Salary for $designation saved!')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Management'),
        backgroundColor: const Color(0xFF722F37),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('DesignationSalaries').orderBy(FieldPath.documentId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No salaries configured. Add one to get started.'));
          }

          final salaries = snapshot.data!.docs.map((doc) => DesignationSalary.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: salaries.length,
            itemBuilder: (context, index) {
              final item = salaries[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(item.designation, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('NGN ${NumberFormat("#,##0.00").format(item.salary)} / month'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showSalaryDialog(existingSalary: item),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalaryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Salary'),
        backgroundColor: const Color(0xFF722F37),
      ),
    );
  }
}