import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/glass_text_field.dart';
import '../../../shared/app_background.dart';
import '../../../shared/back_button_widget.dart';

import 'package:frontend/features/auth/sign_up_account_screen.dart';
import 'package:frontend/features/auth/forgot_password_screen.dart';

import '../../../core/services/auth_service.dart';
import 'package:frontend/features/home/home_screen.dart';

import 'package:frontend/screen/page_chef_screen/chef_main_screen.dart';

import 'package:frontend/screen/page_admin_screen/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;

  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _loading = false;
    });

    _shakeController.forward(from: 0);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    // ✅ EMAIL EMPTY
    if (email.isEmpty) {
      _showError("Please enter your email");
      return;
    }

    // ✅ EMAIL VALIDATION
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      _showError("Please enter a valid email address");
      return;
    }

    // ✅ PASSWORD EMPTY
    if (pass.isEmpty) {
      _showError("Please enter your password");
      return;
    }

    // ✅ PASSWORD LENGTH
    if (pass.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(email: email, password: pass);

      print("LOGIN RESPONSE => $result");

      if (!mounted) return;

      // ❌ LOGIN FAILED
      if (result['success'] != true) {
        _showError(result['message'] ?? 'Invalid email or password');
        return;
      }

      setState(() {
        _loading = false;
      });

      final role = result['role']?.toString().toLowerCase().trim() ?? 'user';

      print("USER ROLE => $role");

      // ✅ NAVIGATION
      if (role == 'chef') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChefMainScreen()),
        );
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      print("LOGIN ERROR => $e");

      _showError("Something went wrong");
    }
  }

  // ✅ OPEN DASHBOARD
  Future<void> _launchDashboard() async {
    final url = Uri.parse('http://192.168.0.108:3000');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Could not open Dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: h * 0.03),

                const Row(children: [AppBackButton()]),

                const SizedBox(height: 20),

                const Text(
                  "Welcome Back to Yummy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Track your meals. Stay healthy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark.withOpacity(0.60),
                  ),
                ),

                const SizedBox(height: 22),

                // ✅ ERROR BOX
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB3B3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFD93025),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD93025),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ✅ EMAIL
                        GlassTextField(
                          label: "",
                          hint: "example@mail.com",
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          validator: (v) => null,
                        ),

                        // ✅ PASSWORD
                        GlassTextField(
                          label: "",
                          hint: "••••••••",
                          controller: _passCtrl,
                          keyboardType: TextInputType.visiblePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscure = !_obscure;
                              });
                            },
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          validator: (v) => null,
                        ),

                        const SizedBox(height: 12),

                        // ✅ REMEMBER + FORGOT
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.navy,
                              onChanged: (v) {
                                setState(() {
                                  _rememberMe = v ?? true;
                                });
                              },
                            ),

                            Text(
                              "Remember me",
                              style: TextStyle(
                                color: AppColors.darkBlue.withOpacity(0.85),
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const Spacer(),

                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot password?",
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ✅ LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor: AppColors.navy,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Log In",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ✅ OR
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.blueGray.withOpacity(0.35),
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.blueGray,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Divider(
                                color: AppColors.blueGray.withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // ✅ GOOGLE BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              side: BorderSide(
                                color: AppColors.navy.withOpacity(0.35),
                                width: 1.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: AppColors.white.withOpacity(
                                0.45,
                              ),
                            ),
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 30,
                            ),
                            label: const Text(
                              "Continue with Google",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // ✅ SIGN UP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: AppColors.dark.withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpAccountScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
