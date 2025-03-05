class BioModel {
  String? firstName;
  String? lastName;
  String? firebaseAuthId;
  String? emailAddress;
  String? mobile;
  String? staffCategory;
  String? location;
  String? state;
  String? maritalStatus;
  String? gender;
  String? designation;
  String? password;
  String? role;
  String? department;
  String? project;
  bool? isSynced ;
  String? supervisor;
  String? supervisorEmail;
  String? version;
  bool? isRemoteDelete;
  bool? isRemoteUpdate;
  DateTime? lastUpdateDate;
  String? signatureLink;

  BioModel({
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.designation,
    this.password,
    this.state,
    this.emailAddress,
    this.role,
    this.location,
    this.firebaseAuthId,
    this.department,
    this.mobile,
    this.project,
    this.isSynced,
    this.supervisor,
    this.supervisorEmail,
    this.version,
    this.isRemoteDelete,
    this.isRemoteUpdate,
    this.lastUpdateDate,
    this.signatureLink
    // ... other fields
  });

  factory BioModel.fromJson(Map<String, dynamic> json) {
    return BioModel(
      firstName: json['firstName'],
      lastName: json['lastName'],
      firebaseAuthId: json['firebaseAuthId'],
      emailAddress: json['emailAddress'],
      mobile: json['mobile'],
      staffCategory: json['staffCategory'],
      location: json['location'],
      state: json['state'],
        designation: json['designation'],
        password: json['password'],
        role: json['role'],
        department: json['department'],
        project: json['project'],
        isSynced:json['isSynced'],
        supervisor:json['supervisor'],
        supervisorEmail:json['supervisorEmail'],
        version:json['version'],
        isRemoteDelete:json['isRemoteDelete'],
        isRemoteUpdate:json['isRemoteUpdate'],
        lastUpdateDate:json['lastUpdateDate'],
        signatureLink:json['signatureLink']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'staffCategory': staffCategory,
      'designation': designation,
      'password': password,
      'state': state,
      'emailAddress': emailAddress,
      'role': role,
      'location': location,
      'firebaseAuthId': firebaseAuthId,
      'department': department,
      'mobile': mobile,
      'project': project,
      'isSynced':isSynced,
      'supervisor':supervisor,
      'supervisorEmail':supervisorEmail,
      'version':version,
      'isRemoteDelete':isRemoteDelete,
      'isRemoteUpdate':isRemoteUpdate,
      'lastUpdateDate':lastUpdateDate,
    };
  }

  map(Map<String, dynamic> Function(dynamic e) param0) {}
}
