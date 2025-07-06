import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorFormScreen extends StatefulWidget {
  final String stateId;
  final Map<String, dynamic>? existingSupervisorData;
  final String? existingSupervisorId;

  const SupervisorFormScreen({
    super.key,
    required this.stateId,
    this.existingSupervisorData,
    this.existingSupervisorId,
  });

  bool get isEditMode => existingSupervisorData != null;

  @override
  _SupervisorFormScreenState createState() => _SupervisorFormScreenState();
}

class _SupervisorFormScreenState extends State<SupervisorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedDepartment;
  List<DropdownMenuItem<String>> _departmentOptions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    if (widget.isEditMode) {
      _nameController.text = widget.existingSupervisorData!['supervisor'] ?? '';
      _emailController.text = widget.existingSupervisorData!['email'] ?? '';
      _selectedDepartment = widget.existingSupervisorData!['department'] ?? '';
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Designation').get();
      final departments = snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(value: doc.id, child: Text(doc.id));
      }).toList();
      if (mounted) {
        setState(() => _departmentOptions = departments);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveSupervisor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final supervisorName = _nameController.text.trim();
    final supervisorData = {
      'supervisor': supervisorName,
      'email': _emailController.text.trim(),
      'department': _selectedDepartment,
    };

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('Supervisors')
          .doc(widget.stateId)
          .collection(widget.stateId);

      // In your structure, the document ID is the supervisor's name.
      await collectionRef.doc(supervisorName).set(supervisorData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Supervisor ${widget.isEditMode ? 'updated' : 'added'} successfully.'),
        backgroundColor: Colors.green,
      ));
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving supervisor: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Supervisor' : 'Add Supervisor', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        items: _departmentOptions,
                        onChanged: (value) => setState(() => _selectedDepartment = value),
                        decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                        validator: (value) => (value == null) ? 'Please select a department' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSupervisor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(widget.isEditMode ? 'Save Changes' : 'Add Supervisor', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}