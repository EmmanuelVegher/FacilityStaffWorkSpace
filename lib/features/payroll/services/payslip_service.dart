import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/payroll_models.dart';

class PayslipService {
  Future<Uint8List> generatePayslipPdf(StaffPayment payment) async {
    final pdf = pw.Document();
    final numberFormat = NumberFormat("#,##0.00", "en_US");
    final monthYear = DateFormat('MMMM - yyyy').format(DateTime.now()); // In real app, pass the period date

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(monthYear),
              pw.SizedBox(height: 20),

              // Staff Details
              _buildSectionTitle('Staff Details'),
              _buildStaffDetailsTable(payment),
              pw.SizedBox(height: 20),

              // Salary Components & Deductions in a two-column layout
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildSalaryComponents(payment, numberFormat),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildDeductions(payment, numberFormat),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary
              _buildSummary(payment, numberFormat),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String monthYear) {
    // In a real app, you would load your logo from assets
    // final image = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List());
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.grey))
      ),
      padding: pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Caritas Nigeria', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.Text('Staff PaySlip - $monthYear', style: pw.TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      color: PdfColors.grey200,
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildStaffDetailsTable(StaffPayment payment) {
    return pw.Table(
      columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)},
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        _buildTableRow('Staff Name:', payment.staffName),
        _buildTableRow('Staff ID:', payment.staffId),
        _buildTableRow('Staff Email:', payment.staffEmail),
        _buildTableRow('Designation:', payment.designation),
      ],
    );
  }

  pw.Widget _buildSalaryComponents(StaffPayment p, NumberFormat f) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Salary Components'),
          pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildTableRow('Basic Salary - 30%:', 'N ${f.format(p.baseSalary)}'),
                _buildTableRow('Housing - 30%:', 'N ${f.format(p.housingAllowance)}'),
                _buildTableRow('Transport - 10%:', 'N ${f.format(p.transportAllowance)}'),
                _buildTableRow('Meal - 15%:', 'N ${f.format(p.mealAllowance)}'),
                _buildTableRow('Utilities - 15%:', 'N ${f.format(p.utilityAllowance)}'),
                _buildTotalRow('GROSS PAY:', 'N ${f.format(p.grossPay)}'),
              ]
          )
        ]
    );
  }

  pw.Widget _buildDeductions(StaffPayment p, NumberFormat f) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Deductions'),
          pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildTableRow('Personal Income Tax (PAYE):', 'N ${f.format(p.paye)}'),
                _buildTableRow('Employee Pension - 8%:', 'N ${f.format(p.employeePension)}'),
                // Add other standard deductions here...
                ...p.manualDeductions.map((d) => _buildTableRow('${d.description}:', 'N ${f.format(d.amount)}')),
                _buildTotalRow('TOTAL DEDUCTIONS:', 'N ${f.format(p.totalDeductions)}'),
              ]
          )
        ]
    );
  }

  pw.Widget _buildSummary(StaffPayment p, NumberFormat f) {
    return pw.Container(
        color: PdfColors.brown,
        padding: pw.EdgeInsets.all(10),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET PAY:', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('N ${f.format(p.netPay)}', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]
        )
    );
  }


  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(label)),
      pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(value, textAlign: pw.TextAlign.right)),
    ]);
  }
  pw.TableRow _buildTotalRow(String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Padding(padding: pw.EdgeInsets.all(5), child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
    ]);
  }
}