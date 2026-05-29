// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Goal _$GoalFromJson(Map<String, dynamic> json) => _Goal(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetAmount: const DecimalConverter().fromJson(json['target_amount']),
      currentAmount: const DecimalConverter().fromJson(json['current_amount']),
      currency: json['currency'] as String,
      targetDate: json['target_date'] == null
          ? null
          : DateTime.parse(json['target_date'] as String),
      status: $enumDecode(_$GoalStatusEnumMap, json['status']),
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      priority: (json['priority'] as num).toInt(),
      category: json['category'] as String?,
      accountId: json['account_id'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );

Map<String, dynamic> _$GoalToJson(_Goal instance) => <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'name': instance.name,
      'description': instance.description,
      'target_amount': const DecimalConverter().toJson(instance.targetAmount),
      'current_amount': const DecimalConverter().toJson(instance.currentAmount),
      'currency': instance.currency,
      'target_date': instance.targetDate?.toIso8601String(),
      'status': _$GoalStatusEnumMap[instance.status]!,
      'icon': instance.icon,
      'color': instance.color,
      'priority': instance.priority,
      'category': instance.category,
      'account_id': instance.accountId,
      'notes': instance.notes,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
    };

const _$GoalStatusEnumMap = {
  GoalStatus.active: 'active',
  GoalStatus.completed: 'completed',
  GoalStatus.paused: 'paused',
  GoalStatus.canceled: 'canceled',
};

_GoalContribution _$GoalContributionFromJson(Map<String, dynamic> json) =>
    _GoalContribution(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      amount: const DecimalConverter().fromJson(json['amount']),
      contributedBy: json['contributed_by'] as String,
      contributedAt: DateTime.parse(json['contributed_at'] as String),
      notes: json['notes'] as String?,
      transactionId: json['transaction_id'] as String?,
    );

Map<String, dynamic> _$GoalContributionToJson(_GoalContribution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'goal_id': instance.goalId,
      'amount': const DecimalConverter().toJson(instance.amount),
      'contributed_by': instance.contributedBy,
      'contributed_at': instance.contributedAt.toIso8601String(),
      'notes': instance.notes,
      'transaction_id': instance.transactionId,
    };
