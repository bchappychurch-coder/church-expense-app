import 'package:flutter/material.dart';

class BigButton extends StatelessWidget {
  final String label;
  final String? subLabel;
  final VoidCallback onTap;
  final Color? color;
  final Color? borderColor;
  final bool selected;

  const BigButton({
    super.key,
    required this.label,
    this.subLabel,
    required this.onTap,
    this.color,
    this.borderColor,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFE0E7FF)
        : (color ?? Colors.white);
    final border = selected
        ? const Color(0xFF6366F1)
        : (borderColor ?? const Color(0xFFD1D5DB));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: selected ? 2.5 : 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF3730A3)
                      : const Color(0xFF1F2937),
                ),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
