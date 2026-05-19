import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../view_models/auth_view_model.dart';
import 'login_screen.dart';
import '../../core/theme.dart';
import '../widgets/auth_error_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onLoginTap;
  const RegisterScreen({super.key, required this.onLoginTap});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  UserRole _selectedRole = UserRole.consumer;
  String _selectedGender = 'Male';

  String? _selectedState;
  String? _selectedCity;
  bool isSending = false;
  String? _generatedOtp;
  bool _isOtpSent = false;
  bool _isEmailVerified = false;

  final Map<String, List<String>> _statesAndCities = {
    'Punjab': [
      'Amritsar',
      'Ludhiana',
      'Jalandhar',
      'Patiala',
      'Mohali',
      'Bathinda',
    ],
    'Delhi': [
      'New Delhi',
      'North Delhi',
      'South Delhi',
      'West Delhi',
      'East Delhi',
    ],
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Thane',
      'Nashik',
      'Aurangabad',
    ],
    'Karnataka': ['Bengaluru', 'Mysore', 'Hubballi', 'Belagavi', 'Mangaluru'],
    'Uttar Pradesh': [
      'Lucknow',
      'Kanpur',
      'Ghaziabad',
      'Agra',
      'Meerut',
      'Varanasi',
    ],
    'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Karnal'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar'],
  };

  void _handleRegister(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      if (!_isEmailVerified) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.mail_outline,
                color: Colors.orange,
                size: 32,
              ),
            ),
            title: const Text("Email Not Verified"),
            content: const Text(
              "Please verify your email first by entering the verification code sent to your email address.",
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      if (_selectedRole == UserRole.provider) {
        if (_selectedState == null || _selectedCity == null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              title: const Text("Location Required"),
              content: const Text(
                "Please select your State and City to continue.",
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }
        _sendEmailToAdmin();
      } else {
        _completeRegistration();
      }
    }
  }

  void _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.email_outlined,
              color: Colors.orange,
              size: 32,
            ),
          ),
          title: const Text("Invalid Email"),
          content: const Text("Please enter a valid email address."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => isSending = true);

    final authVM = context.read<AuthViewModel>();
    final exists = await authVM.checkEmailExists(email);

    if (exists) {
      setState(() => isSending = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AuthErrorDialog(
            title: 'Email Already Registered',
            message:
                'This email is already registered. Please use a different email or try logging in.',
            icon: Icons.email,
            buttonText: 'Go to Login',
            onConfirm: () {
              Navigator.pop(context);
              widget.onLoginTap();
            },
          ),
        );
      }
      return;
    }

    _generatedOtp = (Random().nextInt(900000) + 100000).toString();

    final success = await _sendEmailViaEmailJS(
      templateParams: {
        'email': _emailController.text,
        'otp': _generatedOtp,
        'time': DateTime.now().toLocal().toString().split('.')[0],
      },
    );

    setState(() => isSending = false);

    if (mounted) {
      if (success) {
        setState(() {
          _isOtpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification code sent to your email"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AuthErrorDialog(
            title: 'Failed to Send OTP',
            message:
                'We couldn\'t send the verification code. Please check your internet connection and try again.',
            icon: Icons.error_outline,
            buttonText: 'Retry',
            onConfirm: () {
              Navigator.pop(context);
              _sendOtp();
            },
          ),
        );
      }
    }
  }

  void _verifyOtp() {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter the OTP")));
      return;
    }

    if (_otpController.text == _generatedOtp) {
      setState(() {
        _isEmailVerified = true;
        _isOtpSent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email verified successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AuthErrorDialog(
          title: 'Invalid OTP',
          message:
              'The verification code you entered is incorrect. Please check and try again.',
          icon: Icons.error_outline,
          buttonText: 'Try Again',
          onConfirm: () {
            Navigator.pop(context);
            _otpController.clear();
          },
        ),
      );
    }
  }

  Future<bool> _sendEmailViaEmailJS({
    required Map<String, dynamic> templateParams,
  }) async {
    const serviceId = 'service_gcr01ra';
    const tempId = 'template_m8r3std';
    const publicKey = 'ON_pVSKX8vhc3XEhM';
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': tempId,
          'user_id': publicKey,
          'template_params': templateParams,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _completeRegistration() async {
    final authVM = context.read<AuthViewModel>();
    final success = await authVM.registerUser(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AuthErrorDialog(
            title: authVM.getErrorTitle(authVM.errorCode ?? 'unknown'),
            message:
                authVM.errorMessage ?? 'Registration failed. Please try again.',
            icon: Icons.error_outline,
            buttonText: authVM.isRecoverableError(authVM.errorCode ?? '')
                ? 'Try Again'
                : 'Close',
            onConfirm: () {
              Navigator.pop(context);
              if (authVM.errorCode == 'email-already-in-use') {
                widget.onLoginTap();
              }
            },
          ),
        );
      }
    }
  }

  Future<void> _sendEmailToAdmin() async {
    setState(() => isSending = true);

    final templateParams = {
      'name': _nameController.text,
      'email': _emailController.text,
      'role': 'Provider',
      'age': _ageController.text,
      'gender': _selectedGender,
      'skills': _skillsController.text,
      'city': _selectedCity ?? '',
      'state': _selectedState ?? '',
      'time': DateTime.now().toLocal().toString().split('.')[0],
    };

    final success = await _sendEmailViaEmailJS(templateParams: templateParams);

    if (success) {
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc();
        await docRef.set({
          'uid': docRef.id,
          'name': _nameController.text,
          'email': _emailController.text,
          'role': 'provider',
          'isVerified': false,
          'isActive': false,
          'age': int.tryParse(_ageController.text) ?? 0,
          'gender': _selectedGender,
          'serviceType': _skillsController.text,
          'state': _selectedState,
          'city': _selectedCity,
          'createdAt': FieldValue.serverTimestamp(),
          'rating': 0.0,
          'reviewCount': 0,
        });
      } catch (e) {
        debugPrint("Error saving provider to Firestore: $e");
      }
    }

    setState(() => isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Application Submitted Successfully"
                : "Submission Failed",
          ),
        ),
      );
      if (success) {
        setState(() {
          _nameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _ageController.clear();
          _skillsController.clear();
          _selectedState = null;
          _selectedCity = null;
          _isEmailVerified = false; // Reset for next use
        });
      }
    }
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
                height: 220,
                width: double.infinity,
                color: theme.primaryColor,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedRole == UserRole.consumer
                            ? "Create Account"
                            : "Partner with Us",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRole == UserRole.consumer
                            ? "Join the Quick Hub Community"
                            : "Submit your details to start earning",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildRoleToggle(isDark, theme),
                    const SizedBox(height: 25),

                    _buildTextField(
                      _nameController,
                      "Full Name",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 15),

                    // Email field with Verify button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _emailController,
                            "Email Address",
                            Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isEmailVerified,
                          ),
                        ),
                        if (!_isEmailVerified) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: ElevatedButton(
                              onPressed: isSending ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 45),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_isOtpSent ? "Resend" : "Verify"),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 10),
                          const Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // OTP Field if code is sent
                    if (_isOtpSent && !_isEmailVerified) ...[
                      const SizedBox(height: 15),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _otpController,
                              "Enter OTP",
                              Icons.lock_clock,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: ElevatedButton(
                              onPressed: _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 45),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text("Confirm"),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 15),

                    if (_selectedRole == UserRole.consumer) ...[
                      _buildTextField(
                        _passwordController,
                        "Password",
                        Icons.lock_outline,
                        obscure: true,
                      ),
                    ],

                    if (_selectedRole == UserRole.provider) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: const InputDecoration(
                          labelText: "Select State",
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        items: _statesAndCities.keys
                            .map(
                              (state) => DropdownMenuItem(
                                value: state,
                                child: Text(state),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedState = val;
                          _selectedCity = null;
                        }),
                        validator: (val) => val == null ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: const InputDecoration(
                          labelText: "Select City",
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: _selectedState == null
                            ? []
                            : _statesAndCities[_selectedState]!
                                  .map(
                                    (city) => DropdownMenuItem(
                                      value: city,
                                      child: Text(city),
                                    ),
                                  )
                                  .toList(),
                        onChanged: (val) => setState(() => _selectedCity = val),
                        disabledHint: const Text("Select a state first"),
                        validator: (val) => val == null ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _ageController,
                              "Age",
                              Icons.calendar_today,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: "Gender",
                              ),
                              items: ['Male', 'Female', 'Other']
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedGender = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        _skillsController,
                        "Skills (e.g. Plumbing, Cleaning)",
                        Icons.build_outlined,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Your application will be sent for admin verification. Once approved, you can set your password via 'Forgot Password'.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 30),
                    Consumer<AuthViewModel>(
                      builder: (context, authVM, child) {
                        if (authVM.isLoading) {
                          return const CircularProgressIndicator();
                        }
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: () => _handleRegister(context),
                          child: Text(
                            _selectedRole == UserRole.consumer
                                ? "Sign up"
                                : "Submit Application",
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLoginLink(isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
      validator: (value) => value!.isEmpty ? "Required" : null,
    );
  }

  Widget _buildRoleToggle(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : AppTheme.primaryLightBlue,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildRoleButton(UserRole.consumer, "Need Services", theme, isDark),
          _buildRoleButton(
            UserRole.provider,
            "Provide Services",
            theme,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(
    UserRole role,
    String label,
    ThemeData theme,
    bool isDark,
  ) {
    bool isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = role;
          _isEmailVerified = false;
          _isOtpSent = false;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (isDark ? Colors.white70 : Colors.white)
                  : (isDark ? Colors.white70 : AppTheme.primaryDarkBlue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        GestureDetector(
          onTap: widget.onLoginTap,
          child: Text(
            "Log In",
            style: TextStyle(
              color: isDark ? AppTheme.white : AppTheme.primaryDarkBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
