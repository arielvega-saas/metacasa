import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text.dart';
import '../features/auth/presentation/auth_flow_screen.dart';
import '../features/auth/presentation/create_join_household_screen.dart';
import '../state/app_state.dart';

/// Gate raíz — espejo del `RootView` de iOS. Switchea por [appGateProvider]:
///
/// - `loading`        → splash (logo "Home Finance" serif + spinner)
/// - `unauthenticated`→ pantalla de acceso ([AuthFlowScreen])
/// - `noHousehold`    → alta/ingreso a hogar ([CreateJoinHouseholdScreen])
/// - `ready`          → **el shell** (lo maneja el router: redirect a `/home`)
///
/// Importante: el caso `ready` NO se pinta acá. El `redirect` del router saca a
/// `/home` (el `StatefulShellRoute`) en cuanto el gate llega a `ready`, igual
/// que iOS muestra `MainTabView`. Si por carrera de timing `RootGate` se
/// construye con `ready`, mostramos el splash como puente (el redirect lo
/// reemplaza en el siguiente frame).
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(appGateProvider);
    return switch (gate) {
      AppGate.loading || AppGate.ready => const _SplashView(),
      AppGate.unauthenticated => const AuthFlowScreen(),
      AppGate.noHousehold => const CreateJoinHouseholdScreen(),
    };
  }
}

/// Splash de arranque — espejo de `LaunchView` (iOS): fondo de marca, wordmark
/// serif "Home Finance" y spinner.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 96,
              height: 96,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: Insets.section),
            Text('Home Finance', style: AppText.serifTitle(c.textPrimary)),
            const SizedBox(height: Insets.xl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
