import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_init.dart';
import '../../core/finance/waterfall_calculator.dart';
import '../../models/models.dart';

/// Repositorio de planes de cuotas (installment_plans) y su ledger de pagos
/// (installment_payments). Port de `InstallmentService` de iOS
/// (`Core/InstallmentService.swift`).
///
/// `installment_plans` scoped por household; `installment_payments` por
/// plan_id. Al crear un plan se siembra UNA fila de pago por cuota (período
/// derivado de start_year/start_month + offset). Duplicados (unique constraint)
/// se silencian, igual que iOS.
class InstallmentRepository {
  const InstallmentRepository();

  /// Código Postgres de violación de unique constraint.
  static const String _uniqueViolation = '23505';

  // MARK: - Planes

  /// Planes del hogar. Si [includeCompleted] es `false`, sólo los activos.
  Future<List<InstallmentPlan>> fetchPlans({
    required String householdId,
    bool includeCompleted = true,
  }) async {
    var query = supabase
        .from('installment_plans')
        .select()
        .eq('household_id', householdId);
    if (!includeCompleted) {
      query = query.eq('status', 'active');
    }
    final List<dynamic> rows = await query.order('created_at', ascending: false);
    return rows
        .map((dynamic e) => InstallmentPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea un plan y siembra su ledger de pagos (una fila por cuota). Espejo de
  /// `createPlan` + `seedPayments` en iOS.
  Future<InstallmentPlan> createPlan(InstallmentPlan plan) async {
    final Map<String, dynamic> payload = plan.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at');
    final Map<String, dynamic> row = await supabase
        .from('installment_plans')
        .insert(payload)
        .select()
        .single();
    final InstallmentPlan created = InstallmentPlan.fromJson(row);

    await _seedPayments(created);
    return created;
  }

  /// Inserta las filas de `installment_payments` (1 por cuota). El monto es
  /// `total/N` (`plan.monthlyAmount`) y el período sale de `plan.periodFor(n)`.
  /// Cada fila se inserta por separado para poder tragar duplicados sin abortar
  /// el resto (espejo del try/catch por fila de iOS).
  Future<void> _seedPayments(InstallmentPlan plan) async {
    final String amount = plan.monthlyAmount.toString();
    for (var n = 1; n <= plan.totalInstallments; n++) {
      final ({int year, int month}) period = plan.periodFor(n);
      final Map<String, dynamic> rowPayload = <String, dynamic>{
        'plan_id': plan.id,
        'period_year': period.year,
        'period_month': period.month,
        'installment_number': n,
        'amount': amount,
      };
      try {
        await supabase.from('installment_payments').insert(rowPayload);
      } on PostgrestException catch (e) {
        // Silenciamos duplicados (unique constraint). El resto se propaga.
        if (e.code != _uniqueViolation) rethrow;
      }
    }
  }

  /// Elimina un plan (ON DELETE CASCADE borra sus pagos).
  Future<void> deletePlan(String id) async {
    await supabase.from('installment_plans').delete().eq('id', id);
  }

  /// Cancela un plan (`status='cancelled'`, doble-L como en el wire-value real).
  Future<void> cancelPlan(String id) async {
    await supabase
        .from('installment_plans')
        .update(<String, dynamic>{'status': 'cancelled'})
        .eq('id', id);
  }

  // MARK: - Pagos

  /// Ledger completo de un plan, ordenado por número de cuota.
  Future<List<InstallmentPayment>> fetchPayments(String planId) async {
    final List<dynamic> rows = await supabase
        .from('installment_payments')
        .select()
        .eq('plan_id', planId)
        .order('installment_number', ascending: true);
    return rows
        .map((dynamic e) =>
            InstallmentPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pagos del hogar para el mes [year]/[month]: planes ACTIVOS → sus filas de
  /// pago en ese período, como pares (plan, payment) listos para el waterfall.
  /// Espejo de `fetchPaymentsForMonth` en iOS.
  Future<List<InstallmentPaymentRef>> fetchPaymentsForMonth({
    required String householdId,
    required int year,
    required int month,
  }) async {
    final List<dynamic> planRows = await supabase
        .from('installment_plans')
        .select()
        .eq('household_id', householdId)
        .eq('status', 'active');
    final List<InstallmentPlan> plans = planRows
        .map((dynamic e) => InstallmentPlan.fromJson(e as Map<String, dynamic>))
        .toList();

    final List<InstallmentPaymentRef> result = <InstallmentPaymentRef>[];
    for (final InstallmentPlan p in plans) {
      final List<dynamic> payRows = await supabase
          .from('installment_payments')
          .select()
          .eq('plan_id', p.id)
          .eq('period_year', year)
          .eq('period_month', month);
      for (final dynamic e in payRows) {
        result.add(InstallmentPaymentRef(
          plan: p,
          payment: InstallmentPayment.fromJson(e as Map<String, dynamic>),
        ));
      }
    }
    return result;
  }

  /// Marca una cuota como pagada (`paid=true`, `paid_at=now`, transaction_id
  /// opcional). Espejo de `markPaymentPaid` en iOS.
  Future<void> markPaymentPaid(String id, {String? transactionId}) async {
    await supabase.from('installment_payments').update(<String, dynamic>{
      'paid': true,
      'paid_at': DateTime.now().toUtc().toIso8601String(),
      if (transactionId != null) 'transaction_id': transactionId,
    }).eq('id', id);
  }
}

/// Provider del [InstallmentRepository].
final Provider<InstallmentRepository> installmentRepositoryProvider =
    Provider<InstallmentRepository>((Ref ref) => const InstallmentRepository());
