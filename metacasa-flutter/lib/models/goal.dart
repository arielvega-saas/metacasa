import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'goal.freezed.dart';
part 'goal.g.dart';

/// Estado de la meta de ahorro.
enum GoalStatus {
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('paused')
  paused,
  @JsonValue('canceled')
  canceled;

  String get label => switch (this) {
        GoalStatus.active => 'Activa',
        GoalStatus.completed => 'Completada',
        GoalStatus.paused => 'Pausada',
        GoalStatus.canceled => 'Cancelada',
      };
}

/// Meta de ahorro. Espejo 1:1 de `public.goals`.
@freezed
abstract class Goal with _$Goal {
  const Goal._();

  const factory Goal({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String name,
    String? description,
    @JsonKey(name: 'target_amount')
    @DecimalConverter()
    required Decimal targetAmount,
    @JsonKey(name: 'current_amount')
    @DecimalConverter()
    required Decimal currentAmount,
    required String currency,
    @JsonKey(name: 'target_date') DateTime? targetDate,
    required GoalStatus status,
    String? icon,
    String? color,
    required int priority,
    String? category,
    @JsonKey(name: 'account_id') String? accountId,
    String? notes,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  /// Progreso hacia la meta (0.0 – 1.0).
  double get progress {
    if (targetAmount <= Decimal.zero) return 0;
    final double ratio = currentAmount.toDouble() / targetAmount.toDouble();
    return ratio < 1 ? ratio : 1;
  }
}

/// Aporte a una meta. Espejo 1:1 de `public.goal_contributions`.
@freezed
abstract class GoalContribution with _$GoalContribution {
  const factory GoalContribution({
    required String id,
    @JsonKey(name: 'goal_id') required String goalId,
    @DecimalConverter() required Decimal amount,
    @JsonKey(name: 'contributed_by') required String contributedBy,
    @JsonKey(name: 'contributed_at') required DateTime contributedAt,
    String? notes,
    @JsonKey(name: 'transaction_id') String? transactionId,
  }) = _GoalContribution;

  factory GoalContribution.fromJson(Map<String, dynamic> json) =>
      _$GoalContributionFromJson(json);
}
