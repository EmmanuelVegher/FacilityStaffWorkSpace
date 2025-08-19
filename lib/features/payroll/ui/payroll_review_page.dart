// lib/features/payroll/ui/payroll_review_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../models/payroll_models.dart';
import '../services/payroll_service.dart';
import 'payslip_preview_page.dart'; // We will create this file

// --- USER ROLE SIMULATOR ---
// In a real app, get this from an auth provider.
enum UserRole { programManager, grantOfficer, auditor, financeOfficer }

class PayrollReviewPage extends StatefulWidget {
  const PayrollReviewPage({super.key});

  @override
  _PayrollReviewPageState createState() => _PayrollReviewPageState();
}

class _PayrollReviewPageState extends State<PayrollReviewPage> {
  DateTime _selectedMonth = DateTime.now();
  final PayrollService _payrollService = PayrollService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  UserRole _currentUserRole = UserRole.programManager; // Default role

  String get _payrollPeriodId =>
      "${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}";

  void _pickMonth() {
    showMonthPicker(
      context: context,
      initialDate: _selectedMonth,
    ).then((date) {
      if (date != null) {
        setState(() => _selectedMonth = date);
      }
    });
  }

  Future<void> _updateAllWorkflowStatus(String newStatus, {String? fromStatus}) async {
    setState(() => _isLoading = true);
    final collectionRef = _firestore.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments');
    final periodDocRef = _firestore.collection('Payroll').doc(_payrollPeriodId);

    try {
      final query = fromStatus != null ? collectionRef.where('workflowStatus', isEqualTo: fromStatus) : collectionRef;
      final snapshot = await query.get();

      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'workflowStatus': newStatus});
      }

      batch.update(periodDocRef, {'status': newStatus, 'lastUpdated': Timestamp.now()});
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payroll submitted to: $newStatus'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRejection() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payroll'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Reason for Rejection'),
            validator: (value) => value!.isEmpty ? 'Rejection reason is required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      const newStatus = 'PendingGrantReview'; // Send it back to Grants
      const fromStatus = 'PendingAudit';

      final collectionRef = _firestore.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments');
      final periodDocRef = _firestore.collection('Payroll').doc(_payrollPeriodId);

      try {
        final snapshot = await collectionRef.where('workflowStatus', isEqualTo: fromStatus).get();
        WriteBatch batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {
            'workflowStatus': newStatus,
            'rejectionReason': reasonController.text,
          });
        }
        batch.update(periodDocRef, {'status': newStatus, 'rejectionReason': reasonController.text});
        await batch.commit();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll rejected and sent back to Grants.'), backgroundColor: Colors.orange));
      } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Workflow'),
        backgroundColor: const Color(0xFF722F37),
      ),
      body: Column(
        children: [
          _buildRoleSimulator(),
          _buildControlPanel(),
          Expanded(child: _buildPayrollList()),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildRoleSimulator() {
    return Container(
      color: Colors.amber.shade100,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text("SIMULATOR: Logged in as...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          DropdownButton<UserRole>(
            value: _currentUserRole,
            isExpanded: true,
            items: UserRole.values.map((role) {
              return DropdownMenuItem(value: role, child: Text(role.toString().split('.').last));
            }).toList(),
            onChanged: (UserRole? newValue) {
              setState(() {
                _currentUserRole = newValue!;
              });
            },
          ),
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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Selected Period', style: TextStyle(color: Colors.grey)),
                  Text(DateFormat('MMMM, yyyy').format(_selectedMonth), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                Row(children: [
                  IconButton(icon: const Icon(Icons.calendar_today, color: Colors.blue), onPressed: _pickMonth),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      final result = await _payrollService.generatePayrollForPeriod(_selectedMonth.year, _selectedMonth.month);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                        setState(() => _isLoading = false);
                      }
                    },
                    icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate),
                    label: const Text('Generate'),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            _buildWorkflowActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowActionButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Payroll').doc(_payrollPeriodId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text("Generate payroll for the selected period to begin.");
        }
        final status = snapshot.data!.get('status') as String;

        if (_currentUserRole == UserRole.programManager && status == 'PendingProgramReview') {
          return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isLoading ? null : () => _updateAllWorkflowStatus('PendingGrantReview', fromStatus: 'PendingProgramReview'), icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send), label: const Text('Submit to Grants & Compliance'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800)));
        }
        if (_currentUserRole == UserRole.grantOfficer && status == 'PendingGrantReview') {
          return SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isLoading ? null : () => _updateAllWorkflowStatus('PendingAudit', fromStatus: 'PendingGrantReview'), icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send), label: const Text('Submit to Audit'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800)));
        }
        if (_currentUserRole == UserRole.auditor && status == 'PendingAudit') {
          return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            TextButton.icon(onPressed: _isLoading ? null : _handleRejection, icon: const Icon(Icons.cancel), label: const Text("Reject"), style: TextButton.styleFrom(foregroundColor: Colors.red)),
            ElevatedButton.icon(onPressed: _isLoading ? null : () => _updateAllWorkflowStatus('ReadyForPayment', fromStatus: 'PendingAudit'), icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle), label: const Text('Approve for Finance'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal)),
          ]);
        }
        if (_currentUserRole == UserRole.financeOfficer && status == 'ReadyForPayment') {
          return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text("Download")),
            ElevatedButton.icon(
                onPressed: () {
                  // This would trigger the cloud function for all staff
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requesting emails for all staff...'), backgroundColor: Colors.blue));
                },
                icon: const Icon(Icons.email),
                label: const Text("Email All Payslips"),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor)
            ),
          ]);
        }

        return Chip(label: Text('Current Status: $status'), backgroundColor: Colors.grey.shade300,);
      },
    );
  }

  Widget _buildPayrollList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No payroll data found.'));
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

        final payments = snapshot.data!.docs.map((doc) => StaffPayment.fromMap(doc.data() as Map<String, dynamic>)).toList();

        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return PayrollCard(
              payment: payment,
              periodId: _payrollPeriodId,
              currentUserRole: _currentUserRole,
            );
          },
        );
      },
    );
  }
}

// --- PAYROLL CARD WIDGET ---

class PayrollCard extends StatelessWidget {
  final StaffPayment payment;
  final String periodId;
  final UserRole currentUserRole;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PayrollCard({
    super.key,
    required this.payment,
    required this.periodId,
    required this.currentUserRole
  });

  void _showManualDeductionDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Manual Deduction'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Deduction Reason'), validator: (v) => v!.isEmpty ? 'Required' : null),
            TextFormField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount (NGN)'), keyboardType: TextInputType.number, validator: (v) => double.tryParse(v!) == null ? 'Invalid number' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final newDeduction = ManualDeduction(description: descriptionController.text, amount: double.parse(amountController.text));
              final updatedDeductions = [...payment.manualDeductions, newDeduction];

              final manualTotal = updatedDeductions.fold<double>(0.0, (sum, item) => sum + item.amount);
              final newTotalDeductions = payment.paye + payment.employeePension + manualTotal;
              final newNetPay = payment.grossPay - newTotalDeductions;

              await _firestore.collection('Payroll').doc(periodId).collection('StaffPayments').doc(payment.staffId).update({
                'manualDeductions': updatedDeductions.map((d) => d.toMap()).toList(),
                'totalDeductions': newTotalDeductions,
                'netPay': newNetPay,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deduction Added!'), backgroundColor: Colors.green));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStatutoryDeductionDialog(BuildContext context) async {
    final payeController = TextEditingController(text: payment.paye.toStringAsFixed(2));
    final pensionController = TextEditingController(text: payment.employeePension.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Statutory Deductions'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: payeController, decoration: const InputDecoration(labelText: 'PAYE (NGN)'), keyboardType: TextInputType.number, validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null),
            TextFormField(controller: pensionController, decoration: const InputDecoration(labelText: 'Employee Pension (NGN)'), keyboardType: TextInputType.number, validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final paye = double.parse(payeController.text);
              final pension = double.parse(pensionController.text);
              final manualTotal = payment.manualDeductions.fold<double>(0.0, (sum, item) => sum + item.amount);
              final newTotalDeductions = paye + pension + manualTotal;
              final newNetPay = payment.grossPay - newTotalDeductions;

              await _firestore.collection('Payroll').doc(periodId).collection('StaffPayments').doc(payment.staffId).update({
                'paye': paye,
                'employeePension': pension,
                'totalDeductions': newTotalDeductions,
                'netPay': newNetPay,
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statutory Deductions Saved!'), backgroundColor: Colors.green));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat("#,##0.00");
    final statusColor = _getStatusColor(payment.workflowStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(payment.staffName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Chip(label: Text(payment.workflowStatus, style: const TextStyle(color: Colors.white)), backgroundColor: statusColor),
              ],
            ),
            if (payment.rejectionReason != null && payment.rejectionReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Rejection Reason: ${payment.rejectionReason}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
              ),
            Text(payment.designation, style: const TextStyle(color: Colors.grey)),
            const Divider(height: 20),
            _buildDetailRow('Gross Pay:', 'NGN ${numberFormat.format(payment.grossPay)}'),
            _buildDetailRow('Total Deductions:', 'NGN ${numberFormat.format(payment.totalDeductions)}', color: Colors.red),
            const Divider(thickness: 1, height: 20),
            _buildDetailRow('NET PAY:', 'NGN ${numberFormat.format(payment.netPay)}', isBold: true, color: Colors.green.shade800),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (currentUserRole == UserRole.programManager && payment.workflowStatus == 'PendingProgramReview') {
      return Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _showManualDeductionDialog(context), icon: const Icon(Icons.add_circle_outline), label: const Text('Manage Manual Deductions')));
    }
    if (currentUserRole == UserRole.grantOfficer && payment.workflowStatus == 'PendingGrantReview') {
      return Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _showStatutoryDeductionDialog(context), icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Set Statutory Deductions'), style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800)));
    }
    if (currentUserRole == UserRole.financeOfficer && payment.workflowStatus == 'ReadyForPayment') {
      return Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PayslipPreviewPage(payment: payment)));
      }, icon: const Icon(Icons.receipt_long), label: const Text('View Payslip'), style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor)));
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14, color: color)),
    ]));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PendingProgramReview': return Colors.blue.shade800;
      case 'PendingGrantReview': return Colors.orange.shade800;
      case 'PendingAudit': return Colors.teal;
      case 'ReadyForPayment': return Colors.green.shade800;
      case 'Paid': return Colors.purple;
      default: return Colors.grey;
    }
  }
}