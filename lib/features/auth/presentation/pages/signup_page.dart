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
            Image.asset('assets/signin1.png', fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x26000000), Color(0xCC000000)],
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 72, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom -
                            92,
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFEFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFD7DEED),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x260B0C15),
                                blurRadius: 18,
                                offset: Offset(0, 8),
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
                                  color: AppColors.dark1,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Set up your profile to continue',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.gray1,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: GestureDetector(
                                  onTap: _isSubmitting
                                      ? null
                                      : _pickProfileImage,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: AppColors.main,
                                        width: 1.8,
                                      ),
                                      image: _profileImageBytes == null
                                          ? null
                                          : DecorationImage(
                                              image: MemoryImage(
                                                _profileImageBytes!,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                    child: _profileImageBytes == null
                                        ? const Icon(
                                            Icons.add_a_photo_rounded,
                                            color: AppColors.main,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to add profile picture',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.gray1,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: ReactiveTextField<String>(
                                      formControlName: 'firstName',
                                      readOnly: _isSubmitting,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        label: 'First Name',
                                        errorText: _fieldError(
                                          'firstName',
                                          'First name',
                                        ),
                                        icon: Icons.person_outline_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ReactiveTextField<String>(
                                      formControlName: 'lastName',
                                      readOnly: _isSubmitting,
                                      textInputAction: TextInputAction.next,
                                      decoration: _inputDecoration(
                                        label: 'Last Name',
                                        errorText: _fieldError(
                                          'lastName',
                                          'Last name',
                                        ),
                                        icon: Icons.badge_outlined,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ReactiveTextField<String>(
                                formControlName: 'email',
                                readOnly: _isSubmitting,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  errorText: _fieldError('email', 'Email'),
                                  icon: Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReactiveTextField<String>(
                                formControlName: 'phoneNumber',
                                readOnly: _isSubmitting,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: 'Phone Number',
                                  errorText: _fieldError(
                                    'phoneNumber',
                                    'Phone number',
                                  ),
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final useSingleColumn =
                                      constraints.maxWidth < 430;

                                  final cityField = ReactiveTextField<String>(
                                    formControlName: 'city',
                                    readOnly: _isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      label: 'City',
                                      errorText: _fieldError('city', 'City'),
                                      icon: Icons.location_city_outlined,
                                    ),
                                  );

                                  final genderField =
                                      ReactiveDropdownField<String>(
                                        formControlName: 'gender',
                                        isExpanded: true,
                                        decoration: _inputDecoration(
                                          label: 'Gender',
                                          errorText: _fieldError(
                                            'gender',
                                            'Gender',
                                          ),
                                        ),
                                        items: _genderOptions
                                            .map(
                                              (value) =>
                                                  DropdownMenuItem<String>(
                                                    value: value,
                                                    child: Text(
                                                      value,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                            )
                                            .toList(),
                                      );

                                  if (useSingleColumn) {
                                    return Column(
                                      children: [
                                        cityField,
                                        const SizedBox(height: 12),
                                        genderField,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: cityField),
                                      const SizedBox(width: 10),
                                      Expanded(child: genderField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              ReactiveTextField<String>(
                                formControlName: 'address',
                                readOnly: _isSubmitting,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  label: 'Address',
                                  errorText: _fieldError('address', 'Address'),
                                  icon: Icons.home_outlined,
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 54,
                                child: ReactiveFormConsumer(
                                  builder: (context, form, _) => ElevatedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _submitSignup(form),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: AppColors.main,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _isSubmitting
                                          ? 'Signing Up ...'
                                          : 'Continue',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 8,
                    child: IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
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
