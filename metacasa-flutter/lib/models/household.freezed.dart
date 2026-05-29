// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'household.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FXRate {
  @DecimalConverter()
  Decimal get rate;

  /// ISO 8601 — cuándo el usuario actualizó el rate. String, como en iOS.
  @JsonKey(name: 'updated_at')
  String get updatedAt;

  /// "manual" por ahora; campo reservado para auto-fetch futuro.
  String get source;

  /// Create a copy of FXRate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FXRateCopyWith<FXRate> get copyWith =>
      _$FXRateCopyWithImpl<FXRate>(this as FXRate, _$identity);

  /// Serializes this FXRate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FXRate &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, rate, updatedAt, source);

  @override
  String toString() {
    return 'FXRate(rate: $rate, updatedAt: $updatedAt, source: $source)';
  }
}

/// @nodoc
abstract mixin class $FXRateCopyWith<$Res> {
  factory $FXRateCopyWith(FXRate value, $Res Function(FXRate) _then) =
      _$FXRateCopyWithImpl;
  @useResult
  $Res call(
      {@DecimalConverter() Decimal rate,
      @JsonKey(name: 'updated_at') String updatedAt,
      String source});
}

/// @nodoc
class _$FXRateCopyWithImpl<$Res> implements $FXRateCopyWith<$Res> {
  _$FXRateCopyWithImpl(this._self, this._then);

  final FXRate _self;
  final $Res Function(FXRate) _then;

  /// Create a copy of FXRate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rate = null,
    Object? updatedAt = null,
    Object? source = null,
  }) {
    return _then(_self.copyWith(
      rate: null == rate
          ? _self.rate
          : rate // ignore: cast_nullable_to_non_nullable
              as Decimal,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _FXRate implements FXRate {
  const _FXRate(
      {@DecimalConverter() required this.rate,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      required this.source});
  factory _FXRate.fromJson(Map<String, dynamic> json) => _$FXRateFromJson(json);

  @override
  @DecimalConverter()
  final Decimal rate;

  /// ISO 8601 — cuándo el usuario actualizó el rate. String, como en iOS.
  @override
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  /// "manual" por ahora; campo reservado para auto-fetch futuro.
  @override
  final String source;

  /// Create a copy of FXRate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FXRateCopyWith<_FXRate> get copyWith =>
      __$FXRateCopyWithImpl<_FXRate>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FXRateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FXRate &&
            (identical(other.rate, rate) || other.rate == rate) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.source, source) || other.source == source));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, rate, updatedAt, source);

  @override
  String toString() {
    return 'FXRate(rate: $rate, updatedAt: $updatedAt, source: $source)';
  }
}

/// @nodoc
abstract mixin class _$FXRateCopyWith<$Res> implements $FXRateCopyWith<$Res> {
  factory _$FXRateCopyWith(_FXRate value, $Res Function(_FXRate) _then) =
      __$FXRateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@DecimalConverter() Decimal rate,
      @JsonKey(name: 'updated_at') String updatedAt,
      String source});
}

/// @nodoc
class __$FXRateCopyWithImpl<$Res> implements _$FXRateCopyWith<$Res> {
  __$FXRateCopyWithImpl(this._self, this._then);

  final _FXRate _self;
  final $Res Function(_FXRate) _then;

  /// Create a copy of FXRate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rate = null,
    Object? updatedAt = null,
    Object? source = null,
  }) {
    return _then(_FXRate(
      rate: null == rate
          ? _self.rate
          : rate // ignore: cast_nullable_to_non_nullable
              as Decimal,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$HouseholdStrategy {
  /// Porcentaje del remanente que va automáticamente a ahorro (0-100).
  @JsonKey(name: 'savings_pct')
  @DecimalConverter()
  Decimal get savingsPct;

  /// Porcentaje del remanente que va a inversión (0-100).
  @JsonKey(name: 'investment_pct')
  @DecimalConverter()
  Decimal get investmentPct;

  /// Modo de distribución del remanente entre cuentas personales.
  @JsonKey(name: 'distribution_mode')
  DistributionMode get distributionMode;

  /// Allocations custom por cuenta (usado cuando mode == custom).
  @JsonKey(name: 'custom_allocations')
  @DecimalConverter()
  Map<String, Decimal> get customAllocations;

  /// Flags para incluir/excluir cada tipo de deducción del waterfall.
  @JsonKey(name: 'include_bills_in_waterfall')
  bool get includeBillsInWaterfall;
  @JsonKey(name: 'include_installments_in_waterfall')
  bool get includeInstallmentsInWaterfall;
  @JsonKey(name: 'include_debt_payments_in_waterfall')
  bool get includeDebtPaymentsInWaterfall;

  /// Create a copy of HouseholdStrategy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HouseholdStrategyCopyWith<HouseholdStrategy> get copyWith =>
      _$HouseholdStrategyCopyWithImpl<HouseholdStrategy>(
          this as HouseholdStrategy, _$identity);

  /// Serializes this HouseholdStrategy to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HouseholdStrategy &&
            (identical(other.savingsPct, savingsPct) ||
                other.savingsPct == savingsPct) &&
            (identical(other.investmentPct, investmentPct) ||
                other.investmentPct == investmentPct) &&
            (identical(other.distributionMode, distributionMode) ||
                other.distributionMode == distributionMode) &&
            const DeepCollectionEquality()
                .equals(other.customAllocations, customAllocations) &&
            (identical(
                    other.includeBillsInWaterfall, includeBillsInWaterfall) ||
                other.includeBillsInWaterfall == includeBillsInWaterfall) &&
            (identical(other.includeInstallmentsInWaterfall,
                    includeInstallmentsInWaterfall) ||
                other.includeInstallmentsInWaterfall ==
                    includeInstallmentsInWaterfall) &&
            (identical(other.includeDebtPaymentsInWaterfall,
                    includeDebtPaymentsInWaterfall) ||
                other.includeDebtPaymentsInWaterfall ==
                    includeDebtPaymentsInWaterfall));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      savingsPct,
      investmentPct,
      distributionMode,
      const DeepCollectionEquality().hash(customAllocations),
      includeBillsInWaterfall,
      includeInstallmentsInWaterfall,
      includeDebtPaymentsInWaterfall);

  @override
  String toString() {
    return 'HouseholdStrategy(savingsPct: $savingsPct, investmentPct: $investmentPct, distributionMode: $distributionMode, customAllocations: $customAllocations, includeBillsInWaterfall: $includeBillsInWaterfall, includeInstallmentsInWaterfall: $includeInstallmentsInWaterfall, includeDebtPaymentsInWaterfall: $includeDebtPaymentsInWaterfall)';
  }
}

/// @nodoc
abstract mixin class $HouseholdStrategyCopyWith<$Res> {
  factory $HouseholdStrategyCopyWith(
          HouseholdStrategy value, $Res Function(HouseholdStrategy) _then) =
      _$HouseholdStrategyCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'savings_pct') @DecimalConverter() Decimal savingsPct,
      @JsonKey(name: 'investment_pct')
      @DecimalConverter()
      Decimal investmentPct,
      @JsonKey(name: 'distribution_mode') DistributionMode distributionMode,
      @JsonKey(name: 'custom_allocations')
      @DecimalConverter()
      Map<String, Decimal> customAllocations,
      @JsonKey(name: 'include_bills_in_waterfall') bool includeBillsInWaterfall,
      @JsonKey(name: 'include_installments_in_waterfall')
      bool includeInstallmentsInWaterfall,
      @JsonKey(name: 'include_debt_payments_in_waterfall')
      bool includeDebtPaymentsInWaterfall});
}

/// @nodoc
class _$HouseholdStrategyCopyWithImpl<$Res>
    implements $HouseholdStrategyCopyWith<$Res> {
  _$HouseholdStrategyCopyWithImpl(this._self, this._then);

  final HouseholdStrategy _self;
  final $Res Function(HouseholdStrategy) _then;

  /// Create a copy of HouseholdStrategy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? savingsPct = null,
    Object? investmentPct = null,
    Object? distributionMode = null,
    Object? customAllocations = null,
    Object? includeBillsInWaterfall = null,
    Object? includeInstallmentsInWaterfall = null,
    Object? includeDebtPaymentsInWaterfall = null,
  }) {
    return _then(_self.copyWith(
      savingsPct: null == savingsPct
          ? _self.savingsPct
          : savingsPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      investmentPct: null == investmentPct
          ? _self.investmentPct
          : investmentPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      distributionMode: null == distributionMode
          ? _self.distributionMode
          : distributionMode // ignore: cast_nullable_to_non_nullable
              as DistributionMode,
      customAllocations: null == customAllocations
          ? _self.customAllocations
          : customAllocations // ignore: cast_nullable_to_non_nullable
              as Map<String, Decimal>,
      includeBillsInWaterfall: null == includeBillsInWaterfall
          ? _self.includeBillsInWaterfall
          : includeBillsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
      includeInstallmentsInWaterfall: null == includeInstallmentsInWaterfall
          ? _self.includeInstallmentsInWaterfall
          : includeInstallmentsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
      includeDebtPaymentsInWaterfall: null == includeDebtPaymentsInWaterfall
          ? _self.includeDebtPaymentsInWaterfall
          : includeDebtPaymentsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _HouseholdStrategy implements HouseholdStrategy {
  const _HouseholdStrategy(
      {@JsonKey(name: 'savings_pct')
      @DecimalConverter()
      required this.savingsPct,
      @JsonKey(name: 'investment_pct')
      @DecimalConverter()
      required this.investmentPct,
      @JsonKey(name: 'distribution_mode')
      this.distributionMode = DistributionMode.equal,
      @JsonKey(name: 'custom_allocations')
      @DecimalConverter()
      final Map<String, Decimal> customAllocations = const <String, Decimal>{},
      @JsonKey(name: 'include_bills_in_waterfall')
      this.includeBillsInWaterfall = true,
      @JsonKey(name: 'include_installments_in_waterfall')
      this.includeInstallmentsInWaterfall = true,
      @JsonKey(name: 'include_debt_payments_in_waterfall')
      this.includeDebtPaymentsInWaterfall = true})
      : _customAllocations = customAllocations;
  factory _HouseholdStrategy.fromJson(Map<String, dynamic> json) =>
      _$HouseholdStrategyFromJson(json);

  /// Porcentaje del remanente que va automáticamente a ahorro (0-100).
  @override
  @JsonKey(name: 'savings_pct')
  @DecimalConverter()
  final Decimal savingsPct;

  /// Porcentaje del remanente que va a inversión (0-100).
  @override
  @JsonKey(name: 'investment_pct')
  @DecimalConverter()
  final Decimal investmentPct;

  /// Modo de distribución del remanente entre cuentas personales.
  @override
  @JsonKey(name: 'distribution_mode')
  final DistributionMode distributionMode;

  /// Allocations custom por cuenta (usado cuando mode == custom).
  final Map<String, Decimal> _customAllocations;

  /// Allocations custom por cuenta (usado cuando mode == custom).
  @override
  @JsonKey(name: 'custom_allocations')
  @DecimalConverter()
  Map<String, Decimal> get customAllocations {
    if (_customAllocations is EqualUnmodifiableMapView)
      return _customAllocations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_customAllocations);
  }

  /// Flags para incluir/excluir cada tipo de deducción del waterfall.
  @override
  @JsonKey(name: 'include_bills_in_waterfall')
  final bool includeBillsInWaterfall;
  @override
  @JsonKey(name: 'include_installments_in_waterfall')
  final bool includeInstallmentsInWaterfall;
  @override
  @JsonKey(name: 'include_debt_payments_in_waterfall')
  final bool includeDebtPaymentsInWaterfall;

  /// Create a copy of HouseholdStrategy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HouseholdStrategyCopyWith<_HouseholdStrategy> get copyWith =>
      __$HouseholdStrategyCopyWithImpl<_HouseholdStrategy>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HouseholdStrategyToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HouseholdStrategy &&
            (identical(other.savingsPct, savingsPct) ||
                other.savingsPct == savingsPct) &&
            (identical(other.investmentPct, investmentPct) ||
                other.investmentPct == investmentPct) &&
            (identical(other.distributionMode, distributionMode) ||
                other.distributionMode == distributionMode) &&
            const DeepCollectionEquality()
                .equals(other._customAllocations, _customAllocations) &&
            (identical(
                    other.includeBillsInWaterfall, includeBillsInWaterfall) ||
                other.includeBillsInWaterfall == includeBillsInWaterfall) &&
            (identical(other.includeInstallmentsInWaterfall,
                    includeInstallmentsInWaterfall) ||
                other.includeInstallmentsInWaterfall ==
                    includeInstallmentsInWaterfall) &&
            (identical(other.includeDebtPaymentsInWaterfall,
                    includeDebtPaymentsInWaterfall) ||
                other.includeDebtPaymentsInWaterfall ==
                    includeDebtPaymentsInWaterfall));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      savingsPct,
      investmentPct,
      distributionMode,
      const DeepCollectionEquality().hash(_customAllocations),
      includeBillsInWaterfall,
      includeInstallmentsInWaterfall,
      includeDebtPaymentsInWaterfall);

  @override
  String toString() {
    return 'HouseholdStrategy(savingsPct: $savingsPct, investmentPct: $investmentPct, distributionMode: $distributionMode, customAllocations: $customAllocations, includeBillsInWaterfall: $includeBillsInWaterfall, includeInstallmentsInWaterfall: $includeInstallmentsInWaterfall, includeDebtPaymentsInWaterfall: $includeDebtPaymentsInWaterfall)';
  }
}

/// @nodoc
abstract mixin class _$HouseholdStrategyCopyWith<$Res>
    implements $HouseholdStrategyCopyWith<$Res> {
  factory _$HouseholdStrategyCopyWith(
          _HouseholdStrategy value, $Res Function(_HouseholdStrategy) _then) =
      __$HouseholdStrategyCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'savings_pct') @DecimalConverter() Decimal savingsPct,
      @JsonKey(name: 'investment_pct')
      @DecimalConverter()
      Decimal investmentPct,
      @JsonKey(name: 'distribution_mode') DistributionMode distributionMode,
      @JsonKey(name: 'custom_allocations')
      @DecimalConverter()
      Map<String, Decimal> customAllocations,
      @JsonKey(name: 'include_bills_in_waterfall') bool includeBillsInWaterfall,
      @JsonKey(name: 'include_installments_in_waterfall')
      bool includeInstallmentsInWaterfall,
      @JsonKey(name: 'include_debt_payments_in_waterfall')
      bool includeDebtPaymentsInWaterfall});
}

/// @nodoc
class __$HouseholdStrategyCopyWithImpl<$Res>
    implements _$HouseholdStrategyCopyWith<$Res> {
  __$HouseholdStrategyCopyWithImpl(this._self, this._then);

  final _HouseholdStrategy _self;
  final $Res Function(_HouseholdStrategy) _then;

  /// Create a copy of HouseholdStrategy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? savingsPct = null,
    Object? investmentPct = null,
    Object? distributionMode = null,
    Object? customAllocations = null,
    Object? includeBillsInWaterfall = null,
    Object? includeInstallmentsInWaterfall = null,
    Object? includeDebtPaymentsInWaterfall = null,
  }) {
    return _then(_HouseholdStrategy(
      savingsPct: null == savingsPct
          ? _self.savingsPct
          : savingsPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      investmentPct: null == investmentPct
          ? _self.investmentPct
          : investmentPct // ignore: cast_nullable_to_non_nullable
              as Decimal,
      distributionMode: null == distributionMode
          ? _self.distributionMode
          : distributionMode // ignore: cast_nullable_to_non_nullable
              as DistributionMode,
      customAllocations: null == customAllocations
          ? _self._customAllocations
          : customAllocations // ignore: cast_nullable_to_non_nullable
              as Map<String, Decimal>,
      includeBillsInWaterfall: null == includeBillsInWaterfall
          ? _self.includeBillsInWaterfall
          : includeBillsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
      includeInstallmentsInWaterfall: null == includeInstallmentsInWaterfall
          ? _self.includeInstallmentsInWaterfall
          : includeInstallmentsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
      includeDebtPaymentsInWaterfall: null == includeDebtPaymentsInWaterfall
          ? _self.includeDebtPaymentsInWaterfall
          : includeDebtPaymentsInWaterfall // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$Household {
  String get id;
  String get name;
  @JsonKey(name: 'created_by')
  String get createdBy;
  String get timezone;
  @JsonKey(name: 'default_currency')
  String get defaultCurrency;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  HouseholdStrategy? get strategy;
  @JsonKey(name: 'fx_rates')
  Map<String, FXRate>? get fxRates;

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HouseholdCopyWith<Household> get copyWith =>
      _$HouseholdCopyWithImpl<Household>(this as Household, _$identity);

  /// Serializes this Household to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Household &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.defaultCurrency, defaultCurrency) ||
                other.defaultCurrency == defaultCurrency) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.strategy, strategy) ||
                other.strategy == strategy) &&
            const DeepCollectionEquality().equals(other.fxRates, fxRates));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      createdBy,
      timezone,
      defaultCurrency,
      createdAt,
      updatedAt,
      strategy,
      const DeepCollectionEquality().hash(fxRates));

  @override
  String toString() {
    return 'Household(id: $id, name: $name, createdBy: $createdBy, timezone: $timezone, defaultCurrency: $defaultCurrency, createdAt: $createdAt, updatedAt: $updatedAt, strategy: $strategy, fxRates: $fxRates)';
  }
}

/// @nodoc
abstract mixin class $HouseholdCopyWith<$Res> {
  factory $HouseholdCopyWith(Household value, $Res Function(Household) _then) =
      _$HouseholdCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'created_by') String createdBy,
      String timezone,
      @JsonKey(name: 'default_currency') String defaultCurrency,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      HouseholdStrategy? strategy,
      @JsonKey(name: 'fx_rates') Map<String, FXRate>? fxRates});

  $HouseholdStrategyCopyWith<$Res>? get strategy;
}

/// @nodoc
class _$HouseholdCopyWithImpl<$Res> implements $HouseholdCopyWith<$Res> {
  _$HouseholdCopyWithImpl(this._self, this._then);

  final Household _self;
  final $Res Function(Household) _then;

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdBy = null,
    Object? timezone = null,
    Object? defaultCurrency = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? strategy = freezed,
    Object? fxRates = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      defaultCurrency: null == defaultCurrency
          ? _self.defaultCurrency
          : defaultCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      strategy: freezed == strategy
          ? _self.strategy
          : strategy // ignore: cast_nullable_to_non_nullable
              as HouseholdStrategy?,
      fxRates: freezed == fxRates
          ? _self.fxRates
          : fxRates // ignore: cast_nullable_to_non_nullable
              as Map<String, FXRate>?,
    ));
  }

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HouseholdStrategyCopyWith<$Res>? get strategy {
    if (_self.strategy == null) {
      return null;
    }

    return $HouseholdStrategyCopyWith<$Res>(_self.strategy!, (value) {
      return _then(_self.copyWith(strategy: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _Household implements Household {
  const _Household(
      {required this.id,
      required this.name,
      @JsonKey(name: 'created_by') required this.createdBy,
      required this.timezone,
      @JsonKey(name: 'default_currency') required this.defaultCurrency,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      this.strategy,
      @JsonKey(name: 'fx_rates') final Map<String, FXRate>? fxRates})
      : _fxRates = fxRates;
  factory _Household.fromJson(Map<String, dynamic> json) =>
      _$HouseholdFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  final String timezone;
  @override
  @JsonKey(name: 'default_currency')
  final String defaultCurrency;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  final HouseholdStrategy? strategy;
  final Map<String, FXRate>? _fxRates;
  @override
  @JsonKey(name: 'fx_rates')
  Map<String, FXRate>? get fxRates {
    final value = _fxRates;
    if (value == null) return null;
    if (_fxRates is EqualUnmodifiableMapView) return _fxRates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HouseholdCopyWith<_Household> get copyWith =>
      __$HouseholdCopyWithImpl<_Household>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HouseholdToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Household &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.defaultCurrency, defaultCurrency) ||
                other.defaultCurrency == defaultCurrency) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.strategy, strategy) ||
                other.strategy == strategy) &&
            const DeepCollectionEquality().equals(other._fxRates, _fxRates));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      createdBy,
      timezone,
      defaultCurrency,
      createdAt,
      updatedAt,
      strategy,
      const DeepCollectionEquality().hash(_fxRates));

  @override
  String toString() {
    return 'Household(id: $id, name: $name, createdBy: $createdBy, timezone: $timezone, defaultCurrency: $defaultCurrency, createdAt: $createdAt, updatedAt: $updatedAt, strategy: $strategy, fxRates: $fxRates)';
  }
}

/// @nodoc
abstract mixin class _$HouseholdCopyWith<$Res>
    implements $HouseholdCopyWith<$Res> {
  factory _$HouseholdCopyWith(
          _Household value, $Res Function(_Household) _then) =
      __$HouseholdCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'created_by') String createdBy,
      String timezone,
      @JsonKey(name: 'default_currency') String defaultCurrency,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      HouseholdStrategy? strategy,
      @JsonKey(name: 'fx_rates') Map<String, FXRate>? fxRates});

  @override
  $HouseholdStrategyCopyWith<$Res>? get strategy;
}

/// @nodoc
class __$HouseholdCopyWithImpl<$Res> implements _$HouseholdCopyWith<$Res> {
  __$HouseholdCopyWithImpl(this._self, this._then);

  final _Household _self;
  final $Res Function(_Household) _then;

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdBy = null,
    Object? timezone = null,
    Object? defaultCurrency = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? strategy = freezed,
    Object? fxRates = freezed,
  }) {
    return _then(_Household(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      createdBy: null == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      defaultCurrency: null == defaultCurrency
          ? _self.defaultCurrency
          : defaultCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      strategy: freezed == strategy
          ? _self.strategy
          : strategy // ignore: cast_nullable_to_non_nullable
              as HouseholdStrategy?,
      fxRates: freezed == fxRates
          ? _self._fxRates
          : fxRates // ignore: cast_nullable_to_non_nullable
              as Map<String, FXRate>?,
    ));
  }

  /// Create a copy of Household
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $HouseholdStrategyCopyWith<$Res>? get strategy {
    if (_self.strategy == null) {
      return null;
    }

    return $HouseholdStrategyCopyWith<$Res>(_self.strategy!, (value) {
      return _then(_self.copyWith(strategy: value));
    });
  }
}

/// @nodoc
mixin _$HouseholdMember {
  @JsonKey(name: 'household_id')
  String get householdId;
  @JsonKey(name: 'user_id')
  String get userId;
  MemberRole get role;
  @JsonKey(name: 'display_name')
  String? get displayName;
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt;
  @JsonKey(name: 'invited_by')
  String? get invitedBy;

  /// Create a copy of HouseholdMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HouseholdMemberCopyWith<HouseholdMember> get copyWith =>
      _$HouseholdMemberCopyWithImpl<HouseholdMember>(
          this as HouseholdMember, _$identity);

  /// Serializes this HouseholdMember to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HouseholdMember &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, householdId, userId, role, displayName, joinedAt, invitedBy);

  @override
  String toString() {
    return 'HouseholdMember(householdId: $householdId, userId: $userId, role: $role, displayName: $displayName, joinedAt: $joinedAt, invitedBy: $invitedBy)';
  }
}

/// @nodoc
abstract mixin class $HouseholdMemberCopyWith<$Res> {
  factory $HouseholdMemberCopyWith(
          HouseholdMember value, $Res Function(HouseholdMember) _then) =
      _$HouseholdMemberCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      MemberRole role,
      @JsonKey(name: 'display_name') String? displayName,
      @JsonKey(name: 'joined_at') DateTime joinedAt,
      @JsonKey(name: 'invited_by') String? invitedBy});
}

/// @nodoc
class _$HouseholdMemberCopyWithImpl<$Res>
    implements $HouseholdMemberCopyWith<$Res> {
  _$HouseholdMemberCopyWithImpl(this._self, this._then);

  final HouseholdMember _self;
  final $Res Function(HouseholdMember) _then;

  /// Create a copy of HouseholdMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? householdId = null,
    Object? userId = null,
    Object? role = null,
    Object? displayName = freezed,
    Object? joinedAt = null,
    Object? invitedBy = freezed,
  }) {
    return _then(_self.copyWith(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MemberRole,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      joinedAt: null == joinedAt
          ? _self.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      invitedBy: freezed == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _HouseholdMember implements HouseholdMember {
  const _HouseholdMember(
      {@JsonKey(name: 'household_id') required this.householdId,
      @JsonKey(name: 'user_id') required this.userId,
      required this.role,
      @JsonKey(name: 'display_name') this.displayName,
      @JsonKey(name: 'joined_at') required this.joinedAt,
      @JsonKey(name: 'invited_by') this.invitedBy});
  factory _HouseholdMember.fromJson(Map<String, dynamic> json) =>
      _$HouseholdMemberFromJson(json);

  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final MemberRole role;
  @override
  @JsonKey(name: 'display_name')
  final String? displayName;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @override
  @JsonKey(name: 'invited_by')
  final String? invitedBy;

  /// Create a copy of HouseholdMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HouseholdMemberCopyWith<_HouseholdMember> get copyWith =>
      __$HouseholdMemberCopyWithImpl<_HouseholdMember>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HouseholdMemberToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HouseholdMember &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, householdId, userId, role, displayName, joinedAt, invitedBy);

  @override
  String toString() {
    return 'HouseholdMember(householdId: $householdId, userId: $userId, role: $role, displayName: $displayName, joinedAt: $joinedAt, invitedBy: $invitedBy)';
  }
}

/// @nodoc
abstract mixin class _$HouseholdMemberCopyWith<$Res>
    implements $HouseholdMemberCopyWith<$Res> {
  factory _$HouseholdMemberCopyWith(
          _HouseholdMember value, $Res Function(_HouseholdMember) _then) =
      __$HouseholdMemberCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'household_id') String householdId,
      @JsonKey(name: 'user_id') String userId,
      MemberRole role,
      @JsonKey(name: 'display_name') String? displayName,
      @JsonKey(name: 'joined_at') DateTime joinedAt,
      @JsonKey(name: 'invited_by') String? invitedBy});
}

/// @nodoc
class __$HouseholdMemberCopyWithImpl<$Res>
    implements _$HouseholdMemberCopyWith<$Res> {
  __$HouseholdMemberCopyWithImpl(this._self, this._then);

  final _HouseholdMember _self;
  final $Res Function(_HouseholdMember) _then;

  /// Create a copy of HouseholdMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? householdId = null,
    Object? userId = null,
    Object? role = null,
    Object? displayName = freezed,
    Object? joinedAt = null,
    Object? invitedBy = freezed,
  }) {
    return _then(_HouseholdMember(
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MemberRole,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      joinedAt: null == joinedAt
          ? _self.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      invitedBy: freezed == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$HouseholdInvitation {
  String get id;
  @JsonKey(name: 'household_id')
  String get householdId;
  String get email;
  MemberRole get role;
  @JsonKey(name: 'invite_token')
  String get inviteToken;
  @JsonKey(name: 'invited_by')
  String get invitedBy;
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt;
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt;
  @JsonKey(name: 'accepted_by')
  String? get acceptedBy;
  InvitationStatus get status;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of HouseholdInvitation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HouseholdInvitationCopyWith<HouseholdInvitation> get copyWith =>
      _$HouseholdInvitationCopyWithImpl<HouseholdInvitation>(
          this as HouseholdInvitation, _$identity);

  /// Serializes this HouseholdInvitation to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HouseholdInvitation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.inviteToken, inviteToken) ||
                other.inviteToken == inviteToken) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.acceptedBy, acceptedBy) ||
                other.acceptedBy == acceptedBy) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      email,
      role,
      inviteToken,
      invitedBy,
      expiresAt,
      acceptedAt,
      acceptedBy,
      status,
      createdAt);

  @override
  String toString() {
    return 'HouseholdInvitation(id: $id, householdId: $householdId, email: $email, role: $role, inviteToken: $inviteToken, invitedBy: $invitedBy, expiresAt: $expiresAt, acceptedAt: $acceptedAt, acceptedBy: $acceptedBy, status: $status, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $HouseholdInvitationCopyWith<$Res> {
  factory $HouseholdInvitationCopyWith(
          HouseholdInvitation value, $Res Function(HouseholdInvitation) _then) =
      _$HouseholdInvitationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String email,
      MemberRole role,
      @JsonKey(name: 'invite_token') String inviteToken,
      @JsonKey(name: 'invited_by') String invitedBy,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
      @JsonKey(name: 'accepted_by') String? acceptedBy,
      InvitationStatus status,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class _$HouseholdInvitationCopyWithImpl<$Res>
    implements $HouseholdInvitationCopyWith<$Res> {
  _$HouseholdInvitationCopyWithImpl(this._self, this._then);

  final HouseholdInvitation _self;
  final $Res Function(HouseholdInvitation) _then;

  /// Create a copy of HouseholdInvitation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? email = null,
    Object? role = null,
    Object? inviteToken = null,
    Object? invitedBy = null,
    Object? expiresAt = null,
    Object? acceptedAt = freezed,
    Object? acceptedBy = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MemberRole,
      inviteToken: null == inviteToken
          ? _self.inviteToken
          : inviteToken // ignore: cast_nullable_to_non_nullable
              as String,
      invitedBy: null == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _self.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedBy: freezed == acceptedBy
          ? _self.acceptedBy
          : acceptedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as InvitationStatus,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _HouseholdInvitation implements HouseholdInvitation {
  const _HouseholdInvitation(
      {required this.id,
      @JsonKey(name: 'household_id') required this.householdId,
      required this.email,
      required this.role,
      @JsonKey(name: 'invite_token') required this.inviteToken,
      @JsonKey(name: 'invited_by') required this.invitedBy,
      @JsonKey(name: 'expires_at') required this.expiresAt,
      @JsonKey(name: 'accepted_at') this.acceptedAt,
      @JsonKey(name: 'accepted_by') this.acceptedBy,
      required this.status,
      @JsonKey(name: 'created_at') required this.createdAt});
  factory _HouseholdInvitation.fromJson(Map<String, dynamic> json) =>
      _$HouseholdInvitationFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'household_id')
  final String householdId;
  @override
  final String email;
  @override
  final MemberRole role;
  @override
  @JsonKey(name: 'invite_token')
  final String inviteToken;
  @override
  @JsonKey(name: 'invited_by')
  final String invitedBy;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @override
  @JsonKey(name: 'accepted_at')
  final DateTime? acceptedAt;
  @override
  @JsonKey(name: 'accepted_by')
  final String? acceptedBy;
  @override
  final InvitationStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Create a copy of HouseholdInvitation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HouseholdInvitationCopyWith<_HouseholdInvitation> get copyWith =>
      __$HouseholdInvitationCopyWithImpl<_HouseholdInvitation>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HouseholdInvitationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HouseholdInvitation &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.householdId, householdId) ||
                other.householdId == householdId) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.inviteToken, inviteToken) ||
                other.inviteToken == inviteToken) &&
            (identical(other.invitedBy, invitedBy) ||
                other.invitedBy == invitedBy) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.acceptedBy, acceptedBy) ||
                other.acceptedBy == acceptedBy) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      householdId,
      email,
      role,
      inviteToken,
      invitedBy,
      expiresAt,
      acceptedAt,
      acceptedBy,
      status,
      createdAt);

  @override
  String toString() {
    return 'HouseholdInvitation(id: $id, householdId: $householdId, email: $email, role: $role, inviteToken: $inviteToken, invitedBy: $invitedBy, expiresAt: $expiresAt, acceptedAt: $acceptedAt, acceptedBy: $acceptedBy, status: $status, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$HouseholdInvitationCopyWith<$Res>
    implements $HouseholdInvitationCopyWith<$Res> {
  factory _$HouseholdInvitationCopyWith(_HouseholdInvitation value,
          $Res Function(_HouseholdInvitation) _then) =
      __$HouseholdInvitationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'household_id') String householdId,
      String email,
      MemberRole role,
      @JsonKey(name: 'invite_token') String inviteToken,
      @JsonKey(name: 'invited_by') String invitedBy,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
      @JsonKey(name: 'accepted_by') String? acceptedBy,
      InvitationStatus status,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class __$HouseholdInvitationCopyWithImpl<$Res>
    implements _$HouseholdInvitationCopyWith<$Res> {
  __$HouseholdInvitationCopyWithImpl(this._self, this._then);

  final _HouseholdInvitation _self;
  final $Res Function(_HouseholdInvitation) _then;

  /// Create a copy of HouseholdInvitation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? householdId = null,
    Object? email = null,
    Object? role = null,
    Object? inviteToken = null,
    Object? invitedBy = null,
    Object? expiresAt = null,
    Object? acceptedAt = freezed,
    Object? acceptedBy = freezed,
    Object? status = null,
    Object? createdAt = null,
  }) {
    return _then(_HouseholdInvitation(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      householdId: null == householdId
          ? _self.householdId
          : householdId // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MemberRole,
      inviteToken: null == inviteToken
          ? _self.inviteToken
          : inviteToken // ignore: cast_nullable_to_non_nullable
              as String,
      invitedBy: null == invitedBy
          ? _self.invitedBy
          : invitedBy // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _self.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedBy: freezed == acceptedBy
          ? _self.acceptedBy
          : acceptedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as InvitationStatus,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
