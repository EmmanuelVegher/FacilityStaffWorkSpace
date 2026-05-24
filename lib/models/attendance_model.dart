import 'package:cloud_firestore/cloud_firestore.dart' as cf;

// This class holds the nested recommendation data.
class Recommendation {
  double? deductedHours;
  String? notes;
  String? recommenderCategory;
  String? recommenderDesignation;
  String? recommenderId;
  String? recommenderName;
  DateTime? timestamp;

  // Method to convert this object to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'deductedHours': deductedHours,
      'notes': notes,
      'recommenderCategory': recommenderCategory,
      'recommenderDesignation': recommenderDesignation,
      'recommenderId': recommenderId,
      'recommenderName': recommenderName,
      'timestamp': timestamp != null ? cf.Timestamp.fromDate(timestamp!) : null,
    };
  }
}

class AttendanceModel {
  String? clockIn;
  String? clockOut;
  String? clockInLocation;
  String? clockOutLocation;
  String? date;
  bool? isSynced;
  double? clockInLatitude;
  double? clockInLongitude;
  double? clockOutLatitude;
  double? clockOutLongitude;
  bool? voided;
  bool? isUpdated;
  bool? offDay;
  double? noOfHours;
  String? durationWorked;
  String? month;
  String? comments;
  DateTime? timestamp;

  // <<<--- NEW FIELDS START ---<<<
  int? offlineDbId;
  String? deductionStatus;
  String? evidenceImageUrl;
  Recommendation? recommendation;
  // <<<--- VERIFICATION FIELDS START ---<<<
  String? verificationMethod;
  int? verificationCount;
  bool? verificationRequired;
  List<String>? verifiedByUserIds;
  List<String>? verifiedByUserNames;
  // <<<--- VERIFICATION FIELDS END ---<<<
  // <<<--- NEW FIELDS END ---<<<

  // <<<--- MODIFIED: Constructor updated with new fields ---<<<
  AttendanceModel({
    this.clockIn,
    this.clockOut,
    this.clockInLocation,
    this.clockOutLocation,
    this.date,
    this.isSynced,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.voided,
    this.isUpdated,
    this.offDay,
    this.noOfHours,
    this.durationWorked,
    this.month,
    this.comments,
    this.timestamp,
    // Add new fields to constructor
    this.offlineDbId,
    this.deductionStatus,
    this.evidenceImageUrl,
    this.recommendation,
    // Verification fields
    this.verificationMethod,
    this.verificationCount,
    this.verificationRequired,
    this.verifiedByUserIds,
    this.verifiedByUserNames,
  });

  // <<<--- MODIFIED: This is now the definitive factory for all data sources (local JSON, Firestore) ---<<<
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    Recommendation? rec;
    // Safely parse the nested recommendation map from Firestore data
    if (json['recommendation'] != null && json['recommendation'] is Map) {
      final recData = json['recommendation'] as Map<String, dynamic>;
      rec = Recommendation()
        ..deductedHours = (recData['deductedHours'] as num?)?.toDouble()
        ..notes = recData['notes'] as String?
        ..recommenderCategory = recData['recommenderCategory'] as String?
        ..recommenderDesignation = recData['recommenderDesignation'] as String?
        ..recommenderId = recData['recommenderId'] as String?
        ..recommenderName = recData['recommenderName'] as String?
        ..timestamp = (recData['timestamp'] as cf.Timestamp?)?.toDate();
    }

    return AttendanceModel(
      clockIn: json['clockIn'] as String?,
      clockOut: json['clockOut'] as String?,
      clockInLocation: json['clockInLocation'] as String?,
      clockOutLocation: json['clockOutLocation'] as String?,
      date: json['date'] as String?,
      isSynced: json['isSynced'] as bool?,
      clockInLatitude: (json['clockInLatitude'] as num?)?.toDouble(),
      clockInLongitude: (json['clockInLongitude'] as num?)?.toDouble(),
      clockOutLatitude: (json['clockOutLatitude'] as num?)?.toDouble(),
      clockOutLongitude: (json['clockOutLongitude'] as num?)?.toDouble(),
      voided: json['voided'] as bool?,
      isUpdated: json['isUpdated'] as bool?,
      offDay: json['offDay'] as bool?,
      noOfHours: (json['noOfHours'] as num?)?.toDouble(),
      durationWorked: json['durationWorked'] as String?,
      month: json['month'] as String?,
      comments: json['comments'] as String?,
      timestamp: (json['timestamp'] as cf.Timestamp?)?.toDate(),
      // New fields
      offlineDbId: (json['Offline_DB_id'] as num?)?.toInt(),
      deductionStatus: json['deductionStatus'] as String?,
      evidenceImageUrl: json['evidenceImageUrl'] as String?,
      recommendation: rec,
      // Verification fields
      verificationMethod: json['verificationMethod'] as String?,
      verificationCount: (json['verificationCount'] as num?)?.toInt(),
      verificationRequired: json['verificationRequired'] as bool?,
      verifiedByUserIds:
          (json['verifiedByUserIds'] as List<dynamic>?)?.cast<String>(),
      verifiedByUserNames:
          (json['verifiedByUserNames'] as List<dynamic>?)?.cast<String>(),
    );
  }

  // <<<--- MODIFIED: toJson updated to include new fields ---<<<
  Map<String, dynamic> toJson() {
    return {
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
      'comments': comments,
      'timestamp': timestamp != null ? cf.Timestamp.fromDate(timestamp!) : null,
      // New fields
      'Offline_DB_id': offlineDbId,
      'deductionStatus': deductionStatus,
      'evidenceImageUrl': evidenceImageUrl,
      // Use the toJson method from the embedded class
      'recommendation': recommendation?.toJson(),
      // Verification fields
      'verificationMethod': verificationMethod,
      'verificationCount': verificationCount,
      'verificationRequired': verificationRequired,
      'verifiedByUserIds': verifiedByUserIds,
      'verifiedByUserNames': verifiedByUserNames,
    };
  }
}
