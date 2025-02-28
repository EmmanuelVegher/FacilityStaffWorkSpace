import 'package:excel/excel.dart';

void exportToExcel() {
  var excel = Excel.createExcel();
  var sheet = excel['Timesheet'];
  // Add data rows to sheet based on your table data

  excel.save(fileName: "Timesheet.xlsx");
}
