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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: selected ? 2.5 : 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF3730A3)
                    : const Color(0xFF1F2937),
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                subLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
