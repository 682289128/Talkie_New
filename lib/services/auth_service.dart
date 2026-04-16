import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==============================
  // 🔐 REGISTER USER
  // ==============================
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      final uid = user.uid;

      // Save user in Firestore
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else {
        throw Exception(e.message ?? 'Registration failed.');
      }
    } catch (e) {
      throw Exception('Something went wrong. Try again.');
    }
  }

  // ==============================
  // 🔓 LOGIN USER (UPDATED VERSION)
  // ==============================
  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found with this email.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Incorrect password.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email address.');
      } else {
        throw Exception(e.message ?? 'Login failed.');
      }
    } catch (e) {
      throw Exception('Something went wrong. Try again.');
    }
  }

  // ==============================
  // 🚪 LOGOUT
  // ==============================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ==============================
  // 👤 GET CURRENT USER
  // ==============================
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}