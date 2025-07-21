// lib/features/payroll/ui/payroll_review_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../models/payroll_models.dart';
import '../services/payroll_service.dart';
import '../services/payment_service.dart'; // <-- Use our new service

class PayrollReviewPage extends StatefulWidget {
  const PayrollReviewPage({super.key});

  @override
  _PayrollReviewPageState createState() => _PayrollReviewPageState();
}

class _PayrollReviewPageState extends State<PayrollReviewPage> {
  DateTime _selectedMonth = DateTime.now();
  final PayrollService _payrollService = PayrollService();
  final PaymentService _paymentService = PaymentService(); // <-- Instantiate new service
  bool _isGenerating = false;
  bool _isPaying = false; // For a single payment process
  bool _isVerifying = false; // For a single verification process

  String get _payrollPeriodId => "${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}";

  void _pickMonth() {
    // We are replacing month_year_picker with a different one.
    // If you used another package, replace it here. Otherwise, use Flutter's built-in picker.
    showMonthPicker(
      context: context,
      initialDate: _selectedMonth,
    ).then((date) {
      if (date != null) {
        setState(() => _selectedMonth = date);
      }
    });
  }

  // NEW: Payment Initiation Logic for Web
  Future<void> _initiatePayment(StaffPayment payment) async {
    setState(() => _isPaying = true);

    try {
      final amountInKobo = (payment.payableSalary * 100).toInt();

      final response = await _paymentService.initializeTransaction(
        amount: amountInKobo,
        email: payment.staffEmail,
      );

      if (response['status'] == true) {
        // We got an authorization URL, now open it
        final authUrl = response['data']['authorization_url'];
        final reference = response['data']['reference'];

        // Update Firestore with the reference so we can verify later
        await FirebaseFirestore.instance
            .collection('Payroll').doc(_payrollPeriodId)
            .collection('StaffPayments').doc(payment.staffId)
            .update({'paymentReference': reference});

        // Launch the URL
        await _paymentService.launchPaymentUrl(authUrl);

      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paystack Error: ${response['message']}'), backgroundColor: Colors.red));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isPaying = false);
    }
  }

  // NEW: Verification Logic
  Future<void> _verifyPayment(StaffPayment payment) async {
    if (payment.paymentReference == null || payment.paymentReference!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment reference found to verify.')));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await _paymentService.verifyTransaction(payment.paymentReference!);
      final firestoreRef = FirebaseFirestore.instance.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments').doc(payment.staffId);

      if (response['status'] == true && response['data']['status'] == 'success') {
        await firestoreRef.update({
          'status': 'Paid',
          'paidAt': Timestamp.now(),
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment for ${payment.staffName} confirmed!'), backgroundColor: Colors.green));
      } else {
        await firestoreRef.update({'status': 'Failed'});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${response['data']['gateway_response']}'), backgroundColor: Colors.red));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred during verification: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Review & Payments'),
        backgroundColor: const Color(0xFF722F37),
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(child: _buildPayrollList()),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected Period', style: TextStyle(color: Colors.grey)),
                Text(
                  DateFormat('MMMM, yyyy').format(_selectedMonth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.calendar_today, color: Colors.blue), onPressed: _pickMonth),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : () async {
                    setState(() => _isGenerating = true);
                    final result = await _payrollService.generatePayrollForPeriod(_selectedMonth.year, _selectedMonth.month);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                      setState(() => _isGenerating = false);
                    }
                  },
                  icon: _isGenerating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate),
                  label: const Text('Generate Schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No payroll data for this period.\nClick "Generate Schedule" to begin.', textAlign: TextAlign.center)));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final payments = snapshot.data!.docs.map((doc) => StaffPayment.fromMap(doc.data() as Map<String, dynamic>)).toList();

        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(payment.staffName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Chip(
                          label: Text(payment.status, style: const TextStyle(color: Colors.white)),
                          backgroundColor: payment.status == 'Paid' ? Colors.green : (payment.status == 'Failed' ? Colors.red : Colors.orange),
                        ),
                      ],
                    ),
                    Text(payment.designation, style: const TextStyle(color: Colors.grey)),
                    const Divider(height: 20),
                    _buildPaymentDetailRow('Base Salary:', 'NGN ${NumberFormat("#,##0.00").format(payment.baseSalary)}'),
                    _buildPaymentDetailRow('Hours Worked:', '${payment.totalHoursWorked.toStringAsFixed(2)} / ${payment.expectedWorkHours.toStringAsFixed(2)} hrs'),
                    const Divider(thickness: 1, color: Colors.black12, height: 20),
                    _buildPaymentDetailRow('Payable Salary:', 'NGN ${NumberFormat("#,##0.00").format(payment.payableSalary)}', isBold: true, color: Colors.green.shade800),
                    const SizedBox(height: 16),
                    if (payment.status == 'Pending')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (payment.paymentReference != null) // Show verify button if reference exists
                            TextButton.icon(
                              onPressed: _isVerifying ? null : () => _verifyPayment(payment),
                              icon: _isVerifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_user_outlined),
                              label: const Text("Verify"),
                              style: TextButton.styleFrom(foregroundColor: Colors.teal),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isPaying ? null : () => _initiatePayment(payment),
                            icon: _isPaying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payment),
                            label: const Text('Pay Now'),
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}