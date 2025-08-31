// lib/pages/admin/bank_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// A simple model for our Bank data
class Bank {
  final String id;
  final String name;

  Bank({required this.id, required this.name});

  factory Bank.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Bank(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}


class BankManagementPage extends StatefulWidget {
  const BankManagementPage({Key? key}) : super(key: key);

  @override
  _BankManagementPageState createState() => _BankManagementPageState();
}

class _BankManagementPageState extends State<BankManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          "Manage Banks",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query the "Bank" collection and order by name
        stream: _firestore.collection('Bank').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Map the Firestore documents to a list of Bank objects
          final banks = snapshot.data!.docs.map((doc) => Bank.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: banks.length,
            itemBuilder: (context, index) {
              final bank = banks[index];
              return _buildBankCard(bank);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBankDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add Bank"),
        backgroundColor: const Color(0xFF722F37),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBankCard(Bank bank) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF722F37).withOpacity(0.1),
          child: Text(
            bank.name.isNotEmpty ? bank.name[0] : '?', // Display first letter of the bank name
            style: const TextStyle(
              color: Color(0xFF722F37),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(bank.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () => _showBankDialog(bank: bank),
              tooltip: 'Edit Bank Name',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteBank(bank),
              tooltip: 'Delete Bank',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              "No Banks Found",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Tap the '+' button to add the first bank to the list.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBankDialog({Bank? bank}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: bank?.name);
    final bool isEditMode = bank != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditMode ? "Edit Bank Name" : "Add New Bank"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Bank Name",
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Bank name cannot be empty.";
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF722F37),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final String bankName = nameController.text.trim();
                  try {
                    if (isEditMode) {
                      // Update existing bank
                      await _firestore.collection('Bank').doc(bank.id).update({'name': bankName});
                    } else {
                      // Add new bank
                      await _firestore.collection('Bank').add({'name': bankName});
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Bank '${bankName}' ${isEditMode ? 'updated' : 'added'} successfully.")),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error saving bank: $e")),
                      );
                    }
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBank(Bank bank) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete '${bank.name}'? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('Bank').doc(bank.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("'${bank.name}' was deleted successfully.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting bank: $e")),
          );
        }
      }
    }
  }
}