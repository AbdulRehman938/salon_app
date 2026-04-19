import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance,
      _googleSignIn = kIsWeb ? null : GoogleSignIn(scopes: ['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn? _googleSignIn;
  static String? _sessionVerifiedEmail;
  static const String _emailOtpCollection = 'emailOtpVerifications';
  static const String _usersCollection = 'users';
  static const String _registeredEmailsCollection = 'registeredEmails';
  static const String _locationSearchCollection = 'locationSearchHistory';
  static const String _sessionVerifiedEmailKey = 'session_verified_email';
  static const Duration _defaultEmailOtpTtl = Duration(minutes: 5);

  final String _brevoApiKey =
      (dotenv.env['BREVO_API_KEY'] ??
              const String.fromEnvironment('BREVO_API_KEY'))
          .trim();
  final String _brevoSenderName = 'Salon App';
  final String _brevoSenderEmail =
      (dotenv.env['BREVO_SENDER_EMAIL'] ??
              const String.fromEnvironment(
                'BREVO_SENDER_EMAIL',
                defaultValue: 'no-reply@salonapp.local',
              ))
          .trim();

  // 1. Send Email Link
  Future<void> sendSignInLink(String email) async {
    final acs = ActionCodeSettings(
      // URL must be whitelisted in Firebase Console -> Auth -> Settings
      url: 'https://salonapp-3ba4c.firebaseapp.com',
      handleCodeInApp: true,
      androidPackageName: 'com.example.salon_app',
      androidInstallApp: true,
      androidMinimumVersion: '12',
    );

    await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);
  }

  // 2. Handle Incoming Link
  Future<UserCredential?> handleLink(String link, {String? email}) async {
    if (_auth.isSignInWithEmailLink(link)) {
      final resolvedEmail = email?.trim();
      if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
        return _auth.signInWithEmailLink(email: resolvedEmail, emailLink: link);
      }
    }
    return null;
  }

  // 3. Phone OTP verification
  Future<void> verifyPhone(
    String phoneNumber, {
    required void Function(String verificationId, int? resendToken) onCodeSent,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    void Function(String? errorMessage)? onVerificationFailed,
    void Function(UserCredential credential)? onVerificationCompleted,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval (Android only)
        final userCredential = await _auth.signInWithCredential(credential);
        onVerificationCompleted?.call(userCredential);
      },
      verificationFailed: (e) {
        onVerificationFailed?.call(e.message);
      },
      codeSent: onCodeSent,
      forceResendingToken: forceResendingToken,
      codeAutoRetrievalTimeout: (String verificationId) {
        onCodeAutoRetrievalTimeout?.call(verificationId);
      },
    );
  }

  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      await _auth.signInWithRedirect(provider);
      return null;
    }

    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw FirebaseAuthException(
        code: 'google-not-available',
        message: 'Google sign-in is not available on this platform.',
      );
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await upsertUserProfile(userCredential.user, loginMethod: 'google');
    return userCredential;
  }

  Future<void> handlePendingWebRedirectSignIn() async {
    if (!kIsWeb) {
      return;
    }

    final credential = await _auth.getRedirectResult();
    if (credential.user != null) {
      await upsertUserProfile(credential.user, loginMethod: 'google');
    }
  }

  Future<void> upsertUserProfile(
    User? user, {
    required String loginMethod,
  }) async {
    if (user == null) {
      return;
    }

    final userDoc = _firestore.collection(_usersCollection).doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final providerIds = user.providerData
        .map((p) => p.providerId)
        .where((p) => p.isNotEmpty)
        .toList();
    final isSocialVerified = loginMethod == 'google';
    final isVerified = user.emailVerified || isSocialVerified;

    final snapshot = await userDoc.get();
    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'providerIds': providerIds,
      'loginMethod': loginMethod,
      'emailVerified': user.emailVerified,
      'isVerified': isVerified,
      'lastLoginAt': now,
      'updatedAt': now,
      if (!snapshot.exists) 'createdAt': now,
    }, SetOptions(merge: true));

    final normalizedEmail = normalizeEmail(user.email ?? '');
    if (normalizedEmail.isNotEmpty) {
      await _markEmailAsRegistered(
        normalizedEmail,
        uid: user.uid,
        source: loginMethod,
      );
    }
  }

  Future<User?> refreshCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    await user.reload();
    return _auth.currentUser;
  }

  String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  String _emailDocId(String email) {
    return base64Url.encode(utf8.encode(normalizeEmail(email)));
  }

  Future<bool> sendEmailOTP(String email, String otpCode) async {
    if (_brevoApiKey.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'brevo-not-configured',
        message: 'BREVO_API_KEY is not configured for this build.',
      );
    }

    final url = Uri.parse('https://api.brevo.com/v3/smtp/email');

    final response = await http.post(
      url,
      headers: {
        'api-key': _brevoApiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'sender': {'name': _brevoSenderName, 'email': _brevoSenderEmail},
        'to': [
          {'email': normalizeEmail(email)},
        ],
        'subject': 'Your Salon App Verification Code',
        'htmlContent':
            '<html><body><h2>Your OTP is: $otpCode</h2><p>This code expires in 5 minutes.</p></body></html>',
      }),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<void> _markEmailAsRegistered(
    String email, {
    String? uid,
    String source = 'unknown',
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return;
    }

    await _firestore
        .collection(_registeredEmailsCollection)
        .doc(_emailDocId(normalizedEmail))
        .set({
          'email': normalizedEmail,
          'uid': uid,
          'source': source,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> saveEmailOtp({
    required String email,
    required String otpCode,
    Duration expiresIn = _defaultEmailOtpTtl,
  }) async {
    final now = DateTime.now();
    final normalizedEmail = normalizeEmail(email);
    final expiresAt = now.add(expiresIn);

    await _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email))
        .set({
          'email': normalizedEmail,
          'otp': otpCode,
          'isVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'otpExpiresAt': Timestamp.fromDate(expiresAt),
        }, SetOptions(merge: true));
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    final docRef = _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email));
    final snapshot = await docRef.get();

    final data = snapshot.data();
    if (data == null) {
      return false;
    }

    final savedOtp = (data['otp'] as String? ?? '').trim();
    final expiry = data['otpExpiresAt'] as Timestamp?;
    final isExpired =
        expiry == null || expiry.toDate().isBefore(DateTime.now());
    if (isExpired || savedOtp != otpCode.trim()) {
      await docRef.set({
        'isVerified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    }

    await snapshot.reference.set({
      'isVerified': true,
      'otp': null,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await setSessionVerifiedEmail(email);

    return true;
  }

  Future<bool> isEmailVerifiedInFirestore(String email) async {
    final snapshot = await _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email))
        .get();
    final data = snapshot.data();
    if (data == null) {
      return false;
    }
    final isVerified = data['isVerified'] == true;
    if (isVerified) {
      await setSessionVerifiedEmail(email);
    }
    return isVerified;
  }

  Future<void> saveLocationSearch({required String selectedLocation}) async {
    final location = selectedLocation.trim();
    if (location.isEmpty) {
      return;
    }

    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return;
    }

    await _firestore.collection(_locationSearchCollection).add({
      'userUid': user!.uid,
      'userEmail': email,
      'searchedLocation': location,
      'searchedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isCurrentUserAllowed() async {
    try {
      final user = await refreshCurrentUser();
      if (user == null) {
        final email = await getSessionVerifiedEmail();
        if (email == null || email.isEmpty) {
          return false;
        }
        return isEmailVerifiedInFirestore(email);
      }

      if (user.isAnonymous) {
        final snapshot = await _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .get();
        final data = snapshot.data();
        if (data != null && data['isVerified'] == true) {
          return true;
        }

        // During verified-email bootstrap we may receive an auth state update
        // before the anonymous user profile document is persisted.
        final sessionEmail = await getSessionVerifiedEmail();
        if (sessionEmail == null || sessionEmail.isEmpty) {
          return false;
        }

        final sessionEmailVerified = await isEmailVerifiedInFirestore(
          sessionEmail,
        );
        return sessionEmailVerified;
      }

      // Phone users do not have an email verification requirement.
      if (user.email == null || user.email!.isEmpty) {
        return true;
      }

      final providers = user.providerData
          .map((provider) => provider.providerId)
          .toSet();
      if (providers.contains('google.com')) {
        return true;
      }

      final profileSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final profileData = profileSnapshot.data();
      if (profileData != null && profileData['isVerified'] == true) {
        return true;
      }

      return isEmailVerifiedInFirestore(user.email!);
    } catch (_) {
      final email = await getSessionVerifiedEmail();
      return email != null && email.isNotEmpty;
    }
  }

  Future<bool> isSignedInWithIdentifier({
    required String identifier,
    required bool isPhoneMode,
    String? phoneNumber,
  }) async {
    final user = await refreshCurrentUser();
    if (user == null) {
      if (isPhoneMode) {
        return false;
      }

      final email = await getSessionVerifiedEmail();
      final targetEmail = identifier.trim().toLowerCase();
      if (email == null || email != targetEmail) {
        return false;
      }

      return isEmailVerifiedInFirestore(targetEmail);
    }

    if (isPhoneMode) {
      final currentPhone = user.phoneNumber?.trim() ?? '';
      final targetPhone = (phoneNumber ?? '').trim();
      return currentPhone.isNotEmpty && currentPhone == targetPhone;
    }

    if (user.isAnonymous) {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      final storedEmail = (data?['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final targetEmail = identifier.trim().toLowerCase();
      return storedEmail.isNotEmpty &&
          storedEmail == targetEmail &&
          data?['isVerified'] == true;
    }

    final currentEmail = user.email?.trim().toLowerCase() ?? '';
    final targetEmail = identifier.trim().toLowerCase();
    final firestoreVerified = await isEmailVerifiedInFirestore(targetEmail);
    return currentEmail.isNotEmpty &&
        currentEmail == targetEmail &&
        firestoreVerified;
  }

  bool isEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  String? pendingEmailForLink;

  Future<String?> getSessionVerifiedEmail() async {
    if (_sessionVerifiedEmail != null && _sessionVerifiedEmail!.isNotEmpty) {
      return _sessionVerifiedEmail;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_sessionVerifiedEmailKey);
    if (stored != null && stored.isNotEmpty) {
      _sessionVerifiedEmail = normalizeEmail(stored);
    }

    return _sessionVerifiedEmail;
  }

  Future<void> setSessionVerifiedEmail(String email) async {
    final normalized = normalizeEmail(email);
    _sessionVerifiedEmail = normalized.isEmpty ? null : normalized;

    final prefs = await SharedPreferences.getInstance();
    if (_sessionVerifiedEmail == null) {
      await prefs.remove(_sessionVerifiedEmailKey);
    } else {
      await prefs.setString(_sessionVerifiedEmailKey, _sessionVerifiedEmail!);
    }
  }

  void setPendingEmailForLink(String email) {
    final normalized = email.trim().toLowerCase();
    pendingEmailForLink = normalized.isEmpty ? null : normalized;
  }

  void clearPendingEmailForLink() {
    pendingEmailForLink = null;
  }

  bool get hasPendingEmailForLink => pendingEmailForLink != null;

  String? get currentUserEmail {
    return _auth.currentUser?.email;
  }

  bool get isCurrentUserEmailVerified {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      return false;
    }
    return user.emailVerified;
  }

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  Future<void> signOut() async {
    clearPendingEmailForLink();
    _sessionVerifiedEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionVerifiedEmailKey);
    await _auth.signOut();
  }

  Future<User?> ensureAuthenticatedSessionForVerifiedEmail(String email) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return _auth.currentUser;
    }

    await setSessionVerifiedEmail(normalizedEmail);

    final isVerified = await isEmailVerifiedInFirestore(normalizedEmail);
    if (!isVerified) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Email is not verified with OTP yet.',
      );
    }

    User? user = await refreshCurrentUser();
    final currentEmail = user?.email?.trim().toLowerCase();
    final isMismatchedNamedUser =
        user != null && !user.isAnonymous && currentEmail != normalizedEmail;

    if (isMismatchedNamedUser) {
      await _auth.signOut();
      user = null;
    }

    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }

    if (user == null) {
      return null;
    }

    final now = FieldValue.serverTimestamp();
    final userDoc = _firestore.collection(_usersCollection).doc(user.uid);
    final snapshot = await userDoc.get();

    await userDoc.set({
      'uid': user.uid,
      'email': normalizedEmail,
      'loginMethod': 'email-otp-session',
      'isVerified': true,
      'emailVerified': false,
      'verifiedEmail': normalizedEmail,
      'lastLoginAt': now,
      'updatedAt': now,
      if (!snapshot.exists) 'createdAt': now,
    }, SetOptions(merge: true));

    await _markEmailAsRegistered(
      normalizedEmail,
      uid: user.uid,
      source: 'email-otp-session',
    );

    return user;
  }

  Future<User?> completeEmailSignupProfile({
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String city,
    required String address,
    required String gender,
    String? profileImageBase64,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final sanitizedFirstName = firstName.trim();
    final sanitizedLastName = lastName.trim();
    final displayName = '$sanitizedFirstName $sanitizedLastName'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final user = await ensureAuthenticatedSessionForVerifiedEmail(
      normalizedEmail,
    );
    if (user == null) {
      return null;
    }

    final now = FieldValue.serverTimestamp();
    final userDoc = _firestore.collection(_usersCollection).doc(user.uid);

    await userDoc.set({
      'uid': user.uid,
      'email': normalizedEmail,
      'firstName': sanitizedFirstName,
      'lastName': sanitizedLastName,
      'phoneNumber': phoneNumber.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'gender': gender.trim(),
      'displayName': displayName,
      'profileImageBase64': profileImageBase64,
      'isVerified': true,
      'verifiedEmail': normalizedEmail,
      'loginMethod': 'email-otp-session',
      'updatedAt': now,
      'lastLoginAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));

    await _markEmailAsRegistered(
      normalizedEmail,
      uid: user.uid,
      source: 'email-signup',
    );

    try {
      await user.updateDisplayName(displayName);
    } catch (_) {
      // Non-blocking: profile document is the source of truth for signup data.
    }

    return user;
  }

  Future<bool> isEmailAlreadyRegistered(String email) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return false;
    }

    final registeredEmailSnapshot = await _firestore
        .collection(_registeredEmailsCollection)
        .doc(_emailDocId(normalizedEmail))
        .get();
    if (registeredEmailSnapshot.exists) {
      return true;
    }

    final otpSnapshot = await _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(normalizedEmail))
        .get();
    final otpData = otpSnapshot.data();
    return otpData?['isVerified'] == true;
  }

  Future<String?> getCurrentUserDisplayNameFromProfile() async {
    final user = await refreshCurrentUser();
    if (user == null) {
      return null;
    }

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    final data = snapshot.data();

    final firstName = (data?['firstName'] ?? '').toString().trim();
    final lastName = (data?['lastName'] ?? '').toString().trim();
    final composedName = '$firstName $lastName'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (composedName.isNotEmpty) {
      return composedName;
    }

    final displayName = (data?['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final authName = (user.displayName ?? '').trim();
    if (authName.isNotEmpty) {
      return authName;
    }

    return null;
  }

  Future<Map<String, dynamic>?> getCurrentUserProfileData() async {
    final user = await refreshCurrentUser();
    if (user == null) {
      return null;
    }

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    return snapshot.data();
  }

  Future<void> updateCurrentUserProfileData({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? gender,
    String? address,
    String? city,
    String? profileImageBase64,
  }) async {
    final user = await refreshCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'User is not signed in.',
      );
    }

    final userDoc = _firestore.collection(_usersCollection).doc(user.uid);
    final currentSnapshot = await userDoc.get();
    final currentData = currentSnapshot.data() ?? <String, dynamic>{};

    final nextFirstName = (firstName ?? currentData['firstName'] ?? '')
        .toString()
        .trim();
    final nextLastName = (lastName ?? currentData['lastName'] ?? '')
        .toString()
        .trim();
    final nextDisplayName = '$nextFirstName $nextLastName'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    final payload = <String, dynamic>{
      if (firstName case final value?) 'firstName': value.trim(),
      if (lastName case final value?) 'lastName': value.trim(),
      if (phoneNumber case final value?) 'phoneNumber': value.trim(),
      if (gender case final value?) 'gender': value.trim(),
      if (address case final value?) 'address': value.trim(),
      if (city case final value?) 'city': value.trim(),
      ...?profileImageBase64 == null
          ? null
          : <String, dynamic>{'profileImageBase64': profileImageBase64},
      if (nextDisplayName.isNotEmpty) 'displayName': nextDisplayName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await userDoc.set(payload, SetOptions(merge: true));

    if (nextDisplayName.isNotEmpty) {
      try {
        await user.updateDisplayName(nextDisplayName);
      } catch (_) {
        // Non-blocking: Firestore user doc is source of truth.
      }
    }
  }

  Future<void> updateCurrentUserEmailAfterOtp({
    required String newEmail,
  }) async {
    final user = await refreshCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'User is not signed in.',
      );
    }

    final normalizedEmail = normalizeEmail(newEmail);
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email is invalid.',
      );
    }

    final userDoc = _firestore.collection(_usersCollection).doc(user.uid);
    await userDoc.set({
      'email': normalizedEmail,
      'verifiedEmail': normalizedEmail,
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _markEmailAsRegistered(
      normalizedEmail,
      uid: user.uid,
      source: 'profile-email-update',
    );
    await setSessionVerifiedEmail(normalizedEmail);
  }
}
