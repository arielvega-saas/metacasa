// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InstallmentPlan _$InstallmentPlanFromJson(Map<String, dynamic> json) =>
    _InstallmentPlan(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      totalAmount: const DecimalConverter().fromJson(json['total_amount']),
      totalInstallments: (json['total_installments'] as num).toInt(),
      currency: json['currency'] as String,
      startYear: (json['start_year'] as num).toInt(),
      startMonth: (json['start_month'] as num).toInt(),
      category: json['category'] as String?,
      accountId: json['account_id'] as String?,
      note: json['note'] as String?,
      status: $enumDecode(_$PlanStatusEnumMap, json['status']),
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$InstallmentPlanToJson(_InstallmentPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'household_id': instance.householdId,
      'name': instance.name,
      'total_amount': const DecimalConverter().toJson(instance.totalAmount),
      'total_installments': instance.totalInstallments,
      'currency': instance.currency,
      'start_year': instance.startYear,
      'start_month': instance.startMonth,
      'category': instance.category,
      'account_id': instance.accountId,
      'note': instance.note,
      'status': _$PlanStatusEnumMap[instance.status]!,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$PlanStatusEnumMap = {
  PlanStatus.active: 'active',
  PlanStatus.completed: 'completed',
  PlanStatus.cancelled: 'cancelled',
};

_InstallmentPayment _$InstallmentPaymentFromJson(Map<String, dynamic> json) =>
    _InstallmentPayment(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      periodYear: (json['period_year'] as num).toInt(),
      periodMonth: (json['period_month'] as num).toInt(),
      installmentNumber: (json['installment_number'] as num).toInt(),
      amount: const DecimalConverter().fromJson(json['amount']),
      paid: json['paid'] as bool,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
      transactionId: json['transaction_id'] as String?,
    );

Map<String, dynamic> _$InstallmentPaymentToJson(_InstallmentPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'plan_id': instance.planId,
      'period_year': instance.periodYear,
      'period_month': instance.periodMonth,
      'installment_number': instance.installmentNumber,
      'amount': const DecimalConverter().toJson(instance.amount),
      'paid': instance.paid,
      'paid_at': instance.paidAt?.toIso8601String(),
      'transaction_id': instance.transactionId,
    };
