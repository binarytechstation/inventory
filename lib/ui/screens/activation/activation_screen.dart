import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/license/license_service.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final LicenseService _licenseService = LicenseService();
  final TextEditingController _licenseKeyController = TextEditingController();

  String _installationCode = '';
  String _fullFingerprint = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInstallationCode();
  }

  Future<void> _loadInstallationCode() async {
    try {
      final code = await _licenseService.getInstallationCode();
      final fingerprint = await _licenseService.getDeviceFingerprint();
      setState(() {
        _installationCode = code;
        _fullFingerprint = fingerprint;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating installation code: $e';
      });
    }
  }

  Future<void> _activateLicense() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final licenseString = _licenseKeyController.text.trim();
      if (licenseString.isEmpty) {
        throw Exception('Please enter a license key');
      }

      await _licenseService.importLicenseString(licenseString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _copyInstallationCode() {
    Clipboard.setData(ClipboardData(text: _installationCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Installation code copied to clipboard')),
    );
  }

  void _copyFullFingerprint() {
    Clipboard.setData(ClipboardData(text: _fullFingerprint));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full fingerprint copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Activation'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.vpn_key,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Activate Your Software',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This software requires activation. Please use the installation code below to generate a license key.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Installation Code (Shortened):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _installationCode.isEmpty ? 'Loading...' : _installationCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _installationCode.isEmpty ? null : _copyInstallationCode,
                          tooltip: 'Copy to clipboard',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Full Device Fingerprint (For License Generation):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _fullFingerprint.isEmpty ? 'Loading...' : _fullFingerprint,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: _fullFingerprint.isEmpty ? null : _copyFullFingerprint,
                          tooltip: 'Copy full fingerprint',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter License Key:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _licenseKeyController,
                    decoration: const InputDecoration(
                      hintText: 'Paste your license key here',
                      prefixIcon: Icon(Icons.key),
                    ),
                    maxLines: 3,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _activateLicense,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate License'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How to activate:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Copy the installation code above\n'
                    '2. Use the license generator tool to create a license key\n'
                    '3. Paste the license key in the field above\n'
                    '4. Click "Activate License"',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }
}
