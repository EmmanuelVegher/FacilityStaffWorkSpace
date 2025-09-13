import 'package:cloud_firestore/cloud_firestore.dart';


class ApprovalHistoryEntry {
  final String approverName;
  final String approverEmail;
  final String role;
  final String action;
  final Timestamp timestamp;
  final String? comments;

  ApprovalHistoryEntry({
    required this.approverName,
    required this.approverEmail,
    required this.role,
    required this.action,
    required this.timestamp,
    this.comments,
  });

  Map<String, dynamic> toMap() {
    return {
      'approverName': approverName,
      'approverEmail': approverEmail,
      'role': role,
      'action': action,
      'timestamp': timestamp,
      'comments': comments,
    };
  }

  factory ApprovalHistoryEntry.fromMap(Map<String, dynamic> map) {
    return ApprovalHistoryEntry(
      approverName: map['approverName'] ?? '',
      approverEmail: map['approverEmail'] ?? '',
      role: map['role'] ?? '',
      action: map['action'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      comments: map['comments'],
    );
  }
}

class PaymentScheduleModel {
  final String id;
  final int year;
  final int month;
  final String state;
  String status;
  final String submittedByName;
  final String submittedByEmail;
  final Timestamp submittedAt;
  String currentAssigneeName;
  String currentAssigneeEmail;
  final double totalNetPayroll;
  final String scheduleDataJson; // Store the list of PaymentScheduleItem as JSON
  final List<ApprovalHistoryEntry> approvalHistory;

  PaymentScheduleModel({
    required this.id,
    required this.year,
    required this.month,
    required this.state,
    required this.status,
    required this.submittedByName,
    required this.submittedByEmail,
    required this.submittedAt,
    required this.currentAssigneeName,
    required this.currentAssigneeEmail,
    required this.totalNetPayroll,
    required this.scheduleDataJson,
    required this.approvalHistory,
  });

  factory PaymentScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentScheduleModel(
      id: doc.id,
      year: data['year'] ?? 0,
      month: data['month'] ?? 0,
      state: data['state'] ?? '',
      status: data['status'] ?? 'Draft',
      submittedByName: data['submittedByName'] ?? '',
      submittedByEmail: data['submittedByEmail'] ?? '',
      submittedAt: data['submittedAt'] ?? Timestamp.now(),
      currentAssigneeName: data['currentAssigneeName'] ?? '',
      currentAssigneeEmail: data['currentAssigneeEmail'] ?? '',
      totalNetPayroll: (data['totalNetPayroll'] as num?)?.toDouble() ?? 0.0,
      scheduleDataJson: data['scheduleDataJson'] ?? '[]',
      approvalHistory: (data['approvalHistory'] as List<dynamic>?)
          ?.map((e) => ApprovalHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}