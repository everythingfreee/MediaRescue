import 'package:flutter/material.dart';

abstract class AppColors {
  // Dark Palette
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF141C2B);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF162032);
  static const Color darkBorder = Color(0xFF26334D);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Accents & Primaries
  static const Color primary = Color(0xFF6366F1); // Indigo Primary
  static const Color primaryContainerDark = Color(0xFF1E1B4B);
  static const Color primaryContainerLight = Color(0xFFEEF2FF);

  static const Color secondary = Color(0xFF0284C7); // Electric Cyan
  static const Color secondaryContainerDark = Color(0xFF0C4A6E);
  static const Color secondaryContainerLight = Color(0xFFE0F2FE);

  static const Color accent = Color(0xFF38BDF8);

  // Category Accents
  static const Color images = Color(0xFFA855F7); // Purple
  static const Color videos = Color(0xFF3B82F6); // Blue
  static const Color audio = Color(0xFF10B981); // Emerald
  static const Color documents = Color(0xFFF59E0B); // Amber
  static const Color other = Color(0xFF64748B); // Slate

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors Dark
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Text Colors Light
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}
