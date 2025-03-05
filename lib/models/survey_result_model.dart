class SurveyResultModel {
  int? id;
  DateTime? date;
  String? state;
  String? facilityName;
  String? staffJson;
  bool? isSynced;
  String? name;
  String? emailAddress;
  String? phoneNumber;
  String? staffCategory;
  String? uuid;


  SurveyResultModel({
    this.id,
    this.date,
    this.state,
    this.facilityName,
    this.staffJson,
    this.isSynced,
    this.name,
    this.emailAddress,
    this.phoneNumber,
    this.staffCategory,
    this.uuid,
  });


  factory SurveyResultModel.fromJson(Map<String, dynamic> json) {
    return SurveyResultModel(
      id: json['id'] as int?,
      date: json['date'] == null ? null : DateTime.tryParse(json['date'] as String),
      state: json['state'] as String?,
      facilityName: json['facilityName'] as String?,
      staffJson: json['staffJson'] as String?,
      isSynced: json['isSynced'] as bool?,
      name: json['name'] as String?,
      emailAddress: json['emailAddress'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      staffCategory: json['staffCategory'] as String?,
      uuid: json['uuid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date?.toIso8601String().split('T')[0], // Format date to yyyy-MM-dd for consistency
      'state': state,
      'facilityName': facilityName,
      'staffJson': staffJson,
      'isSynced': isSynced,
      'name': name,
      'emailAddress': emailAddress,
      'phoneNumber': phoneNumber,
      'staffCategory': staffCategory,
      'uuid': uuid,
    };
  }
}