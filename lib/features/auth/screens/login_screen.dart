import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  String? _error;

  Future<void> _signInGoogle() async {
    setState(() { _loadingGoogle = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'Connexion Google échouée. Réessayez.');
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInApple() async {
    setState(() { _loadingApple = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithApple();
    } catch (e) {
      setState(() => _error = 'Connexion Apple échouée. Réessayez.');
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / titre
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SwimColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SwimColors.border, width: 0.5),
                ),
                child: const Icon(Icons.water_outlined,
                    color: SwimColors.wave, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('SwimTracker',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: SwimColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Suivez vos sessions de natation\nen mer et en ocean.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: SwimColors.textSecondary,
                    height: 1.5),
              ),

              const Spacer(flex: 2),

              // Bouton Google
              _SignInButton(
                onPressed: _loadingGoogle || _loadingApple ? null : _signInGoogle,
                loading: _loadingGoogle,
                icon: _GoogleIcon(),
                label: 'Continuer avec Google',
                backgroundColor: SwimColors.surface,
                foregroundColor: SwimColors.textPrimary,
                borderColor: SwimColors.border,
              ),
              const SizedBox(height: 12),

              // Bouton Apple
              _SignInButton(
                onPressed: _loadingGoogle || _loadingApple ? null : _signInApple,
                loading: _loadingApple,
                icon: const Icon(Icons.apple, color: Colors.white, size: 20),
                label: 'Continuer avec Apple',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                borderColor: Colors.transparent,
              ),

              // Erreur
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SwimColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: SwimColors.danger.withOpacity(0.4),
                        width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: SwimColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: SwimColors.danger, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Mentions légales
              const Text(
                'En continuant, vous acceptez nos conditions d\'utilisation.\nVos données sont stockées de façon sécurisée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: SwimColors.textMuted,
                    height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bouton Sign-In générique ─────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  const _SignInButton({
    required this.onPressed,
    required this.loading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foregroundColor),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: foregroundColor)),
                ],
              ),
      ),
    );
  }
}

// ─── Icône Google SVG simplifiée ──────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Cercle de fond simplifié — 4 couleurs Google
    final colors = [
      const Color(0xFF4285F4), // bleu
      const Color(0xFF34A853), // vert
      const Color(0xFFFBBC05), // jaune
      const Color(0xFFEA4335), // rouge
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()..color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        (i * 90 - 90) * 3.14159 / 180,
        90 * 3.14159 / 180,
        true,
        paint,
      );
    }

    // Centre blanc
    canvas.drawCircle(c, r * 0.55,
        Paint()..color = SwimColors.surface);
    canvas.drawCircle(c, r * 0.25,
        Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
