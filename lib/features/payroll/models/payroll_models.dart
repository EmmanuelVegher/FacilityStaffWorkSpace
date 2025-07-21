// lib/features/payroll/models/payroll_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DesignationSalary {
  final String designation;
  final double salary;

  DesignationSalary({required this.designation, required this.salary});

  factory DesignationSalary.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DesignationSalary(
      designation: doc.id,
      salary: (data['salary'] as num? ?? 0.0).toDouble(),
    );
  }
}

class StaffPayment {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String designation;
  final double totalHoursWorked;
  final double expectedWorkHours;
  final double baseSalary;
  final double payableSalary;
  String status;
  String? paymentReference;
  Timestamp? paidAt;

  StaffPayment({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.designation,
    required this.totalHoursWorked,
    required this.expectedWorkHours,
    required this.baseSalary,
    required this.payableSalary,
    this.status = 'Pending',
    this.paymentReference,
    this.paidAt,
  });

  factory StaffPayment.fromMap(Map<String, dynamic> map) {
    return StaffPayment(
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      staffEmail: map['staffEmail'] ?? '',
      designation: map['designation'] ?? '',
      totalHoursWorked: (map['totalHoursWorked'] as num? ?? 0.0).toDouble(),
      expectedWorkHours: (map['expectedWorkHours'] as num? ?? 0.0).toDouble(),
      baseSalary: (map['baseSalary'] as num? ?? 0.0).toDouble(),
      payableSalary: (map['payableSalary'] as num? ?? 0.0).toDouble(),
      status: map['status'] ?? 'Pending',
      paymentReference: map['paymentReference'],
      paidAt: map['paidAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'staffEmail': staffEmail,
      'designation': designation,
      'totalHoursWorked': totalHoursWorked,
      'expectedWorkHours': expectedWorkHours,
      'baseSalary': baseSalary,
      'payableSalary': payableSalary,
      'status': status,
      'paymentReference': paymentReference,
      'paidAt': paidAt,
    };
  }
}