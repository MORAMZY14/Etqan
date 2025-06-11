import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/animation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class VerificationScreen extends StatefulWidget {
  final String email;

  const VerificationScreen({super.key, required this.email});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with  TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _codeFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isResendDisabled = true;
  int _resendCooldown = 30;
  late Timer _timer;

  // Animation controllers
  late AnimationController _entryController;
  late AnimationController _successController;
  late AnimationController _buttonScaleController;
  late AnimationController _liquidController;
  late AnimationController _bottomBarController;

  // Animations
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _successScale;
  late Animation<double> _liquidAnimation;
  late Animation<double> _bottomBarAnimation;

  // Liquid Glass colors
  final Color _primaryColor = const Color(0xFF007AFF); // iOS blue
  final Color _backgroundColor = const Color(0xFFF2F2F7); // iOS system gray 6
  final Color _cardColor = Colors.white.withOpacity(0.8);
  final Color _textColor = const Color(0xFF1C1C1E); // iOS label
  final Color _secondaryTextColor = const Color(0xFF636366); // iOS secondary label
  final Color _errorColor = const Color(0xFFFF3B30); // iOS red
  final Color _glassEffectColor = Colors.white.withOpacity(0.6);

  @override
  void initState() {
    super.initState();

    // Entry animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutQuart,
      ),
    );

    // Button scale animation
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonScaleController,
        curve: Curves.easeInOut,
      ),
    );

    // Success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _successScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _successController,
        curve: Curves.elasticOut,
      ),
    );

    // Liquid glass effect animation
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _liquidAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _liquidController,
        curve: Curves.easeInOut,
      ),
    );

    // Bottom bar animation
    _bottomBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bottomBarAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _bottomBarController,
        curve: Curves.easeOutQuint,
      ),
    );

    _entryController.forward();
    _bottomBarController.forward();
    _codeFocusNode.requestFocus();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _entryController.dispose();
    _buttonScaleController.dispose();
    _successController.dispose();
    _liquidController.dispose();
    _bottomBarController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() => _isResendDisabled = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        setState(() => _isResendDisabled = false);
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      _shakeAnimation();
      return;
    }

    // Button press animation
    await _buttonScaleController.forward();
    await _buttonScaleController.reverse();

    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('verificationCodes').doc(widget.email).get();

      if (!doc.exists || doc.data()?['code'] != _codeController.text.trim()) {
        _shakeAnimation();
        throw FirebaseAuthException(code: 'invalid-code', message: 'Invalid verification code');
      }

      await _firestore.collection('Students').doc(widget.email).update({
        'emailVerified': true,
        'verificationTime': FieldValue.serverTimestamp(),
      });

      final studentDoc = await _firestore.collection('Students').doc(widget.email).get();
      if (studentDoc.exists && studentDoc.data()?['emailVerified'] == true) {
        await _firestore.collection('verificationCodes').doc(widget.email).delete();
        await _showSuccessDialog();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw FirebaseAuthException(
            code: 'verification-failed',
            message: 'Email verification could not be completed'
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Verification failed: ${e.message}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await _successController.forward();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaleTransition(
        scale: _successScale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded,
                    color: _primaryColor,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verified Successfully!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your account has been verified. You can now login to access all features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginPage()),
                            (route) => false,
                      );
                    },
                    child: const Text(
                      'Continue to Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await _successController.reverse();
  }

  void _shakeAnimation() {
    final animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final animation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      ),
    );

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.reverse();
      }
    });

    animationController.addListener(() {
      // This creates the shake effect
    });

    animationController.forward();
    HapticFeedback.lightImpact();

    // Show error on the text field
    setState(() {
      _codeController.clear();
    });

    _showErrorSnackbar('Please enter a valid 6-digit code');
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: _errorColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (_isResendDisabled) return;

    setState(() {
      _isResendDisabled = true;
      _resendCooldown = 30;
      _isLoading = true;
    });

    try {
      final random = Random();
      final code = (100000 + random.nextInt(900000)).toString();

      await _firestore.collection('verificationCodes').doc(widget.email).set({
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('New verification code sent!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _primaryColor,
        ),
      );

      _startCooldownTimer();
    } catch (e) {
      _showErrorSnackbar('Failed to resend code: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLiquidGlassEffect() {
    return AnimatedBuilder(
      animation: _liquidAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _LiquidGlassPainter(
            animationValue: _liquidAnimation.value,
            color: _glassEffectColor,
          ),
          size: Size(MediaQuery.of(context).size.width, 200),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_bottomBarController),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Center(
          child: TextButton(
            onPressed: _isResendDisabled ? null : _resendCode,
            child: Text(
              _isResendDisabled
                  ? 'Resend code in $_resendCooldown seconds'
                  : 'Didn\'t receive code? Resend',
              style: TextStyle(
                color: _isResendDisabled
                    ? _secondaryTextColor
                    : _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Liquid glass background effect
          Positioned.fill(
            child: _buildLiquidGlassEffect(),
          ),

          SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: _textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verify Your Email',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a 6-digit verification code to',
                        style: TextStyle(
                          fontSize: 16,
                          color: _secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _codeController,
                              focusNode: _codeFocusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                                letterSpacing: 8,
                              ),
                              decoration: InputDecoration(
                                hintText: '• • • • • •',
                                hintStyle: TextStyle(
                                  color: _secondaryTextColor.withOpacity(0.3),
                                  letterSpacing: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: _backgroundColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text(
                                    'Verify Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom bar with slide animation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _LiquidGlassPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final path = Path();

    // Create a wave-like pattern that moves with animation
    final waveHeight = size.height * 0.2;
    final waveLength = size.width * 2;

    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      final x = i;
      final y = size.height * 0.7 +
          sin((i / waveLength * 2 * pi) + (animationValue * 2 * pi)) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Add some random bubbles for the liquid effect
    final random = Random(animationValue.toInt());
    final bubblePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.7;
      final radius = random.nextDouble() * 20 + 5;
      canvas.drawCircle(Offset(x, y), radius, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue || color != oldDelegate.color;
  }
}