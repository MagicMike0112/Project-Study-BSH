// lib/utils/bsh_toast.dart
import 'package:flutter/material.dart';

enum BSHToastType { success, error, info, warning }

class BSHToast {
  // NOTE: legacy comment cleaned.
  static void show(BuildContext context, {
    required String title,
    String? description,
    BSHToastType type = BSHToastType.success,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap, // NOTE: legacy comment cleaned.
  }) {
    // NOTE: legacy comment cleaned.
    Color bgColor;
    IconData icon;
    Color iconColor = Colors.white;

    switch (type) {
      case BSHToastType.success:
        bgColor = const Color(0xFF004A77); // BSH Deep Blue
        icon = Icons.check_circle_outline_rounded;
        break;
      case BSHToastType.error:
        bgColor = const Color(0xFFBA1A1A); // Red
        icon = Icons.error_outline_rounded;
        break;
      case BSHToastType.warning:
        bgColor = const Color(0xFFE65100); // Orange
        icon = Icons.warning_amber_rounded;
        break;
      case BSHToastType.info:
        bgColor = const Color(0xFF2D3436); // Grey
        icon = Icons.info_outline_rounded;
        break;
    }

    // NOTE: legacy comment cleaned.
    ScaffoldMessenger.of(context).clearSnackBars();

    // NOTE: legacy comment cleaned.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // NOTE: legacy comment cleaned.
        duration: duration,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20), // NOTE: legacy comment cleaned.
        behavior: SnackBarBehavior.floating,
        
        content: GestureDetector(
          onTap: () {
            if (onTap != null) onTap();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16), // NOTE: legacy comment cleaned.
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: Colors.white24),
                  const SizedBox(width: 8),
                  const Icon(Icons.undo_rounded, color: Colors.white, size: 20),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}


