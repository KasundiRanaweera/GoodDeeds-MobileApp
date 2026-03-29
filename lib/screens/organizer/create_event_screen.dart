import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/event_categories.dart';
import '../../services/firebase_service.dart';
import 'organizer_dashboard_screen.dart';
import 'organizer_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF051A08);

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _organizerNameController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _bannerUrlController = TextEditingController();

  final List<String> _categories = List<String>.from(kOrganizerEventCategories);

  String _selectedCategory = kOrganizerEventCategories.first;
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isManagedStorageUrl(String url) {
    return url.contains('/o/event_banners%2F') ||
        url.contains('/event_banners/');
  }

  Future<void> _tryDeleteStorageByUrl(String url) async {
    if (url.isEmpty || !_isManagedStorageUrl(url)) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    _organizerNameController.text = displayName;
    _pointsController.text = '50';
  }

  @override
  void dispose() {
    _organizerNameController.dispose();
    _contactNumberController.dispose();
    _eventTitleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _pointsController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _promptBannerUrl() async {
    final currentUrl = _bannerUrlController.text.trim();
    final controller = TextEditingController(text: _bannerUrlController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Event Banner URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/banner.jpg',
              labelText: 'Image URL',
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
      final nextUrl = result.trim();
      if (currentUrl.isNotEmpty && currentUrl != nextUrl) {
        await _tryDeleteStorageByUrl(currentUrl);
      }
      setState(() {
        _bannerUrlController.text = nextUrl;
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final userId = _firebaseService.currentUser?.uid ?? 'unknown';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('event_banners')
          .child(userId)
          .child(fileName);

      await ref.putFile(File(picked.path));
      final downloadUrl = await ref.getDownloadURL();

      final currentUrl = _bannerUrlController.text.trim();
      if (currentUrl.isNotEmpty && currentUrl != downloadUrl) {
        await _tryDeleteStorageByUrl(currentUrl);
      }

      if (!mounted) return;
      setState(() {
        _bannerUrlController.text = downloadUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _showImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Use Image URL Instead'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _promptBannerUrl();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _dateTimeLabel() {
    final date = _selectedDateTime;
    if (date == null) return 'Select date and time';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[date.month - 1];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$month ${date.day}, ${date.year}  $hour12:$minute $suffix';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time.')),
      );
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final points = int.tryParse(_pointsController.text.trim()) ?? 0;
      if (points < 50 || points > 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward points must be between 50 and 200.'),
          ),
        );
        return;
      }
      final data = <String, dynamic>{
        'title': _eventTitleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'impactPoints': points,
        'eventDate': Timestamp.fromDate(_selectedDateTime!),
        'imageUrl': _bannerUrlController.text.trim(),
        'organizerName': _organizerNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'organizerContactNumber': _contactNumberController.text.trim(),
        'createdByUid': user.uid,
        'createdByName': _organizerNameController.text.trim(),
        'participantsCount': 0,
        'participantIds': <String>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('events').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create event: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_circle_outline, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Create Event', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 98),
            children: [
              const Text(
                'Event Banner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isUploadingImage ? null : _showImageSourcePicker,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _kPrimaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    color: _kPrimaryColor.withValues(alpha: 0.06),
                  ),
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _kPrimaryColor,
                          ),
                        )
                      : _bannerUrlController.text.trim().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _bannerUrlController.text.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) {
                              return _bannerPlaceholder(isDark);
                            },
                          ),
                        )
                      : _bannerPlaceholder(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _bannerUrlController.text.trim().isEmpty
                          ? 'Tap banner area to upload event image'
                          : 'Banner image uploaded',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : _showImageSourcePicker,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _label('Organizer Name'),
              _field(
                controller: _organizerNameController,
                hintText: 'e.g. Green Earth Foundation',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Organizer name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Contact Number'),
              _field(
                controller: _contactNumberController,
                hintText: 'e.g. 0123456789',
                keyboardType: TextInputType.phone,
                suffixIcon: const Icon(Icons.phone, color: _kPrimaryColor),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Contact number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Event Title'),
              _field(
                controller: _eventTitleController,
                hintText: 'e.g. Community Tech Meetup',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Event title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Description'),
              _field(
                controller: _descriptionController,
                hintText: 'What is this event about?',
                minLines: 5,
                maxLines: 6,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Category'),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade800.withValues(alpha: 0.5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kPrimaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedCategory,
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedCategory = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Points Reward'),
                        _field(
                          controller: _pointsController,
                          hintText: '50 - 200',
                          keyboardType: TextInputType.number,
                          suffixIcon: const Icon(
                            Icons.stars,
                            color: _kPrimaryColor,
                          ),
                          validator: (value) {
                            final points = int.tryParse((value ?? '').trim());
                            if (points == null) {
                              return 'Required';
                            }
                            if (points < 50 || points > 200) {
                              return 'Use 50-200';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label('Location'),
              _field(
                controller: _locationController,
                hintText: 'Add event location',
                suffixIcon: const Icon(Icons.map, color: _kPrimaryColor),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Date & Time'),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDateTime,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kPrimaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateTimeLabel(),
                          style: TextStyle(
                            color: _selectedDateTime == null
                                ? (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500)
                                : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: _kPrimaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: _kPrimaryColor.withValues(alpha: 0.24),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Event',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.rocket_launch),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OrganizerDashboardScreen(),
              ),
            );
            return;
          }

          if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OrganizerProfileScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark
            ? Colors.grey.shade500
            : Colors.grey.shade700,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Create',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _bannerPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate, color: _kPrimaryColor, size: 42),
        const SizedBox(height: 8),
        const Text(
          'Upload event image',
          style: TextStyle(color: _kPrimaryColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended: 1200 x 675 px',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hintText,
    FormFieldValidator<String>? validator,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
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
          borderSide: BorderSide(color: _kPrimaryColor),
        ),
      ),
    );
  }
}
