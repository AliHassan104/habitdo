import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habitdo/presentation/shared/widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:habitdo/presentation/shared/widgets/logo_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up Screen'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            AppLogo(size: 120),
            const SizedBox(height: 20),
            CustomTextField(
              controller: nameController,
              hintText: 'Name',
              labelText: 'Name',
              prefixIcon: Icons.person,
            ),
            CustomTextField(
              controller: phoneController,
              hintText: 'Phone Number',
              labelText: 'Phone Number',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            CustomTextField(
              controller: emailController,
              hintText: 'Email',
              labelText: 'Email',
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            CustomTextField(
              controller: passwordController,
              hintText: 'Password',
              labelText: 'Password',
              prefixIcon: Icons.lock,
              obscureText: _obscurePassword,
              suffixIcon:
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
              onSuffixTap: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (name.isEmpty ||
                    phone.isEmpty ||
                    email.isEmpty ||
                    password.isEmpty) {
                  Get.snackbar('Error', 'Please fill all fields');
                  return;
                }

                if (!email.contains('@')) {
                  Get.snackbar('Error', 'Enter a valid email');
                  return;
                }

                if (phone.length < 10) {
                  Get.snackbar('Error', 'Enter a valid phone number');
                  return;
                }

                try {
                  // Step 1: Create user
                  final userCredential = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );

                  final currentUser = userCredential.user;

                  if (currentUser != null) {
                    // Step 2: Store in Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .set({
                          'name': name,
                          'phone': phone,
                          'email': email,
                          'createdAt': DateTime.now().toIso8601String(),
                          'uid': currentUser.uid,
                        });

                    // Step 3: Sign out and navigate
                    await FirebaseAuth.instance.signOut();

                    Get.snackbar('Success', 'Account created successfully');

                    nameController.clear();
                    phoneController.clear();
                    emailController.clear();
                    passwordController.clear();

                    context.go('/signin'); // ✅ this is correct for GoRouter
                  } else {
                    Get.snackbar('Error', 'User creation failed');
                  }
                } on FirebaseAuthException catch (e) {
                  Get.snackbar('Auth Error', e.message ?? 'Unknown error');
                } catch (e) {
                  Get.snackbar('Error', 'Something went wrong: $e');
                  setState(() => _isLoading = false);
                }
              },

              child: _isLoading ? CircularProgressIndicator() : Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                context.go('/signin'); // Navigate to Sign In screen
              },
              child: const Padding(
                padding: EdgeInsets.all(10.0),
                child: Text.rich(
                  TextSpan(
                    text: "Already have an account? ",
                    style: TextStyle(fontSize: 14),
                    children: [
                      TextSpan(
                        text: "Sign In",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
