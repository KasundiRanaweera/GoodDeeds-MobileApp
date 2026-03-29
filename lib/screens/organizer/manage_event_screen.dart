import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';
import 'create_event_screen.dart';
import 'organizer_dashboard_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class ManageEventScreen extends StatefulWidget {
  const ManageEventScreen({super.key, required this.eventData});

  final Map<String, dynamic> eventData;

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _organizerNameController;
  late final TextEditingController _eventTitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _pointsController;
  late final TextEditingController _bannerUrlController;

  final List<String> _categories = const [
    'Environment',
    'Technology',
    'Education',
    'Health',
    'Networking',
    'Workshop',
    'Charity',
    'Volunteering',
  ];

  late String _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  String get _eventId => widget.eventData['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();

    final displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    final organizerName = _asString(
      widget.eventData['organizerName'] ??
          widget.eventData['createdByName'] ??
          displayName,
      fallback: 'Organizer',
    );

    _organizerNameController = TextEditingController(text: organizerName);
    _eventTitleController = TextEditingController(
      text: _asString(
        widget.eventData['title'] ??
            widget.eventData['eventName'] ??
            widget.eventData['name'],
      ),
    );
    _descriptionController = TextEditingController(
      text: _asString(widget.eventData['description']),
    );
    _locationController = TextEditingController(
      text: _asString(
        widget.eventData['location'] ??
            widget.eventData['venue'] ??
            widget.eventData['address'],
      ),
    );
    _pointsController = TextEditingController(
      text: _asInt(
        widget.eventData['impactPoints'] ??
            widget.eventData['points'] ??
            widget.eventData['rewardPoints'],
        fallback: 0,
      ).toString(),
    );
    _bannerUrlController = TextEditingController(
      text: _asString(
        widget.eventData['imageUrl'] ??
            widget.eventData['bannerUrl'] ??
            widget.eventData['photoUrl'],
      ),
    );

    final rawCategory = _asString(widget.eventData['category']);
    if (rawCategory.isNotEmpty && !_categories.contains(rawCategory)) {
      _categories.add(rawCategory);
    }
    _selectedCategory = rawCategory.isEmpty ? _categories.first : rawCategory;

    final parsedDate = _asDate(
      widget.eventData['eventDate'] ??
          widget.eventData['date'] ??
          widget.eventData['startDate'],
    );
    if (parsedDate != null) {
      _selectedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      _selectedTime = TimeOfDay(
        hour: parsedDate.hour,
        minute: parsedDate.minute,
      );
    }
  }

  @override
  void dispose() {
    _organizerNameController.dispose();
    _eventTitleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _pointsController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic date = value?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }
    if (_eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event ID is missing. Cannot update event.'),
        ),
      );
      return;
    }

    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_eventId)
          .update({
            'organizerName': _organizerNameController.text.trim(),
            'createdByName': _organizerNameController.text.trim(),
            'title': _eventTitleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'impactPoints': int.tryParse(_pointsController.text.trim()) ?? 0,
            'location': _locationController.text.trim(),
            'imageUrl': _bannerUrlController.text.trim(),
            'eventDate': Timestamp.fromDate(selectedDateTime),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save changes: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.9)
            : _kBackgroundLight.withValues(alpha: 0.92),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Event',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
            children: [
              _label('Organizer Name', isDark),
              _field(
                controller: _organizerNameController,
                hintText: 'Green Earth Foundation',
                isDark: isDark,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Organizer name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Event Title', isDark),
              _field(
                controller: _eventTitleController,
                hintText: 'Annual Charity Marathon',
                isDark: isDark,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Event title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Description', isDark),
              _field(
                controller: _descriptionController,
                hintText: 'Describe your event',
                isDark: isDark,
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
                        _label('Category', isDark),
                        _dropdownField(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Points Reward', isDark),
                        _field(
                          controller: _pointsController,
                          hintText: '20',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(top: 18, right: 12),
                            child: Text(
                              'pts',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final points = int.tryParse((value ?? '').trim());
                            if (points == null || points < 0) {
                              return 'Invalid';
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
              _label('Location', isDark),
              _field(
                controller: _locationController,
                hintText: 'Central Park Arena',
                isDark: isDark,
                prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Container(
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBDE6AcMx5b-examgxODuEa_8hoC2vQzHezoIPFOEoQXZbtkk_QtKGaq3p7G5bgylmgSW0gdzKHNQpbfAqtw350O2s7aA9TNq5tQP5Q8BpRMV3ieDtuEAMnDbdbWNArtQfKK6CEs2JfM3YQvkhudM4SLnH3SwPGf9u979GDCAtaY6NogY6-rHhkEaAr_AIMbOZlO_K3XFoGihVdrzurS0sWPPx_CBXixFfh-7ul6iS6dAd_J1GcxYV5ZvfrL8bI7zG7ru4ugl9i7QM',
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) {
                    return Container(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: Text(
                        'Map preview',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Date', isDark),
                        _pickerField(
                          onTap: _pickDate,
                          label: _dateLabel(),
                          icon: Icons.calendar_today,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Time', isDark),
                        _pickerField(
                          onTap: _pickTime,
                          label: _timeLabel(),
                          icon: Icons.schedule,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Banner URL', isDark),
              _field(
                controller: _bannerUrlController,
                hintText: 'https://example.com/banner.jpg',
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: _kPrimaryColor.withValues(alpha: 0.22),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OrganizerDashboardScreen(),
              ),
            );
            return;
          }

          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CreateEventScreen()),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Participants screen coming soon.')),
          );
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
            label: 'Create Event',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Participants',
          ),
        ],
      ),
    );
  }

  Widget _dropdownField(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          items: _categories
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedCategory = value);
          },
        ),
      ),
    );
  }

  Widget _pickerField({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.shade800.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade500, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: label.startsWith('Select')
                      ? (isDark ? Colors.grey.shade400 : Colors.grey.shade500)
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    FormFieldValidator<String>? validator,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
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

  String _dateLabel() {
    final date = _selectedDate;
    if (date == null) return 'Select date';
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _timeLabel() {
    final time = _selectedTime;
    if (time == null) return 'Select time';
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}
