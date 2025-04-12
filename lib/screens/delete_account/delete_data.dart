import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeleteDataPage extends StatefulWidget {
  @override
  _DeleteDataPageState createState() => _DeleteDataPageState();
}

class _DeleteDataPageState extends State<DeleteDataPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isDeleting = false;

  Future<void> _deleteUserData() async {
    setState(() {
      _isDeleting = true;
    });

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Delete user data from Firestore
        await _firestore.collection('Staff').doc(user.uid).delete();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User data deleted successfully')),
        );
        Navigator.pop(context); // Go back to the previous screen
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user data: $e')),
        );
      }
    }

    setState(() {
      _isDeleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delete Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ElevatedButton(
            onPressed: _isDeleting ? null : _deleteUserData,
            child: _isDeleting
                ? CircularProgressIndicator()
                : Text('Delete User Data'),
          ),
        ),
      ),
    );
  }
}
