// lib/features/payroll/services/payroll_workflow_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payroll_workflow_models.dart';

class PayrollWorkflowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> advanceWorkflow({
    required String payrollId,
    required String newStatus,
    required String actorName,
    required String actorRole,
    String? comment,
  }) async {
    final payrollDocRef = _firestore.collection('Payroll').doc(payrollId);

    final historyEntry = ApprovalHistoryEntry(
      actorName: actorName,
      actorRole: actorRole,
      action: 'Approved and sent to ${newStatus.replaceAll("Pending", "").replaceAll("Review", "")}',
      timestamp: Timestamp.now(),
      comment: comment,
    );

    await payrollDocRef.update({
      'status': newStatus,
      'lastModifiedAt': Timestamp.now(),
      'approvalHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });
  }

  Future<void> rejectPayroll({
    required String payrollId,
    required String actorName,
    required String actorRole,
    required String reason,
  }) async {
    final payrollDocRef = _firestore.collection('Payroll').doc(payrollId);

    final historyEntry = ApprovalHistoryEntry(
      actorName: actorName,
      actorRole: actorRole,
      action: 'Rejected',
      timestamp: Timestamp.now(),
      comment: reason,
    );

    await payrollDocRef.update({
      'status': 'Rejected',
      'rejectionReason': reason,
      'lastModifiedAt': Timestamp.now(),
      'approvalHistory': FieldValue.arrayUnion([historyEntry.toMap()]),
    });
  }

  Future<void> updateStaffPaymentDetails({
    required String payrollId,
    required String staffId,
    required double newDeductions,
    required String newNotes,
  }) async {
    final staffPaymentDocRef = _firestore
        .collection('Payroll')
        .doc(payrollId)
        .collection('StaffPayments')
        .doc(staffId);

    // Use a transaction to ensure atomic read-and-write
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(staffPaymentDocRef);
      if (!snapshot.exists) {
        throw Exception("Staff payment document does not exist!");
      }

      final currentPayable = (snapshot.get('payableSalary') as num).toDouble();
      final finalAmount = currentPayable - newDeductions;

      transaction.update(staffPaymentDocRef, {
        'deductions': newDeductions,
        'prorationNotes': newNotes,
        'finalPayableAmount': finalAmount,
      });
    });
  }
}