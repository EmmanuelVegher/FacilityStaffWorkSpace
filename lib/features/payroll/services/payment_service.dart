// lib/features/payroll/services/payment_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Initializes a transaction by calling our secure cloud function
  Future<Map<String, dynamic>> initializeTransaction({
    required int amount,
    required String email,
  }) async {
    try {
      final callable = _functions.httpsCallable('initializePayment');
      final response = await callable.call<Map<String, dynamic>>({
        'email': email,
        'amount': amount,
      });
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      // --- THIS IS THE IMPROVED PART ---
      // This will give us much more useful errors in the console.
      print('Firebase Functions Error:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      // Re-throw the error so the UI can handle it if needed
      rethrow;
      // --- END OF IMPROVEMENT ---
    } catch (e) {
      print('A generic error occurred in initializeTransaction: $e');
      rethrow;
    }
  }


  // Launches the payment URL in a new tab
  Future<void> launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      throw 'Could not launch $url';
    }
  }

  // Verifies a transaction by calling our secure cloud function
  Future<Map<String, dynamic>> verifyTransaction(String reference) async {
    try {
      final callable = _functions.httpsCallable('verifyPayment');
      final response = await callable.call<Map<String, dynamic>>({
        'reference': reference,
      });
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      print('Firebase Functions Error (Verify):');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      rethrow;
    } catch (e) {
      print('A generic error occurred in verifyTransaction: $e');
      rethrow;
    }
  }
}