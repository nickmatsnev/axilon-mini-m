import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:http/http.dart' as http;

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationPage({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final otpController = TextEditingController();

  // Timer-related fields
  bool canResend = false;
  int secondsRemaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOTP(); // Send OTP automatically on page load
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      canResend = false;
      secondsRemaining = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 1) {
        setState(() {
          secondsRemaining--;
        });
      } else {
        setState(() {
          canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _sendOTP() async {
    try {
      final sendResponse = await http.post(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phoneNumber}),
      );

      if (sendResponse.statusCode == 200) {
        final otp = jsonDecode(sendResponse.body)['otp'];
        debugPrint("OTP sent to ${widget.phoneNumber}: $otp");
      } else {
        final data = jsonDecode(sendResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
    }
  }

  Future<void> _resendOTP() async {
    await _sendOTP();
    _startCountdown();
  }

  Future<void> _deleteUserByPhone(String phone) async {
    try {
      final delResp = await http.delete(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/users/phone/$phone'),
      );
      if (delResp.statusCode == 200) {
        debugPrint("User with phone $phone deleted due to failed OTP.");
      } else {
        debugPrint("Failed to delete user: ${delResp.body}");
      }
    } catch (e) {
      debugPrint("Error deleting user by phone: $e");
    }
  }

  Future<void> verifyOTP() async {
    final otp = otpController.text;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://axilon-mini-be-e5732e59dadc.herokuapp.com/api/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phoneNumber, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/ussd');
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Verification failed')),
        );
        // Delete user if verification fails
        await _deleteUserByPhone(widget.phoneNumber);
        Navigator.pushReplacementNamed(context, '/register');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Gradient
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8EDFF), Color(0xFFF9FBFE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Verify OTP'), backgroundColor: Colors.indigo, foregroundColor: Colors.white,),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Enter the OTP sent to ${widget.phoneNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: verifyOTP,
                      child: const Text('Verify'),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: canResend ? Colors.indigo : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: canResend ? _resendOTP : null,
                      child: canResend
                          ? const Text('Resend OTP')
                          : Text('Wait $secondsRemaining s'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
