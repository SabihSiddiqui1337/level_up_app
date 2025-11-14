// ignore_for_file: avoid_print

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import 'auth_service.dart';

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final AuthService _authService = AuthService();
  static const String _followingKey = 'user_following';
  static const String _followersKey = 'user_followers';

  // Get users that a user is following
  Future<List<String>> getFollowing(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followingJson = prefs.getString('${_followingKey}_$userId');
      if (followingJson != null) {
        final List<dynamic> followingList = json.decode(followingJson);
        return followingList.cast<String>();
      }
    } catch (e) {
      print('Error loading following: $e');
    }
    return [];
  }

  // Get users that are following a user
  Future<List<String>> getFollowers(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followersJson = prefs.getString('${_followersKey}_$userId');
      if (followersJson != null) {
        final List<dynamic> followersList = json.decode(followersJson);
        return followersList.cast<String>();
      }
    } catch (e) {
      print('Error loading followers: $e');
    }
    return [];
  }

  // Check if current user is following a user
  Future<bool> isFollowing(String userId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;
    
    final following = await getFollowing(currentUser.id);
    return following.contains(userId);
  }

  // Follow a user
  Future<bool> followUser(String userId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || currentUser.id == userId) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Add to current user's following list
      final following = await getFollowing(currentUser.id);
      if (!following.contains(userId)) {
        following.add(userId);
        await prefs.setString(
          '${_followingKey}_${currentUser.id}',
          json.encode(following),
        );
      }

      // Add to target user's followers list
      final followers = await getFollowers(userId);
      if (!followers.contains(currentUser.id)) {
        followers.add(currentUser.id);
        await prefs.setString(
          '${_followersKey}_$userId',
          json.encode(followers),
        );
      }

      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || currentUser.id == userId) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove from current user's following list
      final following = await getFollowing(currentUser.id);
      following.remove(userId);
      await prefs.setString(
        '${_followingKey}_${currentUser.id}',
        json.encode(following),
      );

      // Remove from target user's followers list
      final followers = await getFollowers(userId);
      followers.remove(currentUser.id);
      await prefs.setString(
        '${_followersKey}_$userId',
        json.encode(followers),
      );

      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  // Get user objects from IDs
  Future<List<User>> getUsersFromIds(List<String> userIds) async {
    await _authService.initialize();
    final allUsers = _authService.users;
    return allUsers.where((user) => userIds.contains(user.id)).toList();
  }
}

