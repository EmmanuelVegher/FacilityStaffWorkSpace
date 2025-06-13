// in vl_eligible_model.dart

class VlEligibleModel {
  final String id; // This will be the quarter name, e.g., "Q3 (FY25)"

  // Summary Metrics
  final int totalEligibleClientsInFilter;
  final double percentageSamplesCollected;
  final double percentageResultsReceived;
  final int refillsDueInQuarter;
  final int refillsDueOutsideQuarter;
  final int samplesCollected;
  final int resultsReturned;
  final int suppressed;
  final int unsuppressed;
  final int tatPendingOver90Days;
  final int tatResultOver90Days;
  final int totalNotActive;
  final int totalDeaths;
  final int totalTransferredOut;
  final int totalMissedAppointments;
  final int totalIIT;
  final int totalDiscontinuedCare;
  late final String? facilityName;
  late final String? state;
  late final String? updatedByFullName;


  // Previous Samples Metrics (collected before previous quarter)
  final String? previousQuarter;
  final String? previousQuarterDisplay;
  final int samplesCollectedPreviousQuarter ;
  final int resultsReturnedPreviousQuarter ;
  final int suppressedPreviousQuarter;
  final int unsuppressedPreviousQuarter;
  final int tatExceeded3MonthsPreviousQuarter;
  final int tatOver3MonthsWithResultPreviousQuarter;

  // Older Samples Metrics (collected before previous quarter)
  final String? olderSamplesDisplayTitle;
  final int samplesCollectedOlder;
  final int resultsReturnedOlder;
  final int suppressedOlder;
  final int unsuppressedOlder; // This field was the problem
  final int tatExceeded3MonthsOlder;
  final int tatOver3MonthsWithResultOlder;

  VlEligibleModel({
    required this.id,
    this.state,
    this.facilityName,
    this.updatedByFullName,
    this.totalEligibleClientsInFilter = 0,
    this.percentageSamplesCollected = 0.0,
    this.percentageResultsReceived = 0.0,
    this.refillsDueInQuarter = 0,
    this.refillsDueOutsideQuarter = 0,
    this.samplesCollected = 0,
    this.resultsReturned = 0,
    this.suppressed = 0,
    this.unsuppressed = 0,
    this.tatPendingOver90Days = 0,
    this.tatResultOver90Days = 0,
    this.totalNotActive = 0,
    this.totalDeaths = 0,
    this.totalTransferredOut = 0,
    this.totalMissedAppointments = 0,
    this.totalIIT = 0,
    this.totalDiscontinuedCare = 0,

    this.previousQuarter,
    this.previousQuarterDisplay,
    this.samplesCollectedPreviousQuarter = 0,
    this.resultsReturnedPreviousQuarter = 0,
    this.suppressedPreviousQuarter = 0,
    this.unsuppressedPreviousQuarter = 0,
    this.tatExceeded3MonthsPreviousQuarter = 0,
    this.tatOver3MonthsWithResultPreviousQuarter = 0,

    // Older Samples Metrics (collected before previous quarter)
    this.olderSamplesDisplayTitle,
    this.samplesCollectedOlder = 0,
    this.resultsReturnedOlder = 0,
    this.suppressedOlder = 0,
    this.unsuppressedOlder = 0,
    this.tatExceeded3MonthsOlder = 0,
    this.tatOver3MonthsWithResultOlder = 0,
  });

  // --- THIS IS THE CORRECTED FACTORY ---
  factory VlEligibleModel.fromMap(String id, Map<String, dynamic> data) {
    return VlEligibleModel(
      id: id,
      state:data['trackerState'] as String?,
      updatedByFullName:data['updatedByFullName'] as String?,
      facilityName:data['trackerFacilityLocation'] as String?,
      totalEligibleClientsInFilter: data['totalEligibleClientsInFilter'] as int? ?? 0,
      percentageSamplesCollected: (data['percentageSamplesCollected'] as num?)?.toDouble() ?? 0.0,
      percentageResultsReceived: (data['percentageResultsReceived'] as num?)?.toDouble() ?? 0.0,
      refillsDueInQuarter: data['refillsDueInQuarter'] as int? ?? 0,
      refillsDueOutsideQuarter: data['refillsDueOutsideQuarter'] as int? ?? 0,
      samplesCollected: data['samplesCollected'] as int? ?? 0,
      resultsReturned: data['resultsReturned'] as int? ?? 0,
      suppressed: data['suppressed'] as int? ?? 0,
      unsuppressed: data['unsuppressed'] as int? ?? 0,
      tatPendingOver90Days: data['tatPendingOver90Days'] as int? ?? 0,
      tatResultOver90Days: data['tatResultOver90Days'] as int? ?? 0,
      totalNotActive: data['totalNotActive'] as int? ?? 0,
      totalDeaths: data['totalDeaths'] as int? ?? 0,
      totalTransferredOut: data['totalTransferredOut'] as int? ?? 0,
      totalMissedAppointments: data['totalMissedAppointments'] as int? ?? 0,
      totalIIT: data['totalIIT'] as int? ?? 0,
      totalDiscontinuedCare: data['totalDiscontinuedCare'] as int? ?? 0,

      // Previous Quarter Metrics
      previousQuarter: data['previousQuarter'] as String?, // Can be null
      previousQuarterDisplay: data['previousQuarterDisplay'] as String?, // Can be null
      samplesCollectedPreviousQuarter: data['samplesCollectedPreviousQuarter'] as int? ?? 0,
      resultsReturnedPreviousQuarter: data['resultsReturnedPreviousQuarter'] as int? ?? 0,
      suppressedPreviousQuarter: data['suppressedPreviousQuarter'] as int? ?? 0,
      unsuppressedPreviousQuarter: data['unsuppressedPreviousQuarter'] as int? ?? 0,
      tatExceeded3MonthsPreviousQuarter: data['tatExceeded3MonthsPreviousQuarter'] as int? ?? 0,
      tatOver3MonthsWithResultPreviousQuarter: data['tatOver3MonthsWithResultPreviousQuarter'] as int? ?? 0,

      // Older Samples Metrics
      olderSamplesDisplayTitle: data['olderSamplesDisplayTitle'] as String?, // Can be null
      samplesCollectedOlder: data['samplesCollectedOlder'] as int? ?? 0,
      resultsReturnedOlder: data['resultsReturnedOlder'] as int? ?? 0,
      suppressedOlder: data['suppressedOlder'] as int? ?? 0,
      // --- FIX: THIS LINE WAS MISSING ---
      unsuppressedOlder: data['unsuppressedOlder'] as int? ?? 0,
      // --- END FIX ---
      tatExceeded3MonthsOlder: data['tatExceeded3MonthsOlder'] as int? ?? 0,
      tatOver3MonthsWithResultOlder: data['tatOver3MonthsWithResultOlder'] as int? ?? 0,
    );
  }

  // toMap is useful for syncing, though not directly used in the report tab logic
  Map<String, dynamic> toMap() {
    // This method should also be complete to avoid issues when writing data
    return {
      'state':state,
      'facilityName':facilityName,
      'updatedByFullName':updatedByFullName,
      'totalEligibleClientsInFilter': totalEligibleClientsInFilter,
      'percentageSamplesCollected': percentageSamplesCollected,
      'percentageResultsReceived': percentageResultsReceived,
      'refillsDueInQuarter': refillsDueInQuarter,
      'refillsDueOutsideQuarter': refillsDueOutsideQuarter,
      'samplesCollected': samplesCollected,
      'resultsReturned': resultsReturned,
      'suppressed': suppressed,
      'unsuppressed': unsuppressed,
      'tatPendingOver90Days': tatPendingOver90Days,
      'tatResultOver90Days': tatResultOver90Days,
      'totalNotActive': totalNotActive,
      'totalDeaths': totalDeaths,
      'totalTransferredOut': totalTransferredOut,
      'totalMissedAppointments': totalMissedAppointments,
      'totalIIT': totalIIT,
      'totalDiscontinuedCare': totalDiscontinuedCare,

      'previousQuarter': previousQuarter,
      'previousQuarterDisplay': previousQuarterDisplay,
      'samplesCollectedPreviousQuarter': samplesCollectedPreviousQuarter,
      'resultsReturnedPreviousQuarter': resultsReturnedPreviousQuarter,
      'suppressedPreviousQuarter': suppressedPreviousQuarter,
      'unsuppressedPreviousQuarter': unsuppressedPreviousQuarter,
      'tatExceeded3MonthsPreviousQuarter': tatExceeded3MonthsPreviousQuarter,
      'tatOver3MonthsWithResultPreviousQuarter': tatOver3MonthsWithResultPreviousQuarter,

      'olderSamplesDisplayTitle': olderSamplesDisplayTitle,
      'samplesCollectedOlder': samplesCollectedOlder,
      'resultsReturnedOlder': resultsReturnedOlder,
      'suppressedOlder': suppressedOlder,
      'unsuppressedOlder': unsuppressedOlder,
      'tatExceeded3MonthsOlder': tatExceeded3MonthsOlder,
      'tatOver3MonthsWithResultOlder': tatOver3MonthsWithResultOlder,
    };
  }
}