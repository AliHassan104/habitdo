import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitdo/presentation/shared/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';
// Add these imports
import 'package:habitdo/core/utils/error_handler.dart';
import 'package:habitdo/core/utils/loading_widget.dart';

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
    _daysPerWeekController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _daysPerWeekController = TextEditingController(
    text: '3',
  ); // Default 3 days per week
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
    if (currentUser == null) {
      ErrorHandler.showErrorSnackbar(
        'Authentication Error',
        'Please sign in to continue',
      );
      context.go('/signin');
      return;
    }
    super.initState();

    // Initialize with passed data if available
    if (widget.existingTitle != null) {
      _titleController.text = widget.existingTitle!;
    }
    if (widget.existingDescription != null) {
      _descriptionController.text = widget.existingDescription!;
    }

    if (widget.habitId != null) {
      _loadExistingHabit();
    }
  }

  /// Load existing habit data with error handling
  Future<void> _loadExistingHabit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Handle unauthenticated state (optional)
        return;
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('habits')
              .doc(widget.habitId)
              .get();

      if (!doc.exists) {
        if (mounted) {
          ErrorHandler.showErrorDialog(
            context,
            title: 'Habit Not Found',
            message: 'The habit you\'re trying to edit no longer exists.',
            onCancel: () => context.go('/home'),
          );
        }
        return;
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('Habit data is empty');
      }

      if (mounted) {
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _categoryController.text = data['category'] ?? '';
          _targetValueController.text = (data['targetValue'] ?? '').toString();
          _targetUnitController.text = (data['targetUnit'] ?? '').toString();
          _repeatType = data['repeatType'] ?? 'Repeat Till Done';
          _priority = data['priority'] ?? 'Medium';
          _daysPerWeekController.text = (data['daysPerWeek'] ?? 3).toString();

          // Handle dates safely
          try {
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
          } catch (e) {
            ErrorHandler.logError(e, context: 'Date parsing in initState');
            // Reset dates on parsing error
            _selectedDate = null;
            _startDate = null;
            _endDate = null;
          }

          _selectedDays = List<String>.from(data['selectedDays'] ?? []);
          _notificationsEnabled = data['notificationsEnabled'] ?? false;

          // Handle notification time safely
          try {
            if (data['notificationTime'] != null) {
              final parts = (data['notificationTime'] as String).split(':');
              if (parts.length == 2) {
                _notificationTime = TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                );
              }
            }
          } catch (e) {
            ErrorHandler.logError(e, context: 'Notification time parsing');
            _notificationTime = null;
          }
        });
      }
    } on FirebaseException catch (e) {
      ErrorHandler.logError(e, context: 'LoadExistingHabit - Firebase');
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          title: 'Loading Error',
          message: ErrorHandler.handleFirestoreError(e),
          onRetry: _loadExistingHabit,
          onCancel: () => context.go('/home'),
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'LoadExistingHabit - General');
      if (mounted) {
        ErrorHandler.showErrorDialog(
          context,
          title: 'Loading Failed',
          message:
              'Failed to load habit data: ${ErrorHandler.handleGeneralError(e)}',
          onRetry: _loadExistingHabit,
          onCancel: () => context.go('/home'),
        );
      }
    }
  }

  void _saveHabit() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final category = _categoryController.text.trim();
      final targetValue = _targetValueController.text.trim();
      final targetUnit = _targetUnitController.text.trim();

      final titleValidation = Validation.validateRequired(title, 'Title');
      if (titleValidation != null) {
        ErrorHandler.showErrorSnackbar('Validation Error', titleValidation);
        return;
      }

      double? parsedTargetValue;

      // ✅ Only validate and parse target for Weekly & Weekly Flexible
      if (_repeatType == 'Weekly' || _repeatType == 'Weekly Flexible') {
        final targetValidation = Validation.validateRequired(
          targetValue,
          'Target value',
        );
        if (targetValidation != null) {
          ErrorHandler.showErrorSnackbar('Validation Error', targetValidation);
          return;
        }

        parsedTargetValue = double.tryParse(targetValue);
        if (parsedTargetValue == null || parsedTargetValue <= 0) {
          ErrorHandler.showErrorSnackbar(
            'Validation Error',
            'Target value must be a positive number',
          );
          return;
        }
      } else {
        // ✅ For Repeat Till Done, use a default target of 1 if left empty
        parsedTargetValue =
            targetValue.isEmpty ? 1.0 : (double.tryParse(targetValue) ?? 1.0);
      }

      // Validate repeat type specific requirements
      if (_repeatType == 'Weekly' && _selectedDays.isEmpty) {
        ErrorHandler.showErrorSnackbar(
          'Validation Error',
          'Please select at least one day for weekly habits',
        );
        return;
      }

      if (_repeatType == 'Repeat Till Done' && _selectedDate == null) {
        ErrorHandler.showErrorSnackbar(
          'Validation Error',
          'Please select a target date for "Repeat Till Done" habits',
        );
        return;
      }

      if ((_repeatType == 'Weekly' || _repeatType == 'Weekly Flexible') &&
          (_startDate == null || _endDate == null)) {
        ErrorHandler.showErrorSnackbar(
          'Validation Error',
          'Please select both start and end dates for weekly habits',
        );
        return;
      }

      if ((_repeatType == 'Weekly' || _repeatType == 'Weekly Flexible') &&
          _endDate!.isBefore(_startDate!)) {
        ErrorHandler.showErrorSnackbar(
          'Validation Error',
          'End date must be after start date',
        );
        return;
      }

      if (_repeatType == 'Weekly Flexible') {
        final daysPerWeek = int.tryParse(_daysPerWeekController.text) ?? 0;
        if (daysPerWeek < 1 || daysPerWeek > 7) {
          ErrorHandler.showErrorSnackbar(
            'Validation Error',
            'Days per week must be between 1 and 7',
          );
          return;
        }
      }

      // Check authentication
      if (currentUser == null) {
        ErrorHandler.showErrorSnackbar(
          'Authentication Error',
          'Please sign in to continue',
        );
        context.go('/signin');
        return;
      }

      // Show loading dialog for long operations
      if (mounted) {
        ErrorHandler.showLoadingDialog(
          context,
          message:
              widget.habitId == null
                  ? 'Creating habit...'
                  : 'Updating habit...',
        );
      }

      final habitData = {
        'title': title,
        'description': description.isEmpty ? null : description,
        'category': category.isEmpty ? null : category,
        'priority': _priority,
        'repeatType': _repeatType,
        'targetValue': parsedTargetValue,
        'targetUnit': targetUnit.isEmpty ? 'times' : targetUnit,
        'uid': currentUser?.uid,
        'dailyCompletion': {},
        'isCompleted': false,
        'notificationsEnabled': _notificationsEnabled,
        'notificationTime':
            _notificationTime != null
                ? '${_notificationTime!.hour}:${_notificationTime!.minute}'
                : null,
      };

      // Add dates and days based on repeat type
      if (_repeatType == 'Repeat Till Done') {
        habitData['selectedDate'] = Timestamp.fromDate(_selectedDate!);
        habitData['selectedDays'] = [];
        habitData['startDate'] = null;
        habitData['endDate'] = null;
        habitData['daysPerWeek'] = null;
      } else if (_repeatType == 'Weekly') {
        habitData['selectedDays'] = _selectedDays;
        habitData['startDate'] = Timestamp.fromDate(_startDate!);
        habitData['endDate'] = Timestamp.fromDate(_endDate!);
        habitData['selectedDate'] = null;
        habitData['daysPerWeek'] = null;
      } else if (_repeatType == 'Weekly Flexible') {
        habitData['selectedDays'] = [];
        habitData['startDate'] = Timestamp.fromDate(_startDate!);
        habitData['endDate'] = Timestamp.fromDate(_endDate!);
        habitData['selectedDate'] = null;
        habitData['daysPerWeek'] =
            int.tryParse(_daysPerWeekController.text) ?? 3;
      }

      // Perform Firestore operation
      if (widget.habitId == null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // Handle unauthenticated state (optional)
          return;
        }

        habitData['createdAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('habits')
            .add(habitData);

        ErrorHandler.showSuccessSnackbar(
          'Success',
          'Habit created successfully',
        );
        ErrorHandler.logError(
          'Habit created successfully',
          context: 'CreateHabit',
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // Handle unauthenticated state (optional)
          return;
        }

        habitData['updatedAt'] = Timestamp.now();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('habits')
            .doc(widget.habitId)
            .update(habitData);

        ErrorHandler.showSuccessSnackbar(
          'Success',
          'Habit updated successfully',
        );
        ErrorHandler.logError(
          'Habit updated successfully',
          context: 'UpdateHabit',
        );
      }

      // Hide loading dialog and navigate
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        context.go('/home');
      }
    } on FirebaseException catch (e) {
      ErrorHandler.logError(e, context: 'SaveHabit - Firebase');
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        ErrorHandler.showErrorDialog(
          context,
          title: 'Database Error',
          message: ErrorHandler.handleFirestoreError(e),
          onRetry: _saveHabit,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'SaveHabit - General');
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        ErrorHandler.showErrorDialog(
          context,
          title: 'Save Failed',
          message: ErrorHandler.handleGeneralError(e),
          onRetry: _saveHabit,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    try {
      if (!mounted) return;

      if (isError) {
        ErrorHandler.showErrorSnackbar('Error', message);
      } else {
        ErrorHandler.showSuccessSnackbar('Success', message);
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ShowSnackBar');
      // Fallback to basic snackbar if ErrorHandler fails
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
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
    } else if (_repeatType == 'Weekly Flexible') {
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
          // Days per week input
          CustomTextField(
            controller: _daysPerWeekController,
            hintText: 'How many days per week?',
            labelText: 'Days per Week',
            prefixIcon: Icons.calendar_view_week,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'You can complete this habit on any ${_daysPerWeekController.text.isNotEmpty ? _daysPerWeekController.text : "X"} days of the week',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
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
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          120,
        ), // Increased bottom padding
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
              hintText: 'Description (optional)',
              labelText: 'Description',
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
                    child: Text('Weekly (Specific Days)'),
                  ),
                  DropdownMenuItem(
                    value: 'Weekly Flexible',
                    child: Text('Weekly Flexible (Any Days)'),
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
              labelText: 'Target Unit',
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
            const SizedBox(height: 24),
          ],
        ),
      ),
      // FIXED: Better positioned floating action button
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Save/Update Button
          // Replace your save FloatingActionButton with:
          FloatingActionButton.extended(
            onPressed: _isSaving ? null : _saveHabit,
            heroTag: "save_button",
            icon:
                _isSaving
                    ? LoadingWidget.button(color: Colors.white, size: 20)
                    : const Icon(Icons.save),
            label: Text(
              _isSaving
                  ? (isEditing ? 'Updating...' : 'Saving...')
                  : (isEditing ? 'Update Habit' : 'Save Habit'),
            ),
            backgroundColor:
                _isSaving ? Colors.grey : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          // Delete Button (for editing only)
          if (isEditing) ...[
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              // Replace the delete button onPressed in your FloatingActionButton with:
              onPressed: () async {
                try {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Text('Delete Habit'),
                            ],
                          ),
                          content: const Text(
                            'Are you sure you want to delete this habit? This action cannot be undone and all progress data will be lost.',
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
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true && mounted) {
                    // Show loading dialog
                    ErrorHandler.showLoadingDialog(
                      context,
                      message: 'Deleting habit...',
                    );

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        // Handle unauthenticated state (optional)
                        return;
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser!.uid)
                          .collection('habits')
                          .doc(widget.habitId)
                          .delete();

                      if (mounted) {
                        ErrorHandler.hideLoadingDialog(context);
                        ErrorHandler.showSuccessSnackbar(
                          'Success',
                          'Habit deleted successfully',
                        );
                        context.go('/home');
                      }
                    } on FirebaseException catch (e) {
                      ErrorHandler.logError(
                        e,
                        context: 'DeleteHabit - Firebase',
                      );
                      if (mounted) {
                        ErrorHandler.hideLoadingDialog(context);
                        ErrorHandler.showErrorDialog(
                          context,
                          title: 'Delete Failed',
                          message: ErrorHandler.handleFirestoreError(e),
                          onRetry: () async {
                            // Retry delete operation
                            try {
                              ErrorHandler.showLoadingDialog(
                                context,
                                message: 'Retrying delete...',
                              );
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                // Handle unauthenticated state (optional)
                                return;
                              }

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('habits')
                                  .doc(widget.habitId)
                                  .delete();
                              if (mounted) {
                                ErrorHandler.hideLoadingDialog(context);
                                ErrorHandler.showSuccessSnackbar(
                                  'Success',
                                  'Habit deleted successfully',
                                );
                                context.go('/home');
                              }
                            } catch (retryError) {
                              if (mounted) {
                                ErrorHandler.hideLoadingDialog(context);
                                ErrorHandler.showErrorSnackbar(
                                  'Error',
                                  'Failed to delete habit',
                                );
                              }
                            }
                          },
                        );
                      }
                    } catch (e) {
                      ErrorHandler.logError(
                        e,
                        context: 'DeleteHabit - General',
                      );
                      if (mounted) {
                        ErrorHandler.hideLoadingDialog(context);
                        ErrorHandler.showErrorDialog(
                          context,
                          title: 'Delete Failed',
                          message: ErrorHandler.handleGeneralError(e),
                        );
                      }
                    }
                  }
                } catch (e) {
                  ErrorHandler.logError(e, context: 'DeleteHabit - Dialog');
                  ErrorHandler.showErrorSnackbar(
                    'Error',
                    'Failed to show delete confirmation',
                  );
                }
              },
              heroTag: "delete_button", // Unique hero tag
              icon: const Icon(Icons.delete),
              label: const Text('Delete Habit'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ],
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
