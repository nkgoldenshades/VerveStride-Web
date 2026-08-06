import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';

/// Service to handle complete account deletion
/// Deletes all user data from Firestore, local storage, and Firebase Auth
class AccountDeletionService {
  static final AccountDeletionService instance = AccountDeletionService._();
  AccountDeletionService._();

  final LocalStorageService _storage = LocalStorageService.instance;

  /// Deletes user account and all associated data
  /// 
  /// CRITICAL ORDER (DO NOT CHANGE):
  /// 1. Delete Firestore data (authoritative server data)
  /// 2. Delete Firebase Auth account (authoritative identity - MANDATORY)
  /// 3. Delete local Isar data (device cache only - safe to delete last)
  /// 4. Sign out (cleanup)
  /// 
  /// This order ensures system integrity if process fails midway.
  /// Authoritative sources (Firestore + Auth) are deleted first.
  /// Local cache (Isar) is deleted last since it's not authoritative.
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final uid = user.uid;
    debugPrint('🗑️ Starting account deletion for user: $uid');

    try {
      // Step 1: Delete Firestore data (authoritative server data)
      // Must be done while user is still authenticated
      await _deleteFirestoreData(uid);

      // Step 2: Delete Firebase Auth account (MANDATORY - must succeed)
      // This is the authoritative identity source
      await user.delete();

      // Step 3: Delete local Isar data (safe to do last)
      // Local cache only - not authoritative
      await _deleteLocalData(uid);

      // Step 4: Sign out to ensure clean state
      await FirebaseAuth.instance.signOut();

      debugPrint('✅ Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint('⚠️ User must re-login before deletion');
        // Sign out and force re-authentication
        await FirebaseAuth.instance.signOut();
        throw AccountDeletionException(
          'For security, please sign in again and retry account deletion.',
          requiresReauth: true,
        );
      }
      debugPrint('❌ Firebase Auth error: ${e.message}');
      throw AccountDeletionException(
        'Account deletion failed: ${e.message}',
      );
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      throw AccountDeletionException(
        'Account deletion failed. Please try again.',
      );
    }
  }

  /// Deletes all Firestore data for the user
  /// CRITICAL: This must be called BEFORE deleting Auth account
  /// 
  /// Current Firestore structure:
  /// - Users/{uid} document (Email, Lifetime, paymentId, purchaseTime)
  /// 
  /// Note: Most app data (activities, meals, hydration) is stored locally in Isar,
  /// not in Firestore. This method only deletes the Users document.
  /// 
  /// Idempotent: Safe to retry if already deleted
  Future<void> _deleteFirestoreData(String uid) async {
    try {
      debugPrint('🗑️ Deleting Firestore data...');
      
      final firestore = FirebaseFirestore.instance;
      
      // Delete main user document from Users collection
      // Contains: Email, Lifetime, paymentId, purchaseTime
      // Idempotent: No error if document doesn't exist
      await firestore.collection('Users').doc(uid).delete();
      
      debugPrint('✅ Firestore Users/{$uid} document deleted');
    } catch (e) {
      // Ignore if document already deleted or doesn't exist
      // This makes deletion idempotent and safe to retry
      debugPrint('⚠️ Firestore deletion note: $e (continuing...)');
      // Continue with deletion process
    }
  }

  /// Deletes all local data stored in Isar database
  /// Safe to call last since it's only local cache, not authoritative data
  Future<void> _deleteLocalData(String uid) async {
    try {
      debugPrint('🗑️ Deleting local data...');
      
      // Clear all user data from local storage
      await _storage.clearUserData();
      
      debugPrint('✅ Local data deleted');
    } catch (e) {
      debugPrint('⚠️ Error deleting local data: $e');
      // Local data deletion failure is not critical
      // Authoritative sources (Firestore + Auth) are already deleted
    }
  }
}

/// Custom exception for account deletion errors
class AccountDeletionException implements Exception {
  final String message;
  final bool requiresReauth;

  AccountDeletionException(
    this.message, {
    this.requiresReauth = false,
  });

  @override
  String toString() => message;
}
