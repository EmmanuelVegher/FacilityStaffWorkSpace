// // lib/features/payroll/ui/payroll_workflow_page.dart
//
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:month_picker_dialog/month_picker_dialog.dart';
// import 'package:csv/csv.dart';
// import 'dart:html' as html;
// import 'dart:convert';
//
// import '../models/payroll_workflow_models.dart';
// import '../services/payroll_service.dart';
// import '../services/payment_service.dart';
// import '../services/payroll_workflow_service.dart';
//
// class PayrollWorkflowPage extends StatefulWidget {
//   const PayrollWorkflowPage({super.key});
//
//   @override
//   _PayrollWorkflowPageState createState() => _PayrollWorkflowPageState();
// }
//
// class _PayrollWorkflowPageState extends State<PayrollWorkflowPage> {
//   DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
//   final PayrollService _payrollService = PayrollService();
//   final PayrollWorkflowService _workflowService = PayrollWorkflowService();
//   final PaymentService _paymentService = PaymentService();
//
//   bool _isGenerating = false;
//   bool _isActionInProgress = false;
//
//   // These will be fetched for the logged-in user
//   String? _currentUserRole;
//   String? _currentUserName;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchCurrentUserProfile();
//   }
//
//   Future<void> _fetchCurrentUserProfile() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       final doc = await FirebaseFirestore.instance.collection('Staff').doc(user.uid).get();
//       if (doc.exists && mounted) {
//         setState(() {
//           _currentUserRole = doc.data()?['role'];
//           _currentUserName = '${doc.data()?['firstName'] ?? ''} ${doc.data()?['lastName'] ?? ''}'.trim();
//         });
//       }
//     }
//   }
//
//   String get _payrollPeriodId => "${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}";
//
//   void _pickMonth() {
//     showMonthPicker(
//       context: context,
//       initialDate: _selectedMonth,
//       firstDate: DateTime(2022),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//     ).then((date) {
//       if (date != null) {
//         setState(() => _selectedMonth = date);
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_currentUserRole == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Payroll Workflow (${_currentUserRole ?? ''})'),
//         backgroundColor: const Color(0xFF722F37),
//       ),
//       body: Column(
//         children: [
//           _buildControlPanel(),
//           Expanded(child: _buildPayrollDetails()),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildControlPanel() {
//     return Card(
//       margin: const EdgeInsets.all(8),
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             TextButton.icon(
//               icon: const Icon(Icons.calendar_today),
//               label: Text(
//                 DateFormat('MMMM, yyyy').format(_selectedMonth),
//                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               onPressed: _pickMonth,
//             ),
//             if (_currentUserRole == 'Programs')
//               ElevatedButton.icon(
//                 onPressed: _isGenerating ? null : () async {
//                   setState(() => _isGenerating = true);
//                   final payrollId = "${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}";
//
//                   // First, create the main payroll document
//                   await FirebaseFirestore.instance.collection('Payroll').doc(payrollId).set({
//                     'period': DateFormat('MMMM yyyy').format(_selectedMonth),
//                     'status': 'Draft',
//                     'generatedBy': _currentUserName,
//                     'generatedAt': Timestamp.now(),
//                     'lastModifiedAt': Timestamp.now(),
//                     'approvalHistory': [],
//                   });
//
//                   // Then, generate the staff payments which will be a subcollection
//                   final result = await _payrollService.generatePayrollForPeriod(_selectedMonth.year, _selectedMonth.month);
//
//                   if (mounted) {
//                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
//                     setState(() => _isGenerating = false);
//                   }
//                 },
//                 icon: _isGenerating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate),
//                 label: const Text('Generate Schedule'),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPayrollDetails() {
//     return StreamBuilder<DocumentSnapshot>(
//       stream: FirebaseFirestore.instance.collection('Payroll').doc(_payrollPeriodId).snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (!snapshot.hasData || !snapshot.data!.exists) {
//           return const Center(child: Text('No payroll schedule generated for this period.'));
//         }
//         if (snapshot.hasError) {
//           return Center(child: Text("Error: ${snapshot.error}"));
//         }
//
//         final payrollPeriod = PayrollPeriod.fromFirestore(snapshot.data!);
//
//         return Column(
//           children: [
//             _buildWorkflowStatusBar(payrollPeriod),
//             Expanded(
//               child: StreamBuilder<QuerySnapshot>(
//                 stream: FirebaseFirestore.instance.collection('Payroll').doc(_payrollPeriodId).collection('StaffPayments').snapshots(),
//                 builder: (context, staffSnapshot) {
//                   if (!staffSnapshot.hasData) return const Center(child: CircularProgressIndicator());
//                   final payments = staffSnapshot.data!.docs.map((doc) => StaffPayment.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
//                   return _StaffPaymentsDataTable(
//                     payments: payments,
//                     payrollPeriod: payrollPeriod,
//                     currentUserRole: _currentUserRole!,
//                     onSaveGrantsEdit: (staffId, deductions, notes) {
//                       _workflowService.updateStaffPaymentDetails(
//                           payrollId: _payrollPeriodId,
//                           staffId: staffId,
//                           newDeductions: deductions,
//                           newNotes: notes
//                       );
//                     },
//                     onInitiatePayment: (payment) {
//                       // Payment logic will be added here
//                     },
//                   );
//                 },
//               ),
//             ),
//             _buildActionButtons(payrollPeriod),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildWorkflowStatusBar(PayrollPeriod payroll) {
//     // A visual representation of the workflow state
//     return Card(
//       color: Colors.blueGrey.shade50,
//       margin: const EdgeInsets.symmetric(horizontal: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text("Current Status:", style: TextStyle(color: Colors.grey.shade700)),
//                 Chip(
//                   label: Text(payroll.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//                   backgroundColor: _getStatusColor(payroll.status),
//                 ),
//               ],
//             ),
//             if (payroll.rejectionReason != null) ...[
//               const Divider(height: 16),
//               Text("Rejection Reason:", style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold)),
//               Text(payroll.rejectionReason!),
//             ]
//           ],
//         ),
//       ),
//     );
//   }
//
//   Color _getStatusColor(String status) {
//     if (status.contains('Pending')) return Colors.orange;
//     if (status.contains('Rejected')) return Colors.red;
//     if (status.contains('Completed')) return Colors.green;
//     return Colors.blueGrey;
//   }
//
//   Widget _buildActionButtons(PayrollPeriod payroll) {
//     if (_isActionInProgress) {
//       return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
//     }
//
//     Map<String, String> nextStateMap = {
//       'Draft': 'PendingGrantsReview',
//       'PendingGrantsReview': 'PendingAuditReview',
//       'PendingAuditReview': 'PendingSTLReview',
//       'PendingSTLReview': 'PendingFinanceProcessing',
//       'PendingFinanceProcessing': 'Completed',
//     };
//
//     // Role required to approve the current state
//     Map<String, String> approvalRoleMap = {
//       'Draft': 'Programs',
//       'PendingGrantsReview': 'Grants',
//       'PendingAuditReview': 'Audit',
//       'PendingSTLReview': 'STL',
//       'PendingFinanceProcessing': 'Finance',
//     };
//
//     final requiredRoleForApproval = approvalRoleMap[payroll.status];
//
//     if (_currentUserRole != requiredRoleForApproval) {
//       return const SizedBox.shrink(); // Hide button if user doesn't have the right role
//     }
//
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           if (payroll.status != 'Completed' && payroll.status != 'Rejected') ...[
//             TextButton.icon(
//               icon: const Icon(Icons.thumb_down, color: Colors.red),
//               label: const Text("Reject", style: TextStyle(color: Colors.red)),
//               onPressed: () => _showRejectionDialog(payroll.id),
//             ),
//             const SizedBox(width: 16),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.thumb_up),
//               label: Text(payroll.status == 'PendingFinanceProcessing' ? 'Mark as Completed' : 'Approve & Forward'),
//               onPressed: () async {
//                 setState(() => _isActionInProgress = true);
//                 await _workflowService.advanceWorkflow(
//                   payrollId: payroll.id,
//                   newStatus: nextStateMap[payroll.status]!,
//                   actorName: _currentUserName!,
//                   actorRole: _currentUserRole!,
//                 );
//                 setState(() => _isActionInProgress = false);
//               },
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Future<void> _showRejectionDialog(String payrollId) async {
//     final reasonController = TextEditingController();
//     final formKey = GlobalKey<FormState>();
//
//     return showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Reject Payroll'),
//           content: Form(
//             key: formKey,
//             child: TextFormField(
//               controller: reasonController,
//               decoration: const InputDecoration(labelText: 'Reason for Rejection'),
//               validator: (value) => value!.isEmpty ? 'A reason is required' : null,
//               maxLines: 3,
//             ),
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//             ElevatedButton(
//               onPressed: () async {
//                 if(formKey.currentState!.validate()) {
//                   setState(() => _isActionInProgress = true);
//                   await _workflowService.rejectPayroll(
//                     payrollId: payrollId,
//                     actorName: _currentUserName!,
//                     actorRole: _currentUserRole!,
//                     reason: reasonController.text,
//                   );
//                   Navigator.pop(context);
//                   setState(() => _isActionInProgress = false);
//                 }
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               child: const Text('Confirm Rejection'),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// // A new widget to handle the complexity of the data table and its editing logic
// class _StaffPaymentsDataTable extends StatefulWidget {
//   final List<StaffPayment> payments;
//   final PayrollPeriod payrollPeriod;
//   final String currentUserRole;
//   final Function(String staffId, double deductions, String notes) onSaveGrantsEdit;
//   final Function(StaffPayment payment) onInitiatePayment;
//
//   const _StaffPaymentsDataTable({
//     required this.payments,
//     required this.payrollPeriod,
//     required this.currentUserRole,
//     required this.onSaveGrantsEdit,
//     required this.onInitiatePayment,
//   });
//
//   @override
//   _StaffPaymentsDataTableState createState() => _StaffPaymentsDataTableState();
// }
//
// class _StaffPaymentsDataTableState extends State<_StaffPaymentsDataTable> {
//   // Map to hold text editing controllers for each staff member being edited
//   final Map<String, TextEditingController> _deductionControllers = {};
//   final Map<String, TextEditingController> _notesControllers = {};
//   String? _editingStaffId;
//
//   void _startEditing(StaffPayment payment) {
//     setState(() {
//       _editingStaffId = payment.staffId;
//       _deductionControllers[payment.staffId] = TextEditingController(text: payment.deductions.toStringAsFixed(2));
//       _notesControllers[payment.staffId] = TextEditingController(text: payment.prorationNotes ?? '');
//     });
//   }
//
//   void _cancelEditing() {
//     setState(() {
//       _deductionControllers.remove(_editingStaffId);
//       _notesControllers.remove(_editingStaffId);
//       _editingStaffId = null;
//     });
//   }
//
//   void _saveChanges(String staffId) {
//     final deductions = double.tryParse(_deductionControllers[staffId]!.text) ?? 0.0;
//     final notes = _notesControllers[staffId]!.text;
//     widget.onSaveGrantsEdit(staffId, deductions, notes);
//     _cancelEditing(); // Exit editing mode after saving
//   }
//
//   Future<void> _exportToExcel() async {
//     final List<List<dynamic>> rows = [
//       // Header
//       [
//         'Staff Name', 'Designation', 'Base Salary', 'Hours Worked', 'Expected Hours',
//         'Initial Payable', 'Deductions/Taxes', 'Proration/Adjustment Notes', 'FINAL PAYABLE AMOUNT'
//       ]
//     ];
//
//     // Data
//     for (var p in widget.payments) {
//       rows.add([
//         p.staffName,
//         p.designation,
//         p.baseSalary,
//         p.totalHoursWorked,
//         p.expectedWorkHours,
//         p.payableSalary,
//         p.deductions,
//         p.prorationNotes ?? '',
//         p.finalPayableAmount,
//       ]);
//     }
//
//     String csvData = const ListToCsvConverter().convert(rows);
//     final bytes = utf8.encode(csvData);
//     final blob = html.Blob([bytes]);
//     final url = html.Url.createObjectUrlFromBlob(blob);
//     final anchor = html.AnchorElement(href: url)
//       ..setAttribute("download", "Payroll_${widget.payrollPeriod.period.replaceAll(' ', '_')}.csv")
//       ..click();
//     html.Url.revokeObjectUrl(url);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool isGrantsEditingAllowed = widget.currentUserRole == 'Grants' && widget.payrollPeriod.status == 'PendingGrantsReview';
//     final bool isFinanceProcessing = widget.currentUserRole == 'Finance' && widget.payrollPeriod.status == 'PendingFinanceProcessing';
//
//     return SingleChildScrollView(
//       child: Column(
//         children: [
//           if(isFinanceProcessing)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Align(
//                 alignment: Alignment.centerRight,
//                 child: ElevatedButton.icon(
//                   onPressed: _exportToExcel,
//                   icon: const Icon(Icons.download),
//                   label: const Text("Export as Excel (CSV)"),
//                 ),
//               ),
//             ),
//           SizedBox(
//             width: double.infinity,
//             child: DataTable(
//               columnSpacing: 20,
//               columns: [
//                 const DataColumn(label: Text('Staff')),
//                 const DataColumn(label: Text('Base Salary'), numeric: true),
//                 const DataColumn(label: Text('Payable'), numeric: true),
//                 const DataColumn(label: Text('Deductions'), numeric: true),
//                 const DataColumn(label: Text('Notes')),
//                 const DataColumn(label: Text('Final Payable'), numeric: true),
//                 if (isGrantsEditingAllowed || isFinanceProcessing) const DataColumn(label: Text('Actions')),
//               ],
//               rows: widget.payments.map((p) {
//                 bool isEditingThisRow = _editingStaffId == p.staffId;
//                 return DataRow(
//                   cells: [
//                     DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.staffName, style: const TextStyle(fontWeight: FontWeight.bold)), Text(p.designation, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
//                     DataCell(Text(NumberFormat.compactCurrency(symbol: 'N').format(p.baseSalary))),
//                     DataCell(Text(NumberFormat.compactCurrency(symbol: 'N').format(p.payableSalary))),
//                     DataCell(
//                       isEditingThisRow
//                           ? SizedBox(width: 80, child: TextField(controller: _deductionControllers[p.staffId], keyboardType: TextInputType.number))
//                           : Text(NumberFormat.compactCurrency(symbol: 'N').format(p.deductions)),
//                     ),
//                     DataCell(
//                       isEditingThisRow
//                           ? SizedBox(width: 150, child: TextField(controller: _notesControllers[p.staffId]))
//                           : SizedBox(width: 150, child: Text(p.prorationNotes ?? '-', overflow: TextOverflow.ellipsis)),
//                     ),
//                     DataCell(Text(NumberFormat.compactCurrency(symbol: 'N').format(p.finalPayableAmount), style: const TextStyle(fontWeight: FontWeight.bold))),
//                     if (isGrantsEditingAllowed || isFinanceProcessing)
//                       DataCell(
//                         isEditingThisRow
//                             ? Row(
//                           children: [
//                             IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _saveChanges(p.staffId)),
//                             IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _cancelEditing),
//                           ],
//                         )
//                             : (isGrantsEditingAllowed
//                             ? IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _startEditing(p))
//                             : const SizedBox.shrink()), // No edit button for finance
//                       ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }