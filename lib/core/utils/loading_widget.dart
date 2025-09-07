import 'package:flutter/material.dart';

/// Collection of reusable loading widgets for consistent loading states
class LoadingWidget {
  /// Basic circular loading indicator
  static Widget circular({
    Color? color,
    double size = 24.0,
    double strokeWidth = 2.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: color != null 
            ? AlwaysStoppedAnimation<Color>(color)
            : null,
      ),
    );
  }

  /// Loading indicator with text
  static Widget withText({
    required String text,
    Color? color,
    double size = 24.0,
    double spacing = 16.0,
    TextStyle? textStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circular(color: color, size: size),
        SizedBox(height: spacing),
        Text(
          text,
          style: textStyle ?? const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Full screen loading overlay
  static Widget fullScreen({
    String? message,
    Color? backgroundColor,
    Color? indicatorColor,
  }) {
    return Container(
      color: backgroundColor ?? Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: withText(
              text: message ?? 'Loading...',
              color: indicatorColor,
              size: 32.0,
            ),
          ),
        ),
      ),
    );
  }

  /// Linear progress indicator
  static Widget linear({
    double? value,
    Color? backgroundColor,
    Color? valueColor,
    double height = 4.0,
  }) {
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: valueColor != null 
            ? AlwaysStoppedAnimation<Color>(valueColor)
            : null,
      ),
    );
  }

  /// Shimmer loading effect for list items
  static Widget shimmerListItem({
    double height = 80.0,
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) {
    return Card(
      margin: margin,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _ShimmerBox(width: 50, height: 50, borderRadius: 25),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ShimmerBox(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  _ShimmerBox(width: 150, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer loading for cards
  static Widget shimmerCard({
    double height = 120.0,
    EdgeInsets margin = const EdgeInsets.all(16),
  }) {
    return Card(
      margin: margin,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _ShimmerBox(width: double.infinity, height: 20)),
                const SizedBox(width: 16),
                _ShimmerBox(width: 60, height: 20, borderRadius: 10),
              ],
            ),
            const SizedBox(height: 12),
            _ShimmerBox(width: double.infinity, height: 14),
            const SizedBox(height: 8),
            _ShimmerBox(width: 200, height: 14),
            const Spacer(),
            _ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  /// Loading state for buttons
  static Widget button({
    Color? color,
    double size = 20.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Colors.white,
        ),
      ),
    );
  }

  /// Custom loading animation with bouncing dots
  static Widget bouncingDots({
    Color? color,
    double size = 8.0,
    int count = 3,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        return _BouncingDot(
          color: color ?? Colors.blue,
          size: size,
          delay: Duration(milliseconds: index * 200),
        );
      }),
    );
  }

  /// Empty state with loading option
  static Widget emptyState({
    required String title,
    required String subtitle,
    IconData icon = Icons.inbox_outlined,
    bool showLoading = false,
    VoidCallback? onRetry,
    String? retryText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLoading) ...[
              circular(size: 32.0),
              const SizedBox(height: 24),
            ] else ...[
              Icon(
                icon,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null && !showLoading) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(retryText ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Loading overlay for specific widgets
  static Widget overlay({
    required Widget child,
    required bool isLoading,
    String? loadingText,
    Color? overlayColor,
  }) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: overlayColor ?? Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: withText(
                      text: loadingText ?? 'Loading...',
                      size: 24.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Internal shimmer box widget
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[300]?.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Internal bouncing dot widget
class _BouncingDot extends StatefulWidget {
  final Color color;
  final double size;
  final Duration delay;

  const _BouncingDot({
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Start animation with delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: widget.size / 4),
          child: Transform.translate(
            offset: Offset(0, -10 * _animation.value),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Specialized loading widgets for different app sections
class HabitLoadingWidgets {
  /// Loading state for habit cards
  static Widget habitCard() {
    return LoadingWidget.shimmerCard(height: 140);
  }

  /// Loading state for habit list
  static Widget habitList({int itemCount = 3}) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => habitCard(),
    );
  }

  /// Loading state for dashboard stats
  static Widget dashboardStats() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ShimmerBox(width: double.infinity, height: 24),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                return Column(
                  children: [
                    _ShimmerBox(width: 60, height: 60, borderRadius: 30),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 50, height: 16),
                    const SizedBox(height: 4),
                    _ShimmerBox(width: 70, height: 12),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading state for charts
  static Widget chart({double height = 200}) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 150, height: 20),
            const SizedBox(height: 16),
            Expanded(
              child: _ShimmerBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}