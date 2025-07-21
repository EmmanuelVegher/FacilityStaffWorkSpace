// lib/features/payroll/models/payroll_workflow_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Represents an entry in the approval audit trail
class ApprovalHistoryEntry {
  final String actorName;
  final String actorRole;
  final String action;
  final Timestamp timestamp;
  final String? comment;

  ApprovalHistoryEntry({
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.timestamp,
    this.comment,
  });

  factory ApprovalHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ApprovalHistoryEntry(
      actorName: map['actorName'] ?? 'Unknown Actor',
      actorRole: map['actorRole'] ?? 'Unknown Role',
      action: map['action'] ?? 'Unknown Action',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      comment: map['comment'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorName': actorName,
      'actorRole': actorRole,
      'action': action,
      'timestamp': timestamp,
      if (comment != null) 'comment': comment,
    };
  }
}

class PayrollPeriod {
  final String id;
  final String period;
  final String state;
  String status;
  final bool isHQPayroll;
  String? notes;
  final String generatedBy;
  final Timestamp generatedAt;
  Timestamp lastModifiedAt;
  String? rejectionReason;
  final List<ApprovalHistoryEntry> approvalHistory;

  PayrollPeriod({
    required this.id,
    required this.period,
    required this.state,
    required this.status,
    required this.isHQPayroll,
    this.notes,
    required this.generatedBy,
    required this.generatedAt,
    required this.lastModifiedAt,
    this.rejectionReason,
    required this.approvalHistory,
  });

  factory PayrollPeriod.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PayrollPeriod(
      id: doc.id,
      period: data['period'] ?? 'Unknown Period',
      state: data['state'] ?? 'N/A',
      status: data['status'] ?? 'Draft',
      isHQPayroll: data['isHQPayroll'] ?? false,
      notes: data['notes'],
      generatedBy: data['generatedBy'] ?? 'Unknown',
      generatedAt: data['generatedAt'] ?? Timestamp.now(),
      lastModifiedAt: data['lastModifiedAt'] ?? Timestamp.now(),
      rejectionReason: data['rejectionReason'],
      approvalHistory: (data['approvalHistory'] as List<dynamic>? ?? [])
          .map((e) => ApprovalHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Rewritten to match the detailed PAYROLL sheet
class StaffPayment {
  final String staffId;
  final String staffName;
  final String designation;
  final String facility;
  final String bankName;
  final String accountNumber;

  // Earnings
  final double grossPay;
  final double housing;
  final double transport;

  // Deductions
  final double pension;
  final double nhf;
  double wht; // Withholding Tax - editable by Grants
  double otherDeductions; // Other deductions - editable by Grants

  // Calculation fields
  final double totalHoursWorked;
  final double expectedWorkHours;
  final double percentageWorked;

  // Final calculation
  double get totalDeductions => pension + nhf + wht + otherDeductions;
  double get netPay => (grossPay + housing + transport) - totalDeductions;

  // Workflow fields
  String paymentStatus;

  StaffPayment({
    required this.staffId,
    required this.staffName,
    required this.designation,
    required this.facility,
    required this.bankName,
    required this.accountNumber,
    required this.grossPay,
    required this.housing,
    required this.transport,
    required this.pension,
    required this.nhf,
    required this.wht,
    required this.otherDeductions,
    required this.totalHoursWorked,
    required this.expectedWorkHours,
    required this.percentageWorked,
    this.paymentStatus = 'Pending',
  });

  factory StaffPayment.fromMap(Map<String, dynamic> map, String id) {
    return StaffPayment(
      staffId: map['staffId'] ?? id,
      staffName: map['staffName'] ?? '',
      designation: map['designation'] ?? '',
      facility: map['facility'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      grossPay: (map['grossPay'] as num? ?? 0.0).toDouble(),
      housing: (map['housing'] as num? ?? 0.0).toDouble(),
      transport: (map['transport'] as num? ?? 0.0).toDouble(),
      pension: (map['pension'] as num? ?? 0.0).toDouble(),
      nhf: (map['nhf'] as num? ?? 0.0).toDouble(),
      wht: (map['wht'] as num? ?? 0.0).toDouble(),
      otherDeductions: (map['otherDeductions'] as num? ?? 0.0).toDouble(),
      totalHoursWorked: (map['totalHoursWorked'] as num? ?? 0.0).toDouble(),
      expectedWorkHours: (map['expectedWorkHours'] as num? ?? 0.0).toDouble(),
      percentageWorked: (map['percentageWorked'] as num? ?? 0.0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'designation': designation,
      'facility': facility,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'grossPay': grossPay,
      'housing': housing,
      'transport': transport,
      'pension': pension,
      'nhf': nhf,
      'wht': wht,
      'otherDeductions': otherDeductions,
      'totalHoursWorked': totalHoursWorked,
      'expectedWorkHours': expectedWorkHours,
      'percentageWorked': percentageWorked,
      'totalDeductions': totalDeductions, // Calculated property
      'netPay': netPay,                   // Calculated property
      'paymentStatus': paymentStatus,
    };
  }
}
