import 'package:flutter/material.dart';

enum ButtonVariant { filled, outlined }

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final ButtonVariant variant;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.variant = ButtonVariant.filled,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = variant == ButtonVariant.filled
        ? ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          );

    final child = Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: variant == ButtonVariant.filled
            ? ElevatedButton(
                onPressed: onPressed,
                style: buttonStyle,
                child: child,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: buttonStyle,
                child: child,
              ),
      );
    }

    return variant == ButtonVariant.filled
        ? ElevatedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: child,
          );
  }
}
