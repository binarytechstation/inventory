import 'package:flutter/material.dart';
import '../../../data/database/database_helper.dart';

class BusinessInfoScreen extends StatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  late TextEditingController _companyNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _taxIdController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _taxIdController = TextEditingController();
    _notesController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;
      final profiles = await db.query('profile', limit: 1);

      if (profiles.isNotEmpty) {
        _profileData = profiles.first;
        _companyNameController.text = _profileData!['company_name'] as String? ?? '';
        _ownerNameController.text = _profileData!['owner_name'] as String? ?? '';
        _phoneController.text = _profileData!['phone'] as String? ?? '';
        _emailController.text = _profileData!['email'] as String? ?? '';
        _addressController.text = _profileData!['address'] as String? ?? '';
        _taxIdController.text = _profileData!['tax_id'] as String? ?? '';
        _notesController.text = _profileData!['notes'] as String? ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading business info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = await _dbHelper.database;

      final profileMap = {
        'company_name': _companyNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'tax_id': _taxIdController.text.trim(),
        'notes': _notesController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_profileData != null) {
        // Update existing profile
        await db.update(
          'profile',
          profileMap,
          where: 'id = ?',
          whereArgs: [_profileData!['id']],
        );
      } else {
        // Create new profile (shouldn't happen, but just in case)
        profileMap['created_at'] = DateTime.now().toIso8601String();
        await db.insert('profile', profileMap);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business information updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload data to get the updated values
        await _loadProfileData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving business info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Information'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Company Details',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _companyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.store),
                              hintText: 'Enter your company name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter company name';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ownerNameController,
                            decoration: const InputDecoration(
                              labelText: 'Owner Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                              hintText: 'Enter owner name',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxIdController,
                            decoration: const InputDecoration(
                              labelText: 'Tax ID / Registration Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                              hintText: 'Enter tax ID or registration number',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.contact_mail, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Contact Information',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                              hintText: 'Enter phone number',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                              hintText: 'Enter email address',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value.trim())) {
                                  return 'Enter valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Business Address',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                              hintText: 'Enter full business address',
                            ),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notes, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                'Additional Information',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note_alt),
                              hintText: 'Additional notes or information',
                            ),
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_profileData != null && _profileData!['updated_at'] != null)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Last updated: ${_formatDateTime(DateTime.parse(_profileData!['updated_at'] as String))}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  // Reset form to original values
                                  if (_profileData != null) {
                                    _companyNameController.text =
                                        _profileData!['company_name'] as String? ?? '';
                                    _ownerNameController.text =
                                        _profileData!['owner_name'] as String? ?? '';
                                    _phoneController.text =
                                        _profileData!['phone'] as String? ?? '';
                                    _emailController.text =
                                        _profileData!['email'] as String? ?? '';
                                    _addressController.text =
                                        _profileData!['address'] as String? ?? '';
                                    _taxIdController.text =
                                        _profileData!['tax_id'] as String? ?? '';
                                    _notesController.text =
                                        _profileData!['notes'] as String? ?? '';
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Changes discarded'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Reset'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
