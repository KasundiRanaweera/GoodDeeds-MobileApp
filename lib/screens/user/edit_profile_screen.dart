import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _photoUrlController = TextEditingController();

  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  bool _isSaving = false;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<void> _loadCurrentProfile() async {
    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final data = await _firebaseService.getUserData(user.uid);
      _nameController.text = _asString(
        data?['name'] ?? user.displayName,
        fallback: 'Community Volunteer',
      );
      _phoneController.text = _asString(data?['phone']);
      _addressController.text = _asString(data?['address']);
      _bioController.text = _asString(data?['bio']);
      _photoUrlController.text = _asString(
        data?['photoUrl'] ?? data?['avatarUrl'],
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile details.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _promptPhotoUrl() async {
    final controller = TextEditingController(text: _photoUrlController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Upload Photo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Photo URL',
              hintText: 'https://example.com/photo.jpg',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Use URL'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _photoUrlController.text = result.trim();
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to edit profile.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
        'photoUrl': _photoUrlController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: background,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _kPrimaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 4,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child:
                                          _photoUrlController.text
                                              .trim()
                                              .isNotEmpty
                                          ? Image.network(
                                              _photoUrlController.text.trim(),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, error, stackTrace) {
                                                    return _EditAvatarFallback(
                                                      initials: _initials(
                                                        _nameController.text,
                                                      ),
                                                    );
                                                  },
                                            )
                                          : _EditAvatarFallback(
                                              initials: _initials(
                                                _nameController.text,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _promptPhotoUrl,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _kPrimaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                      foregroundColor: _kPrimaryColor,
                                      backgroundColor: _kPrimaryColor
                                          .withValues(alpha: 0.1),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.photo_camera,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Upload Photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Full Name',
                            child: TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: 'e.g. Alex Johnson',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                          ),
                          _LabeledField(
                            label: 'Phone Number',
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: '+1 (555) 000-0000',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Address',
                            child: TextFormField(
                              controller: _addressController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: '123 Design St, Creative City',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Bio',
                            child: TextFormField(
                              controller: _bioController,
                              keyboardType: TextInputType.multiline,
                              minLines: 5,
                              maxLines: 6,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: 'Tell us about yourself...',
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kPrimaryColor,
                                  foregroundColor: Colors.black,
                                  elevation: 6,
                                  shadowColor: _kPrimaryColor.withValues(
                                    alpha: 0.25,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'Update Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: isDark ? Colors.grey.shade800 : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kPrimaryColor, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EditAvatarFallback extends StatelessWidget {
  const _EditAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2B2B), Color(0xFF4C4C4C)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
