import 'package:flutter/material.dart';
import 'package:mobile2/shared/theme/dateasy_theme.dart';

class DateasyLogo extends StatelessWidget {
  const DateasyLogo({super.key, this.size = DateasyLogoSize.md});

  final DateasyLogoSize size;

  @override
  Widget build(BuildContext context) {
    final spec = size._spec;

    return Semantics(
      label: 'Frendly',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DateasyLogoMark(size: spec.mark),
          SizedBox(width: spec.gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'frendly',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Sora',
                  fontSize: spec.text,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: spec.dotGap),
              Container(
                width: spec.dot,
                height: spec.dot,
                margin: EdgeInsets.only(bottom: spec.dotBottom),
                decoration: BoxDecoration(
                  color: DateasyColors.lime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DateasyColors.lime.withValues(alpha: 0.7),
                      blurRadius: spec.dot * 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DateasyLogoMark extends StatelessWidget {
  const DateasyLogoMark({super.key, required this.size});

  static const assetName = 'assets/images/frendly-logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFB).withValues(alpha: 0.55),
            blurRadius: size * 0.44,
            spreadRadius: -size * 0.16,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          assetName,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

enum DateasyLogoSize {
  sm,
  md,
  lg,
  xl;

  _LogoSpec get _spec {
    return switch (this) {
      DateasyLogoSize.sm => const _LogoSpec(
          mark: 32,
          text: 20,
          gap: 8,
          dot: 6,
          dotGap: 3,
          dotBottom: 2,
        ),
      DateasyLogoSize.md => const _LogoSpec(
          mark: 44,
          text: 26,
          gap: 10,
          dot: 8,
          dotGap: 4,
          dotBottom: 2,
        ),
      DateasyLogoSize.lg => const _LogoSpec(
          mark: 64,
          text: 40,
          gap: 12,
          dot: 10,
          dotGap: 5,
          dotBottom: 3,
        ),
      DateasyLogoSize.xl => const _LogoSpec(
          mark: 96,
          text: 60,
          gap: 16,
          dot: 12,
          dotGap: 7,
          dotBottom: 5,
        ),
    };
  }
}

class _LogoSpec {
  const _LogoSpec({
    required this.mark,
    required this.text,
    required this.gap,
    required this.dot,
    required this.dotGap,
    required this.dotBottom,
  });

  final double mark;
  final double text;
  final double gap;
  final double dot;
  final double dotGap;
  final double dotBottom;
}
