// lib/constants/vl_form_constants.dart

// --- General Form Concepts ---
const int CONCEPT_VISIT_DATE_ENCOUNTER = 0; // Placeholder - encounterDate is a special tag
const int CONCEPT_LAB_REG_NUMBER = 165394;
const int CONCEPT_INDICATION_FOR_AHD = 167079; // Answers: 162080 (Baseline), 162081 (Repeat)

// --- CD4 Section ---
const int CONCEPT_ORDER_CD4_CELL_COUNT = 165731; // Checkbox
const int CONCEPT_RESULT_CD4_CELL_COUNT = 5497;  // Numeric result
const int CONCEPT_ORDER_CD4_PERCENTAGE = 165748; // Checkbox
const int CONCEPT_RESULT_CD4_PERCENTAGE = 730;   // Numeric result
const int CONCEPT_ORDER_CD4_LFA = 167085;        // Checkbox
const int CONCEPT_RESULT_CD4_LFA = 167088;       // Answers: 167086 (<200), 167087 (>=200)
const int CONCEPT_TIME_CD4_LFA_SAMPLE_COLLECTED = 167091; // Time
const int CONCEPT_TIME_CD4_LFA_RESULT_RECEIVED = 167092;  // Time

// --- Hematology Section ---
const int CONCEPT_ORDER_WBC = 165732;             // Checkbox
const int CONCEPT_RESULT_WBC = 678;              // Numeric
const int CONCEPT_ORDER_POLYMORPHS_ABS = 165749; // Checkbox
const int CONCEPT_RESULT_POLYMORPHS_ABS = 1022;  // Numeric
const int CONCEPT_ORDER_POLYMORPHS_PERC = 165918; // Checkbox
const int CONCEPT_RESULT_POLYMORPHS_PERC = 165919;// Numeric
const int CONCEPT_ORDER_LYMPHOCYTES_ABS = 165733; // Checkbox
const int CONCEPT_RESULT_LYMPHOCYTES_ABS = 1319; // Numeric
const int CONCEPT_ORDER_LYMPHOCYTES_PERC = 165750; // Checkbox
const int CONCEPT_RESULT_LYMPHOCYTES_PERC = 1338;// Numeric
const int CONCEPT_ORDER_MONOCYTES_ABS = 165734;   // Checkbox
const int CONCEPT_RESULT_MONOCYTES_ABS = 1023;   // Numeric
const int CONCEPT_ORDER_MONOCYTES_PERC = 165751;  // Checkbox
const int CONCEPT_RESULT_MONOCYTES_PERC = 1339;  // Numeric
const int CONCEPT_ORDER_EOSINOPHILS_ABS = 165735; // Checkbox
const int CONCEPT_RESULT_EOSINOPHILS_ABS = 1024; // Numeric
const int CONCEPT_ORDER_EOSINOPHILS_PERC = 165752; // Checkbox
const int CONCEPT_RESULT_EOSINOPHILS_PERC = 1340;// Numeric
const int CONCEPT_ORDER_BASOPHILS_ABS = 165736;   // Checkbox
const int CONCEPT_RESULT_BASOPHILS_ABS = 1025;   // Numeric
const int CONCEPT_ORDER_BASOPHILS_PERC = 165753;  // Checkbox
const int CONCEPT_RESULT_BASOPHILS_PERC = 1341;  // Numeric
const int CONCEPT_ORDER_PCV_HB_PERCENT = 165737; // Checkbox
const int CONCEPT_RESULT_PCV_HB_PERCENT = 165395;// Numeric
const int CONCEPT_ORDER_PCV_HB_GDL = 165921;     // Checkbox
const int CONCEPT_RESULT_PCV_HB_GDL = 165920;    // Numeric
const int CONCEPT_ORDER_PLATELETS = 165754;       // Checkbox
const int CONCEPT_RESULT_PLATELETS = 729;        // Numeric

// --- Serology/Other Chemistry ---
const int CONCEPT_ORDER_HCV_ANTIBODY = 165738;  // Checkbox
const int CONCEPT_RESULT_HCV_ANTIBODY = 1325;   // Answers: 703 (Positive), 664 (Negative)
const int CONCEPT_ORDER_HBSAG = 165755;         // Checkbox
const int CONCEPT_RESULT_HBSAG = 159430;        // Answers: 703 (Positive), 664 (Negative)
const int CONCEPT_ORDER_VDRL = 165739;          // Checkbox
const int CONCEPT_RESULT_VDRL = 299;            // Answers: 1228 (Reactive), 1229 (Non-Reactive)
const int CONCEPT_ORDER_CREATININE_MMOL = 165756;// Checkbox
const int CONCEPT_RESULT_CREATININE_MMOL = 164364; // Numeric
const int CONCEPT_ORDER_ALT_SGPT_UI = 165740;   // Checkbox
const int CONCEPT_RESULT_ALT_SGPT_UI = 654;     // Numeric
const int CONCEPT_ORDER_ALT_SGPT_MMOL = 165922; // Checkbox
const int CONCEPT_RESULT_ALT_SGPT_MMOL = 165923;// Numeric
const int CONCEPT_ORDER_AST_SGOT_UL = 165757;   // Checkbox
const int CONCEPT_RESULT_AST_SGOT_UL = 653;     // Numeric
const int CONCEPT_ORDER_ALK_PHOSPHATE = 165741; // Checkbox
const int CONCEPT_RESULT_ALK_PHOSPHATE = 785;   // Numeric
const int CONCEPT_ORDER_TOTAL_BILIRUBIN = 165758; // Checkbox
const int CONCEPT_RESULT_TOTAL_BILIRUBIN = 655; // Numeric
const int CONCEPT_ORDER_NA = 165742;            // Checkbox
const int CONCEPT_RESULT_NA = 1132;             // Numeric
const int CONCEPT_ORDER_K = 165759;             // Checkbox
const int CONCEPT_RESULT_K = 1133;              // Numeric

// --- Glucose/Lipids ---
const int CONCEPT_ORDER_FASTING_GLUCOSE = 165743; // Checkbox
const int CONCEPT_RESULT_FASTING_GLUCOSE = 160053;// Numeric (also used for general Glucose)
const int CONCEPT_ORDER_TOTAL_CHOLESTEROL = 165760; // Checkbox
const int CONCEPT_RESULT_TOTAL_CHOLESTEROL = 1006;// Numeric
const int CONCEPT_ORDER_LDL = 165744;           // Checkbox
const int CONCEPT_RESULT_LDL = 1008;            // Numeric
const int CONCEPT_ORDER_HDL = 165761;           // Checkbox
const int CONCEPT_RESULT_HDL = 1007;            // Numeric
const int CONCEPT_ORDER_TRIGLYCERIDE = 165763;  // Checkbox
const int CONCEPT_RESULT_TRIGLYCERIDE = 1009;   // Numeric

// --- Urinalysis/Other ---
const int CONCEPT_ORDER_GLUCOSE_URINE = 165745; // Checkbox (Listed under Urinalysis section in some forms)
const int CONCEPT_RESULT_GLUCOSE_URINE = 160053;// Numeric (Same as blood glucose concept)
const int CONCEPT_ORDER_PROTEIN_URINE = 165762; // Checkbox
const int CONCEPT_RESULT_PROTEIN_URINE = 165926;// Text
const int CONCEPT_ORDER_CYTOLOGY_PAP = 165746;  // Checkbox
const int CONCEPT_RESULT_CYTOLOGY_PAP = 165927; // Text
const int CONCEPT_ORDER_PREGNANCY = 165747;     // Checkbox
const int CONCEPT_RESULT_PREGNANCY = 45;        // Answers: 703 (Positive), 664 (Negative)
const int CONCEPT_ORDER_MALARIA_SMEAR = 165764; // Checkbox
const int CONCEPT_RESULT_MALARIA_SMEAR = 32;    // Answers: 703 (Positive), 664 (Negative) - Note: HTML form has 664 (Pos), 703 (Neg), check your dictionary
const int CONCEPT_ORDER_TB_LF_LAM = 167080;     // Checkbox
const int CONCEPT_RESULT_TB_LF_LAM = 166697;    // Answers: 703 (Positive), 664 (Negative)
const int CONCEPT_ORDER_URINALYSIS = 167095;    // Checkbox for overall Urinalysis test
const int CONCEPT_RESULT_URINALYSIS = 160987;   // Text result for Urinalysis

// --- CrAg Section ---
const int CONCEPT_ORDER_SEROLOGY_CRAG = 167089; // Checkbox
const int CONCEPT_RESULT_SEROLOGY_CRAG = 167090;// Answers: 703 (Positive), 664 (Negative)
const int CONCEPT_TIME_SEROLOGY_CRAG_SAMPLE_COLLECTED = 167093; // Time
const int CONCEPT_TIME_SEROLOGY_CRAG_RESULT_RECEIVED = 167094;  // Time
const int CONCEPT_ORDER_CSF_CRAG = 167081;      // Checkbox
const int CONCEPT_RESULT_CSF_CRAG = 167082;     // Answers: 703 (Positive), 664 (Negative)

// --- Additional Tests ---
const int CONCEPT_CLINICAL_INDICATION_ADDITIONAL = 165717; // Text

// --- Viral Load Section ---
const int CONCEPT_ORDER_VIRAL_LOAD_TEST = 165765; // Checkbox
const int CONCEPT_VL_SAMPLE_ID = 165715;        // Text
const int CONCEPT_VL_SAMPLE_TYPE = 162476;      // Answers: 1000 (Whole Blood), 1002 (Plasma), 165568 (DBS), 166615 (PSC)
const int CONCEPT_VL_INDICATION = 164980;       // Various answers
const int CONCEPT_VL_REASON_FOR_REPEAT = 165831;// Text
const int CONCEPT_VL_SAMPLE_COLLECTION_DATE_LAB = 159951; // Date (Lab section)
const int CONCEPT_VL_DATE_SAMPLE_SENT_PCR = 165988;    // Date
const int CONCEPT_VL_DATE_SAMPLE_RECEIVED_PCR = 165716;// Date
const int CONCEPT_VL_DATE_RESULT_SENT_PCR = 165989;    // Date
const int CONCEPT_VL_DATE_RESULT_RECEIVED_FACILITY = 165987; // Date
const int CONCEPT_VL_RESULT_DATE_LAB = 166423;  // Date (Lab section)
const int CONCEPT_VL_ASSAY_DATE = 166424;       // Date
const int CONCEPT_VL_APPROVAL_DATE = 166425;    // Date
const int CONCEPT_VL_ALPHANUMERIC_RESULT = 166422; // Various answers
const int CONCEPT_VL_NUMERIC_RESULT = 856;      // Numeric (Lab section)
// In vl_form_constants.dart
const int CONCEPT_VL_ALPHA_LT_SPECIFIED_VALUE = 166426; // Or the correct concept ID

// --- HIVDR Section ---
const int CONCEPT_HIVDR_SAMPLE_SELECTED = 167004; // Checkbox
const int CONCEPT_HIVDR_STUDY_ID = 167005;      // Text
const int CONCEPT_HIVDR_DATE_SAMPLE_SENT = 167006; // Date
const int CONCEPT_HIVDR_DATE_SAMPLE_ARRIVAL = 167007; // Date
const int CONCEPT_HIVDR_DATE_GENOTYPING = 167008; // Date
const int CONCEPT_HIVDR_MUTATIONS_DETECTED_PARENT = 167070; // Parent for multiple checkbox answers
// Individual mutation concepts (examples, add all from your form)
const int CONCEPT_HIVDR_MUTATION_M41L = 167009;
const int CONCEPT_HIVDR_MUTATION_K65R = 167010;
// ... (add all 167011 to 167069)
const int CONCEPT_HIVDR_CLASSES_AFFECTED = 167076; // Text

// HIVDR ARV Classes Affected Options (Example - use your actual concept IDs if available)
// If these are free text in OpenMRS, then storing the string is fine.
// If they are coded answers, you'd use their concept IDs.
const int HIVDR_CLASS_NNRTI = 167072;//167072//NNRTI
const int HIVDR_CLASS_NRTI = 167071;//167071//NRTI
const int HIVDR_CLASS_NRTI_NNRTI = 167074;//167074//NRTI and NNRTI
const int HIVDR_CLASS_NRTI_NNRTI_PI = 167075; //167075//NRTI, NNRTI, and PI
const int HIVDR_CLASS_PI = 167073;//167073//PI

final Map<int, String> hivdrArvClassesAffectedOptions = {
  HIVDR_CLASS_NNRTI: "NNRTI",
  HIVDR_CLASS_NRTI: "NRTI",
  HIVDR_CLASS_NRTI_NNRTI: "NRTI and NNRTI",
  HIVDR_CLASS_NRTI_NNRTI_PI: "NRTI, NNRTI, and PI",
  HIVDR_CLASS_PI: "PI",
  // Add "Other" if needed, and handle its 'specify' field
};

// --- Signatures ---
const int CONCEPT_DATE_ORDERED = 164989;        // Date
const int CONCEPT_REPORTED_BY_PERSON = 164982;  // Person (store ID or name)
const int CONCEPT_DATE_REPORTED = 165414;       // Date
const int CONCEPT_CHECKED_BY_PERSON = 164983;   // Person (store ID or name)
const int CONCEPT_DATE_CHECKED = 164984;        // Date

// --- Answer Concepts (Commonly used) ---
const int CONCEPT_YES = 1065;
const int CONCEPT_NO = 1066;
const int CONCEPT_POSITIVE = 703;
const int CONCEPT_NEGATIVE = 664;
const int CONCEPT_REACTIVE = 1228;
const int CONCEPT_NON_REACTIVE = 1229;
const int CONCEPT_CD4_LFA_LT_200 = 167086;
const int CONCEPT_CD4_LFA_GTE_200 = 167087;

const int CONCEPT_VL_INDICATION_BASELINE_6M = 162080;
const int CONCEPT_VL_INDICATION_ROUTINE_12M = 161236;
const int CONCEPT_VL_INDICATION_CONFIRMATION_EAC = 162082;
const int CONCEPT_VL_INDICATION_REPEAT_TEST = 162081; // This one shows "Reason for Repeat"
const int CONCEPT_VL_INDICATION_CLINICAL_FAILURE = 163523;
const int CONCEPT_VL_INDICATION_IMMUNOLOGICAL_FAILURE = 160566;
const int CONCEPT_VL_INDICATION_PMTCT_32_36W = 165978;

const int CONCEPT_VL_SAMPLE_TYPE_WHOLE_BLOOD = 1000;
const int CONCEPT_VL_SAMPLE_TYPE_PLASMA = 1002;
const int CONCEPT_VL_SAMPLE_TYPE_DBS = 165568;
const int CONCEPT_VL_SAMPLE_TYPE_PSC = 166615;

// VL Alphanumeric Results (examples)
const int CONCEPT_VL_ALPHA_LT20 = 166407;
const int CONCEPT_VL_ALPHA_LT29 = 166408;
const int CONCEPT_VL_ALPHA_LT30 = 167121;
const int CONCEPT_VL_ALPHA_LT40 = 166409;
// ... add all others
const int CONCEPT_VL_ALPHA_TARGET_NOT_DETECTED = 163611; // TND
const int CONCEPT_VL_ALPHA_NUMERIC_VALUE = 166426; // Indicates a numeric value will be entered in the other field

// AHD Indication Answers
const int CONCEPT_AHD_INDICATION_BASELINE = 162080; // Reusing VL baseline
const int CONCEPT_AHD_INDICATION_REPEAT = 162081;   // Reusing VL repeat


// Helper Maps for dropdowns/radio buttons
final Map<int, String> ahdIndicationOptions = {
  CONCEPT_AHD_INDICATION_BASELINE: 'Baseline',
  CONCEPT_AHD_INDICATION_REPEAT: 'Repeat',
};

final Map<int, String> cd4LfaResultOptions = {
  CONCEPT_CD4_LFA_LT_200: '<200',
  CONCEPT_CD4_LFA_GTE_200: '>=200',
};

final Map<int, String> positiveNegativeOptions = {
  CONCEPT_POSITIVE: 'Positive',
  CONCEPT_NEGATIVE: 'Negative',
};
// Note for Malaria: Your HTML has Positive=664, Negative=703. Double check this.
// For this example, I'll use the more common 703=Positive, 664=Negative
final Map<int, String> malariaResultOptions = {
  CONCEPT_POSITIVE: 'Positive', // Assuming 703 is Positive
  CONCEPT_NEGATIVE: 'Negative', // Assuming 664 is Negative
};


final Map<int, String> reactiveNonReactiveOptions = {
  CONCEPT_REACTIVE: 'Reactive',
  CONCEPT_NON_REACTIVE: 'Non-Reactive',
};

final Map<int, String> vlSampleTypeOptions = {
  CONCEPT_VL_SAMPLE_TYPE_WHOLE_BLOOD: 'Whole Blood',
  CONCEPT_VL_SAMPLE_TYPE_PLASMA: 'Plasma',
  CONCEPT_VL_SAMPLE_TYPE_DBS: 'DBS',
  CONCEPT_VL_SAMPLE_TYPE_PSC: 'Plasma separation card(PSC)',
};

final Map<int, String> vlIndicationOptions = {
  CONCEPT_VL_INDICATION_BASELINE_6M: 'Baseline (6 months after ART initiation)',
  CONCEPT_VL_INDICATION_ROUTINE_12M: 'Routine (every 12 months)',
  CONCEPT_VL_INDICATION_CONFIRMATION_EAC: 'Confirmation (3-6 months after intense adherence counselling)',
  CONCEPT_VL_INDICATION_REPEAT_TEST: 'Repeat test',
  CONCEPT_VL_INDICATION_CLINICAL_FAILURE: 'Clinical failure',
  CONCEPT_VL_INDICATION_IMMUNOLOGICAL_FAILURE: 'Immunological failure',
  CONCEPT_VL_INDICATION_PMTCT_32_36W: 'PMTCT 32-36 weeks gestation',
};

final Map<int, String> vlAlphanumericResultOptions = {
  CONCEPT_VL_ALPHA_LT20: '<20',
  CONCEPT_VL_ALPHA_LT29: '<29',
  CONCEPT_VL_ALPHA_LT30: '<30',
  CONCEPT_VL_ALPHA_LT40: '<40',
  166410: '<400', // Example from HTML
  166411: '<80',  // Example from HTML
  166412: '>10 000 000', // Example
  166413: 'Aborted',
  166414: 'Double entry',
  166415: 'Duplicate',
  166416: 'Failed',
  166417: 'Failed twice',
  166418: 'Incomplete number',
  166419: 'Incorrect entry',
  163611: 'Invalid', // HTML has 'Invalid', but 163611 is often TND. Check your dictionary. Using 163611 for TND.
  CONCEPT_VL_ALPHA_TARGET_NOT_DETECTED: 'Target Not Detected',
  166420: 'Wrong entry', // Example from HTML
  CONCEPT_VL_ALPHA_NUMERIC_VALUE: 'Numeric Value',
  // Add all other Alphanumeric options from your HTML schema
};

// HIVDR Mutations - for building checkboxes dynamically
// Key is the concept_id of the mutation, value is the label
const Map<int, String> hivdrMutationOptions = {
  167009: "M41L", 167010: "K65R", 167011: "D67N", 167012: "D67G",
  167013: "T69D", 167014: "K70R", 167015: "K70E", 167016: "L74V",
  167017: "L74I", 167018: "V75M", 167019: "F77L", 167020: "Y115F",
  167021: "F116Y", 167022: "Q151M", 167023: "M184V", 167024: "M184I",
  167025: "L210W", 167026: "T215Y", 167027: "T215F", 167028: "T215I",
  167029: "T215S", 167030: "T215C", 167031: "T215E", 167032: "K219Q",
  167033: "K219E", 167034: "K219N", 167035: "K219R", 167036: "L100I",
  167037: "K101E", 167038: "K101P", 167039: "K103N", 167040: "K103S",
  167041: "V106M", 167042: "V106A", 167043: "Y181C", 167044: "Y181V",
  167045: "Y188L", 167046: "Y188H", 167047: "Y188C", 167048: "G190A",
  167049: "G190S", 167050: "G190E", 167051: "P225H", 167052: "M230L",
  167053: "L24I",  167054: "M46I",  167055: "M46L",  167056: "I50V",
  167057: "I50L",  167058: "F53L",  167059: "I54V",  167060: "I54L",
  167061: "G73S",  167062: "L76V",  167063: "V82A",  167064: "V82F",
  167065: "V82S",  167066: "V82M",  167067: "N83D",  167068: "I84V",
  167069: "L90M",
  // Add any other mutations if present in your form
};