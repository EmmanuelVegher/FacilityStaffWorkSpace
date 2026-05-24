import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/payment_schedule_model.dart';
import 'payment_schedule_page.dart';

class PendingSchedulesPage extends StatefulWidget {
  const PendingSchedulesPage({super.key});

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
        title: Text("Pending Payment Schedules",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF5C1A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C1A2E), Color(0xFF2E0215)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SelectionArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : (!_accessAllowed
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text("Access Denied",
                            style: GoogleFonts.poppins(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(
                            "You do not have permission to view pending payment schedules.",
                            style: GoogleFonts.poppins(color: Colors.grey)),
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
                        return Center(
                            child:
                                Text("An error occurred: ${snapshot.error}", style: GoogleFonts.poppins()));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 80, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text("No Pending Schedules",
                                  style: GoogleFonts.poppins(
                                      fontSize: 22, fontWeight: FontWeight.bold)),
                              Text(
                                  "You have no payment schedules awaiting your review.",
                                  style: GoogleFonts.poppins(color: Colors.grey)),
                            ],
                          ),
                        );
                      }
  
                      return ListView(
                        padding: const EdgeInsets.all(8.0),
                        children: snapshot.data!.docs.map((doc) {
                          final schedule = PaymentScheduleModel.fromFirestore(doc);
                          final monthName =
                              DateFormat('MMMM').format(DateTime(0, schedule.month));
  
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: ListTile(
                              leading: const Icon(Icons.hourglass_top_rounded,
                                  color: Colors.orange),
                              title: Text(
                                "${schedule.state} - $monthName ${schedule.year}",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "Status: ${schedule.status}\nSubmitted by: ${schedule.submittedByName}",
                                style: GoogleFonts.poppins(),
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
      ),
    );
  }
}