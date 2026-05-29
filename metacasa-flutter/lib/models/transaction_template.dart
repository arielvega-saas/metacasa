import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';
import 'transaction.dart';

part 'transaction_template.freezed.dart';
part 'transaction_template.g.dart';

/// Plantilla de transacción guardada para crear movimientos con 1 tap
/// ("quick shortcuts"). Espejo 1:1 de `public.transaction_templates`.
@freezed
abstract class TransactionTemplate with _$TransactionTemplate {
  const factory TransactionTemplate({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String name,
    String? emoji,
    required TxType type,
    @DecimalConverter() required Decimal amount,
    required String currency,
    required String category,
    String? subcategory,
    String? note,
    required int position,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _TransactionTemplate;

  factory TransactionTemplate.fromJson(Map<String, dynamic> json) =>
      _$TransactionTemplateFromJson(json);
}
