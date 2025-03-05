// model/staff_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffModel {
  String? id;
  String? firstName;
  String? lastName;
  String? staffCategory;
  String? designation;
  String? state;
  String? emailAddress;
  String? location;
  String? department;
  String? mobile;
  String? project;
  String? role;
  String? supervisor;
  String? supervisorEmail;
  String? photoUrl;
  String? signatureLink;
  bool? isSynced;
  DateTime? lastUpdateDate;
  String? version;
  bool? isRemoteDelete;
  bool? isRemoteUpdate;

  StaffModel({
    this.id,
    this.firstName,
    this.lastName,
    this.staffCategory,
    this.designation,
    this.state,
    this.emailAddress,
    this.location,
    this.department,
    this.mobile,
    this.project,
    this.role,
    this.supervisor,
    this.supervisorEmail,
    this.photoUrl,
    this.signatureLink,
    this.isSynced,
    this.lastUpdateDate,
    this.version,
    this.isRemoteDelete,
    this.isRemoteUpdate,
  });

  factory StaffModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return StaffModel(
      id: snapshot.id,
      firstName: data?['firstName'],
      lastName: data?['lastName'],
      staffCategory: data?['staffCategory'],
      designation: data?['designation'],
      state: data?['state'],
      emailAddress: data?['emailAddress'],
      location: data?['location'],
      department: data?['department'],
      mobile: data?['mobile'],
      project: data?['project'],
      role: data?['role'],
      supervisor: data?['supervisor'],
      supervisorEmail: data?['supervisorEmail'],
      photoUrl: data?['photoUrl'],
      signatureLink: data?['signatureLink'],
      isSynced: data?['isSynced'],
      lastUpdateDate: data?['lastUpdateDate'] != null ? (data?['lastUpdateDate'] as Timestamp).toDate() : null,
      version: data?['version'],
      isRemoteDelete: data?['isRemoteDelete'],
      isRemoteUpdate: data?['isRemoteUpdate'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'staffCategory': staffCategory,
      'designation': designation,
      'state': state,
      'emailAddress': emailAddress,
      'location': location,
      'department': department,
      'mobile': mobile,
      'project': project,
      'role': role,
      'supervisor': supervisor,
      'supervisorEmail': supervisorEmail,
      'photoUrl': photoUrl,
      'signatureLink': signatureLink,
      'isSynced': isSynced,
      'lastUpdateDate': lastUpdateDate,
      'version': version,
      'isRemoteDelete': isRemoteDelete,
      'isRemoteUpdate': isRemoteUpdate,
    };
  }
}