import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimesheetTable extends StatefulWidget {
  const TimesheetTable({super.key});

  @override
  _TimesheetTableState createState() => _TimesheetTableState();
}

class _TimesheetTableState extends State<TimesheetTable> {
  final DateTime startDate = DateTime.now().subtract(const Duration(days: 10)); // Start from 20th of previous month
  final DateTime endDate = DateTime.now().add(const Duration(days: 10)); // End on 19th of current month
  List<DateTime> dates = [];

  @override
  void initState() {
    super.initState();
    dates = generateDateRange(startDate, endDate);
  }

  List<DateTime> generateDateRange(DateTime start, DateTime end) {
    List<DateTime> dateRange = [];
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      dateRange.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(),
      columnWidths: const {0: FixedColumnWidth(120)}, // Fix width for the Project column
      children: [
        _buildHeaderRow(),
        _buildDateRow(),
        ..._buildHourRows(),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      children: [
        const TableCell(child: Text('Project', style: TextStyle(fontWeight: FontWeight.bold))),
        ...dates.map((date) => TableCell(
          child: Center(
            child: Text(
              DateFormat.E().format(date), // Display day (Sun, Mon, etc.)
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )),
      ],
    );
  }

  TableRow _buildDateRow() {
    return TableRow(
      children: [
        TableCell(child: Container()), // Empty cell for Project row
        ...dates.map((date) => TableCell(
          child: Center(
            child: Text(
              DateFormat.d().format(date), // Display day number
            ),
          ),
        )),
      ],
    );
  }

  List<TableRow> _buildHourRows() {
    return [
      TableRow(
        children: [
          const TableCell(child: Text('Project from Bio', textAlign: TextAlign.center)),
          ...dates.map((date) => TableCell(
            child: _buildHourCell(date),
          )),
        ],
      ),
    ];
  }

  Widget _buildHourCell(DateTime date) {
    bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    bool isFriday = date.weekday == DateTime.friday;

    return Container(
      color: isWeekend ? Colors.grey[300] : Colors.white,
      child: isWeekend
          ? const Center(child: Text('N/A'))
          : TextField(
        enabled: !isWeekend,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            double hours = double.tryParse(value) ?? 0;
            if (!isFriday && hours > 8.5) hours = 8.5;
            if (isFriday && hours > 6) hours = 6;
          });
        },
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(4),
          hintText: isFriday ? 'Max 6' : 'Max 8.5',
        ),
      ),
    );
  }
}
