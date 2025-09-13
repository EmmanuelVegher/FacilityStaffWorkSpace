import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/payment_schedule_model.dart';
import 'payment_schedule_page.dart';

class PendingSchedulesPage extends StatefulWidget {
  const PendingSchedulesPage({Key? key}) : super(key: key);

  @override
  _PendingSchedulesPageState createState() => _PendingSchedulesPageState();
}

class _PendingSchedulesPageState extends State<PendingSchedulesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _schedulesStream;

  @override
  void initState() {
    super.initState();
    final userEmail = _auth.currentUser?.email;
    if (userEmail != null) {
      _schedulesStream = FirebaseFirestore.instance
          .collection('PaymentSchedules')
          .where('currentAssigneeEmail', isEqualTo: userEmail)
          .orderBy('submittedAt', descending: true)
          .snapshots();
    } else {
      // Handle case where user is not logged in
      _schedulesStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Payment Schedules", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _schedulesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("An error occurred: ${snapshot.error}");
            return Center(child: Text("An error occurred: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No Pending Schedules", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("You have no payment schedules awaiting your review.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((doc) {
              final schedule = PaymentScheduleModel.fromFirestore(doc);
              final monthName = DateFormat('MMMM').format(DateTime(0, schedule.month));

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                  title: Text(
                    "${schedule.state} - $monthName ${schedule.year}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Status: ${schedule.status}\nSubmitted by: ${schedule.submittedByName}",
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentSchedulePage(
                          // Pass the model to enter "Review Mode"
                          scheduleModel: schedule,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}