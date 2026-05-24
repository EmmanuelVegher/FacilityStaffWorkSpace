import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'verification_page.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String _selectedVerificationType = 'qr';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Options'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Verification Method',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildVerificationTypeCard(
              'QR Code',
              'Scan QR codes for mutual verification',
              'qr',
              Icons.qr_code,
              Colors.blue,
            ),
            const SizedBox(height: 10),
            _buildVerificationTypeCard(
              'Bluetooth Proximity',
              'Verify using Bluetooth signal strength',
              'bluetooth',
              Icons.bluetooth,
              Colors.green,
            ),
            const SizedBox(height: 10),
            _buildVerificationTypeCard(
              'Hybrid (QR + Bluetooth)',
              'Combine QR and Bluetooth verification',
              'hybrid',
              Icons.sync,
              Colors.purple,
            ),
            const SizedBox(height: 10),
            _buildVerificationTypeCard(
              'Location-based',
              'Verify based on proximity (fallback)',
              'location',
              Icons.location_on,
              Colors.orange,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedWithVerification,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Proceed with Verification'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationTypeCard(
    String title,
    String description,
    String type,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedVerificationType == type;

    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedVerificationType = type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: type,
                groupValue: _selectedVerificationType,
                onChanged: (value) =>
                    setState(() => _selectedVerificationType = value!),
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceedWithVerification() {
    switch (_selectedVerificationType) {
      case 'qr':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VerificationPage()),
        );
        break;
      case 'bluetooth':
        _showBluetoothVerification();
        break;
      case 'hybrid':
        _showHybridVerification();
        break;
      case 'location':
        _showLocationVerification();
        break;
    }
  }

  void _showBluetoothVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Verification'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Searching for nearby devices...'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                  'This feature requires Bluetooth permissions and nearby devices.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showHybridVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hybrid Verification'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Combining QR and Bluetooth verification...'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                  'This provides enhanced security by requiring both methods.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationVerification() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location-based Verification'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Verifying proximity based on GPS location...'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                  'This is used as a fallback when other methods are unavailable.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
