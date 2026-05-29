import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/utils/decimal_converter.dart';

part 'household.freezed.dart';
part 'household.g.dart';

/// Modo de distribución del remanente entre cuentas personales (waterfall).
enum DistributionMode {
  @JsonValue('equal')
  equal,
  @JsonValue('proportional')
  proportional,
  @JsonValue('custom')
  custom;

  String get label => switch (this) {
        DistributionMode.equal => 'Equitativa',
        DistributionMode.proportional => 'Proporcional',
        DistributionMode.custom => 'Personalizada',
      };
}

/// Rol de un miembro del hogar.
enum MemberRole {
  @JsonValue('owner')
  owner,
  @JsonValue('admin')
  admin,
  @JsonValue('member')
  member,
  @JsonValue('viewer')
  viewer;

  String get label => switch (this) {
        MemberRole.owner => 'Propietario',
        MemberRole.admin => 'Administrador',
        MemberRole.member => 'Miembro',
        MemberRole.viewer => 'Solo lectura',
      };

  /// Si el rol puede invitar a otros miembros.
  bool get canInvite => this == MemberRole.owner || this == MemberRole.admin;
}

/// Estado de una invitación al hogar.
enum InvitationStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('expired')
  expired,
  @JsonValue('revoked')
  revoked,
}

/// Tasa de cambio manual — "cuántas unidades de la moneda BASE del hogar
/// equivalen a 1 unidad de esta moneda". Vive en `households.fx_rates` (JSONB,
/// clave = código ISO). Espejo 1:1 de `FXRate` en iOS.
@freezed
abstract class FXRate with _$FXRate {
  const factory FXRate({
    @DecimalConverter() required Decimal rate,

    /// ISO 8601 — cuándo el usuario actualizó el rate. String, como en iOS.
    @JsonKey(name: 'updated_at') required String updatedAt,

    /// "manual" por ahora; campo reservado para auto-fetch futuro.
    required String source,
  }) = _FXRate;

  factory FXRate.fromJson(Map<String, dynamic> json) => _$FXRateFromJson(json);
}

/// Configuración waterfall del hogar. Vive en `households.strategy` (JSONB).
/// Espejo 1:1 de `HouseholdStrategy` en iOS.
///
/// NOTA: `savingsPct`/`investmentPct` son `required` (no `@Default`) porque
/// `Decimal` no tiene constructor const y Freezed exige constantes en
/// `@Default`. Esto además replica el decode de Swift, que también exige las
/// claves presentes. Para construir con los defaults de iOS (10 / 0) usar
/// [HouseholdStrategy.standard].
@freezed
abstract class HouseholdStrategy with _$HouseholdStrategy {
  const factory HouseholdStrategy({
    /// Porcentaje del remanente que va automáticamente a ahorro (0-100).
    @JsonKey(name: 'savings_pct')
    @DecimalConverter()
    required Decimal savingsPct,

    /// Porcentaje del remanente que va a inversión (0-100).
    @JsonKey(name: 'investment_pct')
    @DecimalConverter()
    required Decimal investmentPct,

    /// Modo de distribución del remanente entre cuentas personales.
    @JsonKey(name: 'distribution_mode')
    @Default(DistributionMode.equal)
    DistributionMode distributionMode,

    /// Allocations custom por cuenta (usado cuando mode == custom).
    @JsonKey(name: 'custom_allocations')
    @DecimalConverter()
    @Default(<String, Decimal>{})
    Map<String, Decimal> customAllocations,

    /// Flags para incluir/excluir cada tipo de deducción del waterfall.
    @JsonKey(name: 'include_bills_in_waterfall')
    @Default(true)
    bool includeBillsInWaterfall,
    @JsonKey(name: 'include_installments_in_waterfall')
    @Default(true)
    bool includeInstallmentsInWaterfall,
    @JsonKey(name: 'include_debt_payments_in_waterfall')
    @Default(true)
    bool includeDebtPaymentsInWaterfall,
  }) = _HouseholdStrategy;

  factory HouseholdStrategy.fromJson(Map<String, dynamic> json) =>
      _$HouseholdStrategyFromJson(json);

  /// Estrategia por defecto (espejo de `HouseholdStrategy.default` en iOS):
  /// 10% ahorro, 0% inversión, distribución equitativa, todo incluido.
  factory HouseholdStrategy.standard() => HouseholdStrategy(
        savingsPct: Decimal.fromInt(10),
        investmentPct: Decimal.zero,
      );
}

/// Hogar (tenant). Espejo 1:1 de `public.households`.
/// `fxRates` mapea la columna JSONB `fx_rates` (no presente en el struct iOS
/// `Household`, pero leída por `FXService` desde la misma tabla).
@freezed
abstract class Household with _$Household {
  const factory Household({
    required String id,
    required String name,
    @JsonKey(name: 'created_by') required String createdBy,
    required String timezone,
    @JsonKey(name: 'default_currency') required String defaultCurrency,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    HouseholdStrategy? strategy,
    @JsonKey(name: 'fx_rates') Map<String, FXRate>? fxRates,
  }) = _Household;

  factory Household.fromJson(Map<String, dynamic> json) =>
      _$HouseholdFromJson(json);
}

/// Miembro del hogar. Espejo 1:1 de `public.household_members`.
@freezed
abstract class HouseholdMember with _$HouseholdMember {
  const factory HouseholdMember({
    @JsonKey(name: 'household_id') required String householdId,
    @JsonKey(name: 'user_id') required String userId,
    required MemberRole role,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    @JsonKey(name: 'invited_by') String? invitedBy,
  }) = _HouseholdMember;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      _$HouseholdMemberFromJson(json);
}

/// Invitación a unirse a un hogar. Espejo 1:1 de `public.household_invitations`.
@freezed
abstract class HouseholdInvitation with _$HouseholdInvitation {
  const factory HouseholdInvitation({
    required String id,
    @JsonKey(name: 'household_id') required String householdId,
    required String email,
    required MemberRole role,
    @JsonKey(name: 'invite_token') required String inviteToken,
    @JsonKey(name: 'invited_by') required String invitedBy,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'accepted_by') String? acceptedBy,
    required InvitationStatus status,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _HouseholdInvitation;

  factory HouseholdInvitation.fromJson(Map<String, dynamic> json) =>
      _$HouseholdInvitationFromJson(json);
}
