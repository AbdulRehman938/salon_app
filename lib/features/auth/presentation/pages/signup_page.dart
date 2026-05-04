import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../data/services/auth_service.dart';
import 'verify_identity_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const int _maxProfileImageBytes = 2 * 1024 * 1024;

  final _authService = AuthService();
  final _picker = ImagePicker();
  final _random = Random();

  final _form = FormGroup({
    'firstName': FormControl<String>(
      validators: [
        Validators.required,
        Validators.minLength(2),
        Validators.pattern(r'^[A-Za-z ]+$'),
      ],
    ),
    'lastName': FormControl<String>(
      validators: [
        Validators.required,
        Validators.minLength(2),
        Validators.pattern(r'^[A-Za-z ]+$'),
      ],
    ),
    'email': FormControl<String>(
      validators: [Validators.required, Validators.email],
    ),
    'phoneNumber': FormControl<String>(
      validators: [
        Validators.required,
        Validators.minLength(7),
        Validators.pattern(r'^\+?[0-9 ]+$'),
      ],
    ),
    'city': FormControl<String>(
      validators: [Validators.required, Validators.minLength(2)],
    ),
    'address': FormControl<String>(
      validators: [Validators.required, Validators.minLength(5)],
    ),
    'gender': FormControl<String>(validators: [Validators.required]),
  });

  bool _isSubmitting = false;
  Uint8List? _profileImageBytes;
  String? _profileImageBase64;

  static const List<String> _genderOptions = <String>[
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  String? _fieldError(String fieldName, String label) {
    final control = _form.control(fieldName);
    if (!control.invalid || !control.touched) {
      return null;
    }

    if (control.hasError(ValidationMessage.required)) {
      return '$label is required.';
    }
    if (control.hasError(ValidationMessage.minLength)) {
      return '$label must be at least 2 characters.';
    }
    if (control.hasError(ValidationMessage.email)) {
      return 'Please enter a valid email address.';
    }
    if (control.hasError(ValidationMessage.pattern)) {
      if (fieldName == 'phoneNumber') {
        return 'Phone number can contain digits, spaces, and optional +.';
      }
      return '$label can contain letters and spaces only.';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    String? errorText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    if (_isSubmitting) {
      return;
    }

    try {
      XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxHeight: 1024,
        maxWidth: 1024,
      );

      // Some platforms/dev environments may fail when resize/compression args
      // are provided. Retry with basic picker options before showing an error.
      file ??= await _picker.pickImage(source: ImageSource.gallery);

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return;
      }

      if (bytes.lengthInBytes > _maxProfileImageBytes) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture must be 2MB or smaller.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      setState(() {
        _profileImageBytes = bytes;
        _profileImageBase64 = base64Encode(bytes);
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }

      final reason = (e.message ?? '').trim();
      final lowerReason = reason.toLowerCase();
      final message = lowerReason.contains('permission')
          ? 'Gallery permission is required to select a profile picture.'
          : reason.isNotEmpty
          ? 'Unable to pick profile picture: $reason'
          : 'Unable to pick profile picture. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to pick profile picture: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _submitSignup(FormGroup form) async {
    form.markAllAsTouched();
    if (!form.valid) {
      return;
    }

    if (_profileImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a profile picture.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final firstName = (form.control('firstName').value as String? ?? '').trim();
    final lastName = (form.control('lastName').value as String? ?? '').trim();
    final rawEmail = (form.control('email').value as String? ?? '').trim();
    final phoneNumber = (form.control('phoneNumber').value as String? ?? '')
        .trim();
    final city = (form.control('city').value as String? ?? '').trim();
    final address = (form.control('address').value as String? ?? '').trim();
    final gender = (form.control('gender').value as String? ?? '').trim();
    final email = _authService.normalizeEmail(rawEmail);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final alreadyExists = await _authService.isEmailAlreadyRegistered(email);
      if (alreadyExists) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This email is already registered. Please log in instead.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final emailOtp = (_random.nextInt(900000) + 100000).toString();
      final sent = await _authService.sendEmailOTP(email, emailOtp);
      if (!sent) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP email. Please try again.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      await _authService.saveEmailOtp(email: email, otpCode: emailOtp);

      if (!mounted) {
        return;
      }

      final verifiedInOtp = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VerifyIdentityPage(contact: email, isEmailFlow: true),
        ),
      );

      if (verifiedInOtp != true || !mounted) {
        return;
      }

      await _authService.completeEmailSignupProfile(
        email: email,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        city: city,
        address: address,
        gender: gender,
        profileImageBase64: _profileImageBase64,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      final message = switch (e.code) {
        'permission-denied' =>
          'Signup failed due to Firebase permission issue. Please update rules.',
        'unavailable' => 'Firebase service is unavailable. Please try again.',
        _ => e.message ?? 'Unable to complete signup right now.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete signup: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: _form,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with Mesh Gradient Overlay
            Image.asset('assets/signin1.png', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4A90E2).withOpacity(0.4),
                    const Color(0xFF1A1A1A).withOpacity(0.9),
                  ],
                ),
              ),
            ),
            // Floating Decorative Circles for "Aura" effect
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90E2).withOpacity(0.15),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ColorFilter.mode(
                            Colors.white.withOpacity(0.05),
                            BlendMode.srcOver,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Create Account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Join our community of beauty lovers',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Profile Picture Section with Glow
                                Center(
                                  child: GestureDetector(
                                    onTap: _isSubmitting ? null : _pickProfileImage,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF4A90E2).withOpacity(0.3),
                                                blurRadius: 20,
                                                spreadRadius: 5,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFF4A90E2),
                                              width: 3,
                                            ),
                                            image: _profileImageBytes == null
                                                ? null
                                                : DecorationImage(
                                                    image: MemoryImage(_profileImageBytes!),
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          child: _profileImageBytes == null
                                              ? const Icon(
                                                  Icons.add_a_photo_rounded,
                                                  color: Color(0xFF4A90E2),
                                                  size: 32,
                                                )
                                              : null,
                                        ),
                                        if (_profileImageBytes == null)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4A90E2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Profile Picture',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Name Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: ReactiveTextField<String>(
                                        formControlName: 'firstName',
                                        readOnly: _isSubmitting,
                                        decoration: _inputDecoration(
                                          label: 'First Name',
                                          icon: Icons.person_outline_rounded,
                                          errorText: _fieldError('firstName', 'First name'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ReactiveTextField<String>(
                                        formControlName: 'lastName',
                                        readOnly: _isSubmitting,
                                        decoration: _inputDecoration(
                                          label: 'Last Name',
                                          icon: Icons.badge_outlined,
                                          errorText: _fieldError('lastName', 'Last name'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ReactiveTextField<String>(
                                  formControlName: 'email',
                                  readOnly: _isSubmitting,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    errorText: _fieldError('email', 'Email'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ReactiveTextField<String>(
                                  formControlName: 'phoneNumber',
                                  readOnly: _isSubmitting,
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputDecoration(
                                    label: 'Phone Number',
                                    icon: Icons.phone_outlined,
                                    errorText: _fieldError('phoneNumber', 'Phone'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: ReactiveTextField<String>(
                                        formControlName: 'city',
                                        readOnly: _isSubmitting,
                                        decoration: _inputDecoration(
                                          label: 'City',
                                          icon: Icons.location_city_outlined,
                                          errorText: _fieldError('city', 'City'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ReactiveDropdownField<String>(
                                        formControlName: 'gender',
                                        isExpanded: true,
                                        decoration: _inputDecoration(
                                          label: 'Gender',
                                          errorText: _fieldError('gender', 'Gender'),
                                        ),
                                        items: _genderOptions
                                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ReactiveTextField<String>(
                                  formControlName: 'address',
                                  readOnly: _isSubmitting,
                                  decoration: _inputDecoration(
                                    label: 'Residential Address',
                                    icon: Icons.home_outlined,
                                    errorText: _fieldError('address', 'Address'),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Enhanced Continue Button
                                SizedBox(
                                  height: 60,
                                  child: ReactiveFormConsumer(
                                    builder: (context, form, _) => Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4A90E2).withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting ? null : () => _submitSignup(form),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: Text(
                                          _isSubmitting ? 'Creating Account...' : 'Continue',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Already have an account? ',
                                      style: TextStyle(color: Color(0xFF666666)),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          color: Color(0xFF4A90E2),
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
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
