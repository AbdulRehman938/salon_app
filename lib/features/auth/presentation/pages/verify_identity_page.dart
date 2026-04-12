import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

class VerifyIdentityPage extends StatefulWidget {
  const VerifyIdentityPage({
    super.key,
    required this.contact,
    this.initialVerificationId,
    this.initialResendToken,
    this.initialEmailOtp,
  });

  final String contact;
  final String? initialVerificationId;
  final int? initialResendToken;
  final String? initialEmailOtp;

  @override
  State<VerifyIdentityPage> createState() => _VerifyIdentityPageState();
}

class _VerifyIdentityPageState extends State<VerifyIdentityPage> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  final _authService = AuthService();
  Timer? _resendTimer;
  int? _resendToken;
  String? _verificationId;
  bool _isSendingCode = true;
  bool _isVerifyingCode = false;
  int _resendSecondsLeft = 0;
  bool _isResending = false;
  String _errorText = '';
  String? _emailOtp;

  bool get _isEmailFlow => _emailOtp != null;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _verificationId = widget.initialVerificationId;
    _resendToken = widget.initialResendToken;
    _emailOtp = widget.initialEmailOtp;
    _isSendingCode = !_isEmailFlow && _verificationId == null;
    for (final focus in _focusNodes) {
      focus.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focus in _focusNodes) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEmailFlow && _verificationId == null && _isSendingCode) {
      _startPhoneVerification();
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    final digit = value.replaceAll(RegExp(r'\D'), '');
    _controllers[index].text = digit.isEmpty ? '' : digit[digit.length - 1];
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: _controllers[index].text.length),
    );

    if (_controllers[index].text.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onOtpInputChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length <= 1) {
      _onDigitChanged(index, digits);
      return;
    }

    for (var i = index; i < _controllers.length; i++) {
      _controllers[i].text = '';
    }

    var offset = 0;
    while (offset < digits.length && index + offset < _controllers.length) {
      _controllers[index + offset].text = digits[offset];
      offset++;
    }

    final lastFilledIndex = (index + offset - 1).clamp(
      0,
      _controllers.length - 1,
    );
    if (lastFilledIndex < _focusNodes.length - 1) {
      _focusNodes[lastFilledIndex + 1].requestFocus();
    } else {
      _focusNodes[lastFilledIndex].unfocus();
    }

    setState(() {
      _errorText = '';
    });
  }

  Future<void> _continue() async {
    final code = _controllers.map((e) => e.text).join();
    final isValid = _controllers.every(
      (controller) => RegExp(r'^\d$').hasMatch(controller.text),
    );

    if (!isValid) {
      setState(() {
        _errorText = 'Please enter all 6 digits using numbers only.';
      });
      return;
    }

    if (_isEmailFlow) {
      if (code != _emailOtp) {
        setState(() {
          _errorText = 'Invalid code. Please try again.';
        });
        return;
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
      return;
    }

    if (_verificationId == null) {
      setState(() {
        _errorText = 'Please wait, sending OTP...';
      });
      return;
    }

    setState(() {
      _errorText = '';
      _isVerifyingCode = true;
    });

    try {
      await _authService.signInWithSmsCode(
        verificationId: _verificationId!,
        smsCode: code,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Invalid code. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  Future<void> _startPhoneVerification({bool isResend = false}) async {
    setState(() {
      _isSendingCode = true;
      if (!isResend) {
        _errorText = '';
      }
    });

    await _authService.verifyPhone(
      widget.contact,
      forceResendingToken: isResend ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) {
          return;
        }

        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isSendingCode = false;
        });

        if (isResend) {
          _startResendCooldown();
        }
      },
      onVerificationFailed: (message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSendingCode = false;
          _errorText = message ?? 'OTP verification failed.';
        });
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
      onVerificationCompleted: (_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      },
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = 120;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsLeft = 0;
        });
        return;
      }

      setState(() {
        _resendSecondsLeft--;
      });
    });
  }

  Future<bool> _requestResendOtp() async {
    if (_isEmailFlow) {
      final nextOtp = (Random().nextInt(900000) + 100000).toString();
      try {
        final sent = await _authService.sendEmailOTP(widget.contact, nextOtp);
        if (!sent) {
          return false;
        }
        _emailOtp = nextOtp;
        return true;
      } catch (_) {
        return false;
      }
    }

    try {
      await _startPhoneVerification(isResend: true);
      return _verificationId != null;
    } catch (_) {
      return false;
    }
  }

  void _showToast(String message, Color background) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _handleResendTap() async {
    if (_resendSecondsLeft > 0 || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final success = await _requestResendOtp();
      if (!mounted) {
        return;
      }

      if (success) {
        _startResendCooldown();
        _showToast('OTP resent successfully.', AppColors.successGreen);
      } else {
        _showToast(
          'Failed to resend OTP. Please try again.',
          AppColors.errorRed,
        );
      }
    } catch (_) {
      if (mounted) {
        _showToast(
          'Failed to resend OTP. Please try again.',
          AppColors.errorRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  String _formattedResendTime() {
    final minutes = (_resendSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendSecondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _otpBox(int index) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final isActive = _focusNodes[index].hasFocus || hasValue;

    return SizedBox(
      width: 42,
      height: 48,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        cursorColor: AppColors.main,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.dark1,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isActive ? AppColors.mainLight : const Color(0xFFE5E5E5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isActive ? AppColors.main : Colors.transparent,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.main, width: 1.2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onOtpInputChanged(index, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify Your Identity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent a 6-digit code to ${widget.contact}.\nPlease enter it below.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.gray1,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    _otpBox(i),
                    if (i < 5) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: Text(
                  _errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive a code? ",
                    style: TextStyle(
                      color: AppColors.gray1,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: _resendSecondsLeft == 0 && !_isResending
                        ? _handleResendTap
                        : null,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      _isResending
                          ? 'Sending...'
                          : _resendSecondsLeft == 0
                          ? 'Resend'
                          : _formattedResendTime(),
                      style: TextStyle(
                        color: _resendSecondsLeft == 0 && !_isResending
                            ? AppColors.main
                            : AppColors.gray1,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifyingCode ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.main,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isVerifyingCode
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
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
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _cancel,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.dark1,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
