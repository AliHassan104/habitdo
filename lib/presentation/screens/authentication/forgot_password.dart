import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:habitdo/presentation/screens/authentication/signin.dart';
import 'package:habitdo/presentation/shared/widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:habitdo/presentation/shared/widgets/logo_widget.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/signin'), // or context.pop()
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Get.snackbar(
                'Info',
                'Enter your registered email to reset password.',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            AppLogo(size: 120),
            const SizedBox(height: 40),
            const Text(
              'Reset your password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your email below and we’ll send you a link to reset your password.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            CustomTextField(
              controller: emailController,
              hintText: 'Email',
              labelText: 'Email',
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                var email = emailController.text.trim();
                if (email.isEmpty) {
                  Get.snackbar('Error', 'Please enter your email');
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );
                  Get.snackbar('Success', 'Password reset email has been sent');
                  Get.off(() => const SignInScreen());
                } on FirebaseAuthException catch (e) {
                  Get.snackbar('Error', e.message ?? 'Something went wrong');
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Send Reset Email'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/signin'),
              child: const Text(
                'Back to Sign In',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
