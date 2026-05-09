import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_hub_project/view/screens/register_screen.dart';
import '../../view_models/auth_view_model.dart';
import '../../core/theme.dart';
import '../widgets/auth_error_scaffold.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onRegisterTap;
  const LoginScreen({super.key, required this.onRegisterTap});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authVM = context.read<AuthViewModel>();
      final success = await authVM.loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        if (!success) {
          _showLoginErrorDialog(authVM);
        } else {
          // Success is handled by AuthenticationWrapper in main.dart
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login Successful! Welcome back."),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _showLoginErrorDialog(AuthViewModel authVM) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(Icons.error_outline, color: Colors.red, size: 32),
        ),
        title: Text(authVM.getErrorTitle(authVM.errorCode ?? 'unknown')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authVM.errorMessage ?? "Login failed. Please try again."),
              const SizedBox(height: 12),
              if (authVM.isNetworkError(authVM.errorCode ?? ''))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Check your internet connection",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (authVM.isRateLimitError(authVM.errorCode ?? ''))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Please wait a few minutes before trying again",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (authVM.errorCode == 'user-not-found' ||
                  authVM.errorCode == 'invalid-credential')
                GestureDetector(
                  onTap: widget.onRegisterTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.app_registration,
                          color: Colors.blue,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Create a new account",
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (authVM.errorCode == 'wrong-password')
                GestureDetector(
                  onTap: () => _showForgotPasswordDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_reset, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Reset your password",
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          if (authVM.isRecoverableError(authVM.errorCode ?? ''))
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _emailController.clear();
                _passwordController.clear();
              },
              child: const Text("Try Again"),
            ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email to receive a password reset link."),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                hintText: "Email Address",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          Consumer<AuthViewModel>(
            builder: (context, authVM, child) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 40),
                ),
                onPressed: authVM.isLoading
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text("Please enter your email"),
                            ),
                          );
                          return;
                        }

                        final success = await authVM.sendPasswordResetEmail(
                          email,
                        );

                        if (dialogContext.mounted) {
                          if (!success) {
                            // Show comprehensive error dialog
                            showDialog(
                              context: dialogContext,
                              builder: (errorDialogContext) => AlertDialog(
                                icon: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 32,
                                  ),
                                ),
                                title: Text(
                                  authVM.getErrorTitle(
                                    authVM.errorCode ?? 'unknown',
                                  ),
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authVM.errorMessage ??
                                            "Failed to send reset link.",
                                      ),
                                      if (authVM.isNetworkError(
                                        authVM.errorCode ?? '',
                                      )) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.wifi_off,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  "Check your internet connection",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(errorDialogContext);
                                      Navigator.pop(dialogContext);
                                    },
                                    child: const Text("Close"),
                                  ),
                                  if (authVM.isRecoverableError(
                                    authVM.errorCode ?? '',
                                  ))
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(errorDialogContext);
                                      },
                                      child: const Text("Retry"),
                                    ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Reset link sent! Check your email.",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: authVM.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Send"),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ClipPath(
              clipper: MyCustomClipper(),
              child: Container(
                height: 280,
                width: double.infinity,
                color: theme.primaryColor,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.handyman,
                        size: 60,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Quick Hub",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      Text(
                        '"Sab Kaam Yahan"',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withOpacity(0.8),
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: "Email Address",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Enter your email" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Enter your password" : null,
                    ),
                    const SizedBox(height: 15),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(),
                        child: Text(
                          "Forgot password?",
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.white
                                : AppTheme.primaryDarkBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Consumer<AuthViewModel>(
                      builder: (context, authVM, child) {
                        if (authVM.isLoading) {
                          return const CircularProgressIndicator();
                        }
                        return ElevatedButton(onPressed: () async {
                          await analytics.setUserId();
                          await analytics.setUserProperty(name: 'email', value: _emailController.text);
                          await analytics.logLogin();
                           _handleLogin();

                        },
                          child: const Text("Log in"),);
                      },
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onRegisterTap,
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.white
                                  : AppTheme.primaryDarkBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCustomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
