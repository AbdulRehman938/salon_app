import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final String _brevoApiKey = const String.fromEnvironment(
    'BREVO_API_KEY',
    defaultValue: 'YOUR_BREVO_API_KEY_HERE',
  );
  final String _brevoSenderName = 'Salon App';
  final String _brevoSenderEmail = const String.fromEnvironment(
    'BREVO_SENDER_EMAIL',
    defaultValue: 'your-verified-brevo-email@example.com',
  );

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

    // Save email locally to verify later
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', email);
  }

  // 2. Handle Incoming Link
  Future<void> handleLink(String link) async {
    if (_auth.isSignInWithEmailLink(link)) {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail');

      if (email != null) {
        await _auth.signInWithEmailLink(email: email, emailLink: link);
      }
    }
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

  Future<bool> sendEmailOTP(String email, String otpCode) async {
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
          {'email': email.trim()},
        ],
        'subject': 'Your Salon App Verification Code',
        'htmlContent':
            '<html><body><h1>Your OTP is: $otpCode</h1><p>This code expires in 5 minutes.</p></body></html>',
      }),
    );

    return response.statusCode == 201 || response.statusCode == 200;
  }
}
