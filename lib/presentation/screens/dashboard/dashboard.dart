import 'package:flutter/material.dart';
import 'package:habitdo/presentation/shared/widgets/bottom_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Add these imports
import 'package:habitdo/core/utils/error_handler.dart';
import 'package:habitdo/core/utils/loading_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = false;
  String? _errorMessage;

  // Selected Period Type - Default to Week for better granular view
  String _selectedPeriod = "Week";

  // Anchor date (today or user-picked date)
  DateTime _anchorDate = DateTime.now();

  // Enhanced period options with better ordering
  final List<String> _periodOptions = [
    "Week",
    "Month",
    "Quarter",
    "Half Year",
    "Year",
  ];

  // Helper method to get icon for period
  IconData _getPeriodIcon(String period) {
    switch (period) {
      case "Week":
        return Icons.view_week;
      case "Month":
        return Icons.calendar_view_month;
      case "Quarter":
        return Icons.calendar_view_day;
      case "Half Year":
        return Icons.date_range;
      case "Year":
        return Icons.calendar_today;
      default:
        return Icons.calendar_today;
    }
  }

  /// Get date range based on selectedPeriod
  Map<String, DateTime> _getDateRange() {
    DateTime start;
    DateTime end;

    switch (_selectedPeriod) {
      case "Week":
        start = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
        end = start.add(const Duration(days: 6));
        break;
      case "Quarter":
        int currentQuarter = ((_anchorDate.month - 1) ~/ 3) + 1;
        start = DateTime(_anchorDate.year, (currentQuarter - 1) * 3 + 1, 1);
        end = DateTime(_anchorDate.year, currentQuarter * 3 + 1, 0);
        break;
      case "Half Year":
        if (_anchorDate.month <= 6) {
          start = DateTime(_anchorDate.year, 1, 1);
          end = DateTime(_anchorDate.year, 6, 30);
        } else {
          start = DateTime(_anchorDate.year, 7, 1);
          end = DateTime(_anchorDate.year, 12, 31);
        }
        break;
      case "Year":
        start = DateTime(_anchorDate.year, 1, 1);
        end = DateTime(_anchorDate.year, 12, 31);
        break;
      case "Month":
      default:
        start = DateTime(_anchorDate.year, _anchorDate.month, 1);
        end = DateTime(_anchorDate.year, _anchorDate.month + 1, 0);
    }

    return {"start": start, "end": end};
  }

  // Replace your navigation methods with these error-handled versions:

  /// Navigate to previous period
  void _navigateToPreviousPeriod() {
    try {
      setState(() {
        switch (_selectedPeriod) {
          case "Week":
            _anchorDate = _anchorDate.subtract(const Duration(days: 7));
            break;
          case "Month":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month - 1,
              _anchorDate.day,
            );
            break;
          case "Quarter":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month - 3,
              _anchorDate.day,
            );
            break;
          case "Half Year":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month - 6,
              _anchorDate.day,
            );
            break;
          case "Year":
            _anchorDate = DateTime(
              _anchorDate.year - 1,
              _anchorDate.month,
              _anchorDate.day,
            );
            break;
        }
      });
    } catch (e) {
      ErrorHandler.logError(e, context: 'NavigateToPreviousPeriod');
      ErrorHandler.showErrorSnackbar(
        'Navigation Error',
        'Failed to navigate to previous period',
      );
    }
  }

  /// Navigate to next period
  void _navigateToNextPeriod() {
    try {
      setState(() {
        switch (_selectedPeriod) {
          case "Week":
            _anchorDate = _anchorDate.add(const Duration(days: 7));
            break;
          case "Month":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month + 1,
              _anchorDate.day,
            );
            break;
          case "Quarter":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month + 3,
              _anchorDate.day,
            );
            break;
          case "Half Year":
            _anchorDate = DateTime(
              _anchorDate.year,
              _anchorDate.month + 6,
              _anchorDate.day,
            );
            break;
          case "Year":
            _anchorDate = DateTime(
              _anchorDate.year + 1,
              _anchorDate.month,
              _anchorDate.day,
            );
            break;
        }
      });
    } catch (e) {
      ErrorHandler.logError(e, context: 'NavigateToNextPeriod');
      ErrorHandler.showErrorSnackbar(
        'Navigation Error',
        'Failed to navigate to next period',
      );
    }
  }

  /// Reset to current period
  void _resetToCurrentPeriod() {
    try {
      setState(() {
        _anchorDate = DateTime.now();
      });
    } catch (e) {
      ErrorHandler.logError(e, context: 'ResetToCurrentPeriod');
      ErrorHandler.showErrorSnackbar(
        'Navigation Error',
        'Failed to reset to current period',
      );
    }
  }

  /// Check if we're viewing current period
  bool _isCurrentPeriod() {
    final now = DateTime.now();
    final range = _getDateRange();
    final start = range["start"]!;
    final end = range["end"]!;

    return now.isAfter(start.subtract(const Duration(days: 1))) &&
        now.isBefore(end.add(const Duration(days: 1)));
  }

  /// Helper method to check if a habit is active on a specific date
  bool _isHabitActiveOnDate(Map<String, dynamic> data, DateTime date) {
    try {
      final repeatType = data['repeatType'];
      if (repeatType == null) return false;

      final selectedDays = List<String>.from(data['selectedDays'] ?? []);
      final weekday = DateFormat.E().format(date).substring(0, 3);

      switch (repeatType) {
        case 'Repeat Till Done':
          try {
            final selectedDate = (data['selectedDate'] as Timestamp?)?.toDate();
            if (selectedDate != null &&
                selectedDate.year == date.year &&
                selectedDate.month == date.month &&
                selectedDate.day == date.day) {
              return true;
            }
          } catch (e) {
            ErrorHandler.logError(e, context: 'RepeatTillDone date check');
            return false;
          }
          break;

        case 'Weekly':
          try {
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();

            if (startDate != null &&
                endDate != null &&
                selectedDays.contains(weekday) &&
                date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                date.isBefore(endDate.add(const Duration(days: 1)))) {
              return true;
            }
          } catch (e) {
            ErrorHandler.logError(e, context: 'Weekly date check');
            return false;
          }
          break;

        case 'Weekly Flexible':
          try {
            final startDate = (data['startDate'] as Timestamp?)?.toDate();
            final endDate = (data['endDate'] as Timestamp?)?.toDate();

            if (startDate != null &&
                endDate != null &&
                date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                date.isBefore(endDate.add(const Duration(days: 1)))) {
              return true;
            }
          } catch (e) {
            ErrorHandler.logError(e, context: 'WeeklyFlexible date check');
            return false;
          }
          break;

        default:
          ErrorHandler.logError(
            'Unknown repeat type: $repeatType',
            context: 'IsHabitActiveOnDate',
          );
          return false;
      }

      return false;
    } catch (e) {
      ErrorHandler.logError(e, context: 'IsHabitActiveOnDate - General');
      return false; // Return false instead of crashing
    }
  }

  /// Helper method to calculate weekly flexible completion
  Map<String, dynamic> _calculateWeeklyFlexibleProgress(
    Map<String, dynamic> data,
    DateTime start,
    DateTime end,
  ) {
    try {
      final completionMap = Map<String, dynamic>.from(
        data['dailyCompletion'] ?? {},
      );
      final daysPerWeek = (data['daysPerWeek'] as num?)?.toInt() ?? 3;
      final targetValue = (data['targetValue'] as num?)?.toDouble() ?? 1.0;

      // Group days by week and calculate completion
      Map<String, List<DateTime>> weeklyDates = {};
      int totalCompletedDays = 0;
      int totalPossibleDays = 0;
      double totalAchievedValue = 0;
      double totalTargetValue = 0;

      try {
        for (
          DateTime date = start;
          !date.isAfter(end);
          date = date.add(const Duration(days: 1))
        ) {
          if (_isHabitActiveOnDate(data, date)) {
            // Get the Monday of this week as the key
            final weekStart = date.subtract(Duration(days: date.weekday - 1));
            final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

            weeklyDates.putIfAbsent(weekKey, () => []);
            weeklyDates[weekKey]!.add(date);
          }
        }
      } catch (e) {
        ErrorHandler.logError(e, context: 'WeeklyFlexible - Date iteration');
        throw Exception('Failed to process weekly dates: ${e.toString()}');
      }

      // For each week, check how many days were completed vs target
      weeklyDates.forEach((weekKey, datesInWeek) {
        try {
          int completedInWeek = 0;
          int targetForWeek = daysPerWeek.clamp(0, datesInWeek.length);
          totalPossibleDays += targetForWeek;

          for (DateTime date in datesInWeek) {
            try {
              final dateString = DateFormat('yyyy-MM-dd').format(date);
              final entry = completionMap[dateString];
              totalTargetValue += targetValue;

              if (entry != null) {
                bool dayCompleted = false;
                if (entry is bool && entry) {
                  dayCompleted = true;
                } else if (entry is Map<String, dynamic>) {
                  final achievedValue =
                      (entry['value'] as num?)?.toDouble() ?? 0.0;
                  totalAchievedValue += achievedValue;
                  if (achievedValue >= targetValue) {
                    dayCompleted = true;
                  }
                }

                if (dayCompleted && completedInWeek < targetForWeek) {
                  completedInWeek++;
                }
              }
            } catch (e) {
              ErrorHandler.logError(
                e,
                context: 'WeeklyFlexible - Processing date $date',
              );
              // Continue with next date instead of failing
              continue;
            }
          }

          totalCompletedDays += completedInWeek;
        } catch (e) {
          ErrorHandler.logError(
            e,
            context: 'WeeklyFlexible - Processing week $weekKey',
          );
          // Continue with next week instead of failing
        }
      });

      return {
        'completedDays': totalCompletedDays,
        'totalDays': totalPossibleDays,
        'totalAchievedValue': totalAchievedValue,
        'totalTargetValue': totalTargetValue,
      };
    } catch (e) {
      ErrorHandler.logError(e, context: 'CalculateWeeklyFlexibleProgress');
      // Return safe default values instead of crashing
      return {
        'completedDays': 0,
        'totalDays': 0,
        'totalAchievedValue': 0.0,
        'totalTargetValue': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHabitData() async {
    if (currentUser == null) {
      ErrorHandler.showErrorSnackbar(
        'Authentication Error',
        'Please sign in to view dashboard',
      );
      return [];
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final range = _getDateRange();
      final start = range["start"]!;
      final end = range["end"]!;

      final snapshot = await FirebaseFirestore.instance
          .collection('habits')
          .where('uid', isEqualTo: currentUser?.uid)
          .get()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      final List<Map<String, dynamic>> habitSummaries = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data['dailyCompletion'] == null || data['title'] == null) {
            ErrorHandler.logError(
              'Skipping habit with missing data: ${doc.id}',
              context: 'FetchHabitData',
            );
            continue;
          }

          final completionMap = Map<String, dynamic>.from(
            data['dailyCompletion'],
          );
          final repeatType = data['repeatType'];

          int completedDays = 0;
          int totalDays = 0;
          double totalAchievedValue = 0;
          double totalTargetValue = 0;

          if (repeatType == 'Weekly Flexible') {
            // Use special calculation for weekly flexible habits
            try {
              final flexibleProgress = _calculateWeeklyFlexibleProgress(
                data,
                start,
                end,
              );
              completedDays = flexibleProgress['completedDays'];
              totalDays = flexibleProgress['totalDays'];
              totalAchievedValue = flexibleProgress['totalAchievedValue'];
              totalTargetValue = flexibleProgress['totalTargetValue'];
            } catch (e) {
              ErrorHandler.logError(
                e,
                context: 'Weekly flexible calculation for ${doc.id}',
              );
              // Skip this habit if calculation fails
              continue;
            }
          } else {
            // Standard calculation for other habit types
            try {
              final targetValue =
                  (data['targetValue'] as num?)?.toDouble() ?? 0.0;

              for (
                DateTime date = start;
                !date.isAfter(end);
                date = date.add(const Duration(days: 1))
              ) {
                if (_isHabitActiveOnDate(data, date)) {
                  totalDays++;
                  final dateString = DateFormat('yyyy-MM-dd').format(date);
                  final entry = completionMap[dateString];

                  if (entry != null) {
                    try {
                      if (entry is bool && entry) {
                        completedDays++;
                      } else if (entry is Map<String, dynamic>) {
                        final achievedValue =
                            (entry['value'] as num?)?.toDouble() ?? 0.0;
                        totalAchievedValue += achievedValue;
                        totalTargetValue += targetValue;

                        if (targetValue > 0 && achievedValue >= targetValue) {
                          completedDays++;
                        }
                      }
                    } catch (e) {
                      ErrorHandler.logError(
                        e,
                        context:
                            'Processing entry for date $dateString in habit ${doc.id}',
                      );
                    }
                  } else {
                    totalTargetValue += targetValue;
                  }
                }
              }
            } catch (e) {
              ErrorHandler.logError(
                e,
                context: 'Standard calculation for habit ${doc.id}',
              );
              // Skip this habit if calculation fails
              continue;
            }
          }

          if (totalDays > 0) {
            try {
              habitSummaries.add({
                'id': doc.id,
                'title': data['title'],
                'repeatType': repeatType,
                'completedDays': completedDays,
                'totalDays': totalDays,
                'completionPercent': (completedDays / totalDays * 100).clamp(
                  0,
                  100,
                ),
                'targetValue': data['targetValue'],
                'targetUnit': data['targetUnit'] ?? 'times',
                'totalAchievedValue': totalAchievedValue,
                'totalTargetValue': totalTargetValue,
                'daysPerWeek': data['daysPerWeek'],
              });
            } catch (e) {
              ErrorHandler.logError(
                e,
                context: 'Creating summary for habit ${doc.id}',
              );
            }
          }
        } catch (e) {
          ErrorHandler.logError(
            e,
            context: 'Processing habit document ${doc.id}',
          );
          // Continue with next habit instead of failing completely
          continue;
        }
      }

      try {
        habitSummaries.sort(
          (a, b) => b['completionPercent'].compareTo(a['completionPercent']),
        );
      } catch (e) {
        ErrorHandler.logError(e, context: 'Sorting habit summaries');
        // Don't fail if sorting fails
      }

      return habitSummaries;
    } on FirebaseException catch (e) {
      ErrorHandler.logError(e, context: 'FetchHabitData - Firebase');
      setState(() => _errorMessage = ErrorHandler.handleFirestoreError(e));
      ErrorHandler.showErrorSnackbar(
        'Database Error',
        ErrorHandler.handleFirestoreError(e),
      );
      return [];
    } catch (e) {
      ErrorHandler.logError(e, context: 'FetchHabitData - General');
      setState(() => _errorMessage = ErrorHandler.handleGeneralError(e));
      ErrorHandler.showErrorSnackbar(
        'Loading Error',
        ErrorHandler.handleGeneralError(e),
      );
      return [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      selectedIndex: 2,
      showHome: true,
      child: Column(
        children: [
          _buildAppBar(),
          _buildPeriodSelector(),
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null) _buildErrorWidget(),
          // Replace your existing FutureBuilder in the Expanded widget with:
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  setState(() {
                    _errorMessage = null;
                  });
                  await _fetchHabitData();
                } catch (e) {
                  ErrorHandler.logError(e, context: 'Dashboard refresh');
                  ErrorHandler.showErrorSnackbar(
                    'Refresh Error',
                    ErrorHandler.handleGeneralError(e),
                  );
                }
              },
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchHabitData(),
                builder: (context, snapshot) {
                  // Handle loading state
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_isLoading) {
                    return LoadingWidget.overlay(
                      isLoading: true,
                      loadingText: 'Loading dashboard data...',
                      child: Column(
                        children: [
                          HabitLoadingWidgets.dashboardStats(),
                          HabitLoadingWidgets.chart(),
                          Expanded(child: HabitLoadingWidgets.habitList()),
                        ],
                      ),
                    );
                  }

                  // Handle errors
                  if (snapshot.hasError) {
                    final errorMessage = ErrorHandler.handleGeneralError(
                      snapshot.error,
                    );
                    ErrorHandler.logError(
                      snapshot.error,
                      context: 'Dashboard FutureBuilder',
                    );

                    return LoadingWidget.emptyState(
                      title: 'Failed to load dashboard',
                      subtitle: errorMessage,
                      icon: Icons.error_outline,
                      onRetry: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      retryText: 'Retry',
                    );
                  }

                  final data = snapshot.data ?? [];

                  // Handle empty data
                  if (data.isEmpty && !_isLoading && _errorMessage == null) {
                    return LoadingWidget.emptyState(
                      title:
                          'No habit data for this ${_selectedPeriod.toLowerCase()}',
                      subtitle: 'Complete some habits to see your analytics',
                      icon: Icons.analytics_outlined,
                      onRetry: () => context.go('/home'),
                      retryText: 'Go to Habits',
                    );
                  }

                  // Handle error state from _fetchHabitData
                  if (_errorMessage != null) {
                    return LoadingWidget.emptyState(
                      title: 'Dashboard Error',
                      subtitle: _errorMessage!,
                      icon: Icons.error_outline,
                      onRetry: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      retryText: 'Retry',
                    );
                  }

                  // Success state - show dashboard content
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildStatsHeader(data)),
                      SliverToBoxAdapter(child: _buildPieChart(data)),
                      SliverToBoxAdapter(child: _buildHabitListHeader()),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          try {
                            return _buildHabitCard(data[index]);
                          } catch (e) {
                            ErrorHandler.logError(
                              e,
                              context: 'Building habit card at index $index',
                            );
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                title: const Text('Error loading habit'),
                                trailing: TextButton(
                                  onPressed: () => setState(() {}),
                                  child: const Text('Retry'),
                                ),
                              ),
                            );
                          }
                        }, childCount: data.length),
                      ),
                      // Add some bottom padding
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Dashboard",
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.home, color: Colors.white),
        onPressed: () => context.go('/home'),
        tooltip: 'Go to Home',
      ),
      // Replace your AppBar actions with:
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () async {
            try {
              setState(() {
                _anchorDate = DateTime.now();
                _errorMessage = null;
              });
              ErrorHandler.showInfoSnackbar(
                'Dashboard',
                'Refreshing dashboard data...',
              );
            } catch (e) {
              ErrorHandler.logError(e, context: 'Dashboard refresh button');
              ErrorHandler.showErrorSnackbar(
                'Error',
                'Failed to refresh dashboard',
              );
            }
          },
          tooltip: 'Refresh Dashboard',
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final range = _getDateRange();
    final start = range["start"]!;
    final end = range["end"]!;

    String dateRangeText;
    if (_selectedPeriod == "Week") {
      dateRangeText =
          "${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}";
    } else if (_selectedPeriod == "Month") {
      dateRangeText = DateFormat.yMMMM().format(start);
    } else if (_selectedPeriod == "Quarter") {
      int q = ((start.month - 1) ~/ 3) + 1;
      dateRangeText = "Q$q ${start.year}";
    } else if (_selectedPeriod == "Half Year") {
      dateRangeText =
          start.month == 1 ? "H1 ${start.year}" : "H2 ${start.year}";
    } else {
      dateRangeText = DateFormat.y().format(start);
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                items:
                    _periodOptions.map((period) {
                      return DropdownMenuItem<String>(
                        value: period,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPeriodIcon(period),
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(period),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPeriod = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _navigateToPreviousPeriod,
                icon: Icon(
                  Icons.chevron_left,
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      dateRangeText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!_isCurrentPeriod())
                      TextButton(
                        onPressed: _resetToCurrentPeriod,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.today, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Go to Current",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _navigateToNextPeriod,
                icon: Icon(
                  Icons.chevron_right,
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchHabitData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No habit data for this ${_selectedPeriod.toLowerCase()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some habits to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.add),
            label: const Text('Go to Habits'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox();

    final totalCompleted = data.fold<int>(
      0,
      (sum, item) => sum + ((item['completedDays'] ?? 0) as int),
    );
    final totalPossible = data.fold<int>(
      0,
      (sum, item) => sum + ((item['totalDays'] ?? 0) as int),
    );
    final overallPercentage =
        totalPossible > 0 ? (totalCompleted / totalPossible * 100).round() : 0;

    final bestHabit = data.isNotEmpty ? data.first : null;
    final activeHabits = data.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Theme.of(context).primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                'Performance Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    Icons.check_circle,
                    '$totalCompleted',
                    'Completed',
                    Colors.green,
                  ),
                  _buildStatItem(
                    Icons.calendar_today,
                    '$totalPossible',
                    'Total Days',
                    Colors.blue,
                  ),
                  _buildStatItem(
                    Icons.trending_up,
                    '$overallPercentage%',
                    'Success Rate',
                    _getCompletionColor(overallPercentage.toDouble()),
                  ),
                ],
              ),
              if (bestHabit != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      Icons.star,
                      '${bestHabit['completionPercent'].toStringAsFixed(0)}%',
                      'Top Habit',
                      Colors.amber,
                    ),
                    _buildStatItem(
                      Icons.format_list_bulleted,
                      '$activeHabits',
                      'Active Habits',
                      Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox();

    final totalPossible = data.fold<int>(
      0,
      (sum, item) => sum + ((item['totalDays'] ?? 0) as int),
    );
    if (totalPossible == 0) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Habit Completion Distribution',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.5,
                child: PieChart(
                  PieChartData(
                    sections: _buildChartSections(data),
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend(data),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(
    List<Map<String, dynamic>> data,
  ) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final habit = entry.value;
      final completed = habit['completedDays'].toDouble();
      final color = Colors.accents[index % Colors.accents.length];

      return PieChartSectionData(
        color: color,
        value: completed,
        radius: 25,
        title: '',
        showTitle: false,
      );
    }).toList();
  }

  Widget _buildChartLegend(List<Map<String, dynamic>> data) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children:
          data.asMap().entries.map((entry) {
            final index = entry.key;
            final habit = entry.value;
            final color = Colors.accents[index % Colors.accents.length];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  habit['title'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildHabitListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        'Your Habits',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHabitCard(Map<String, dynamic> habit) {
    final isMeasurable =
        habit['targetValue'] != null && habit['targetValue'] > 0;
    final progress = habit['completionPercent'] / 100;
    final repeatType = habit['repeatType'] ?? '';

    // Get achieved vs target values for display
    final totalAchieved = habit['totalAchievedValue']?.toDouble() ?? 0.0;
    final totalTarget = habit['totalTargetValue']?.toDouble() ?? 0.0;
    final completedDays = habit['completedDays'] as int;
    final totalDays = habit['totalDays'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              () => context.goNamed(
                'habit-detail',
                pathParameters: {'id': habit['id']},
              ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _getCompletionColor(
                    habit['completionPercent'],
                  ).withOpacity(0.1),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        habit['title'],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        // Habit type indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getHabitTypeColor(
                              repeatType,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getHabitTypeLabel(repeatType),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getHabitTypeColor(repeatType),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Completion percentage
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getCompletionColor(
                              habit['completionPercent'],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${habit['completionPercent'].toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Special display for Weekly Flexible habits
                if (repeatType == 'Weekly Flexible') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Target: ${habit['daysPerWeek'] ?? 3} days/week',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.teal[700],
                      ),
                    ),
                  ),
                ] else if (isMeasurable) ...[
                  // Show achieved vs target values for measurable habits
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Achieved: ${totalAchieved.toStringAsFixed(0)} ${habit['targetUnit']}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Target: ${totalTarget.toStringAsFixed(0)} ${habit['targetUnit']}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Show exceeded indicator if achieved > target
                      if (totalAchieved > totalTarget && totalTarget > 0)
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
                              "+${(totalAchieved - totalTarget).toStringAsFixed(0)}",
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
                ] else if (habit['targetValue'] != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Target: ${habit['targetValue']} ${habit['targetUnit']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    color: _getCompletionColor(habit['completionPercent']),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      repeatType == 'Weekly Flexible'
                          ? '${completedDays}/${totalDays} weekly targets met'
                          : '${completedDays}/${totalDays} days completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCompletionColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getHabitTypeColor(String repeatType) {
    switch (repeatType) {
      case 'Repeat Till Done':
        return Colors.purple;
      case 'Weekly Flexible':
        return Colors.teal;
      case 'Weekly':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getHabitTypeLabel(String repeatType) {
    switch (repeatType) {
      case 'Repeat Till Done':
        return 'Till Done';
      case 'Weekly Flexible':
        return 'Flexible';
      case 'Weekly':
        return 'Weekly';
      default:
        return 'Other';
    }
  }
}
