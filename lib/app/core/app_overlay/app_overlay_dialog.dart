import 'package:flutter/material.dart';
import 'package:mobile2/shared/models/backend_models.dart';

class AppOverlayDialog extends StatelessWidget {
  const AppOverlayDialog({
    super.key,
    required this.overlay,
    required this.onDismiss,
    required this.onCta,
  });

  final AppOverlay overlay;
  final VoidCallback onDismiss;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: overlay.dismissible,
      child: Material(
        color: Colors.black.withValues(alpha: 0.52),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 32,
                        offset: Offset(0, 18),
                        color: Color(0x33000000),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                overlay.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (overlay.dismissible)
                              Semantics(
                                label: 'Закрыть',
                                button: true,
                                child: IconButton(
                                  onPressed: onDismiss,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          overlay.body,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (overlay.cta != null) ...[
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: onCta,
                            child: Text(overlay.cta!.label),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
