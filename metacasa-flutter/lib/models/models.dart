/// Barrel de la capa de modelos de datos de Home Finance (MetaCasa).
///
/// Reexporta todos los modelos `freezed`, sus enums y los converters de
/// `Decimal`. Importá `package:metacasa/models/models.dart` para tener acceso
/// a toda la capa de datos de una sola vez.
library;

// Converters / utils de dinero.
export '../core/utils/decimal_converter.dart';
export '../core/utils/money.dart';

// Modelos (+ enums embebidos).
export 'account.dart';
export 'bill.dart';
export 'budget.dart';
export 'categories_blob.dart';
export 'debt.dart';
export 'entitlement.dart';
export 'goal.dart';
export 'household.dart';
export 'installment.dart';
export 'recurring_transaction.dart';
export 'transaction.dart';
export 'transaction_template.dart';
