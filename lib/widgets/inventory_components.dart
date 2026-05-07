import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_haptics.dart';
import 'animations.dart'; // NOTE: legacy comment cleaned.

class UserFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? currentUserName;

  const UserFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isFamily = label == 'Family';
    final isMe = label == 'Me' || (currentUserName != null && label == currentUserName);
    final displayName = isFamily
        ? 'Shared'
        : (label == 'Me' && currentUserName != null ? currentUserName! : label);
    final icon = isFamily ? Icons.home_rounded : (isMe ? Icons.account_circle_rounded : Icons.person_rounded);
    final initials = displayName.isNotEmpty ? displayName.trim()[0].toUpperCase() : '?';
    final bgColor = isSelected ? colors.primary : theme.cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: isSelected ? 1.0 : 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Row(
            children: [
              if (label != 'All')
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : colors.primary.withValues(alpha: 0.1),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : colors.primary,
                      ),
                    ),
                  ),
                )
              else
                Icon(icon, size: 16, color: isSelected ? Colors.white : colors.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                child: Text(displayName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const QuickActionButton({
    super.key,
    required this.icon,
    this.iconWidget,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = BouncingButton(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Center(
          child: iconWidget ?? Icon(icon, color: color, size: 20),
        ),
      ),
    );
    if (kIsWeb) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

class UserAvatarTag extends StatelessWidget {
  final String name;
  final double size;
  final bool showBorder;
  final String? currentUserName;

  const UserAvatarTag({
    super.key,
    required this.name,
    this.size = 20,
    this.showBorder = true,
    this.currentUserName,
  });

  bool _isCurrentUser(String name) {
    return name == 'Me' || (currentUserName != null && name == currentUserName);
  }

  Color _getNameColor(String name) {
    if (name.isEmpty || name == 'All') return Colors.grey;
    if (name == 'Family') return Colors.orangeAccent;
    if (_isCurrentUser(name)) return Colors.blueAccent;
    final colors = [
      Colors.blue.shade600,
      Colors.red.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isFamily = name == 'Family';
    final isMe = _isCurrentUser(name);
    final color = _getNameColor(name);
    final displayName = name == 'Me' && currentUserName != null ? currentUserName! : name;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFamily ? Colors.orange.shade50 : (isMe ? Colors.blue.shade50 : color.withValues(alpha: 0.1)),
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: isFamily
          ? Icon(Icons.home_rounded, color: Colors.orange, size: size * 0.6)
          : (isMe
              ? Icon(Icons.person, color: Colors.blueAccent, size: size * 0.6)
              : Text(initial, style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold, color: color))),
    );
  }
}

class SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  const SheetTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? Colors.red.withValues(alpha: 0.1) : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: danger ? Colors.red : Colors.grey[800], size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? Colors.red : Colors.black87,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])) : null,
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}






