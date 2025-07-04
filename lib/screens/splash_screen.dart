import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _ThemeResponsiveTradingSplashState();
}

class _ThemeResponsiveTradingSplashState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _candlestickController;
  late AnimationController _tickerController;
  late AnimationController _logoController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _candlestickAnimation;
  late Animation<double> _tickerAnimation;
  late Animation<double> _goldShimmerAnimation;

  bool _isDisposed = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    if (_isDisposed) return;

    _masterController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _candlestickController = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );

    _tickerController = AnimationController(
      duration: const Duration(milliseconds: 6400),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _setupAnimations();
    _isInitialized = true;

    // Start animations after a small delay to ensure everything is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimationSequence();
    });
  }

  void _setupAnimations() {
    if (_isDisposed) return;

    // Use more efficient animation curves
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    // Synchronized logo animations with text timing
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
    ));

    _logoRotateAnimation = Tween<double>(
      begin: -0.5,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack),
    ));

    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _candlestickAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _candlestickController,
      curve: Curves.easeInOutCubic,
    ));

    _tickerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _tickerController,
      curve: Curves.linear,
    ));

    _goldShimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));
  }

  void _startAnimationSequence() async {
    if (_isDisposed) return;

    try {
      // Reduced delay to ensure everything is ready
      await Future.delayed(const Duration(milliseconds: 50));

      if (!_isDisposed && mounted) {
        // Start both master controller (for image and text) together
        await _masterController.forward();
      }

      if (!_isDisposed && mounted) {
        await Future.delayed(const Duration(milliseconds: 350));
        _candlestickController.forward();
      }

      if (!_isDisposed && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        _tickerController.repeat();
      }

      if (!_isDisposed && mounted) {
        await Future.delayed(const Duration(milliseconds: 3500));
        _navigateToNextScreen();
      }
    } catch (e) {
      // Handle any animation errors gracefully
      if (mounted && !_isDisposed) {
        _navigateToNextScreen();
      }
    }
  }

  void _navigateToNextScreen() {
    if (!mounted || _isDisposed) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.child,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _masterController.dispose();
    _candlestickController.dispose();
    _tickerController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // Get theme-responsive colors - cached for performance
  Color get _primaryAccent => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFD700)
      : const Color(0xFF1E40AF);

  Color get _secondaryAccent => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFA500)
      : const Color(0xFF3B82F6);

  Color get _tertiaryAccent => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFF8C00)
      : const Color(0xFF60A5FA);

  Color get _textPrimary => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2937);

  Color get _textSecondary => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8B9DC3)
      : const Color(0xFF6B7280);

  Color get _backgroundPrimary => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0A0E1A)
      : const Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Don't build the UI until animations are initialized
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: _backgroundPrimary,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                const Color(0xFF0A0E1A),
                const Color(0xFF1A1F2E),
                const Color(0xFF2A2F3E),
              ]
                  : [
                const Color(0xFFF8FAFC),
                const Color(0xFFE2E8F0),
                const Color(0xFFCBD5E1),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundPrimary, // Set explicit background color
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
              const Color(0xFF0A0E1A),
              const Color(0xFF1A1F2E),
              const Color(0xFF2A2F3E),
            ]
                : [
              const Color(0xFFF8FAFC),
              const Color(0xFFE2E8F0),
              const Color(0xFFCBD5E1),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background candlestick chart - with RepaintBoundary for optimization
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _candlestickAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ThemeResponsiveCandlestickPainter(
                        _candlestickAnimation.value,
                        isDark,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Ticker tape at top - with RepaintBoundary for optimization
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _tickerAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A1F2E).withOpacity(0.8)
                            : Colors.white.withOpacity(0.9),
                        border: Border(
                          bottom: BorderSide(
                            color: _primaryAccent.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildTickerTape(),
                    );
                  },
                ),
              ),
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _masterController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Investment image with synchronized animations
                        RepaintBoundary(
                          child: Transform.rotate(
                            angle: _logoRotateAnimation.value,
                            child: Transform.scale(
                              scale: _logoScaleAnimation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                child: Image.asset(
                                  'icon/investment.png',
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.contain,
                                  // High quality image rendering
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to a simple container with text if image fails
                                    return Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _primaryAccent,
                                            _secondaryAccent,
                                            _tertiaryAccent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(35),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _primaryAccent.withOpacity(0.3),
                                            blurRadius: 30,
                                            spreadRadius: 5,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'INV',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF0A0E1A) : Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // App title with theme-responsive typography
                        Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              Text(
                                'INVESTMENT',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                  color: _primaryAccent,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 200,
                                height: 1,
                                color: _primaryAccent.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'TRACKING',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'PROFESSIONAL PORTFOLIO MANAGEMENT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: _textSecondary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Theme-responsive loading indicator
                        Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                'LOADING PORTFOLIO DATA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _textSecondary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom theme-responsive border
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _primaryAccent,
                            Colors.transparent,
                          ],
                        ),
                      ),
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

  Widget _buildTickerTape() {
    final tickerItems = [
      'AAPL +2.45%',
      'GOOGL -1.23%',
      'TSLA +5.67%',
      'MSFT +0.89%',
      'AMZN -0.45%',
      'NVDA +3.21%',
      'META +1.78%',
      'BTC +4.32%',
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tickerItems.length * 10,
      itemBuilder: (context, index) {
        final item = tickerItems[index % tickerItems.length];
        final isPositive = item.contains('+');

        return Transform.translate(
          offset: Offset(-MediaQuery.of(context).size.width * _tickerAnimation.value, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      },
    );
  }
}

// Theme-responsive candlestick painter - optimized for performance
class ThemeResponsiveCandlestickPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  // Cache candlestick data for performance
  static List<CandlestickData>? _cachedCandlesticks;

  ThemeResponsiveCandlestickPainter(this.progress, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    // Use cached candlestick data
    _cachedCandlesticks ??= _generateCandlestickData(20);
    final candlesticks = _cachedCandlesticks!;

    final candlestickWidth = size.width / candlesticks.length;
    final progressIndex = (candlesticks.length * progress).floor();

    // Only draw visible candlesticks for performance
    for (int i = 0; i < progressIndex; i++) {
      _drawCandlestick(
        canvas,
        candlesticks[i],
        Offset(i * candlestickWidth + candlestickWidth / 2, 0),
        candlestickWidth * 0.6,
        size.height,
      );
    }
  }

  List<CandlestickData> _generateCandlestickData(int count) {
    final random = math.Random(42);
    final data = <CandlestickData>[];
    double basePrice = 100.0;

    for (int i = 0; i < count; i++) {
      final open = basePrice + (random.nextDouble() - 0.5) * 10;
      final close = open + (random.nextDouble() - 0.5) * 15;
      final high = math.max(open, close) + random.nextDouble() * 8;
      final low = math.min(open, close) - random.nextDouble() * 8;

      data.add(CandlestickData(
        open: open,
        high: high,
        low: low,
        close: close,
      ));

      basePrice = close;
    }

    return data;
  }

  void _drawCandlestick(Canvas canvas, CandlestickData data, Offset center, double width, double height) {
    final isGreen = data.close > data.open;
    final color = isGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.3 : 0.2)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(isDark ? 0.6 : 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Normalize prices to fit canvas
    const maxPrice = 150.0;
    const minPrice = 50.0;
    const priceRange = maxPrice - minPrice;

    final openY = height - ((data.open - minPrice) / priceRange) * height * 0.8;
    final closeY = height - ((data.close - minPrice) / priceRange) * height * 0.8;
    final highY = height - ((data.high - minPrice) / priceRange) * height * 0.8;
    final lowY = height - ((data.low - minPrice) / priceRange) * height * 0.8;

    // Draw wick
    canvas.drawLine(
      Offset(center.dx, highY),
      Offset(center.dx, lowY),
      strokePaint,
    );

    // Draw body
    final bodyRect = Rect.fromLTWH(
      center.dx - width / 2,
      math.min(openY, closeY),
      width,
      (openY - closeY).abs(),
    );

    canvas.drawRect(bodyRect, paint);
    canvas.drawRect(bodyRect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ThemeResponsiveCandlestickPainter &&
        (oldDelegate.progress != progress || oldDelegate.isDark != isDark);
  }
}

class CandlestickData {
  final double open;
  final double high;
  final double low;
  final double close;

  CandlestickData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}