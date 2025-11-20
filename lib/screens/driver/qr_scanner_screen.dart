import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = true;
  String? _scannedData;

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isScanning = false;
      _scannedData = barcode.rawValue!;
    });

    // You can add logic here to process the scanned data, e.g.:
    // check if it's a student ID, validate attendance, etc.
    debugPrint('Scanned QR/Barcode: $_scannedData');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scanned Result'),
        content: Text(_scannedData!),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isScanning = true); // Resume scanning
            },
            child: const Text('Scan Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR/Barcode'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            //allowDuplicates: false,
          ),
          if (!_isScanning)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
