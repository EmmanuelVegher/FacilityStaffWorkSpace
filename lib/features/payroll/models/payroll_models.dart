import 'package:cloud_firestore/cloud_firestore.dart';

// ADD THIS CLASS
class DesignationSalary {
  final String designation;
  final double salary;

  DesignationSalary({required this.designation, required this.salary});

  factory DesignationSalary.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DesignationSalary(
      designation: doc.id, // The document ID is the designation name
      salary: (data['salary'] ?? 0.0).toDouble(),
    );
  }
}

// Represents a single manual deduction added by the Program team.
class ManualDeduction {
  final String description;
  final double amount;

  ManualDeduction({required this.description, required this.amount});

  Map<String, dynamic> toMap() {
    return {'description': description, 'amount': amount};
  }

  factory ManualDeduction.fromMap(Map<String, dynamic> map) {
    return ManualDeduction(
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
    );
  }
}

// The main model for a staff member's payment for a specific period.
class StaffPayment {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String designation;

  // Core Salary Components
  final double baseSalary; // This is the "Amount" from your Excel sheet
  final double housingAllowance; // 30% of Base
  final double transportAllowance; // 10% of Base
  final double mealAllowance; // 15% of Base
  final double utilityAllowance; // 15% of Base

  // Calculated Gross Pay
  final double grossPay;

  // Deductions
  final double paye; // To be filled by Grants team
  final double employeePension; // Example: 8%
  List<ManualDeduction> manualDeductions; // Added by Program team

  // Calculated Totals
  final double totalDeductions;
  final double netPay;

  // Workflow & Payment Status
  final String workflowStatus; // e.g., 'PendingProgramReview', 'PendingGrantReview', 'PendingAudit', 'ReadyForPayment', 'Paid'
  final String? paymentReference;
  final Timestamp? paidAt;
  final String? rejectionReason; // If rejected by Audit

  StaffPayment({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    required this.designation,
    required this.baseSalary,
    required this.housingAllowance,
    required this.transportAllowance,
    required this.mealAllowance,
    required this.utilityAllowance,
    required this.grossPay,
    this.paye = 0.0,
    this.employeePension = 0.0,
    required this.manualDeductions,
    required this.totalDeductions,
    required this.netPay,
    required this.workflowStatus,
    this.paymentReference,
    this.paidAt,
    this.rejectionReason,
  });

  factory StaffPayment.fromMap(Map<String, dynamic> map) {
    // Calculate derived values for backward compatibility if they don't exist
    final base = (map['baseSalary'] ?? 0.0).toDouble();
    final manualDeductionsList = (map['manualDeductions'] as List<dynamic>? ?? [])
        .map((d) => ManualDeduction.fromMap(d as Map<String, dynamic>))
        .toList();

    final paye = (map['paye'] ?? 0.0).toDouble();
    final pension = (map['employeePension'] ?? 0.0).toDouble();
    final manualDeductionsTotal = manualDeductionsList.fold<double>(0.0, (sum, item) => sum + item.amount);

    final totalDeductions = paye + pension + manualDeductionsTotal;
    final grossPay = (map['grossPay'] ?? 0.0).toDouble();

    return StaffPayment(
      staffId: map['staffId'],
      staffName: map['staffName'],
      staffEmail: map['staffEmail'],
      designation: map['designation'],
      baseSalary: base,
      housingAllowance: (map['housingAllowance'] ?? base * 0.3).toDouble(),
      transportAllowance: (map['transportAllowance'] ?? base * 0.1).toDouble(),
      mealAllowance: (map['mealAllowance'] ?? base * 0.15).toDouble(),
      utilityAllowance: (map['utilityAllowance'] ?? base * 0.15).toDouble(),
      grossPay: grossPay,
      paye: paye,
      employeePension: pension,
      manualDeductions: manualDeductionsList,
      totalDeductions: (map['totalDeductions'] ?? totalDeductions).toDouble(),
      netPay: (map['netPay'] ?? grossPay - totalDeductions).toDouble(),
      workflowStatus: map['workflowStatus'] ?? 'PendingProgramReview',
      paymentReference: map['paymentReference'],
      paidAt: map['paidAt'],
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'staffEmail': staffEmail,
      'designation': designation,
      'baseSalary': baseSalary,
      'housingAllowance': housingAllowance,
      'transportAllowance': transportAllowance,
      'mealAllowance': mealAllowance,
      'utilityAllowance': utilityAllowance,
      'grossPay': grossPay,
      'paye': paye,
      'employeePension': employeePension,
      'manualDeductions': manualDeductions.map((d) => d.toMap()).toList(),
      'totalDeductions': totalDeductions,
      'netPay': netPay,
      'workflowStatus': workflowStatus,
      'paymentReference': paymentReference,
      'paidAt': paidAt,
      'rejectionReason': rejectionReason,
    };
  }
}