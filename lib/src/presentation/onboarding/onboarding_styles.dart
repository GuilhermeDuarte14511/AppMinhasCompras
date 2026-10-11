import 'package:flutter/material.dart';

/// Tokens from the approved onboarding Stitch export.
class OnboardingStyles {
  OnboardingStyles(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;

  final bool dark;
  Color get background =>
      dark ? const Color(0xFF20231E) : const Color(0xFFFBF9F3);
  Color get foreground =>
      dark ? const Color(0xFFF3F1EB) : const Color(0xFF1B1C18);
  Color get secondary =>
      dark ? const Color(0xFFC4C9B4) : const Color(0xFF5B604F);
  Color get outline => dark ? const Color(0xFF60685D) : const Color(0xFFC1C8C1);
  Color get primary => dark ? const Color(0xFFA9D0B4) : const Color(0xFF1F412D);
  Color get surface => dark ? const Color(0xFF30312D) : Colors.white;
  Color get muted => dark ? const Color(0xFF363B33) : const Color(0xFFF0EEE8);

  TextStyle body(double size) => TextStyle(
    fontFamily: 'MercadoPublicSans',
    fontSize: size,
    height: 1.5,
    letterSpacing: 0,
    color: secondary,
  );
  TextStyle headline(double size) => TextStyle(
    fontFamily: 'MercadoNewsreader',
    fontSize: size,
    height: 1.375,
    letterSpacing: -.025 * size,
    color: foreground,
  );

  ButtonStyle button({bool filled = false, double height = 44}) =>
      (filled
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1F412D),
                  foregroundColor: Colors.white,
                )
              : OutlinedButton.styleFrom(
                  foregroundColor: foreground,
                  side: BorderSide(color: outline),
                ))
          .copyWith(
            minimumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            textStyle: WidgetStatePropertyAll(
              body(14).copyWith(fontWeight: FontWeight.w500),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
}

class OnboardingThemeOption extends StatelessWidget {
  const OnboardingThemeOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onPressed,
    required this.styles,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onPressed;
  final OnboardingStyles styles;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: true,
    child: OutlinedButton(
      onPressed: onPressed,
      style: styles
          .button(height: 56)
          .copyWith(
            backgroundColor: WidgetStatePropertyAll(styles.surface),
            side: WidgetStatePropertyAll(
              BorderSide(
                color: selected ? styles.primary : styles.outline,
                width: selected ? 2 : 1,
              ),
            ),
          ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? styles.primary : styles.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: styles.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: styles
                  .body(14)
                  .copyWith(
                    color: selected ? styles.foreground : styles.secondary,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            icon,
            size: 18,
            color: selected ? styles.primary : styles.secondary,
          ),
        ],
      ),
    ),
  );
}
