import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AppTheme {
  // Default colors (blue theme for owners)
  static const Color _defaultPrimary = Color(0xFF6495ED); // Cornflower blue
  static const Color _defaultPrimary600 = Colors.blue;
  
  // Walker colors (green theme) - Slightly lighter green shades
  static const Color _walkerPrimary = Color(0xFF66BB6A); // Lighter Material Green 400
  static const Color _walkerPrimary600 = Color(0xFF66BB6A); // Lighter Material Green 400

  /// Gets the primary theme color based on user role
  static Color getPrimaryColor(UserModel? user) {
    if (user?.isWalker == true) {
      return _walkerPrimary;
    }
    return _defaultPrimary; // Default to blue for owners or unknown users
  }

  /// Gets the primary color (600 shade) based on user role
  static Color getPrimaryColor600(UserModel? user) {
    if (user?.isWalker == true) {
      return _walkerPrimary600;
    }
    return _defaultPrimary600;
  }

  /// Gets a specific shade of the theme color based on user role
  static Color? getColorShade(UserModel? user, int shade) {
    if (user?.isWalker == true) {
      // Return specific lighter green shades for walker users
      switch (shade) {
        case 50:
          return const Color(0xFFF1F8E9); // Lighter
        case 100:
          return const Color(0xFFDCEDC8); // Lighter green background
        case 200:
          return const Color(0xFFC5E1A5); // Lighter
        case 300:
          return const Color(0xFFAED581); // Lighter
        case 400:
          return const Color(0xFF9CCC65); // Lighter
        case 500:
          return const Color(0xFF8BC34A); // Lighter main green
        case 600:
          return const Color(0xFF7CB342); // Lighter
        case 700:
          return const Color(0xFF689F38); // Lighter dark green
        case 800:
          return const Color(0xFF558B2F); // Lighter
        case 900:
          return const Color(0xFF33691E); // Lighter
        default:
          return const Color(0xFF8BC34A); // Default to lighter main green
      }
    }
    return Colors.blue[shade];
  }

  /// Gets the accent color for buttons and highlights
  static Color getAccentColor(UserModel? user) {
    return getPrimaryColor(user);
  }

  /// Gets border colors for focused inputs
  static Color getFocusedBorderColor(UserModel? user) {
    return getColorShade(user, 600) ?? _defaultPrimary;
  }

  /// Gets background colors for containers
  static Color? getContainerColor(UserModel? user, int shade) {
    return getColorShade(user, shade);
  }

  /// Helper method to get role-based color with fallback
  static Color getRoleColor(UserModel? user, {Color? defaultColor}) {
    if (user?.isWalker == true) {
      return _walkerPrimary;
    }
    return defaultColor ?? _defaultPrimary;
  }

  /// Gets icon color based on state and role
  static Color getIconColor(UserModel? user, bool isSelected) {
    if (isSelected) {
      return getPrimaryColor(user);
    }
    return Colors.grey[600] ?? Colors.grey;
  }

  /// Gets text color based on state and role
  static Color getTextColor(UserModel? user, bool isSelected) {
    if (isSelected) {
      return getPrimaryColor(user);
    }
    return Colors.grey[600] ?? Colors.grey;
  }
} 