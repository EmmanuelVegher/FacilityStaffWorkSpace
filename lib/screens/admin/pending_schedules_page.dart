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
  bool _loaded = false;
  bool _accessAllowed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<bool> _hasPendingPaymentAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
      final dept = (doc.data()?['department'] as String? ?? '').trim().toLowerCase();
      const allowed = {
        'program management',
        'compliance',
        'state management',
        'internal audit',
        'finance',
      };
      return allowed.contains(dept);
    } catch (_) {
      return false;
    }
  }

  Future<void> _init() async {
    final userEmail = _auth.currentUser?.email;
    final allowed = await _hasPendingPaymentAccess();

    if (!allowed || userEmail == null) {
      setState(() {
        _accessAllowed = false;
        _loaded = true;
        _schedulesStream = const Stream.empty();
      });
      return;
    }

    setState(() {
      _accessAllowed = true;
      _loaded = true;
      _schedulesStream = FirebaseFirestore.instance
          .collection('PaymentSchedules')
          .where('currentAssigneeEmail', isEqualTo: userEmail)
          .orderBy('submittedAt', descending: true)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Payment Schedules", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF722F37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : (!_accessAllowed
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Access Denied", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text("You do not have permission to view pending payment schedules.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
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
                )),
    );
  }
}