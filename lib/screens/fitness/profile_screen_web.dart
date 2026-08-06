import 'package:flutter/material.dart';

import '../../core/routes.dart';
import 'package:vervestride/models/user_profile.dart';
import '../../services/local_storage_service.dart';
import '../premium/premium_screen.dart';
import '../../widgets/ad_banner_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStorageService _storage = LocalStorageService.instance;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController heightCtrl = TextEditingController();
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController ageCtrl = TextEditingController();
  final TextEditingController activityCtrl =
      TextEditingController(text: '3'); // Default moderate
  final TextEditingController kgChangeCtrl = TextEditingController();
  final TextEditingController goalCaloriesCtrl = TextEditingController();
  final TextEditingController goalProteinCtrl = TextEditingController();
  final TextEditingController goalWaterCtrl = TextEditingController();
  final TextEditingController goalBurnCtrl = TextEditingController();

  String gender = 'male';
  String goal = 'maintain';
  DateTime? goalStartDate;
  DateTime? goalEndDate;

  @override
  void initState() {
    super.initState();
    emailCtrl.text = FirebaseAuth.instance.currentUser?.email ?? 'N/A';
    _loadData();
    validationMessage = null;
    _recomputeRecommendation();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    ageCtrl.dispose();
    kgChangeCtrl.dispose();
    goalCaloriesCtrl.dispose();
    goalProteinCtrl.dispose();
    goalWaterCtrl.dispose();
    goalBurnCtrl.dispose();
    super.dispose();
  }

  String? validationMessage;
  int? recommendedKcalAdjustment;

  // Store calculated targets to show as defaults
  Map<String, dynamic> _calculatedTargets = {};

  List<UserGoal> _goals = <UserGoal>[];
  String? _editingGoalId;

  int _recommendedGoalDays() {
    if (goal == 'maintain') return 0;
    final kg = double.tryParse(kgChangeCtrl.text) ?? 0;
    if (kg <= 0) return 0;
    final maxPerWeek = goal == 'lose_weight' ? 1.0 : 0.5;
    final weeks = kg / maxPerWeek;
    final days = (weeks * 7).ceil();
    return days <= 0 ? 0 : days;
  }

  DateTime? _recommendedEndDate() {
    if (goalStartDate == null) return null;
    final days = _recommendedGoalDays();
    if (days <= 0) return null;
    return goalStartDate!.add(Duration(days: days));
  }

  bool _rangesOverlap(
      DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final aS = DateTime(aStart.year, aStart.month, aStart.day);
    final aE = DateTime(aEnd.year, aEnd.month, aEnd.day);
    final bS = DateTime(bStart.year, bStart.month, bStart.day);
    final bE = DateTime(bEnd.year, bEnd.month, bEnd.day);
    return !aE.isBefore(bS) && !bE.isBefore(aS);
  }

  String? _validateNoOverlap(DateTime start, DateTime end) {
    for (final g in _goals) {
      if (_editingGoalId != null && g.id == _editingGoalId) continue;
      if (_rangesOverlap(start, end, g.fromDate, g.toDate)) {
        return 'Goal dates overlap with an existing goal.';
      }
    }
    return null;
  }

  void _startNewGoal() {
    setState(() {
      _editingGoalId = null;
      goal = 'maintain';
      goalStartDate = null;
      goalEndDate = null;
      kgChangeCtrl.text = '0';
      goalCaloriesCtrl.clear();
      goalProteinCtrl.clear();
      goalWaterCtrl.clear();
      goalBurnCtrl.clear();
      validationMessage = null;
      _recomputeRecommendation();
    });
  }

  void _editGoal(UserGoal g) {
    final weight = double.tryParse(weightCtrl.text) ?? 70;
    final kg = (g.targetWeightKg - weight).abs();
    setState(() {
      _editingGoalId = g.id;
      goal = g.goalType;
      goalStartDate = g.fromDate;
      goalEndDate = g.toDate;
      kgChangeCtrl.text = kg.toStringAsFixed(1);
      goalCaloriesCtrl.text =
          (g.targetCalories != null && g.targetCalories! > 0)
              ? g.targetCalories.toString()
              : '';
      goalProteinCtrl.text =
          (g.targetProteinGrams != null && g.targetProteinGrams! > 0)
              ? g.targetProteinGrams.toString()
              : '';
      goalWaterCtrl.text = (g.targetWaterMl != null && g.targetWaterMl! > 0)
          ? g.targetWaterMl.toString()
          : '';
      goalBurnCtrl.text =
          (g.targetBurnCalories != null && g.targetBurnCalories! > 0)
              ? g.targetBurnCalories.toString()
              : '';
      validationMessage = null;
      _recomputeRecommendation();
    });
  }

  Future<void> _deleteGoal(UserGoal g) async {
    setState(() {
      _goals.removeWhere((x) => x.id == g.id);
      if (_editingGoalId == g.id) {
        _editingGoalId = null;
        goal = 'maintain';
        goalStartDate = null;
        goalEndDate = null;
        kgChangeCtrl.text = '0';
        validationMessage = null;
        _recomputeRecommendation();
      }
    });

    final existing = await _storage.getUserProfile();
    final current = existing != null
        ? UserProfile.fromJson(existing)
        : UserProfile.defaultProfile();

    current.goals = _goals;

    final active = current.activeGoalForDate(DateTime.now());
    if (active != null) {
      current.goal = active.goalType;
      current.targetWeightKg = active.targetWeightKg;
      current.goalStartDate = active.fromDate;
      current.goalEndDate = active.toDate;
    } else {
      current.goal = 'maintain';
      current.targetWeightKg = 0.0;
      current.goalStartDate = null;
      current.goalEndDate = null;
    }

    await _storage.saveUserProfile(current.toJson());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal deleted')),
    );
  }

  Future<void> _loadData() async {
    final existing = await _storage.getUserProfile();
    final current = existing != null
        ? UserProfile.fromJson(existing)
        : UserProfile.defaultProfile();

    nameCtrl.text = current.name;
    heightCtrl.text = current.heightCm.toStringAsFixed(0);
    weightCtrl.text = current.weightKg.toStringAsFixed(1);
    ageCtrl.text = current.age.toString();
    gender = current.gender;
    goal = current.goal;
    goalStartDate = current.goalStartDate;
    goalEndDate = current.goalEndDate;
    _goals = current.sortedGoals;
    kgChangeCtrl.text = current.targetWeightKg > 0
        ? (current.targetWeightKg - current.weightKg).abs().toStringAsFixed(1)
        : '0';

    _recomputeRecommendation();

    if (mounted) setState(() {});
  }

  void _recomputeRecommendation() {
    final weight = double.tryParse(weightCtrl.text) ?? 70;
    final height = double.tryParse(heightCtrl.text) ?? 170;
    final age = int.tryParse(ageCtrl.text) ?? 25;
    final activityLevel = int.tryParse(activityCtrl.text) ?? 3;

    final kg = double.tryParse(kgChangeCtrl.text) ?? 0;
    final targetWeight = (() {
      if (goal == 'lose_weight' && kg > 0) return weight - kg;
      return 0.0;
    })();

    final tmp = UserProfile(
      name: nameCtrl.text,
      gender: gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      activityLevel: activityLevel,
      goal: goal,
      targetWeightKg: targetWeight,
      goalStartDate: null,
      goalEndDate: null,
      goals: [],
    );

    // Calculate targets based on profile and goal
    _calculatedTargets = tmp.calculateDailyTargets(forDate: DateTime.now());
    recommendedKcalAdjustment =
        (_calculatedTargets['kcalAdjustment'] as num?)?.toInt();

    // Update text fields with calculated values if they're empty
    _updateTargetFields();
  }

  void _updateTargetFields() {
    // Only update fields if they're empty (user hasn't manually entered values)
    if (goalCaloriesCtrl.text.isEmpty && _calculatedTargets['kcal'] != null) {
      goalCaloriesCtrl.text =
          (_calculatedTargets['kcal'] as num).round().toString();
    }
    if (goalProteinCtrl.text.isEmpty && _calculatedTargets['protein'] != null) {
      goalProteinCtrl.text =
          (_calculatedTargets['protein'] as num).round().toString();
    }
    if (goalWaterCtrl.text.isEmpty && _calculatedTargets['waterMl'] != null) {
      goalWaterCtrl.text =
          (_calculatedTargets['waterMl'] as num).round().toString();
    }
    if (goalBurnCtrl.text.isEmpty &&
        _calculatedTargets['burnCalories'] != null) {
      goalBurnCtrl.text =
          (_calculatedTargets['burnCalories'] as num).round().toString();
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String? _validateGoal() {
    final kg = double.tryParse(kgChangeCtrl.text) ?? 0;
    if (goal == 'maintain') {
      final hasAnyDate = goalStartDate != null || goalEndDate != null;
      final hasBothDates = goalStartDate != null && goalEndDate != null;
      if (hasAnyDate && !hasBothDates) {
        return 'Select both goal start and end date.';
      }
      if (!hasBothDates) return null;
    } else {
      if (goalStartDate == null || goalEndDate == null) {
        return 'Select goal start and end date.';
      }
      if (goal == 'lose_weight' && kg <= 0) return 'Enter kg to lose.';
    }
    final s =
        DateTime(goalStartDate!.year, goalStartDate!.month, goalStartDate!.day);
    final e = DateTime(goalEndDate!.year, goalEndDate!.month, goalEndDate!.day);
    final days = e.difference(s).inDays + 1;
    if (days <= 0) return 'End date must be after start date.';
    final weeks = days / 7.0;
    if (goal == 'lose_weight') {
      final kgPerWeek = kg / weeks;
      const max = 1.0;
      if (kgPerWeek > max) {
        return 'Not possible safely. Recommended max is ${max.toStringAsFixed(1)} kg/week. Reduce kg or increase days.';
      }
    }
    return null;
  }

  Future<void> _saveAll() async {
    final msg = _validateGoal();
    if (msg != null) {
      setState(() => validationMessage = msg);
      return;
    }

    final weight = double.tryParse(weightCtrl.text) ?? 70;
    final kg = double.tryParse(kgChangeCtrl.text) ?? 0;

    var nextGoals = [..._goals];
    final shouldSaveGoal =
        goal != 'maintain' || (goalStartDate != null && goalEndDate != null);
    if (shouldSaveGoal) {
      if (goalStartDate == null || goalEndDate == null) {
        setState(() => validationMessage = 'Select goal start and end date.');
        return;
      }
      final overlapMsg = _validateNoOverlap(goalStartDate!, goalEndDate!);
      if (overlapMsg != null) {
        setState(() => validationMessage = overlapMsg);
        return;
      }

      final target = (() {
        if (goal == 'lose_weight' && kg > 0) return weight - kg;
        if (goal == 'gain_muscle') return weight + kg;
        return 0.0;
      })();

      final id =
          _editingGoalId ?? DateTime.now().millisecondsSinceEpoch.toString();
      nextGoals.removeWhere((g) => g.id == id);

      final overrideCalories = int.tryParse(goalCaloriesCtrl.text.trim());
      final overrideProtein = int.tryParse(goalProteinCtrl.text.trim());
      final overrideWater = int.tryParse(goalWaterCtrl.text.trim());
      final overrideBurn = int.tryParse(goalBurnCtrl.text.trim());

      nextGoals.add(
        UserGoal(
          id: id,
          goalType: goal,
          targetWeightKg: target,
          fromDate: goalStartDate!,
          toDate: goalEndDate!,
          createdAt: DateTime.now(),
          targetCalories: (overrideCalories != null && overrideCalories > 0)
              ? overrideCalories
              : null,
          targetProteinGrams: (overrideProtein != null && overrideProtein > 0)
              ? overrideProtein
              : null,
          targetWaterMl: (overrideWater != null && overrideWater > 0)
              ? overrideWater
              : null,
          targetBurnCalories:
              (overrideBurn != null && overrideBurn > 0) ? overrideBurn : null,
        ),
      );
    }
    final updated = UserProfile(
      name: nameCtrl.text,
      age: int.tryParse(ageCtrl.text) ?? 25,
      gender: gender,
      heightCm: double.tryParse(heightCtrl.text) ?? 170,
      weightKg: weight,
      activityLevel: int.tryParse(activityCtrl.text) ?? 3,
      goal: 'maintain',
      targetWeightKg: 0.0,
      goalStartDate: null,
      goalEndDate: null,
      goals: nextGoals,
    );

    final active = updated.activeGoalForDate(DateTime.now());
    if (active != null) {
      updated.goal = active.goalType;
      updated.targetWeightKg = active.targetWeightKg;
      updated.goalStartDate = active.fromDate;
      updated.goalEndDate = active.toDate;
    }

    await _storage.saveUserProfile(updated.toJson());
    if (!mounted) return;

    setState(() {
      _goals = updated.sortedGoals;
      _editingGoalId = null;
      validationMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile & Goal saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile & Goal'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, Routes.settings);
                return;
              }
              if (value == 'premium') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuItem(
                value: 'premium',
                child: Text('Subscription'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    readOnly: true,
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (val) => setState(() {
                      gender = val ?? gender;
                      _recomputeRecommendation();
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: activityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Activity level (1-5)'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: activityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Activity level (1-5)'),
                    onChanged: (_) => setState(_recomputeRecommendation),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1=Sedentary, 2=Light, 3=Moderate, 4=Very, 5=Super active',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Goal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: goal,
                    items: const [
                      DropdownMenuItem(
                        value: 'maintain',
                        child: Text('Maintain'),
                      ),
                      DropdownMenuItem(
                        value: 'lose_weight',
                        child: Text('Lose weight'),
                      ),
                      DropdownMenuItem(
                        value: 'gain_muscle',
                        child: Text('Gain muscle'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        goal = v ?? goal;
                        if (goal != 'lose_weight') kgChangeCtrl.text = '0';
                        validationMessage = null;
                        _recomputeRecommendation();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Goal Type'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kgChangeCtrl,
                    enabled: goal == 'lose_weight',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          goal == 'lose_weight' ? 'How many kg to lose' : 'kg',
                    ),
                    onChanged: (_) => setState(() {
                      validationMessage = null;
                      _recomputeRecommendation();
                    }),
                  ),
                  if (goal == 'lose_weight' && goalStartDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Builder(
                        builder: (context) {
                          final rec = _recommendedEndDate();
                          if (rec == null) return const SizedBox.shrink();
                          return Text(
                            'Recommended To date: ${_fmtDate(rec)} (based on a safe pace)',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Target Overrides (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: goalCaloriesCtrl,
                    enabled: goal != 'maintain',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calories target',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: goalProteinCtrl,
                    enabled: goal != 'maintain',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein target (g)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: goalWaterCtrl,
                    enabled: goal != 'maintain',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Water target (ml)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: goalBurnCtrl,
                    enabled: goal != 'maintain',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Burn target (kcal)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final today = DateTime(now.year, now.month, now.day);
                            final firstAllowed =
                                _editingGoalId != null ? DateTime(2000, 1, 1) : today;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: goalStartDate ?? DateTime.now(),
                              firstDate: firstAllowed,
                              lastDate: DateTime(2035, 12, 31),
                            );
                            if (picked == null) return;
                            if (!mounted) return;
                            setState(() {
                              goalStartDate = picked;
                              validationMessage = null;
                              _recomputeRecommendation();
                            });
                          },
                          child: Text('From: ${_fmtDate(goalStartDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final today = DateTime(now.year, now.month, now.day);
                            final baseline =
                                _editingGoalId != null ? DateTime(2000, 1, 1) : today;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: goalEndDate ??
                                  (_recommendedEndDate() ??
                                      (goalStartDate ?? DateTime.now())),
                              firstDate: goalStartDate ?? baseline,
                              lastDate: DateTime(2035, 12, 31),
                            );
                            if (picked == null) return;
                            if (!mounted) return;
                            setState(() {
                              goalEndDate = picked;
                              validationMessage = null;
                              _recomputeRecommendation();
                            });
                          },
                          child: Text('To: ${_fmtDate(goalEndDate)}'),
                        ),
                      ),
                    ],
                  ),
                  if (goal != 'maintain' && recommendedKcalAdjustment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Recommended per day: ${recommendedKcalAdjustment! > 0 ? '+' : ''}${recommendedKcalAdjustment!} kcal',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  if (validationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        validationMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAll,
                      child: const Text('Save Profile & Goal'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Goals',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _startNewGoal,
                        icon: const Icon(Icons.add),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_goals.isEmpty)
                    const Text('No goals')
                  else
                    ..._goals.map(
                      (g) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(g.goalType),
                        subtitle: Text(
                          '${_fmtDate(g.fromDate)} to ${_fmtDate(g.toDate)}',
                        ),
                        onTap: () => _editGoal(g),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteGoal(g),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ┌──────── Premium Banner Ad ────────┐
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: const AdBannerWidget(adUnitId: AdBannerWidget.banner2Id),
          ),
          // └───────────────────────────────────┘
        ],
      ),
    );
  }
}
