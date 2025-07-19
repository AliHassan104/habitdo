import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitdo/presentation/shared/widgets/bottom_navigation.dart';
import 'package:habitdo/presentation/shared/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';

class AddEditScreen extends StatefulWidget {
  final String? habitId;
  final String? existingTitle;
  final String? existingDescription;

  const AddEditScreen({
    super.key,
    this.habitId,
    this.existingTitle,
    this.existingDescription,
  });

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _targetUnitController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _repeatType = 'Once';
  DateTime? _selectedDate;
  List<String> _selectedDays = [];
  bool _notificationsEnabled = false;
  TimeOfDay? _notificationTime;
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _targetUnitController = TextEditingController();

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.habitId != null) {
      FirebaseFirestore.instance
          .collection('habits')
          .doc(widget.habitId)
          .get()
          .then((doc) {
            if (doc.exists) {
              final data = doc.data()!;
              setState(() {
                _titleController.text = data['title'] ?? '';
                _descriptionController.text = data['description'] ?? '';
                _targetValueController.text =
                    (data['targetValue'] ?? '').toString();

                _targetUnitController.text =
                    (data['targetUnit'] ?? '').toString();

                _repeatType = data['repeatType'] ?? 'Once';
                _selectedDate =
                    data['selectedDate'] != null
                        ? (data['selectedDate'] as Timestamp).toDate()
                        : null;
                _selectedDays = List<String>.from(data['selectedDays'] ?? []);
                _notificationsEnabled = data['notificationsEnabled'] ?? false;
                if (data['notificationTime'] != null) {
                  final parts = (data['notificationTime'] as String).split(':');
                  _notificationTime = TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  );
                }
              });
            }
          });
    }
  }

  void _saveHabit() async {
    if (_isSaving) return; // prevent double tap
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final targetValue = _targetValueController.text.trim();
    final targetUnit = _targetUnitController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        targetValue.isEmpty ||
        targetUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final habitData = {
        'title': title,
        'description': description,
        'repeatType': _repeatType,
        'selectedDate':
            _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'selectedDays': _repeatType == 'Weekly' ? _selectedDays : [],
        'notificationsEnabled': _notificationsEnabled,
        'notificationTime':
            _notificationTime != null
                ? '${_notificationTime!.hour}:${_notificationTime!.minute}'
                : null,
        'targetValue': double.tryParse(targetValue),

        'targetUnit': targetUnit,
        'uid': currentUser?.uid,
        'dailyCompletion': {},
      };

      if (widget.habitId == null) {
        habitData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('habits').add(habitData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit created successfully')),
        );
      } else {
        habitData['updatedAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(widget.habitId)
            .update(habitData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit updated successfully')),
        );
      }

      if (context.mounted) context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habitId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Habit' : 'Create Habit'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveHabit),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          children: [
            CustomTextField(
              controller: _titleController,
              hintText: 'Title',
              labelText: 'Title',
              prefixIcon: Icons.title,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              hintText: 'Description',
              labelText: 'Description',
              prefixIcon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: DropdownButtonFormField<String>(
                value: _repeatType,
                items: const [
                  DropdownMenuItem(value: 'Once', child: Text('Once')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                ],
                onChanged: (value) {
                  setState(() {
                    _repeatType = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Repeat Type',
                  prefixIcon: const Icon(Icons.repeat),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_repeatType == 'Once')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Date'),
                    ElevatedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📅 Selected Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
            if (_repeatType == 'Weekly')
              Wrap(
                spacing: 8,
                children:
                    _weekDays.map((day) {
                      final isSelected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            isSelected
                                ? _selectedDays.remove(day)
                                : _selectedDays.add(day);
                          });
                        },
                      );
                    }).toList(),
              ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _targetValueController,
              hintText: 'Target Value',
              labelText: 'Target Value',
              prefixIcon: Icons.check_circle,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _targetUnitController,
              hintText: 'Target Unit',
              labelText: 'Target Unit',
              prefixIcon: Icons.straighten,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Allow Notifications'),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_notificationsEnabled)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notification Time'),
                  ElevatedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _notificationTime = time;
                        });
                      }
                    },
                    child: const Text('Select Time'),
                  ),
                ],
              ),
            if (_notificationTime != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '⏰ Notification Time: ${_notificationTime!.format(context)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              ),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Habit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Habit'),
                            content: const Text(
                              'Are you sure you want to delete this habit?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('habits')
                          .doc(widget.habitId)
                          .delete();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Habit deleted successfully'),
                          ),
                        );
                        context.go('/home');
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveHabit,
          icon:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.add),
          label: Text(
            _isSaving
                ? (isEditing ? 'Updating...' : 'Saving...')
                : (isEditing ? 'Update Habit' : 'Save Habit'),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
