import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanFamilyInvitationPage extends StatefulWidget {
  const ScanFamilyInvitationPage({super.key});

  @override
  State<ScanFamilyInvitationPage> createState() =>
      _ScanFamilyInvitationPageState();
}

class _ScanFamilyInvitationPageState extends State<ScanFamilyInvitationPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _hasDetectedCode = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR-Code scannen'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Taschenlampe',
            onPressed: () {
              _scannerController.toggleTorch();
            },
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          IgnorePointer(
            child: Column(
              children: [
                Expanded(
                  child: Container(color: Colors.black.withValues(alpha: 0.45)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 250,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 250,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(
                      top: 28,
                      left: 24,
                      right: 24,
                    ),
                    child: Text(
                      'Halte den FamilyLog-QR-Code '
                      'in den markierten Bereich.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_hasDetectedCode) {
      return;
    }

    String? detectedCode;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;

      if (rawValue == null) {
        continue;
      }

      final normalizedCode = rawValue.trim().toUpperCase();

      if (_isValidFamilyLogCode(normalizedCode)) {
        detectedCode = normalizedCode;
        break;
      }
    }

    if (detectedCode == null) {
      return;
    }

    _hasDetectedCode = true;

    await _scannerController.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(detectedCode);
  }

  bool _isValidFamilyLogCode(String code) {
    return RegExp(r'^FAM-[A-HJ-NP-Z2-9]{6}$').hasMatch(code);
  }
}
