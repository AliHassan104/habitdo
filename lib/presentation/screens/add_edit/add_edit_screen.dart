import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    _categoryController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String _repeatType = 'Repeat Till Done';
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedDays = [];
  bool _notificationsEnabled = false;
  TimeOfDay? _notificationTime;
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _targetUnitController = TextEditingController();
  String _priority = 'Medium';

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final List<String> _priorityLevels = ['High', 'Medium', 'Low'];

  // Predefined categories for quick selection
  final List<String> _predefinedCategories = [
    'Health & Fitness',
    'Learning',
    'Work',
    'Personal',
    'Hobbies',
    'Social',
    'Finance',
    'Home',
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
                _categoryController.text = data['category'] ?? '';
                _targetValueController.text =
                    (data['targetValue'] ?? '').toString();
                _targetUnitController.text =
                    (data['targetUnit'] ?? '').toString();
                _repeatType = data['repeatType'] ?? 'Repeat Till Done';
                _priority = data['priority'] ?? 'Medium';

                // Handle dates
                _selectedDate =
                    data['selectedDate'] != null
                        ? (data['selectedDate'] as Timestamp).toDate()
                        : null;
                _startDate =
                    data['startDate'] != null
                        ? (data['startDate'] as Timestamp).toDate()
                        : null;
                _endDate =
                    data['endDate'] != null
                        ? (data['endDate'] as Timestamp).toDate()
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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final targetValue = _targetValueController.text.trim();
    final targetUnit = _targetUnitController.text.trim();

    // Validation
    if (title.isEmpty ||
        description.isEmpty ||
        targetValue.isEmpty ||
        targetUnit.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      setState(() => _isSaving = false);
      return;
    }

    if (_repeatType == 'Weekly' && _selectedDays.isEmpty) {
      _showSnackBar('Please select at least one day for weekly habits');
      setState(() => _isSaving = false);
      return;
    }

    if (_repeatType == 'Repeat Till Done' && _selectedDate == null) {
      _showSnackBar(
        'Please select a target date for "Repeat Till Done" habits',
      );
      setState(() => _isSaving = false);
      return;
    }

    if (_repeatType == 'Weekly' && (_startDate == null || _endDate == null)) {
      _showSnackBar('Please select both start and end dates for weekly habits');
      setState(() => _isSaving = false);
      return;
    }

    if (_repeatType == 'Weekly' && _endDate!.isBefore(_startDate!)) {
      _showSnackBar('End date must be after start date');
      setState(() => _isSaving = false);
      return;
    }

    try {
      final habitData = {
        'title': title,
        'description': description,
        'category': category,
        'priority': _priority,
        'repeatType': _repeatType,
        'targetValue': double.tryParse(targetValue),
        'targetUnit': targetUnit,
        'uid': currentUser?.uid,
        'dailyCompletion': {},
        'isCompleted': false, // For "Repeat Till Done" habits
        'notificationsEnabled': _notificationsEnabled,
        'notificationTime':
            _notificationTime != null
                ? '${_notificationTime!.hour}:${_notificationTime!.minute}'
                : null,
      };

      // Add dates based on repeat type
      if (_repeatType == 'Repeat Till Done') {
        habitData['selectedDate'] = Timestamp.fromDate(_selectedDate!);
        habitData['selectedDays'] = [];
        habitData['startDate'] = null;
        habitData['endDate'] = null;
      } else if (_repeatType == 'Weekly') {
        habitData['selectedDays'] = _selectedDays;
        habitData['startDate'] = Timestamp.fromDate(_startDate!);
        habitData['endDate'] = Timestamp.fromDate(_endDate!);
        habitData['selectedDate'] = null;
      }

      if (widget.habitId == null) {
        habitData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance.collection('habits').add(habitData);
        _showSnackBar('Habit created successfully');
      } else {
        habitData['updatedAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('habits')
            .doc(widget.habitId)
            .update(habitData);
        _showSnackBar('Habit updated successfully');
      }

      if (context.mounted) context.go('/home');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _categoryController,
          hintText: 'Category (optional)',
          labelText: 'Category',
          prefixIcon: Icons.category,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              _predefinedCategories.map((category) {
                return ActionChip(
                  label: Text(category),
                  onPressed: () {
                    setState(() {
                      _categoryController.text = category;
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    if (_repeatType == 'Repeat Till Done') {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Target Date', style: TextStyle(fontSize: 16)),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '📅 Target Date: ${DateFormat.yMMMd().format(_selectedDate!)}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      );
    } else if (_repeatType == 'Weekly') {
      return Column(
        children: [
          // Start Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Start Date', style: TextStyle(fontSize: 16)),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                      });
                    }
                  },
                  child: const Text('Select Start'),
                ),
              ],
            ),
          ),
          if (_startDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '📅 Start: ${DateFormat.yMMMd().format(_startDate!)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // End Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('End Date', style: TextStyle(fontSize: 16)),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _endDate ??
                          _startDate ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: _startDate ?? DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                  child: const Text('Select End'),
                ),
              ],
            ),
          ),
          if (_endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '📅 End: ${DateFormat.yMMMd().format(_endDate!)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Week days selection
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Days:', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    showCheckmark: false,
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
        ],
      );
    }
    return const SizedBox.shrink();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            CustomTextField(
              controller: _titleController,
              hintText: 'Title',
              labelText: 'Title *',
              prefixIcon: Icons.title,
              autofocus: true,
              maxLength: 150,
            ),
            const SizedBox(height: 16),

            // Description
            CustomTextField(
              controller: _descriptionController,
              hintText: 'Description',
              labelText: 'Description *',
              prefixIcon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Category
            _buildCategoryField(),
            const SizedBox(height: 16),

            // Priority
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: DropdownButtonFormField<String>(
                value: _priority,
                items:
                    _priorityLevels.map((priority) {
                      return DropdownMenuItem(
                        value: priority,
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag,
                              color:
                                  priority == 'High'
                                      ? Colors.red
                                      : priority == 'Medium'
                                      ? Colors.orange
                                      : Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(priority),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: const Icon(Icons.flag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Repeat Type
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: DropdownButtonFormField<String>(
                value: _repeatType,
                items: const [
                  DropdownMenuItem(
                    value: 'Repeat Till Done',
                    child: Text('Repeat Till Done'),
                  ),
                  DropdownMenuItem(
                    value: 'Weekly',
                    child: Text('Weekly (Date Range)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _repeatType = value!;
                    // Reset related fields when changing type
                    _selectedDate = null;
                    _startDate = null;
                    _endDate = null;
                    _selectedDays.clear();
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

            // Date/Days Selection
            _buildDateSelector(),
            const SizedBox(height: 16),

            // Target Value
            CustomTextField(
              controller: _targetValueController,
              hintText: 'Target Value',
              labelText: 'Target Value *',
              prefixIcon: Icons.check_circle,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),

            // Target Unit
            CustomTextField(
              controller: _targetUnitController,
              hintText: 'Target Unit (e.g., minutes, pages, reps)',
              labelText: 'Target Unit *',
              prefixIcon: Icons.straighten,
            ),
            const SizedBox(height: 16),

            // Notifications
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Allow Notifications',
                    style: TextStyle(fontSize: 16),
                  ),
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

            // Notification Time
            if (_notificationsEnabled) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Time',
                    style: TextStyle(fontSize: 16),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _notificationTime ?? TimeOfDay.now(),
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '⏰ Notification Time: ${_notificationTime!.format(context)}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
            ],

            // Delete Button (for editing)
            if (isEditing) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
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
                            'Are you sure you want to delete this habit? This action cannot be undone.',
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
                      _showSnackBar('Habit deleted successfully');
                      context.go('/home');
                    }
                  }
                },
              ),
            ],
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
                  : const Icon(Icons.save),
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
