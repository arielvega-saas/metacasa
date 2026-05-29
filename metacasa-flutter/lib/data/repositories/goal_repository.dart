import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_init.dart';
import '../../models/models.dart';

/// Repositorio de metas de ahorro (goals) y sus aportes (goal_contributions).
/// Port de `GoalService` de iOS (`Core/GoalService.swift`).
///
/// `goals` scoped por household; `goal_contributions` por goal_id. Un TRIGGER
/// en DB recalcula `goals.current_amount` al insertar un aporte, por eso
/// [addContribution] **re-lee la meta** para devolver el monto actualizado.
class GoalRepository {
  const GoalRepository();

  /// Metas del hogar. Si [includeCompleted] es `false`, excluye las
  /// completadas. Orden: prioridad desc, luego creación asc (igual que iOS).
  Future<List<Goal>> fetchAll({
    required String householdId,
    bool includeCompleted = true,
  }) async {
    var query =
        supabase.from('goals').select().eq('household_id', householdId);
    if (!includeCompleted) {
      query = query.neq('status', 'completed');
    }
    final List<dynamic> rows = await query
        .order('priority', ascending: false)
        .order('created_at', ascending: true);
    return rows
        .map((dynamic e) => Goal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una meta. Descarta claves server-generated; `current_amount`/`status`
  /// los completa la DB por default si el modelo trae los suyos.
  Future<Goal> insert(Goal goal) async {
    final Map<String, dynamic> payload = _writePayload(goal);
    final Map<String, dynamic> row =
        await supabase.from('goals').insert(payload).select().single();
    return Goal.fromJson(row);
  }

  /// Actualiza una meta existente.
  Future<Goal> update(Goal goal) async {
    final Map<String, dynamic> payload = _writePayload(goal);
    final Map<String, dynamic> row = await supabase
        .from('goals')
        .update(payload)
        .eq('id', goal.id)
        .select()
        .single();
    return Goal.fromJson(row);
  }

  /// Elimina una meta (cascada borra sus aportes en DB).
  Future<void> delete(String id) async {
    await supabase.from('goals').delete().eq('id', id);
  }

  /// Aportes de una meta, más recientes primero.
  Future<List<GoalContribution>> fetchContributions(String goalId) async {
    final List<dynamic> rows = await supabase
        .from('goal_contributions')
        .select()
        .eq('goal_id', goalId)
        .order('contributed_at', ascending: false);
    return rows
        .map((dynamic e) =>
            GoalContribution.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Agrega un aporte a la meta y devuelve `(contribution, goal)` con la meta
  /// YA recargada (el trigger de DB actualizó `current_amount`). `contributed_by`
  /// se completa con el usuario autenticado. Espejo de `contribute` en iOS más
  /// el re-fetch que pide la lógica del trigger.
  Future<GoalContributionResult> addContribution({
    required String goalId,
    required Decimal amount,
    String? notes,
    String? transactionId,
  }) async {
    final String userId = supabase.auth.currentUser!.id;
    final Map<String, dynamic> payload = <String, dynamic>{
      'goal_id': goalId,
      'amount': amount.toString(),
      'contributed_by': userId,
      if (notes != null) 'notes': notes,
      if (transactionId != null) 'transaction_id': transactionId,
    };
    final Map<String, dynamic> contribRow = await supabase
        .from('goal_contributions')
        .insert(payload)
        .select()
        .single();
    final GoalContribution contribution = GoalContribution.fromJson(contribRow);

    // El trigger ya actualizó goals.current_amount: re-leemos la meta.
    final Map<String, dynamic> goalRow =
        await supabase.from('goals').select().eq('id', goalId).single();
    final Goal goal = Goal.fromJson(goalRow);

    return GoalContributionResult(contribution: contribution, goal: goal);
  }

  /// Elimina un aporte (el trigger reajusta `current_amount`).
  Future<void> removeContribution(String id) async {
    await supabase.from('goal_contributions').delete().eq('id', id);
  }

  /// Payload de insert/update: `goal.toJson()` sin claves server-generated
  /// (id, created_at, updated_at, completed_at) y con `target_date` normalizada
  /// a 'YYYY-MM-DD' (columna Postgres `date`).
  Map<String, dynamic> _writePayload(Goal goal) {
    final Map<String, dynamic> json = goal.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('completed_at');
    final DateTime? td = goal.targetDate;
    if (td != null) {
      json['target_date'] = _dateOnly(td);
    }
    return json;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Resultado de [GoalRepository.addContribution]: el aporte insertado más la
/// meta recargada (con `current_amount` ya actualizado por el trigger).
class GoalContributionResult {
  const GoalContributionResult({
    required this.contribution,
    required this.goal,
  });

  final GoalContribution contribution;
  final Goal goal;
}

/// Provider del [GoalRepository].
final Provider<GoalRepository> goalRepositoryProvider =
    Provider<GoalRepository>((Ref ref) => const GoalRepository());
