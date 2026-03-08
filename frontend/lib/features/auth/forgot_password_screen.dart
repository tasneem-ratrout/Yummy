import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/app_background.dart';
import '../../../shared/glass_text_field.dart';
import '../../../shared/back_button_widget.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final List<TextEditingController> _codeCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );

  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _errorMessage;

  int _step = 0;
  // 0 = email
  // 1 = verify code
  // 2 = reset password

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    for (final c in _codeCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _codeCtrls.map((e) => e.text).join();

  void _showError(String message) {
    setState(() {
      _loading = false;
      _errorMessage = message;
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email");
      return;
    }

    if (!email.contains("@") || !email.contains(".")) {
      _showError("Please enter a valid email");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() {
      _loading = false;
      _step = 1;
    });
  }

  Future<void> _verifyCode() async {
    if (_enteredCode.length != 4 || _enteredCode.contains(RegExp(r'[^0-9]'))) {
      _showError("Please enter the 4-digit code");
      return;
    }

    /// مثال: الكود الصحيح في الديمو
    if (_enteredCode != "1234") {
      _showError("Invalid verification code");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() {
      _loading = false;
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    final pass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (pass.isEmpty) {
      _showError("Please enter your new password");
      return;
    }

    if (pass.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    if (confirm.isEmpty) {
      _showError("Please confirm your new password");
      return;
    }

    if (pass != confirm) {
      _showError("Passwords do not match");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password reset successfully ✅")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _title() {
    if (_step == 0) return "Forgot Password";
    if (_step == 1) return "Verify Code";
    return "Create New Password";
  }

  String _subtitle() {
    if (_step == 0) {
      return "Enter your email and we’ll send you a verification code.";
    }
    if (_step == 1) {
      return "Enter the 4-digit code sent to\n${_emailCtrl.text.trim()}";
    }
    return "Create a new password for\nyour account.";
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

                Row(
                  children: [
                    AppBackButton(
                      onTap: () {
                        if (_step == 0) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            _errorMessage = null;
                            _loading = false;
                            _step--;
                          });
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  _title(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _subtitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark.withOpacity(0.60),
                  ),
                ),

                const SizedBox(height: 22),

                if (_errorMessage != null)
                  Container(
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
                          Icons.error_outline_rounded,
                          color: Color(0xFFD93025),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD93025),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _step == 0
                      ? _EmailStep(
                          key: const ValueKey("email"),
                          emailCtrl: _emailCtrl,
                        )
                      : _step == 1
                      ? _CodeStep(
                          key: const ValueKey("code"),
                          codeCtrls: _codeCtrls,
                        )
                      : _ResetStep(
                          key: const ValueKey("reset"),
                          newPassCtrl: _newPassCtrl,
                          confirmPassCtrl: _confirmPassCtrl,
                          obscureNew: _obscureNew,
                          obscureConfirm: _obscureConfirm,
                          onToggleNew: () {
                            setState(() => _obscureNew = !_obscureNew);
                          },
                          onToggleConfirm: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : _step == 0
                        ? _sendCode
                        : _step == 1
                        ? _verifyCode
                        : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      disabledBackgroundColor: AppColors.navy,
                      disabledForegroundColor: Colors.white,
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
                        : Text(
                            _step == 0
                                ? "Send Code"
                                : _step == 1
                                ? "Verify"
                                : "Reset Password",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                if (_step == 1)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code resent ✅")),
                      );
                    },
                    child: Text(
                      "Resend Code",
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                if (_step == 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Back to login",
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _EmailStep extends StatelessWidget {
  final TextEditingController emailCtrl;

  const _EmailStep({super.key, required this.emailCtrl});

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      label: "",
      hint: "example@mail.com",
      controller: emailCtrl,
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.mail_outline_rounded,
      validator: (_) => null,
    );
  }
}

class _CodeStep extends StatefulWidget {
  final List<TextEditingController> codeCtrls;

  const _CodeStep({super.key, required this.codeCtrls});

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 3) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        FocusScope.of(context).unfocus();
      }
    } else {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        4,
        (index) => SizedBox(
          width: 68,
          height: 72,
          child: TextField(
            controller: widget.codeCtrls[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: index == 3
                ? TextInputAction.done
                : TextInputAction.next,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
            ),
            onChanged: (value) => _onChanged(value, index),
            decoration: InputDecoration(
              counterText: "",
              filled: true,
              fillColor: AppColors.white.withOpacity(0.88),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.dark.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppColors.dark.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.mediumBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetStep extends StatelessWidget {
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final bool obscureNew;
  final bool obscureConfirm;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;

  const _ResetStep({
    super.key,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.onToggleNew,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassTextField(
          label: "",
          hint: "New password",
          controller: newPassCtrl,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscureNew,
          suffix: IconButton(
            onPressed: onToggleNew,
            icon: Icon(
              obscureNew
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          validator: (_) => null,
        ),
        GlassTextField(
          label: "",
          hint: "Confirm new password",
          controller: confirmPassCtrl,
          keyboardType: TextInputType.visiblePassword,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: obscureConfirm,
          suffix: IconButton(
            onPressed: onToggleConfirm,
            icon: Icon(
              obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          validator: (_) => null,
        ),
      ],
    );
  }
}
