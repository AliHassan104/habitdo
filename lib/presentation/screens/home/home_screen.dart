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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _dateScrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  @override
  void initState() {
    super.initState();

    // Delay to wait for build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int selectedIndex = 15; // Assuming today is at index 15
      _dateScrollController.animateTo(
        selectedIndex * 72.0, // 60 width + 12 margin/padding approx
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    );
    final totalDays = lastDayOfMonth.day;
    return Scaffold(
      appBar: CommonAppBar(
        title: 'HabitDo',
        showHome: true,
        onCalendarTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });

            // Delay to allow setState to finish before scrolling
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final index = picked.day - 1;
              _dateScrollController.animateTo(
                index * 72.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        },
      ),
      body: BottomNavScaffold(
        selectedIndex: 0,
        showHome: true,
        child: Column(
          children: [
            // Horizontal Scrollable Date Picker
            SizedBox(
              height: 100,
              child: ListView.builder(
                controller: _dateScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: totalDays,
                itemBuilder: (context, index) {
                  final date = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    index + 1,
                  );
                  final isSelected =
                      _selectedDate.year == date.year &&
                      _selectedDate.month == date.month &&
                      _selectedDate.day == date.day;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        // Recenter on new selected date
                        _dateScrollController.animateTo(
                          index * 72.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      });
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
                                : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.E().format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Habits and PieChart
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('habits')
                        .where('uid', isEqualTo: currentUser?.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No habits for selected day.'),
                    );
                  }

                  final today = _selectedDate;
                  final todayWeekday =
                      [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday',
                      ][today.weekday - 1];

                  final habits =
                      snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final repeatType = data['repeatType'];
                        final selectedDays = List<String>.from(
                          data['selectedDays'] ?? [],
                        );
                        final selectedDate =
                            (data['selectedDate'] as Timestamp?)?.toDate();

                        if (repeatType == 'Once') {
                          return selectedDate != null &&
                              selectedDate.year == today.year &&
                              selectedDate.month == today.month &&
                              selectedDate.day == today.day;
                        } else if (repeatType == 'Weekly') {
                          return selectedDays.contains(todayWeekday);
                        }

                        return false;
                      }).toList();

                  final totalCount = habits.length;

                  final formattedDate = DateFormat(
                    'yyyy-MM-dd',
                  ).format(_selectedDate);

                  double totalPercentComplete = 0;
                  int percentBasedHabits = 0;
                  int daysCompleted = 0;
                  int totalDaysThisMonth = 0;
                  final currentMonth = _selectedDate.month;
                  final currentYear = _selectedDate.year;

                  for (var habit in habits) {
                    final data = habit.data() as Map<String, dynamic>;
                    final dailyCompletion = data['dailyCompletion'] ?? {};
                    final entry = dailyCompletion[formattedDate];

                    if (entry is Map<String, dynamic>) {
                      double target =
                          (data['targetValue'] as num?)?.toDouble() ?? 0.0;

                      final double value =
                          double.tryParse(entry['value'].toString()) ?? 0.0;

                      if (target > 0 && value >= target) {
                        daysCompleted++;
                      }

                      if (target > 0) {
                        totalPercentComplete += (value / target).clamp(
                          0.0,
                          1.0,
                        );
                        percentBasedHabits += 1;
                      }
                    }
                  }

                  final double completedCount = totalPercentComplete;
                  final double incompleteCount =
                      totalCount - totalPercentComplete;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...habits.map((habit) {
                          final data = habit.data() as Map<String, dynamic>;
                          final dailyCompletion =
                              data['dailyCompletion'] ?? {}; // Moved this up

                          final entry =
                              dailyCompletion[formattedDate]; // Now this works fine
                          double value = 0;
                          double target =
                              (data['targetValue'] ?? 0)
                                  .toDouble(); // use `data` instead of `habit[...]`

                          if (entry is Map<String, dynamic>) {
                            value = (entry['value'] ?? 0).toDouble();
                          }

                          bool isMeasurable = target > 0;

                          final title = data['title'] ?? '';
                          final description = data['description'] ?? '';

                          // Calculate progress over this month

                          dailyCompletion.forEach((key, value) {
                            final date = DateTime.tryParse(key);
                            if (date == null ||
                                date.month != currentMonth ||
                                date.year != currentYear) {
                              return;
                            }

                            if (value == true) {
                              daysCompleted++;
                            } else if (value is Map<String, dynamic>) {
                              final double target =
                                  double.tryParse(
                                    value['target']?.toString() ?? '0',
                                  ) ??
                                  0.0;
                              final double achieved =
                                  double.tryParse(
                                    value['value']?.toString() ?? '0',
                                  ) ??
                                  0.0;
                              if (target > 0 && achieved / target >= 1.0) {
                                daysCompleted++;
                              }
                            }
                          });

                          // Optional: You can decide what "total" means — for now, using days till today
                          totalDaysThisMonth = DateTime.now().day;
                          final progress =
                              totalDaysThisMonth > 0
                                  ? daysCompleted / totalDaysThisMonth
                                  : 0.0;

                          final isCompleted =
                              entry is Map<String, dynamic>
                                  ? (double.tryParse(
                                            entry['value']?.toString() ?? '0',
                                          ) ??
                                          0.0) >=
                                      (double.tryParse(
                                            entry['target']?.toString() ?? '0',
                                          ) ??
                                          0.0)
                                  : (entry == true);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                context.goNamed(
                                  AppRoutes.addEdit,
                                  extra: {
                                    'habitId': habit.id,
                                    'existingTitle': title,
                                    'existingDescription': description,
                                  },
                                );
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        decoration:
                                            isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                      ),
                                    ),
                                    if (isMeasurable)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Slider(
                                                      value: value,
                                                      min: 0,
                                                      max: target,
                                                      divisions:
                                                          target < 1
                                                              ? null
                                                              : target.toInt(),
                                                      label:
                                                          "${value.toStringAsFixed(1)}",
                                                      onChanged: (newValue) {
                                                        setState(() {
                                                          value = newValue;
                                                        });

                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'habits',
                                                            )
                                                            .doc(habit.id)
                                                            .update({
                                                              'dailyCompletion.$formattedDate':
                                                                  {
                                                                    'value':
                                                                        newValue,
                                                                    'target':
                                                                        target,
                                                                  },
                                                            });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 1,
                                                    child: TextFormField(
                                                      initialValue:
                                                          value
                                                              .toInt()
                                                              .toString(),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration: InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 8,
                                                            ),
                                                      ),
                                                      onFieldSubmitted: (
                                                        newVal,
                                                      ) {
                                                        final parsed =
                                                            double.tryParse(
                                                              newVal,
                                                            ) ??
                                                            0.0;
                                                        final newValue =
                                                            parsed
                                                                .clamp(
                                                                  0,
                                                                  target,
                                                                )
                                                                .toDouble();

                                                        setState(() {
                                                          value = newValue;
                                                        });

                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'habits',
                                                            )
                                                            .doc(habit.id)
                                                            .update({
                                                              'dailyCompletion.$formattedDate':
                                                                  {
                                                                    'value':
                                                                        newValue,
                                                                    'target':
                                                                        target,
                                                                  },
                                                            });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text("/ $target"),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: CircularPercentIndicator(
                                  radius: 25.0,
                                  lineWidth: 5.0,
                                  percent:
                                      isMeasurable
                                          ? (value / target).clamp(0.0, 1.0)
                                          : progress.clamp(0.0, 1.0),
                                  center: Text(
                                    isMeasurable
                                        ? "${((value / target) * 100).clamp(0, 100).toStringAsFixed(0)}%"
                                        : "${(progress * 100).toStringAsFixed(0)}%",
                                  ),
                                  progressColor: Colors.blue,
                                  backgroundColor: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 20),
                        if (totalCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              height: 150,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: [
                                    PieChartSectionData(
                                      value: completedCount,
                                      color: Colors.green,
                                      title:
                                          totalCount > 0
                                              ? '${((completedCount / totalCount) * 100).toStringAsFixed(0)}%'
                                              : '0%',

                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: incompleteCount,
                                      color: Colors.redAccent,
                                      title: '',
                                      radius: 60,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 60), // Spacer for scroll comfort
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
