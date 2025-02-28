class AttendanceData {
  final int day;
  final int onTimeCount;
  final int lateCount;

  AttendanceData({
    required this.day,
    required this.onTimeCount,
    required this.lateCount,
  });

  // Convert AttendanceData instance to a Map
  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'onTimeCount': onTimeCount,
      'lateCount': lateCount,
    };
  }
}
