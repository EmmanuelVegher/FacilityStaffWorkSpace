class FacilityStaffModel {
  String? id;
  String? name;
  String? designation;
  String? state;
  String? facilityName;
  String? userId;
  String? emailAddress;
  // ... other fields

  FacilityStaffModel({
    this.id,
    this.name,
    this.designation,
    this.state,
    this.facilityName,
    this.userId,
    this.emailAddress,
    // ... other fields
  });

  factory FacilityStaffModel.fromJson(Map<String, dynamic> json) {
    return FacilityStaffModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      designation: json['designation'] as String?,
      state: json['state'] as String?,
      facilityName: json['facilityName'] as String?,
      userId: json['userId'] as String?,
      emailAddress: json['emailAddress'] as String?,
      // ... other fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'designation': designation,
      'state': state,
      'facilityName': facilityName,
      'userId': userId,
      'emailAddress': emailAddress,
      // ... other fields
    };
  }
}