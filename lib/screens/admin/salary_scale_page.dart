// lib/pages/admin/salary_scale_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For number formatting

// Model for Salary Scale (No changes needed here)
class SalaryScale {
  final String id;
  final String designation;
  final double grossPay;
  final double basic;
  final double housing;
  final double transport;
  final double meal;
  final double utility;
  final double paye;
  final double netPay;

  SalaryScale({
    required this.id,
    required this.designation,
    required this.grossPay,
    required this.basic,
    required this.housing,
    required this.transport,
    required this.meal,
    required this.utility,
    required this.paye,
    required this.netPay,
  });

  factory SalaryScale.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SalaryScale(
      id: doc.id,
      designation: data['designation'] ?? '',
      grossPay: (data['grossPay'] ?? 0).toDouble(),
      basic: (data['basic'] ?? 0).toDouble(),
      housing: (data['housing'] ?? 0).toDouble(),
      transport: (data['transport'] ?? 0).toDouble(),
      meal: (data['meal'] ?? 0).toDouble(),
      utility: (data['utility'] ?? 0).toDouble(),
      paye: (data['paye'] ?? 0).toDouble(),
      netPay: (data['netPay'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'designation': designation,
      'grossPay': grossPay,
      'basic': basic,
      'housing': housing,
      'transport': transport,
      'meal': meal,
      'utility': utility,
      'paye': paye,
      'netPay': netPay,
    };
  }
}


class SalaryScalePage extends StatefulWidget {
  const SalaryScalePage({Key? key}) : super(key: key);

  @override
  _SalaryScalePageState createState() => _SalaryScalePageState();
}

class _SalaryScalePageState extends State<SalaryScalePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          "Manage Salary Scales",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // Text color set to white
        ),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white), // Back button color
        elevation: 4.0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('SalaryScales').orderBy('designation').snapshots(),
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

          final scales = snapshot.data!.docs.map((doc) => SalaryScale.fromFirestore(doc)).toList();

          // The list is now scrollable by default with ListView.builder
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: scales.length,
            itemBuilder: (context, index) {
              final scale = scales[index];
              return _buildSalaryCard(scale);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalaryScaleDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add New Scale"),
        backgroundColor: const Color(0xFF722F37),
        foregroundColor: Colors.white, // Sets icon and text color to white
      ),
    );
  }

  // A beautiful card widget for displaying salary info
  Widget _buildSalaryCard(SalaryScale scale) {
    return Card(
      elevation: 5.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    scale.designation,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                      onPressed: () => _showSalaryScaleDialog(scale: scale),
                      tooltip: 'Edit Scale',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteScale(scale.id),
                      tooltip: 'Delete Scale',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24.0, thickness: 1.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFinancialInfo("Gross Pay", _currencyFormat.format(scale.grossPay)),
                _buildFinancialInfo("PAYE", _currencyFormat.format(scale.paye)),
                _buildFinancialInfo("Net Pay", _currencyFormat.format(scale.netPay), isHighlight: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for financial figures inside the card
  Widget _buildFinancialInfo(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            color: isHighlight ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }

  // A more engaging empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              "No Salary Scales Found",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Tap the '+' button to add the first salary scale and get started.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _deleteScale(String docId) async {
    // ... (This function remains the same, it's already well-designed)
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this salary scale? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _firestore.collection('SalaryScales').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salary scale deleted successfully.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting scale: $e")));
      }
    }
  }

// REPLACE your old _showSalaryScaleDialog with this one.

  void _showSalaryScaleDialog({SalaryScale? scale}) {
    showDialog(
      context: context,
      // barrierDismissible: false, // Optional: prevent closing by tapping outside
      builder: (context) {
        return SalaryScaleFormDialog(
          scale: scale,
        );
      },
    );
  }
}



class SalaryScaleFormDialog extends StatefulWidget {
  final SalaryScale? scale;

  const SalaryScaleFormDialog({Key? key, this.scale}) : super(key: key);

  @override
  _SalaryScaleFormDialogState createState() => _SalaryScaleFormDialogState();
}

class _SalaryScaleFormDialogState extends State<SalaryScaleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Controllers are now instance variables, managed by the state
  late TextEditingController _designationController;
  late TextEditingController _grossController;
  late TextEditingController _payeController;
  late TextEditingController _netPayController;
  late TextEditingController _basicController;
  late TextEditingController _housingController;
  late TextEditingController _transportController;
  late TextEditingController _mealController;
  late TextEditingController _utilityController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers here
    _designationController = TextEditingController(text: widget.scale?.designation);
    _grossController = TextEditingController(text: widget.scale != null ? widget.scale!.grossPay.toStringAsFixed(0) : '');
    _payeController = TextEditingController(text: widget.scale != null ? widget.scale!.paye.toStringAsFixed(0) : '');
    _netPayController = TextEditingController(text: widget.scale != null ? widget.scale!.netPay.toStringAsFixed(0) : '');
    _basicController = TextEditingController(text: widget.scale != null ? widget.scale!.basic.toStringAsFixed(0) : '');
    _housingController = TextEditingController(text: widget.scale != null ? widget.scale!.housing.toStringAsFixed(0) : '');
    _transportController = TextEditingController(text: widget.scale != null ? widget.scale!.transport.toStringAsFixed(0) : '');
    _mealController = TextEditingController(text: widget.scale != null ? widget.scale!.meal.toStringAsFixed(0) : '');
    _utilityController = TextEditingController(text: widget.scale != null ? widget.scale!.utility.toStringAsFixed(0) : '');

    // Add listeners
    _grossController.addListener(_calculateAll);
    _payeController.addListener(_calculateAll);
  }

  @override
  void dispose() {
    // Dispose controllers here
    _grossController.removeListener(_calculateAll);
    _payeController.removeListener(_calculateAll);
    _designationController.dispose();
    _grossController.dispose();
    _payeController.dispose();
    _netPayController.dispose();
    _basicController.dispose();
    _housingController.dispose();
    _transportController.dispose();
    _mealController.dispose();
    _utilityController.dispose();
    super.dispose();
  }

  void _calculateAll() {
    final gross = double.tryParse(_grossController.text) ?? 0;
    final paye = double.tryParse(_payeController.text) ?? 0;

    // setState is not needed here because we are only updating controller text,
    // which automatically updates the UI of the TextFormField.
    _basicController.text = (gross * 0.30).toStringAsFixed(0);
    _housingController.text = (gross * 0.30).toStringAsFixed(0);
    _transportController.text = (gross * 0.10).toStringAsFixed(0);
    _mealController.text = (gross * 0.15).toStringAsFixed(0);
    _utilityController.text = (gross * 0.15).toStringAsFixed(0);
    _netPayController.text = (gross - paye).toStringAsFixed(0);
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final newScale = SalaryScale(
        id: widget.scale?.id ?? '',
        designation: _designationController.text.trim(),
        grossPay: double.parse(_grossController.text),
        basic: double.parse(_basicController.text),
        housing: double.parse(_housingController.text),
        transport: double.parse(_transportController.text),
        meal: double.parse(_mealController.text),
        utility: double.parse(_utilityController.text),
        paye: double.parse(_payeController.text),
        netPay: double.parse(_netPayController.text),
      );

      try {
        if (widget.scale == null) {
          await _firestore.collection('SalaryScales').add(newScale.toMap());
        } else {
          await _firestore.collection('SalaryScales').doc(widget.scale!.id).update(newScale.toMap());
        }
        if (mounted) {
          Navigator.pop(context); // Close dialog on success
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Salary scale ${widget.scale == null ? 'added' : 'updated'} successfully.")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving scale: $e")));
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.scale == null ? "Add New Salary Scale" : "Edit Salary Scale"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _designationController, decoration: const InputDecoration(labelText: "Designation", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _grossController, decoration: const InputDecoration(labelText: "Gross Pay (Amount)", border: OutlineInputBorder()), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _payeController, decoration: const InputDecoration(labelText: "PAYE Deduction", border: OutlineInputBorder()), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _netPayController, decoration: const InputDecoration(labelText: "Net Pay (Auto-Calculated)", border: OutlineInputBorder(), filled: true, fillColor: Colors.black12), readOnly: true),

              ExpansionTile(
                title: const Text("View Breakdown"),
                children: [
                  const SizedBox(height: 8),
                  TextFormField(controller: _basicController, decoration: const InputDecoration(labelText: "Basic (30%)", border: OutlineInputBorder()), readOnly: true),
                  const SizedBox(height: 8),
                  TextFormField(controller: _housingController, decoration: const InputDecoration(labelText: "Housing (30%)", border: OutlineInputBorder()), readOnly: true),
                  const SizedBox(height: 8),
                  TextFormField(controller: _transportController, decoration: const InputDecoration(labelText: "Transport (10%)", border: OutlineInputBorder()), readOnly: true),
                  const SizedBox(height: 8),
                  TextFormField(controller: _mealController, decoration: const InputDecoration(labelText: "Meal (15%)", border: OutlineInputBorder()), readOnly: true),
                  const SizedBox(height: 8),
                  TextFormField(controller: _utilityController, decoration: const InputDecoration(labelText: "Utility (15%)", border: OutlineInputBorder()), readOnly: true),
                  const SizedBox(height: 8),
                ],
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF722F37),
            foregroundColor: Colors.white,
          ),
          onPressed: _saveForm,
          child: const Text("Save"),
        ),
      ],
    );
  }
}