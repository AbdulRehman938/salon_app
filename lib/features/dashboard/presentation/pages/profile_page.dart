import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/verify_identity_page.dart';
import '../widgets/dashboard_bottom_nav.dart';
import 'bookings_page.dart';
import 'dashboard_page.dart';
import 'edit_email_page.dart';
import 'favorites_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const int _maxProfileImageBytes = 2 * 1024 * 1024;

  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final Random _random = Random();

  Map<String, dynamic>? _profileData;
  bool _isProfileLoading = true;
  bool _isSaving = false;
  bool _isSigningOut = false;

  void _showInfoMessage(String message, {Color? color}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.dark1,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isProfileLoading = true;
    });

    try {
      final data = await _authService.getCurrentUserProfileData();
      if (!mounted) {
        return;
      }

      setState(() {
        _profileData = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load profile: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
      }
    }
  }

  String _read(String key, {String fallback = '-'}) {
    final value = (_profileData?[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  Uint8List? _profileImageBytes() {
    final raw = (_profileData?['profileImageBase64'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showReloadAppPrompt() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profile Updated'),
          content: const Text(
            'Changes were saved. Please reload the app to see all updates everywhere.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editProfileDetails() async {
    if (_isSaving) {
      _showInfoMessage('Please wait, update in progress...');
      return;
    }

    final firstNameController = TextEditingController(
      text: _read('firstName', fallback: ''),
    );
    final lastNameController = TextEditingController(
      text: _read('lastName', fallback: ''),
    );
    final phoneController = TextEditingController(
      text: _read('phoneNumber', fallback: ''),
    );
    final cityController = TextEditingController(
      text: _read('city', fallback: ''),
    );
    final addressController = TextEditingController(
      text: _read('address', fallback: ''),
    );

    String selectedGender = _read('gender', fallback: 'Prefer not to say');
    if (!<String>{
      'Male',
      'Female',
      'Other',
      'Prefer not to say',
    }.contains(selectedGender)) {
      selectedGender = 'Prefer not to say';
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedGender,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                          DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setModalState(() {
                            selectedGender = value;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Gender'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final address = addressController.text.trim();

    if (!mounted) {
      return;
    }

    if (firstName.length < 2 || lastName.length < 2) {
      _showInfoMessage(
        'First and last name must be at least 2 characters.',
        color: AppColors.errorRed,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.updateCurrentUserProfileData(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phone,
        city: city,
        address: address,
        gender: selectedGender,
      );
      await _loadProfile();
      await _showReloadAppPrompt();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showInfoMessage(
        'Unable to update profile: $e',
        color: AppColors.errorRed,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    if (_isSaving) {
      _showInfoMessage('Please wait, update in progress...');
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxHeight: 1024,
        maxWidth: 1024,
      );
      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxProfileImageBytes) {
        if (!mounted) {
          return;
        }
        _showInfoMessage(
          'Profile picture must be 2MB or smaller.',
          color: AppColors.errorRed,
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      await _authService.updateCurrentUserProfileData(
        profileImageBase64: base64Encode(bytes),
      );
      await _loadProfile();
      await _showReloadAppPrompt();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showInfoMessage(
        'Unable to update profile picture: $e',
        color: AppColors.errorRed,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openProfilePhotoPreview(Uint8List bytes) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeEmailWithOtp() async {
    if (_isSaving) {
      _showInfoMessage('Please wait, update in progress...');
      return;
    }

    final newEmail = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const EditEmailPage()));

    final normalizedNewEmail = _authService.normalizeEmail(newEmail ?? '');
    final currentEmail = _authService.normalizeEmail(
      _read('email', fallback: ''),
    );
    if (!mounted) {
      return;
    }
    if (normalizedNewEmail.isEmpty) {
      return;
    }
    if (normalizedNewEmail == currentEmail) {
      _showInfoMessage(
        'Please enter a different email address.',
        color: AppColors.errorRed,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final alreadyExists = await _authService.isEmailAlreadyRegistered(
        normalizedNewEmail,
      );
      if (alreadyExists) {
        if (!mounted) {
          return;
        }
        _showInfoMessage(
          'This email is already registered.',
          color: AppColors.errorRed,
        );
        return;
      }

      final otp = (_random.nextInt(900000) + 100000).toString();
      final sent = await _authService.sendEmailOTP(normalizedNewEmail, otp);
      if (!sent) {
        if (!mounted) {
          return;
        }
        _showInfoMessage(
          'Failed to send OTP. Please try again.',
          color: AppColors.errorRed,
        );
        return;
      }

      await _authService.saveEmailOtp(email: normalizedNewEmail, otpCode: otp);

      if (!mounted) {
        return;
      }

      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => VerifyIdentityPage(
            contact: normalizedNewEmail,
            isEmailFlow: true,
          ),
        ),
      );

      if (verified != true) {
        return;
      }

      await _authService.updateCurrentUserEmailAfterOtp(
        newEmail: normalizedNewEmail,
      );
      await _loadProfile();
      await _showReloadAppPrompt();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      _showInfoMessage(
        e.message ?? 'Unable to change email right now.',
        color: AppColors.errorRed,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showInfoMessage('Unable to change email: $e', color: AppColors.errorRed);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onBottomNavChanged(int index) {
    if (index == 3) {
      return;
    }

    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BookingsPage()),
        (route) => false,
      );
      return;
    }

    if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FavoritesPage()),
        (route) => false,
      );
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to sign out right now: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Widget _infoTile({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.main, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.gray1,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.dark1,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${_read('firstName', fallback: '')} ${_read('lastName', fallback: '')}'
            .trim();
    final displayName = name.isEmpty
        ? _read('displayName', fallback: 'My Profile')
        : name;
    final email = _read('email', fallback: '-');
    final gender = _read('gender', fallback: '-');
    final phone = _read('phoneNumber', fallback: '-');
    final city = _read('city', fallback: '-');
    final address = _read('address', fallback: '-');
    final profileBytes = _profileImageBytes();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.dark1,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Expanded(
              child: _isProfileLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Account Overview',
                            style: TextStyle(
                              color: AppColors.dark1,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE7EBF3),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundColor: AppColors.mainLight,
                                  backgroundImage: profileBytes == null
                                      ? null
                                      : MemoryImage(profileBytes),
                                  child: profileBytes == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 36,
                                          color: AppColors.main,
                                        )
                                      : null,
                                ),
                                if (profileBytes != null) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        _openProfilePhotoPreview(profileBytes),
                                    child: const Text(
                                      'Tap photo to preview',
                                      style: TextStyle(
                                        color: AppColors.main,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  displayName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.dark1,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: AppColors.gray1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : _changeProfilePicture,
                                  icon: const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.main,
                                      width: 1.2,
                                    ),
                                  ),
                                  label: const Text('Update Profile Picture'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              color: AppColors.dark1,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE7EBF3),
                              ),
                            ),
                            child: Column(
                              children: [
                                _infoTile(
                                  label: 'Full Name',
                                  value: displayName,
                                  icon: Icons.badge_outlined,
                                ),
                                _infoTile(
                                  label: 'Email',
                                  value: email,
                                  icon: Icons.email_outlined,
                                ),
                                _infoTile(
                                  label: 'Phone Number',
                                  value: phone,
                                  icon: Icons.phone_outlined,
                                ),
                                _infoTile(
                                  label: 'Gender',
                                  value: gender,
                                  icon: Icons.wc_rounded,
                                ),
                                _infoTile(
                                  label: 'City',
                                  value: city,
                                  icon: Icons.location_city_outlined,
                                ),
                                _infoTile(
                                  label: 'Address',
                                  value: address,
                                  icon: Icons.home_outlined,
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : _editProfileDetails,
                                    icon: const Icon(Icons.edit_outlined),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.main,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    label: const Text('Edit Profile Details'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : _changeEmailWithOtp,
                                    icon: const Icon(
                                      Icons.mark_email_read_outlined,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.main,
                                        width: 1.2,
                                      ),
                                      foregroundColor: AppColors.main,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    label: const Text(
                                      'Change Email (OTP Verification)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'After any profile update, please reload the app to ensure changes are reflected everywhere.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.gray1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isSigningOut ? null : _signOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE45757),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSigningOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Logout'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            DashboardBottomNav(
              selectedIndex: 3,
              onChanged: _onBottomNavChanged,
            ),
          ],
        ),
      ),
    );
  }
}
