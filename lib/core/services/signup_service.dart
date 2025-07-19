import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

Future<void> signUp(
  BuildContext context,
  String name,
  String phone,
  String email,
  String password,
) async {
  try {
    final UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    // Give a moment for Firebase to update currentUser properly
    await Future.delayed(const Duration(milliseconds: 500));

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
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

      await FirebaseAuth.instance.signOut();

      Get.snackbar('Success', 'Account created successfully');
      context.go('/signin'); // or: Get.to(() => SignInScreen());
    } else {
      Get.snackbar('Error', 'User not available after sign-up');
    }
  } on FirebaseAuthException catch (e) {
    Get.snackbar('Error', e.message ?? 'Something went wrong');
  } catch (e) {
    Get.snackbar('Error', 'Unexpected error: $e');
  }
}
