// recommendation_info.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendationInfo {
  final String notes;
  final String recommenderId;
  final String recommenderName;
  final String recommenderDesignation;
  final String recommenderCategory;
  final DateTime timestamp;
  final int deductedHours; // <-- ADD THIS NEW FIELD

  RecommendationInfo({
    required this.notes,
    required this.recommenderId,
    required this.recommenderName,
    required this.recommenderDesignation,
    required this.recommenderCategory,
    required this.timestamp,
    required this.deductedHours, // <-- ADD TO CONSTRUCTOR
  });

  factory RecommendationInfo.fromMap(Map<String, dynamic> map) {
    return RecommendationInfo(
      notes: map['notes'] ?? '',
      recommenderId: map['recommenderId'] ?? '',
      recommenderName: map['recommenderName'] ?? '',
      recommenderDesignation: map['recommenderDesignation'] ?? '',
      recommenderCategory: map['recommenderCategory'] ?? '',
      timestamp: (map['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
      // Provide a default value for older records that won't have this field
      deductedHours: map['deductedHours'] as int? ?? 0, // <-- ADD THIS LINE
    );
  }
}