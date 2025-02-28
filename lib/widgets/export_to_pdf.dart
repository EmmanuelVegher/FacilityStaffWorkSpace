import 'package:pdf/widgets.dart' as pdf;

void exportToPDF() async {
  final pdf.Document document = pdf.Document();

  document.addPage(
    pdf.Page(
      build: (pdf.Context context) {
        return pdf.Column(
          children: [
            pdf.Text("Timesheet"),
            // Add more content from table here
          ],
        );
      },
    ),
  );

  // Save PDF
}
