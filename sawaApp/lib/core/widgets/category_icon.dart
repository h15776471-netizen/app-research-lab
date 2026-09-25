import 'package:flutter/material.dart';

/// Category glyphs keyed by `categories.id` (and `icon_key` fallbacks).
IconData categoryIcon(String? idOrKey) => switch (idOrKey) {
      'halls' || 'building' => Icons.villa_outlined,
      'photography' || 'camera' => Icons.photo_camera_outlined,
      'flowers' || 'flower' => Icons.local_florist_outlined,
      'decoration' || 'sparkle' => Icons.auto_awesome_outlined,
      'beauty' || 'makeup' => Icons.face_retouching_natural_outlined,
      'catering' || 'fork_knife' => Icons.restaurant_outlined,
      'music' => Icons.music_note_outlined,
      'cars' || 'car' => Icons.directions_car_outlined,
      'invitations' || 'envelope' => Icons.mail_outline,
      _ => Icons.celebration_outlined,
    };
