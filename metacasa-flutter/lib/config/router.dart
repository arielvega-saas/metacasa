import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../features/accounts/presentation/accounts_screen.dart';
import '../features/assistant/presentation/assistant_fab.dart';
import '../features/bills/presentation/bills_screen.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/budget/presentation/waterfall_screen.dart';
import '../features/debts/presentation/debts_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/installments/presentation/installments_screen.dart';
import '../features/households/presentation/household_settings_screen.dart';
import '../features/recurring/presentation/recurring_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/notifications/notification_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/transactions/presentation/add_transaction_sheet.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../state/app_state.dart';
import 'root_gate.dart';

/// Índice de la rama central "Agregar". No navega: intercepta la selección para
/// abrir la hoja `AddTransactionSheet` (espejo del tab `.add` de iOS).
const int _addBranchIndex = 2;

/// Ruta del gate raíz (splash / auth / sin-hogar). El `redirect` manda acá
/// cuando `appGateProvider` no está en `ready`. El shell vive en `/home`+.
const String _gatePath = '/gate';

/// Provider del `GoRouter`. Se construye con acceso al `ref` para que el
/// `redirect` consulte `appGateProvider` y `refreshListenable` lo re-evalúe
/// cuando el gate cambie (login, alta de hogar, etc.).
///
/// Espejo del `RootView` de iOS: antes de mostrar el shell de tabs, un gate
/// decide splash → auth → sin-hogar → app. Acá el gate es declarativo (redirect)
/// y la pantalla la pinta [RootGate].
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    // Re-evalúa el redirect cada vez que cambia el estado del gate.
    refreshListenable: _GateListenable(ref),
    redirect: (context, state) {
      final gate = ref.read(appGateProvider);
      final atGate = state.matchedLocation == _gatePath;
      // Si todavía no estamos listos, todo va al gate.
      if (gate != AppGate.ready) return atGate ? null : _gatePath;
      // Ya listos: si quedamos parados en el gate, entrar al shell.
      if (atGate) return '/home';
      return null;
    },
    routes: [
      // Gate raíz: una sola ruta que delega en [RootGate], que internamente
      // switchea por el estado actual (loading / unauthenticated / noHousehold).
      GoRoute(
        path: _gatePath,
        builder: (context, state) => const RootGate(),
      ),
      // Shell de tabs (IndexedStack): cada rama conserva su stack y estado,
      // igual que el TabView nativo de iOS.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          // 0 · Inicio
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 1 · Movimientos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          // 2 · Agregar — rama "fantasma". Nunca se muestra porque la selección
          // se intercepta antes de navegar; el builder existe solo para cumplir
          // el contrato de StatefulShellRoute (1 rama por destino del NavBar).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
          // 3 · Presupuesto (+ Waterfall como sub-ruta, queda dentro de la rama)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budget',
                builder: (context, state) => const BudgetScreen(),
                routes: [
                  GoRoute(
                    path: 'waterfall',
                    builder: (context, state) => const WaterfallScreen(),
                  ),
                ],
              ),
            ],
          ),
          // 4 · Más (+ destinos secundarios como sub-rutas dentro de la rama,
          // así la NavigationBar queda visible y el back vuelve a "Más", igual
          // que los NavigationLink del MoreView de iOS).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'accounts',
                    builder: (context, state) => const AccountsScreen(),
                  ),
                  GoRoute(
                    path: 'goals',
                    builder: (context, state) => const GoalsScreen(),
                  ),
                  GoRoute(
                    path: 'recurring',
                    builder: (context, state) => const RecurringScreen(),
                  ),
                  GoRoute(
                    path: 'bills',
                    builder: (context, state) => const BillsScreen(),
                  ),
                  GoRoute(
                    path: 'installments',
                    builder: (context, state) => const InstallmentsScreen(),
                  ),
                  GoRoute(
                    path: 'debts',
                    builder: (context, state) => const DebtsScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'household',
                    builder: (context, state) =>
                        const HouseholdSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'notifications',
                        builder: (context, state) =>
                            const NotificationSettingsScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Scaffold del shell: apila el cuerpo (IndexedStack que provee el
/// `navigationShell`), el FAB del asistente como overlay, y la `NavigationBar`.
///
/// El FAB se posiciona a mano (Stack + Positioned), NO como FAB docked de
/// Material — fiel al `.overlay(alignment: .bottomTrailing)` del iOS RootView.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Maneja la selección de un destino. El central "Agregar" NO navega: dispara
  /// el haptic y abre la hoja, dejando el índice en el tab previo (igual que
  /// iOS, que restaura `lastNonAddTab`).
  void _onDestinationSelected(BuildContext context, int index) {
    if (index == _addBranchIndex) {
      HapticFeedback.mediumImpact();
      AddTransactionSheet.show(context);
      return; // no goBranch → el índice se mantiene en el tab actual
    }
    // `initialLocation: true` re-pop-ea al root de la rama si ya estás en ella
    // (mismo gesto "tap en el tab activo vuelve arriba" del nativo).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.appBackground,
      // El cuerpo y el FAB conviven en un Stack para que el FAB flote por encima
      // del contenido y justo arriba de la NavigationBar (bottomTrailing).
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            right: Insets.fabTrailing,
            bottom: Insets.fabBottom,
            child: const AssistantFab(),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (i) => _onDestinationSelected(context, i),
      ),
    );
  }
}

/// `NavigationBar` Material 3 con el branding Midnight Sage: indicador sage de
/// baja opacidad, tinte seleccionado brandPrimary. Orden/íconos 1:1 con iOS.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: c.appSurface,
        // Indicador sage tenue detrás del ícono seleccionado.
        indicatorColor: c.brandPrimary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.brandPrimary : c.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? c.brandPrimary : c.textMuted,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        // Sin barrido de fondo por scroll: queremos color sólido de superficie.
        surfaceTintColor: Colors.transparent,
        backgroundColor: c.appSurface,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.scrollText),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.plusCircle),
            label: 'Agregar',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.pieChart),
            label: 'Presupuesto',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.menu),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

/// Puente Riverpod → `Listenable` para `GoRouter.refreshListenable`.
///
/// Escucha [appGateProvider] y notifica al router cuando el gate cambia, para
/// que el `redirect` se re-evalúe (entrar/salir del shell). `ref.listen` aquí
/// vive lo que vive el provider del router, así que no hace falta `dispose`.
class _GateListenable extends ChangeNotifier {
  _GateListenable(Ref ref) {
    ref.listen<AppGate>(appGateProvider, (_, __) => notifyListeners());
  }
}
