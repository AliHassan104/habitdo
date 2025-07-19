import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:habitdo/presentation/shared/widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';
import 'package:habitdo/presentation/shared/widgets/logo_widget.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Sign In Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Action for menu
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              AppLogo(size: 120),

              const SizedBox(height: 20),
              const Text(
                'Welcome Back!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Email field
              CustomTextField(
                controller: emailController,
                hintText: 'Email',
                labelText: 'Email',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),

              // Password field
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

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),

              // Forgot Password
              GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sign Up Link
              GestureDetector(
                onTap: () => context.go('/signup'),
                child: const Text.rich(
                  TextSpan(
                    text: 'Don\'t have an account? ',
                    style: TextStyle(fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Sign Up',
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    var email = emailController.text.trim();
    var password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Please fill all fields');
      return;
    }

    try {
      final User? fireBaseUser =
          (await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          )).user;

      if (fireBaseUser == null) {
        Get.snackbar('Error', 'Login failed');
        return;
      } else {
        print('User logged in: ${fireBaseUser.email}');
        context.go('/home');
        Get.snackbar('Success', 'Login successful');
      }
    } catch (e) {
      Get.snackbar('Error', 'Login failed: $e');
    }
  }
}
