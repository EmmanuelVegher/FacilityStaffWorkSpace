// lib/features/payroll/services/payroll_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PayrollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to get number of working days in a month (Mon-Fri)
  int _getWorkingDaysInMonth(int year, int month) {
    int workingDays = 0;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }
    return workingDays;
  }

  Future<String> generatePayrollForPeriod(int year, int month) async {
    try {
      // 1. Fetch all staff
      final staffSnapshot = await _firestore.collection('Staff').get();
      if (staffSnapshot.docs.isEmpty) {
        return "No staff found in the database.";
      }

      // 2. Fetch all designation salaries into a map for quick lookup
      final salariesSnapshot = await _firestore.collection('DesignationSalaries').get();
      final salaryMap = {for (var doc in salariesSnapshot.docs) doc.id: (doc.data()['salary'] as num? ?? 0.0).toDouble()};

      // 3. Define payroll period and expected hours
      final payrollPeriodId = "${year}_${month.toString().padLeft(2, '0')}";
      final workingDays = _getWorkingDaysInMonth(year, month);
      final expectedWorkHours = workingDays * 8.0; // Assuming 8-hour work day

      final WriteBatch batch = _firestore.batch();

      // 4. Loop through each staff member to calculate their salary
      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data();
        final staffId = staffDoc.id;
        final designation = staffData['designation'] as String?;
        final staffName = '${staffData['firstName'] ?? ''} ${staffData['lastName'] ?? ''}'.trim();
        final staffEmail = staffData['emailAddress'] as String? ?? 'no-email@example.com';

        if (designation == null || salaryMap[designation] == null) {
          print("Skipping ${staffName} (ID: $staffId) due to missing designation or salary info.");
          continue;
        }

        final baseSalary = salaryMap[designation]!;

        // 5. Fetch attendance records for the month
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0);
        final attendanceSnapshot = await _firestore
            .collection('Staff')
            .doc(staffId)
            .collection('Record')
            .where('timestamp', isGreaterThanOrEqualTo: startDate)
            .where('timestamp', isLessThanOrEqualTo: endDate)
            .get();

        double totalHoursWorked = 0.0;
        for (final recordDoc in attendanceSnapshot.docs) {
          totalHoursWorked += (recordDoc.data()['noOfHours'] as num? ?? 0.0).toDouble();
        }

        // 6. Calculate payable salary
        double percentageWorked = expectedWorkHours > 0 ? (totalHoursWorked / expectedWorkHours) : 0.0;
        percentageWorked = percentageWorked.clamp(0.0, 1.0); // Ensure percentage is not > 100%
        final payableSalary = baseSalary * percentageWorked;

        // 7. Prepare the payroll document for batch write
        final payrollDocRef = _firestore
            .collection('Payroll')
            .doc(payrollPeriodId)
            .collection('StaffPayments')
            .doc(staffId);

        final paymentData = {
          'staffId': staffId,
          'staffName': staffName,
          'staffEmail': staffEmail,
          'designation': designation,
          'totalHoursWorked': totalHoursWorked,
          'expectedWorkHours': expectedWorkHours,
          'baseSalary': baseSalary,
          'payableSalary': payableSalary,
          'status': 'Pending',
          'paymentReference': null,
          'paidAt': null,
        };

        batch.set(payrollDocRef, paymentData);
      }

      // 8. Commit the batch write
      await batch.commit();

      return "Successfully generated payroll for ${DateFormat('MMMM yyyy').format(DateTime(year, month))}.";
    } catch (e) {
      print("Error generating payroll: $e");
      return "An error occurred: $e";
    }
  }
}