import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle get headlineXl => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 48 / 40,
        letterSpacing: -0.02 * 40,
      );
  static TextStyle get headlineLg => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.01 * 32,
      );
  static TextStyle get headlineMd => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
      );
  static TextStyle get headlineSm => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      );
  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
      );
  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );
  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
      );
  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );
  static TextStyle get headlineLgMobile => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
      );
}
