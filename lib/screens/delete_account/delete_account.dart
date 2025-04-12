import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeleteAccountPage extends StatefulWidget {
  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _passwordController = TextEditingController();
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
    });

    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Re-authenticate the user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Delete user data from Firestore
        await _firestore.collection('Staff').doc(user.uid).delete();

        // Delete the user account
        await user.delete();

        // Optionally, sign out the user
        await _auth.signOut();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.pop(context); // Go back to the previous screen
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
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
      appBar: AppBar(title: Text('Delete Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Enter your password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isDeleting ? null : _deleteAccount,
              child: _isDeleting
                  ? CircularProgressIndicator()
                  : Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }
}
