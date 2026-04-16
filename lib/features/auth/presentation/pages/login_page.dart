import 'dart:ui';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/country_phone_data.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/country_service.dart';
import 'verify_identity_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _random = Random();
  final _form = FormGroup({
    'identifier': FormControl<String>(
      validators: [
        Validators.required,
        Validators.delegate(_emailOrPhoneValidator),
      ],
    ),
    'country': FormControl<CountryPhoneData>(),
  });

  final _countryService = CountryService();
  final _authService = AuthService();
  late final Future<List<CountryPhoneData>> _countriesFuture;

  bool _isPhoneMode = false;
  bool _isSubmitting = false;
  CountryPhoneData? _selectedCountry;
  String _identifierFormatError = '';

  String _phoneOtpErrorMessage(String? rawMessage) {
    final message = (rawMessage ?? '').trim();
    if (message.isEmpty) {
      return 'Unable to send SMS OTP right now. Please use email OTP.';
    }

    final normalized = message.toUpperCase();
    if (normalized.contains('BILLING_NOT_ENABLED')) {
      return 'SMS OTP is unavailable because Firebase billing is not enabled. Please sign in with email OTP.';
    }
    if (normalized.contains(
      'SMS UNABLE TO BE SENT UNTIL THIS REGION ENABLED',
    )) {
      return 'SMS OTP is blocked for this region. Please sign in with email OTP.';
    }
    if (normalized.contains('OPERATION_NOT_ALLOWED')) {
      return 'Phone OTP is disabled in Firebase settings. Please sign in with email OTP.';
    }

    return '$message Please use email OTP.';
  }

  static Map<String, dynamic>? _emailOrPhoneValidator(
    AbstractControl<dynamic> control,
  ) {
    final raw = (control.value as String? ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    if (raw.contains('@')) {
      const emailPattern = r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
      return RegExp(emailPattern).hasMatch(raw) ? null : {'emailOrPhone': true};
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return {'emailOrPhone': true};
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _countriesFuture = _countryService.fetchCountries().then((countries) {
      if (!mounted || countries.isEmpty) {
        return countries;
      }

      CountryPhoneData defaultCountry = countries.first;
      for (final country in countries) {
        if (country.dialCode == '+92') {
          defaultCountry = country;
          break;
        }
      }

      setState(() {
        _selectedCountry = defaultCountry;
      });
      (_form.control('country') as FormControl<CountryPhoneData>).value =
          defaultCountry;
      return countries;
    });
    _form.control('identifier').valueChanges.listen((value) {
      final text = (value as String? ?? '').trim();
      final shouldUsePhoneMode =
          text.isNotEmpty &&
          !text.contains('@') &&
          RegExp(r'^[\d\s()+-]+$').hasMatch(text);
      final countryControl =
          _form.control('country') as FormControl<CountryPhoneData>;

      if (shouldUsePhoneMode) {
        countryControl.setValidators([Validators.required]);
      } else {
        countryControl.clearValidators();
      }
      countryControl.updateValueAndValidity();

      if (_isPhoneMode != shouldUsePhoneMode) {
        setState(() {
          _isPhoneMode = shouldUsePhoneMode;
        });
      }

      if (_identifierFormatError.isNotEmpty) {
        setState(() {
          _identifierFormatError = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickCountry(List<CountryPhoneData> countries) async {
    String searchQuery = '';

    final selected = await showModalBottomSheet<CountryPhoneData>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final filtered = countries.where((country) {
                    final q = searchQuery.toLowerCase();
                    if (q.isEmpty) {
                      return true;
                    }
                    return country.name.toLowerCase().contains(q) ||
                        country.dialCode.contains(q) ||
                        country.iso2.toLowerCase().contains(q);
                  }).toList();

                  return Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value.trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search country or code',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.mainLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final country = filtered[index];
                              return ListTile(
                                onTap: () => Navigator.of(context).pop(country),
                                title: Text('${country.flag}  ${country.name}'),
                                subtitle: Text(
                                  '${country.dialCode}  •  ${country.phoneFormat}',
                                  style: const TextStyle(
                                    color: AppColors.gray1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedCountry = selected;
      _identifierFormatError = '';
    });
    (_form.control('country') as FormControl<CountryPhoneData>).value =
        selected;
  }

  bool _isPhoneValidForCountry(String input, CountryPhoneData country) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final requiredDigits = RegExp('#').allMatches(country.phoneFormat).length;
    if (requiredDigits <= 0) {
      return digits.length >= 7 && digits.length <= 15;
    }
    return digits.length == requiredDigits;
  }

  Future<void> _continue(FormGroup form) async {
    form.markAllAsTouched();
    if (!form.valid) {
      return;
    }

    final identifier = (_form.control('identifier').value as String? ?? '')
        .trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isPhoneMode && _selectedCountry != null) {
        final validByCountry = _isPhoneValidForCountry(
          identifier,
          _selectedCountry!,
        );
        if (!validByCountry) {
          setState(() {
            _identifierFormatError =
                'Invalid phone format for ${_selectedCountry!.dialCode}. Use ${_selectedCountry!.phoneFormat}';
          });
          return;
        }

        setState(() {
          _identifierFormatError = '';
        });

        final phoneNumber =
            '${_selectedCountry!.dialCode}${identifier.replaceAll(RegExp(r'\D'), '')}';

        if (await _authService.isSignedInWithIdentifier(
          identifier: identifier,
          isPhoneMode: true,
          phoneNumber: phoneNumber,
        )) {
          if (!mounted) {
            return;
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
          return;
        }

        unawaited(
          _authService.verifyPhone(
            phoneNumber,
            onCodeSent: (verificationId, resendToken) async {
              if (!mounted) {
                return;
              }

              setState(() {
                _isSubmitting = false;
              });

              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerifyIdentityPage(
                    contact: phoneNumber,
                    initialVerificationId: verificationId,
                    initialResendToken: resendToken,
                  ),
                ),
              );

              if (!mounted) {
                return;
              }
              (_form.control('identifier') as FormControl<String>).value = '';
              (_form.control('identifier') as FormControl<String>)
                ..markAsUntouched()
                ..markAsPristine();
              setState(() {
                _isPhoneMode = false;
              });
            },
            onVerificationFailed: (message) {
              if (!mounted) {
                return;
              }
              setState(() {
                _isSubmitting = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_phoneOtpErrorMessage(message)),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            },
          ),
        );
        return;
      } else {
        final normalizedEmail = _authService.normalizeEmail(identifier);

        bool isVerifiedEmail = false;
        try {
          isVerifiedEmail = await _authService.isEmailVerifiedInFirestore(
            normalizedEmail,
          );
        } on FirebaseException catch (e) {
          final isTransientFirestoreChannelIssue =
              e.code == 'channel-error' || e.code == 'unavailable';
          if (!isTransientFirestoreChannelIssue) {
            rethrow;
          }
        }

        if (isVerifiedEmail) {
          await _authService.setSessionVerifiedEmail(normalizedEmail);
          await _authService.ensureAuthenticatedSessionForVerifiedEmail(
            normalizedEmail,
          );
          if (!mounted) {
            return;
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
          return;
        }

        final emailOtp = (_random.nextInt(900000) + 100000).toString();
        final sent = await _authService.sendEmailOTP(normalizedEmail, emailOtp);

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

        await _authService.saveEmailOtp(
          email: normalizedEmail,
          otpCode: emailOtp,
        );

        if (!mounted) {
          return;
        }

        final verifiedInOtp = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                VerifyIdentityPage(contact: normalizedEmail, isEmailFlow: true),
          ),
        );

        if (!mounted) {
          return;
        }

        if (verifiedInOtp == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email verified. Please continue again to sign in.',
              ),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
        return;
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      final message = switch (e.code) {
        'channel-error' =>
          'Firestore connection channel failed. Fully stop the app and run it again (not hot reload).',
        'permission-denied' =>
          'Firebase permission denied while checking/saving OTP. Please update Firestore rules.',
        'unavailable' =>
          'Firebase service is currently unavailable. Please try again.',
        _ => e.message ?? 'Firebase error: ${e.code}',
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
          content: Text('Unable to continue: $e'),
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

  Widget _buildCountryPrefix(List<CountryPhoneData> countries) {
    final label = _selectedCountry == null
        ? '+Code'
        : '${_selectedCountry!.flag} ${_selectedCountry!.dialCode}';

    return GestureDetector(
      onTap: () => _pickCountry(countries),
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.mainLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  String _identifierError() {
    if (_identifierFormatError.isNotEmpty) {
      return _identifierFormatError;
    }

    final control = _form.control('identifier');
    if (!control.invalid || !control.touched) {
      return '';
    }
    if (control.hasError(ValidationMessage.required)) {
      return 'Please enter email or phone number.';
    }
    return 'Please enter a valid email or phone number.';
  }

  String _countryError() {
    final control = _form.control('country');
    if (_isPhoneMode && control.invalid && control.touched) {
      return 'Please select a country code for phone login.';
    }
    return '';
  }

  Future<void> _continueWithGoogle() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential?.user == null || !mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.message ?? 'Google sign-in failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: $e'),
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

  Future<void> _continueWithApple() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await _authService.signInWithApple();
      if (credential?.user == null || !mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      final message = switch (e.code) {
        'apple-not-available' =>
          'Apple sign-in is not available on this device.',
        'apple-not-configured' =>
          'Apple sign-in setup is incomplete. Configure APPLE_SERVICE_ID and APPLE_REDIRECT_URI.',
        _ => e.message ?? 'Apple sign-in failed.',
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
          content: Text('Apple sign-in failed: $e'),
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

  Widget _socialButton({
    required String title,
    required Color background,
    required Color foreground,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _isSubmitting ? null : onPressed,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(iconPath, width: 20, height: 20, fit: BoxFit.contain),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopLogoSection() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 5),
          color: Colors.black.withValues(alpha: 0.24),
          child: Center(
            child: Image.asset(
              'assets/logo.png',
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CountryPhoneData>>(
      future: _countriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.main),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load countries. Please check internet and reload.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final countries = snapshot.data ?? const <CountryPhoneData>[];

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
                  child: Column(
                    children: [
                      const SizedBox(height: 150),
                      _buildTopLogoSection(),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -8),
                                  child: const Text(
                                    'Book Your Perfect\nLook in Minutes!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 24,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _identifierError(),
                                      style: const TextStyle(
                                        color: AppColors.errorRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                ReactiveTextField<String>(
                                  formControlName: 'identifier',
                                  showErrors: (_) => false,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(
                                    color: AppColors.dark2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter your email or phone number.',
                                    hintStyle: const TextStyle(
                                      color: AppColors.gray1,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: _isPhoneMode
                                        ? _buildCountryPrefix(countries)
                                        : null,
                                    prefixIconConstraints: const BoxConstraints(
                                      minHeight: 0,
                                      minWidth: 0,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                if (_countryError().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _countryError(),
                                    style: const TextStyle(
                                      color: AppColors.errorRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 56,
                                  child: ReactiveFormConsumer(
                                    builder: (context, form, _) =>
                                        ElevatedButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : () => _continue(form),
                                          style: ElevatedButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: AppColors.main,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: _isSubmitting
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Or',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _socialButton(
                                  title: 'Continue with Apple',
                                  background: AppColors.dark1,
                                  foreground: Colors.white,
                                  iconPath: 'assets/apple_icon.png',
                                  onPressed: _continueWithApple,
                                ),
                                const SizedBox(height: 10),
                                _socialButton(
                                  title: 'Continue with Google',
                                  background: Colors.white,
                                  foreground: AppColors.dark1,
                                  iconPath: 'assets/Google_icon.png',
                                  onPressed: _continueWithGoogle,
                                ),
                              ],
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
      },
    );
  }
}
