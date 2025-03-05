class AttendanceModel {
  int? id;
  String? clockIn;
  String? clockOut;
  String? date;
  double? clockInLatitude;
  double? clockInLongitude;
  String? clockInLocation;
  double? clockOutLatitude;
  double? clockOutLongitude;
  String? clockOutLocation;
  bool? isSynced;
  bool? voided;
  bool? isUpdated;
  String? durationWorked;
  double? noOfHours;
  bool? offDay;
  String? month;
  String? comments;

  AttendanceModel({
    this.id,
    this.clockIn,
    this.clockOut,
    this.date,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInLocation,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutLocation,
    this.isSynced,
    this.voided,
    this.isUpdated,
    this.durationWorked,
    this.noOfHours,
    this.offDay,
    this.month,
    this.comments,
  });

  Map<String, dynamic> toMap() {
    return {
      'clockIn': clockIn,
      'clockOut': clockOut,
      'date': date,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockInLocation': clockInLocation,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'clockOutLocation': clockOutLocation,
      'isSynced': isSynced,
      'voided': voided,
      'isUpdated': isUpdated,
      'durationWorked': durationWorked,
      'noOfHours': noOfHours,
      'offDay': offDay,
      'month': month,
      'comments': comments,
    };
  }

  factory AttendanceModel.fromJson(json) {
    return AttendanceModel(
        clockIn: json['clockIn'],
        clockOut: json['clockOut'],
        clockInLocation: json['clockInLocation'],
        clockOutLocation: json['clockOutLocation'],
        date: json['date'],
        isSynced: json['isSynced'],
        clockInLatitude: json['clockInLatitude'],
        clockInLongitude: json['clockInLongitude'],
        clockOutLatitude: json['clockOutLatitude'],
        clockOutLongitude: json['clockOutLongitude'],
        voided: json['voided'],
        isUpdated: json['isUpdated'],
        offDay: json['offDay'],
        noOfHours: json['noOfHours'],
        durationWorked: json['durationWorked'],
        month: json['month'],
        comments:json['comments']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'clockIn': clockIn,
      'clockOut': clockOut,
      'clockInLocation': clockInLocation,
      'clockOutLocation': clockOutLocation,
      'date': date,
      'isSynced': isSynced,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'voided': voided,
      'isUpdated': isUpdated,
      'offDay': offDay,
      'noOfHours': noOfHours,
      'durationWorked': durationWorked,
      'month': month,
      'comments':comments
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      clockIn: map['clockIn'] as String?,
      clockOut: map['clockOut'] as String?,
      date: map['date'] as String?,
      clockInLatitude: map['clockInLatitude'] as double?,
      clockInLongitude: map['clockInLongitude'] as double?,
      clockInLocation: map['clockInLocation'] as String?,
      clockOutLatitude: map['clockOutLatitude'] as double?,
      clockOutLongitude: map['clockOutLongitude'] as double?,
      clockOutLocation: map['clockOutLocation'] as String?,
      isSynced: map['isSynced'] as bool?,
      voided: map['voided'] as bool?,
      isUpdated: map['isUpdated'] as bool?,
      durationWorked: map['durationWorked'] as String?,
      noOfHours: map['noOfHours'] as double?,
      offDay: map['offDay'] as bool?,
      month: map['month'] as String?,
      comments: map['comments'] as String?,
    );
  }
}