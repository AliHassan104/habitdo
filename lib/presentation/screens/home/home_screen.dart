import 'package:flutter/material.dart';
import 'package:habitdo/presentation/app/app_router.dart';
import 'package:habitdo/presentation/shared/widgets/bottom_navigation.dart';
import 'package:habitdo/presentation/shared/widgets/common_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
// Add these imports for error handling
import 'package:habitdo/core/utils/error_handler.dart';
import 'package:habitdo/core/utils/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(
    initialPage: DateTime.now().day - 1,
    viewportFraction: 0.2,
  );
  final User? currentUser = FirebaseAuth.instance.currentUser;
  DateTime _selectedDate = DateTime.now();

  // Error handling state
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Initialize with today's date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });

    // Check authentication state
    _checkAuthState();
  }

  /// Check if user is authenticated
  void _checkAuthState() {
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorHandler.showErrorSnackbar(
          'Authentication Required',
          'Please sign in to continue',
        );
        context.go('/signin');
      });
    }
  }

  /// Handle errors and show appropriate UI
  void _handleError(dynamic error, {String? context}) {
    setState(() {
      _hasError = true;
      _errorMessage = ErrorHandler.handleGeneralError(error);
      _isLoading = false;
    });

    ErrorHandler.logError(error, context: context ?? 'HomeScreen');
    ErrorHandler.showErrorSnackbar('Error', _errorMessage!);
  }

  /// Reset error state
  void _resetError() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
  }

  /// Refresh data and handle errors
  Future<void> _refreshData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Force rebuild of StreamBuilder by creating a small delay
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() => _isLoading = false);
    } catch (error) {
      _handleError(error, context: 'RefreshData');
    }
  }

  void _scrollToSelectedDate() {
    try {
      final index = _selectedDate.day - 1;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (error) {
      ErrorHandler.logError(error, context: 'ScrollToSelectedDate');
      // Don't show snackbar for scroll errors as they're not critical
    }
  }

  List<DocumentSnapshot> _getHabitsForDate(
    List<DocumentSnapshot> allHabits,
    DateTime date,
  ) {
    try {
      final dateWeekday =
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

      return allHabits.where((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;

          final repeatType = data['repeatType'];

          if (repeatType == 'Repeat Till Done') {
            final selectedDate = (data['selectedDate'] as Timestamp?)?.toDate();
            final isCompleted = data['isCompleted'] ?? false;

            // Show if target date is today or in the past AND not completed yet
            if (selectedDate != null && !isCompleted) {
              return selectedDate.isBefore(date.add(const Duration(days: 1))) ||
                  (selectedDate.year == date.year &&
                      selectedDate.month == date.month &&
                      selectedDate.day == date.day);
            }
            return false;
          } else if (repeatType == 'Weekly') {
            final selectedDays = List<String>.from(data['selectedDays'] ?? []);
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();

            // Check if date is within the range and on the selected weekday
            if (startDate != null &&
                endDate != null &&
                selectedDays.contains(dateWeekday)) {
              return date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  date.isBefore(endDate.add(const Duration(days: 1)));
            }
          } else if (repeatType == 'Weekly Flexible') {
            // Handle Weekly Flexible - show on any day within the date range
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();

            if (startDate != null && endDate != null) {
              return date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  date.isBefore(endDate.add(const Duration(days: 1)));
            }
          }

          return false;
        } catch (error) {
          ErrorHandler.logError(
            error,
            context: 'GetHabitsForDate - Document ${doc.id}',
          );
          return false; // Skip this document if there's an error
        }
      }).toList();
    } catch (error) {
      ErrorHandler.logError(error, context: 'GetHabitsForDate');
      return []; // Return empty list on error
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDateSelector() {
    try {
      final lastDayOfMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
      );
      final totalDays = lastDayOfMonth.day;
      final today = DateTime.now();

      return SizedBox(
        height: 100,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            try {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  index + 1,
                );
              });
            } catch (error) {
              ErrorHandler.logError(error, context: 'PageView onPageChanged');
            }
          },
          itemCount: totalDays,
          itemBuilder: (context, index) {
            try {
              final date = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                index + 1,
              );
              final isSelected = _selectedDate.day == date.day;
              final isToday =
                  today.year == date.year &&
                  today.month == date.month &&
                  today.day == date.day;
              final isPast = date.isBefore(today);
              final isFuture = date.isAfter(today);

              return GestureDetector(
                onTap: () {
                  try {
                    setState(() {
                      _selectedDate = date;
                      _scrollToSelectedDate();
                    });
                  } catch (error) {
                    ErrorHandler.logError(error, context: 'Date selection tap');
                  }
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(context).primaryColor
                            : isToday
                            ? Colors.blue.shade100
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isToday
                              ? Colors.blue
                              : isPast
                              ? Colors.grey.shade400
                              : isFuture
                              ? Colors.grey.shade300
                              : Colors.grey.shade300,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E().format(date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isPast
                                  ? Colors.grey.shade600
                                  : Colors.black,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isPast
                                  ? Colors.grey.shade600
                                  : Colors.black,
                        ),
                      ),
                      if (isPast)
                        Icon(
                          Icons.history,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                      if (isFuture)
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                    ],
                  ),
                ),
              );
            } catch (error) {
              ErrorHandler.logError(
                error,
                context: 'Date selector item builder',
              );
              return const SizedBox(
                width: 60,
              ); // Return empty container on error
            }
          },
        ),
      );
    } catch (error) {
      ErrorHandler.logError(error, context: 'BuildDateSelector');
      return const SizedBox(height: 100); // Return empty container on error
    }
  }

  Widget _buildHabitCard(
    DocumentSnapshot habit,
    String formattedDate,
    bool isPastDate,
  ) {
    try {
      final data = habit.data() as Map<String, dynamic>?;
      if (data == null) {
        return const SizedBox.shrink();
      }

      final title = data['title'] ?? '';
      final description = data['description'] ?? '';
      final category = data['category'] ?? '';
      final priority = data['priority'] ?? 'Medium';
      final repeatType = data['repeatType'] ?? '';
      final dailyCompletion = data['dailyCompletion'] ?? {};
      final entry = dailyCompletion[formattedDate];
      final isCompletedForever =
          data['isCompleted'] ?? false; // For "Repeat Till Done"

      double value = 0;
      double target = (data['targetValue'] ?? 0).toDouble();
      String targetUnit = data['targetUnit'] ?? '';

      if (entry is Map<String, dynamic>) {
        value = (entry['value'] ?? 0).toDouble();
      }

      bool isMeasurable = target > 0;
      bool isCompleted = false;

      if (repeatType == 'Repeat Till Done') {
        isCompleted = isCompletedForever;
      } else {
        isCompleted = isMeasurable ? value >= target : (entry == true);
      }

      // Calculate overall progress for this habit
      double overallProgress = 0.0;
      if (repeatType == 'Weekly' || repeatType == 'Weekly Flexible') {
        try {
          int completedDays = 0;
          int totalValidDays = 0;

          dailyCompletion.forEach((key, value) {
            try {
              final date = DateTime.tryParse(key);
              if (date != null) {
                final startDate = (data['startDate'] as Timestamp?)?.toDate();
                final endDate = (data['endDate'] as Timestamp?)?.toDate();

                if (startDate != null &&
                    endDate != null &&
                    date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                    date.isBefore(endDate.add(const Duration(days: 1)))) {
                  // For Weekly Flexible, count all days in range
                  // For Weekly, only count selected weekdays
                  bool shouldCount = true;
                  if (repeatType == 'Weekly') {
                    final selectedDays = List<String>.from(
                      data['selectedDays'] ?? [],
                    );
                    final weekday =
                        [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ][date.weekday - 1];
                    shouldCount = selectedDays.contains(weekday);
                  }

                  if (shouldCount) {
                    totalValidDays++;

                    if (value is Map<String, dynamic>) {
                      final achieved = (value['value'] ?? 0).toDouble();
                      final target = (value['target'] ?? 1).toDouble();
                      if (achieved >= target) completedDays++;
                    } else if (value == true) {
                      completedDays++;
                    }
                  }
                }
              }
            } catch (error) {
              ErrorHandler.logError(
                error,
                context: 'Progress calculation for date $key',
              );
            }
          });

          overallProgress =
              totalValidDays > 0 ? completedDays / totalValidDays : 0.0;
        } catch (error) {
          ErrorHandler.logError(error, context: 'Overall progress calculation');
          overallProgress = 0.0;
        }
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 2,
        child: InkWell(
          onTap: () {
            try {
              context.goNamed(
                AppRoutes.addEdit,
                extra: {
                  'habitId': habit.id,
                  'existingTitle': title,
                  'existingDescription': description,
                },
              );
            } catch (error) {
              _handleError(error, context: 'Navigate to edit habit');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title, category, and priority
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flag,
                                color: _getPriorityColor(priority),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    decoration:
                                        isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (category.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Type indicator with enhanced labels
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            repeatType == 'Repeat Till Done'
                                ? Colors.purple.shade100
                                : repeatType == 'Weekly Flexible'
                                ? Colors.teal.shade100
                                : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        repeatType == 'Repeat Till Done'
                            ? 'Till Done'
                            : repeatType == 'Weekly Flexible'
                            ? 'Flexible'
                            : 'Weekly',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              repeatType == 'Repeat Till Done'
                                  ? Colors.purple.shade700
                                  : repeatType == 'Weekly Flexible'
                                  ? Colors.teal.shade700
                                  : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress section
                Row(
                  children: [
                    // Input section for measurable habits
                    if (isMeasurable && !isCompletedForever)
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                initialValue: value.toInt().toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabled: true, // Allow editing for any date
                                ),
                                onFieldSubmitted: (newVal) async {
                                  try {
                                    final parsed =
                                        double.tryParse(newVal) ?? 0.0;
                                    final newValue = parsed < 0 ? 0.0 : parsed;

                                    // Update Firestore
                                    Map<String, dynamic> updateData = {
                                      'dailyCompletion.$formattedDate': {
                                        'value': newValue,
                                        'target': target,
                                      },
                                    };

                                    // For "Repeat Till Done", mark as completed if target is met
                                    if (repeatType == 'Repeat Till Done' &&
                                        newValue >= target) {
                                      updateData['isCompleted'] = true;
                                    }

                                    await FirebaseFirestore.instance
                                        .collection('habits')
                                        .doc(habit.id)
                                        .update(updateData);

                                    setState(() {});

                                    ErrorHandler.showSuccessSnackbar(
                                      'Updated',
                                      'Progress saved successfully',
                                    );
                                  } catch (error) {
                                    _handleError(
                                      error,
                                      context: 'Update habit progress',
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "/ ${target.toInt()} $targetUnit",
                              style: const TextStyle(fontSize: 14),
                            ),
                            // Show exceeded indicator if value > target
                            if (value > target)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "+${(value - target).toInt()}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // For "Repeat Till Done" completed habits
                    if (repeatType == 'Repeat Till Done' && isCompletedForever)
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Completed!",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                try {
                                  // Allow unmarking completion
                                  await FirebaseFirestore.instance
                                      .collection('habits')
                                      .doc(habit.id)
                                      .update({'isCompleted': false});

                                  ErrorHandler.showInfoSnackbar(
                                    'Updated',
                                    'Habit marked as incomplete',
                                  );
                                } catch (error) {
                                  _handleError(
                                    error,
                                    context: 'Unmark habit completion',
                                  );
                                }
                              },
                              child: Text(
                                "Undo",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Progress indicator - Cap at 100% for display but allow higher values
                    CircularPercentIndicator(
                      radius: 25,
                      lineWidth: 5.0,
                      percent:
                          isMeasurable
                              ? (value / target).clamp(
                                0.0,
                                1.0,
                              ) // Cap display at 100%
                              : (repeatType == 'Weekly' ||
                                      repeatType == 'Weekly Flexible'
                                  ? overallProgress
                                  : (isCompleted ? 1.0 : 0.0)),
                      center: Text(
                        isMeasurable
                            ? "${((value / target) * 100).clamp(0, 100).toStringAsFixed(0)}%"
                            : (repeatType == 'Weekly' ||
                                    repeatType == 'Weekly Flexible'
                                ? "${(overallProgress * 100).toStringAsFixed(0)}%"
                                : (isCompleted ? "✓" : "0%")),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      progressColor: isCompleted ? Colors.green : Colors.blue,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ],
                ),

                // Show weekly flexible progress info
                if (repeatType == 'Weekly Flexible')
                  Builder(
                    builder: (context) {
                      try {
                        final daysPerWeek = data['daysPerWeek'] ?? 3;
                        final startDate =
                            (data['startDate'] as Timestamp?)?.toDate();
                        final endDate =
                            (data['endDate'] as Timestamp?)?.toDate();

                        if (startDate != null && endDate != null) {
                          // Calculate current week progress
                          final now = DateTime.now();
                          final weekStart = now.subtract(
                            Duration(days: now.weekday - 1),
                          );
                          final weekEnd = weekStart.add(
                            const Duration(days: 6),
                          );

                          int completedThisWeek = 0;
                          for (int i = 0; i < 7; i++) {
                            final day = weekStart.add(Duration(days: i));
                            final dayString = DateFormat(
                              'yyyy-MM-dd',
                            ).format(day);
                            final dayEntry = dailyCompletion[dayString];

                            if (dayEntry != null) {
                              if (dayEntry is bool && dayEntry) {
                                completedThisWeek++;
                              } else if (dayEntry is Map<String, dynamic>) {
                                final achieved =
                                    (dayEntry['value'] ?? 0).toDouble();
                                if (achieved >= target) completedThisWeek++;
                              }
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_view_week,
                                    size: 14,
                                    color: Colors.teal.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "This week: $completedThisWeek/$daysPerWeek days",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      } catch (error) {
                        ErrorHandler.logError(
                          error,
                          context: 'Weekly flexible progress widget',
                        );
                        return const SizedBox.shrink();
                      }
                    },
                  ),

                // Show backlog indicator for overdue "Repeat Till Done" habits
                if (repeatType == 'Repeat Till Done' && !isCompletedForever)
                  Builder(
                    builder: (context) {
                      try {
                        final targetDate =
                            (data['selectedDate'] as Timestamp?)?.toDate();
                        final today = DateTime.now();

                        if (targetDate != null && targetDate.isBefore(today)) {
                          final daysPast = today.difference(targetDate).inDays;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Overdue by $daysPast day${daysPast > 1 ? 's' : ''}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      } catch (error) {
                        ErrorHandler.logError(
                          error,
                          context: 'Overdue indicator widget',
                        );
                        return const SizedBox.shrink();
                      }
                    },
                  ),

                // Show description if available
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      ErrorHandler.logError(error, context: 'Build habit card for ${habit.id}');
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(child: Text('Error loading habit')),
              TextButton(
                onPressed: () => setState(() {}), // Trigger rebuild
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isPastDate = _selectedDate.isBefore(
      DateTime(today.year, today.month, today.day),
    );

    return Scaffold(
      appBar: CommonAppBar(
        title: 'HabitDo',
        showHome: true,
        onCalendarTap: () async {
          try {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
                _scrollToSelectedDate();
              });
            }
          } catch (error) {
            _handleError(error, context: 'Date picker');
          }
        },
      ),
      body: BottomNavScaffold(
        selectedIndex: 0,
        showHome: true,
        child: Column(
          children: [
            // Month/Year header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      try {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month - 1,
                          );
                          _pageController.animateToPage(
                            _selectedDate.day - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        });
                      } catch (error) {
                        _handleError(
                          error,
                          context: 'Previous month navigation',
                        );
                      }
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    DateFormat.yMMMM().format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      try {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month + 1,
                          );
                          _pageController.animateToPage(
                            _selectedDate.day - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        });
                      } catch (error) {
                        _handleError(error, context: 'Next month navigation');
                      }
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            // Horizontal Scrollable Date Picker
            _buildDateSelector(),

            // Selected date info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Error display with retry option
            if (_hasError && _errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                child: Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Something went wrong',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _resetError();
                            _refreshData();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),

            // Habits List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('habits')
                        .where('uid', isEqualTo: currentUser?.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  // Handle loading state
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_hasError) {
                    return LoadingWidget.overlay(
                      isLoading: true,
                      loadingText: 'Loading your habits...',
                      child: HabitLoadingWidgets.habitList(),
                    );
                  }

                  // Handle stream errors
                  if (snapshot.hasError) {
                    final errorMessage = ErrorHandler.handleGeneralError(
                      snapshot.error,
                    );
                    ErrorHandler.logError(
                      snapshot.error,
                      context: 'Habits StreamBuilder',
                    );

                    return LoadingWidget.emptyState(
                      title: 'Failed to load habits',
                      subtitle: errorMessage,
                      icon: Icons.error_outline,
                      onRetry: _refreshData,
                      retryText: 'Retry',
                    );
                  }

                  // Handle no data
                  if (!snapshot.hasData) {
                    return LoadingWidget.emptyState(
                      title: 'No connection',
                      subtitle: 'Unable to connect to the database',
                      icon: Icons.cloud_off,
                      onRetry: _refreshData,
                    );
                  }

                  // Handle empty data
                  if (snapshot.data!.docs.isEmpty) {
                    return LoadingWidget.emptyState(
                      title: 'No habits yet!',
                      subtitle: 'Tap + to create your first habit',
                      icon: Icons.add_task,
                    );
                  }

                  try {
                    final habits = _getHabitsForDate(
                      snapshot.data!.docs,
                      _selectedDate,
                    );
                    final formattedDate = DateFormat(
                      'yyyy-MM-dd',
                    ).format(_selectedDate);

                    if (habits.isEmpty) {
                      return LoadingWidget.emptyState(
                        title: 'No habits for this date',
                        subtitle: 'Select another date or create new habits',
                        icon: Icons.event_available,
                      );
                    }

                    // Calculate stats - Only count up to 100% per habit for overall progress
                    int totalHabits = habits.length;
                    int completedHabits = 0;
                    double totalProgress = 0;

                    for (var habit in habits) {
                      try {
                        final data = habit.data() as Map<String, dynamic>?;
                        if (data == null) continue;

                        final repeatType = data['repeatType'];
                        final dailyCompletion = data['dailyCompletion'] ?? {};
                        final entry = dailyCompletion[formattedDate];
                        final target = (data['targetValue'] ?? 0).toDouble();

                        if (repeatType == 'Repeat Till Done') {
                          final isCompleted = data['isCompleted'] ?? false;
                          if (isCompleted) {
                            completedHabits++;
                            totalProgress += 1.0;
                          }
                        } else {
                          if (entry is Map<String, dynamic>) {
                            final value = (entry['value'] ?? 0).toDouble();
                            // Cap individual habit progress at 1.0 (100%) for overall calculation
                            final progress =
                                target > 0
                                    ? (value / target).clamp(0.0, 1.0)
                                    : 0.0;
                            totalProgress += progress;
                            if (value >= target)
                              completedHabits++; // Mark as completed if target met
                          }
                        }
                      } catch (error) {
                        ErrorHandler.logError(
                          error,
                          context: 'Stats calculation for habit ${habit.id}',
                        );
                      }
                    }

                    final overallProgress =
                        totalHabits > 0 ? totalProgress / totalHabits : 0.0;

                    return RefreshIndicator(
                      onRefresh: _refreshData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Progress summary
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Today\'s Progress',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$completedHabits of $totalHabits habits completed',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CircularPercentIndicator(
                                      radius: 30,
                                      lineWidth: 6.0,
                                      percent: overallProgress,
                                      center: Text(
                                        "${(overallProgress * 100).toStringAsFixed(0)}%",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      progressColor:
                                          overallProgress > 0.7
                                              ? Colors.green
                                              : Colors.blue,
                                      backgroundColor: Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Habits list
                            ...habits.map(
                              (habit) => _buildHabitCard(
                                habit,
                                formattedDate,
                                isPastDate,
                              ),
                            ),

                            const SizedBox(height: 80), // Bottom padding
                          ],
                        ),
                      ),
                    );
                  } catch (error) {
                    ErrorHandler.logError(error, context: 'Build habits list');
                    return LoadingWidget.emptyState(
                      title: 'Error displaying habits',
                      subtitle:
                          'Something went wrong while loading your habits',
                      icon: Icons.error_outline,
                      onRetry: _refreshData,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button with error handling
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          try {
            context.goNamed(AppRoutes.addEdit);
          } catch (error) {
            _handleError(error, context: 'Navigate to add habit');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _pageController.dispose();
    } catch (error) {
      ErrorHandler.logError(error, context: 'HomeScreen dispose');
    }
    super.dispose();
  }
}
