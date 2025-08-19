import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/payroll_models.dart';
import '../services/payslip_service.dart';

class PayslipPreviewPage extends StatelessWidget {
  final StaffPayment payment;
  final PayslipService _payslipService = PayslipService();

  PayslipPreviewPage({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payslip for ${payment.staffName}'),
        backgroundColor: const Color(0xFF722F37),
      ),
      body: PdfPreview(
        build: (format) => _payslipService.generatePayslipPdf(payment),
      ),
    );
  }
}