import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import 'ai_consent_provider.dart';
import 'assistant_chat_sheet.dart';
import 'consent_sheet.dart';

/// FAB del asistente — espejo de `AssistantFloatingButton` (iOS), que en
/// `RootView` se monta como `.overlay(alignment: .bottomTrailing)` sobre el
/// TabView. Acá NO es el FAB docked de Material: se posiciona a mano dentro del
/// `Stack` del shell para poder vivir por encima de la `NavigationBar`.
///
/// Portado 1:1 del ZStack de `AssistantFloatingButton` (iOS):
/// - halo exterior difuso: círculo Ø68 de `brandPrimary @ 0.25` con blur 8;
/// - círculo sage Ø54 (`brandPrimary`) con anillo champagne (`brandSecondary @ 0.4`,
///   1pt) y drop shadow `brandPrimary @ 0.35` (blur 10, offset 0,4);
/// - ícono `sparkles` en `#0E1312` (texto oscuro sobre sage).
///
/// El widget se dimensiona al círculo visible (Ø54 = el tap target); el halo
/// desborda simétricamente (`Clip.none`) sin mover el anchor del overlay.
///
/// Tap → gate de consentimiento: si el usuario todavía no aceptó la privacidad
/// del Asistente IA, abre primero el [AssistantConsentSheet] (no descartable); si
/// aceptó (o ya había consentido), abre [AssistantChatSheet]. Espejo del flujo
/// del `AssistantChatView` (iOS), donde el consent sheet se presenta al `.task`
/// si `!privacy.assistantCloudConsent`.
class AssistantFab extends ConsumerWidget {
  const AssistantFab({super.key});

  /// Diámetro del círculo sage visible (= área tappable).
  static const double diameter = 54;

  /// Diámetro del halo difuso exterior (desborda detrás del círculo).
  static const double haloDiameter = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Asistente',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          // El halo es más grande que el círculo: que desborde sin recortarse.
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Halo exterior difuso (no interactivo).
            IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: haloDiameter,
                  height: haloDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.brandPrimary.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            // Círculo sage con anillo champagne + drop shadow de color.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.brandPrimary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: c.brandPrimary,
                shape: CircleBorder(
                  side: BorderSide(
                    color: c.brandSecondary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openAssistant(context, ref),
                  child: const SizedBox(
                    width: diameter,
                    height: diameter,
                    child: Icon(
                      LucideIcons.sparkles,
                      // Texto/ícono oscuro sobre sage (mismo onPrimary del tema).
                      color: Color(0xFF0E1312),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el asistente con gate de consentimiento.
  ///
  /// 1. Si el usuario ya consintió (`aiConsentProvider == true`) → abre el chat
  ///    directo.
  /// 2. Si no, presenta el [AssistantConsentSheet] (no descartable). Si acepta,
  ///    encadena la apertura del chat; si cancela, no pasa nada.
  ///
  /// El consentimiento se persiste en `shared_preferences` (`pref_ai_consent`),
  /// así que el sheet solo aparece la primera vez (igual que el iOS).
  Future<void> _openAssistant(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    final bool consented = ref.read(aiConsentProvider);
    if (consented) {
      await AssistantChatSheet.show(context);
      return;
    }

    final bool? accepted = await AssistantConsentSheet.show(context);
    if (accepted ?? false) {
      // `context.mounted` tras el await del sheet — el FAB pudo desmontarse.
      if (!context.mounted) return;
      await AssistantChatSheet.show(context);
    }
  }
}
