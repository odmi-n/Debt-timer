import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const DebtTimerApp());
}

class DebtTimerApp extends StatelessWidget {
  const DebtTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debt Timer',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF8A00),
          secondary: Color(0xFFFF8A00),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const DebtTimerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DebtTimerPage extends StatefulWidget {
  const DebtTimerPage({super.key});

  @override
  State<DebtTimerPage> createState() => _DebtTimerPageState();
}

class _DebtTimerPageState extends State<DebtTimerPage> {
  final TextEditingController _lenderController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  DebtResult? _result;
  Timer? _ticker;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _rateController.addListener(_recalculate);
    _paymentController.addListener(_recalculate);
    _totalController.addListener(_recalculate);
    _recalculate();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final current = _remainingSeconds;
      if (current != null && current > 0) {
        setState(() {
          _remainingSeconds = current - 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lenderController.dispose();
    _rateController.dispose();
    _paymentController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final principal = double.tryParse(_totalController.text.replaceAll(',', ''));
    final annualRate = double.tryParse(_rateController.text);
    final monthlyPayment = double.tryParse(_paymentController.text.replaceAll(',', ''));

    setState(() {
      _result = DebtCalculator.calculate(
        principal: principal,
        annualRatePercent: annualRate,
        monthlyPayment: monthlyPayment,
      );
      if (_result!.canPayoff) {
        _remainingSeconds = _result!.totalSeconds ?? 0;
      } else {
        _remainingSeconds = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lenderName = _lenderController.text.trim();
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Debt Timer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('借入を追加'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DebtTimerDial(
                accentColor: accent,
                child: _buildCountdown(context),
              ),
              const SizedBox(height: 24),
              _buildInfoCard(lenderName),
              const SizedBox(height: 16),
              _buildVisualCountdown(),
              const SizedBox(height: 12),
              _buildInputFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown(BuildContext context) {
    if (_result == null || !_result!.hasInputs) {
      return const Text(
        '値を入力すると\n完済までの期間が表示されます',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
      );
    }

    if (!_result!.canPayoff) {
      return const Text(
        '月の返済額が\n利息を下回っています',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Color(0xFFFF8A00)),
      );
    }

    final breakdown = _currentBreakdown();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '完済まであと',
          style: TextStyle(color: Color(0xFF616161)),
        ),
        const SizedBox(height: 6),
        Text(
          '${breakdown.years}年${breakdown.months}ヶ月${breakdown.days}日',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${breakdown.seconds}秒',
          style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String lenderName) {
    final label = lenderName.isEmpty ? '借入会社未入力' : lenderName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFF8A00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        TextField(
          controller: _lenderController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '借入会社',
            hintText: '例）夕張信用',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: '利率（年率％）',
            hintText: '例）3.5',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paymentController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '月の返済額（円）',
            hintText: '例）30000',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _totalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '借入総額（円）',
            hintText: '例）2000000',
          ),
        ),
      ],
    );
  }

  Widget _buildVisualCountdown() {
    if (_result == null || !_result!.hasInputs) {
      return const SizedBox.shrink();
    }

    if (!_result!.canPayoff) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: const Text(
          '月の返済額が利息を下回っています。',
          style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.w600),
        ),
      );
    }

    final breakdown = _currentBreakdown();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC5E1A5)),
      ),
      child: Text(
        '完済まであと${breakdown.years}年${breakdown.months}ヶ月${breakdown.days}日${breakdown.seconds}秒です。',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  RemainingBreakdown _currentBreakdown() {
    if (_result == null || !_result!.canPayoff) {
      return const RemainingBreakdown.zero();
    }
    final baseSeconds = _result!.totalSeconds ?? 0;
    final remaining = max(0, _remainingSeconds ?? baseSeconds);
    return _secondsToBreakdown(remaining);
  }

  RemainingBreakdown _secondsToBreakdown(int totalSeconds) {
    const secondsPerDay = 24 * 60 * 60;
    const daysPerMonth = 30;
    const daysPerYear = 360;
    final totalDays = totalSeconds ~/ secondsPerDay;
    final years = totalDays ~/ daysPerYear;
    final months = (totalDays % daysPerYear) ~/ daysPerMonth;
    final days = totalDays % daysPerMonth;
    final seconds = totalSeconds % secondsPerDay;
    return RemainingBreakdown(
      years: years,
      months: months,
      days: days,
      seconds: seconds,
    );
  }
}

class RemainingBreakdown {
  const RemainingBreakdown({
    required this.years,
    required this.months,
    required this.days,
    required this.seconds,
  });

  const RemainingBreakdown.zero()
      : years = 0,
        months = 0,
        days = 0,
        seconds = 0;

  final int years;
  final int months;
  final int days;
  final int seconds;
}

class DebtResult {
  DebtResult({
    required this.hasInputs,
    required this.canPayoff,
    required this.totalSeconds,
  });

  final bool hasInputs;
  final bool canPayoff;
  final int? totalSeconds;
}

class DebtCalculator {
  static DebtResult calculate({
    required double? principal,
    required double? annualRatePercent,
    required double? monthlyPayment,
  }) {
    final hasInputs = principal != null &&
        annualRatePercent != null &&
        monthlyPayment != null &&
        principal > 0 &&
        monthlyPayment > 0;

    if (!hasInputs) {
      return DebtResult(
        hasInputs: false,
        canPayoff: false,
        totalSeconds: 0,
      );
    }

    final monthlyRate = (annualRatePercent / 100) / 12;
    double monthsExact;
    if (monthlyRate == 0) {
      monthsExact = principal / monthlyPayment;
    } else {
      final interestOnly = principal * monthlyRate;
      if (monthlyPayment <= interestOnly) {
        return DebtResult(
          hasInputs: true,
          canPayoff: false,
          totalSeconds: 0,
        );
      }
      monthsExact =
          log(monthlyPayment / (monthlyPayment - interestOnly)) / log(1 + monthlyRate);
    }

    final totalSeconds = max(0, (monthsExact * 30 * 24 * 60 * 60).ceil());

    return DebtResult(
      hasInputs: true,
      canPayoff: true,
      totalSeconds: totalSeconds,
    );
  }
}

class DebtTimerDial extends StatelessWidget {
  const DebtTimerDial({
    super.key,
    required this.accentColor,
    required this.child,
  });

  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: DebtTimerPainter(accentColor),
        child: Center(child: child),
      ),
    );
  }
}

class DebtTimerPainter extends CustomPainter {
  DebtTimerPainter(this.accentColor);

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
