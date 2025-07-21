import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentModulePage extends StatefulWidget {
  const PaymentModulePage({super.key});

  @override
  State<PaymentModulePage> createState() => _PaymentModulePageState();
}

class _PaymentModulePageState extends State<PaymentModulePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _approvedTimesheets = [];

  @override
  void initState() {
    super.initState();
    _fetchApprovedTimesheets();
  }

  Future<void> _fetchApprovedTimesheets() async {
    try {
      final snapshot = await _firestore.collectionGroup('TimeSheets')
          .where('facilitySupervisorSignatureStatus', isEqualTo: 'Approved')
          .where('caritasSupervisorSignatureStatus', isEqualTo: 'Approved')
          .get();

      setState(() {
        _approvedTimesheets = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching timesheets: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPaid(DocumentSnapshot doc) async {
    try {
      await doc.reference.update({ 'paymentStatus': 'Paid' });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment marked as completed.")));
      _fetchApprovedTimesheets();
    } catch (e) {
      debugPrint("Error updating payment status: $e");
    }
  }

  double _calculateAmount(double totalHours) {
    const hourlyRate = 2000.0;
    return totalHours * hourlyRate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Process Staff Payments"),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _approvedTimesheets.length,
        itemBuilder: (context, index) {
          final data = _approvedTimesheets[index].data() as Map<String, dynamic>;
          final staffName = data['staffName'] ?? 'Unknown';
          final location = data['location'] ?? 'N/A';
          final state = data['state'] ?? 'N/A';
          final totalHours = (data['timesheetEntries'] as List?)?.fold<double>(0.0, (sum, entry) => sum + (entry['noOfHours'] ?? 0.0)) ?? 0.0;
          final paymentStatus = data['paymentStatus'] ?? 'Pending';
          final amount = _calculateAmount(totalHours);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text(staffName[0])),
              title: Text(staffName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Location: $location, $state"),
                  Text("Hours: ${totalHours.toStringAsFixed(1)} hrs"),
                  Text("Status: $paymentStatus"),
                ],
              ),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₦${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  paymentStatus == 'Paid'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                    onPressed: () => _markAsPaid(_approvedTimesheets[index]),
                    child: const Text("Pay"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
