// lib/features/payroll/services/payroll_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payroll_models.dart';

class PayrollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates the payroll schedule for a given month and year.
  ///
  /// This function now efficiently fetches all designation salaries first, then
  /// processes each active staff member, looking up their salary from the pre-fetched map.
  Future<String> generatePayrollForPeriod(int year, int month) async {
    final payrollPeriodId = "${year}_${month.toString().padLeft(2, '0')}";
    final payrollBatch = _firestore.batch();
    int staffProcessed = 0;
    List<String> staffSkipped = [];

    try {
      // Step 1: Fetch all designation salaries and store them in a Map for efficient lookup.
      final salarySnapshot = await _firestore.collection('DesignationSalaries').get();
      if (salarySnapshot.docs.isEmpty) {
        return "Error: No salaries found in the 'DesignationSalaries' collection. Please configure salaries first.";
      }
      final Map<String, double> salaryMap = {
        for (var doc in salarySnapshot.docs)
          doc.id: (doc.data()['salary'] ?? 0.0).toDouble(),
      };

      // Step 2: Fetch all active staff members.
      final staffSnapshot = await _firestore.collection('Staff').where('isActive', isEqualTo: true).get();
      if (staffSnapshot.docs.isEmpty) {
        return "No active staff found to generate payroll.";
      }

      // Step 3: Iterate through each staff member and create their payment record.
      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data();
        final staffId = staffDoc.id;
        final designation = staffData['designation'] as String?;
        final staffName = staffData['name'] ?? 'Unknown Staff';

        // CRITICAL: Check if the staff has a valid designation with a configured salary.
        if (designation == null || !salaryMap.containsKey(designation)) {
          // If not, skip this staff member and record their name for the final report.
          staffSkipped.add('$staffName (Designation: ${designation ?? 'Not Set'})');
          continue; // Move to the next staff member
        }

        // The salary from the map corresponds to the "Amount/Gross Pay" in your salary scale.
        final grossPay = salaryMap[designation]!;

        // Calculate components based on the salary scale logic from your image.
        // "Basic" and "Housing" are both 30% of the gross pay.
        final basicSalaryComponent = grossPay * 0.30;
        final housingAllowance = grossPay * 0.30;
        final transportAllowance = grossPay * 0.10;
        final mealAllowance = grossPay * 0.15;
        final utilityAllowance = grossPay * 0.15;

        // Create the StaffPayment object with the calculated values.
        final staffPayment = StaffPayment(
          staffId: staffId,
          staffName: staffName,
          staffEmail: staffData['email'] ?? 'no-email@example.com',
          designation: designation,
          baseSalary: basicSalaryComponent, // This is the 30% "Basic" component
          housingAllowance: housingAllowance,
          transportAllowance: transportAllowance,
          mealAllowance: mealAllowance,
          utilityAllowance: utilityAllowance,
          grossPay: grossPay, // This is the total gross pay amount
          manualDeductions: [],
          paye: 0.0,
          employeePension: 0.0,
          totalDeductions: 0.0, // Deductions are initially zero
          netPay: grossPay,     // Net pay is initially the same as gross
          workflowStatus: 'PendingProgramReview', // Start of the workflow
          rejectionReason: null,
          paidAt: null,
          paymentReference: null,
        );

        final docRef = _firestore.collection('Payroll').doc(payrollPeriodId).collection('StaffPayments').doc(staffId);
        payrollBatch.set(docRef, staffPayment.toMap());
        staffProcessed++;
      }

      // Set an overall status for the payroll period document itself.
      final periodDocRef = _firestore.collection('Payroll').doc(payrollPeriodId);
      payrollBatch.set(periodDocRef, {'status': 'PendingProgramReview', 'lastUpdated': Timestamp.now()}, SetOptions(merge: true));

      // Commit all the batched writes to Firestore.
      await payrollBatch.commit();

      // Prepare a final report message.
      String report = "Payroll generated for $staffProcessed staff. Ready for Program Review.";
      if (staffSkipped.isNotEmpty) {
        report += "\n\nSkipped ${staffSkipped.length} staff due to missing or unconfigured designations:\n- ${staffSkipped.join('\n- ')}";
      }

      return report;

    } catch (e) {
      // Return a comprehensive error message if anything goes wrong.
      return "An error occurred during payroll generation: $e";
    }
  }
}