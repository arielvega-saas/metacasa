import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/installment_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Snapshot de un plan de cuotas con su recuento de pagos ya resuelto.
///
/// El repo trae los planes y, por separado, el ledger de cada uno. La pantalla
/// necesita ambos: el plan (descripción, monto mensual, total) y cuántas cuotas
/// están pagas (para la barra de progreso "paga/total"). Empaquetamos los dos en
/// esta clase plana (sin freezed/codegen, por requerimiento) para que la lista
/// renderice sin volver a tocar la red.
///
/// Espejo del `progressByPlan[plan.id] = (paid, total)` que el
/// `InstallmentsListView` de iOS arma en su `load()`.
class PlanProgress {
  const PlanProgress({required this.plan, required this.paidCount});

  /// El plan de cuotas (`installment_plans`).
  final InstallmentPlan plan;

  /// Cantidad de cuotas marcadas como pagas (filas `paid=true` del ledger).
  final int paidCount;

  /// Total de cuotas del plan (atajo a `plan.totalInstallments`).
  int get totalCount => plan.totalInstallments;

  /// Cuotas que faltan pagar (nunca negativo).
  int get remainingCount {
    final int rem = totalCount - paidCount;
    return rem < 0 ? 0 : rem;
  }

  /// Fracción pagada (0.0 – 1.0) para la `MCProgressBar`. 0 si no hay cuotas.
  double get progress {
    if (totalCount <= 0) return 0;
    return (paidCount / totalCount).clamp(0.0, 1.0);
  }

  /// `true` si el plan está completo (todas las cuotas pagas) o su estado lo es.
  bool get isCompleted =>
      plan.status == PlanStatus.completed || paidCount >= totalCount;
}

/// Estado inmutable de la pantalla de Cuotas: la lista de planes con su progreso
/// ya computado + los agregados del header (cuota mensual total y total
/// restante). Clase plana (sin freezed), igual criterio que `AccountsState`.
class InstallmentsState {
  const InstallmentsState({
    required this.plans,
    required this.totalMonthly,
    required this.totalRemaining,
  });

  /// Estado vacío (sin hogar o sin planes): lista vacía + agregados en cero.
  factory InstallmentsState.empty() => InstallmentsState(
        plans: const <PlanProgress>[],
        totalMonthly: Decimal.zero,
        totalRemaining: Decimal.zero,
      );

  /// Planes del hogar (orden del repo: `created_at` desc) con su progreso.
  final List<PlanProgress> plans;

  /// Suma de la cuota mensual (`monthlyAmount`) de los planes NO completados.
  /// Es el compromiso mensual vivo de cuotas (lo que sigue saliendo cada mes).
  final Decimal totalMonthly;

  /// Suma de lo que falta pagar: por cada plan no completado,
  /// `monthlyAmount × cuotas restantes`. Es la deuda remanente de cuotas.
  final Decimal totalRemaining;

  /// `true` si no hay ningún plan para mostrar.
  bool get isEmpty => plans.isEmpty;
}

/// Controller de la pantalla de Cuotas. `AsyncNotifier` que observa el hogar
/// activo y, ante un cambio (switch de hogar), recarga planes + ledgers.
///
/// Replica el `load()` del `InstallmentsListView` de iOS: trae los planes y,
/// por cada uno, su ledger para contar las cuotas pagas. Los agregados se
/// computan en `Decimal` (matemática exacta de dinero).
class InstallmentsController extends AsyncNotifier<InstallmentsState> {
  @override
  Future<InstallmentsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      // Sin hogar no hay cuotas (el gate cubre el alta de hogar).
      return InstallmentsState.empty();
    }
    return _load(householdId);
  }

  /// Fetch de planes + sus ledgers + cómputo de agregados.
  Future<InstallmentsState> _load(String householdId) async {
    final InstallmentRepository repo = ref.read(installmentRepositoryProvider);

    // Incluimos completados para que el historial siga visible (igual que iOS,
    // que llama `fetchPlans(householdId:)` con el default `includeCompleted`).
    final List<InstallmentPlan> rawPlans =
        await repo.fetchPlans(householdId: householdId);

    final List<PlanProgress> plans = <PlanProgress>[];
    for (final InstallmentPlan plan in rawPlans) {
      // El ledger de un plan puede fallar puntualmente; degradamos a "0 pagas"
      // para no tumbar la lista entera (mismo criterio que el `try?` de iOS).
      final List<InstallmentPayment> payments = await repo
          .fetchPayments(plan.id)
          .catchError((_) => <InstallmentPayment>[]);
      final int paidCount =
          payments.where((InstallmentPayment p) => p.paid).length;
      plans.add(PlanProgress(plan: plan, paidCount: paidCount));
    }

    // Agregados sobre los planes NO completados: cuota mensual viva y deuda
    // remanente de cuotas (mensual × cuotas que faltan).
    var totalMonthly = Decimal.zero;
    var totalRemaining = Decimal.zero;
    for (final PlanProgress pp in plans) {
      if (pp.isCompleted) continue;
      final Decimal monthly = pp.plan.monthlyAmount;
      totalMonthly += monthly;
      totalRemaining += monthly * Decimal.fromInt(pp.remainingCount);
    }

    return InstallmentsState(
      plans: plans,
      totalMonthly: totalMonthly,
      totalRemaining: totalRemaining,
    );
  }

  /// Crea un plan (el repo siembra el ledger de pagos) y refresca la lista.
  Future<void> createPlan(InstallmentPlan plan) async {
    await ref.read(installmentRepositoryProvider).createPlan(plan);
    await refresh();
  }

  /// Elimina un plan (ON DELETE CASCADE borra sus pagos) y refresca.
  Future<void> deletePlan(String id) async {
    await ref.read(installmentRepositoryProvider).deletePlan(id);
    await refresh();
  }

  /// Cancela un plan (`status='cancelled'`) y refresca.
  Future<void> cancelPlan(String id) async {
    await ref.read(installmentRepositoryProvider).cancelPlan(id);
    await refresh();
  }

  /// Fuerza una recarga (pull-to-refresh / post-alta / post-pago). Mantiene
  /// visible el dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(InstallmentsState.empty());
      return;
    }
    state = const AsyncLoading<InstallmentsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }
}

/// Provider del controller de Cuotas. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final installmentsControllerProvider =
    AsyncNotifierProvider<InstallmentsController, InstallmentsState>(
        InstallmentsController.new);
