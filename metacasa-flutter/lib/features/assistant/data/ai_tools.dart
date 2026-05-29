import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/balance_calculator.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/bill_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../domain/ai_money_format.dart';

export 'ai_tool_schemas.dart';

/// Ejecutor de las tools del asistente contra los repos.
///
/// Port de `AIToolHandler.swift` + `AnthropicToolDispatcher.swift` de iOS. Cada
/// tool devuelve un **String** con los montos prefijados por código ISO (ej.
/// "ARS 6,000") — convención que el system prompt le explica al modelo. Las
/// mutaciones devuelven un confirmation string con la convención de emoji
/// (`✅`/`⚠️`/`❌`) que la UI usa para clasificar la burbuja.
///
/// Diferencias con iOS por API de los repos Flutter:
/// - No hay `fetchOne(id:)` ni `update(tx)` por mutación directa de un struct
///   editable: para update/delete por id (y mark_bill_paid) resolvemos el row
///   completo trayendo una ventana amplia y casando por UUID completo o por el
///   prefijo de 8 chars (que es lo que `query_transactions` expone al modelo).
class FinanceToolExecutor {
  FinanceToolExecutor({
    required this.ref,
    required this.householdId,
    required this.userId,
    required this.currency,
  });

  final Ref ref;
  final String householdId;
  final String userId;
  final String currency;

  TransactionRepository get _txRepo => ref.read(transactionRepositoryProvider);
  AccountRepository get _accountRepo => ref.read(accountRepositoryProvider);
  GoalRepository get _goalRepo => ref.read(goalRepositoryProvider);
  BillRepository get _billRepo => ref.read(billRepositoryProvider);
  DebtRepository get _debtRepo => ref.read(debtRepositoryProvider);
  BudgetRepository get _budgetRepo => ref.read(budgetRepositoryProvider);

  /// Despacha una tool por nombre. Espejo de `AnthropicToolDispatcher.dispatch`.
  /// Nunca lanza: ante error devuelve un string "Error executing tool: …" (el
  /// loop lo re-inyecta como tool_result, igual que iOS).
  Future<String> execute(String name, Map<String, dynamic> input) async {
    try {
      switch (name) {
        case 'query_transactions':
          return _queryTransactions(input);
        case 'add_transaction':
          return _addTransaction(input);
        case 'update_transaction':
          return _updateTransaction(input);
        case 'delete_transaction':
          return _deleteTransaction(input);
        case 'get_financial_summary':
          return _getFinancialSummary(input);
        case 'get_budget_status':
          return _getBudgetStatus(input);
        case 'get_net_worth':
          return _getNetWorth();
        case 'get_financial_health_score':
          return _getHealthScore();
        case 'project_scenario':
          return _projectScenario(input);
        case 'detect_spending_patterns':
          return _detectSpendingPatterns(input);
        case 'suggest_savings_opportunities':
          return _suggestSavings(input);
        case 'get_goals':
          return _getGoals(input);
        case 'get_accounts':
          return _getAccounts(input);
        case 'get_bills':
          return _getBills(input);
        case 'analyze_inflation_impact':
          return _analyzeInflation(input);
        case 'mark_bill_paid':
          return _markBillPaid(input);
        case 'compare_periods':
          return _comparePeriods(input);
        case 'set_budget_envelope':
          return _setBudgetEnvelope(input);
        case 'transfer_between_accounts':
          return _transferBetweenAccounts(input);
        case 'categorize_transaction':
          return _categorizeTransaction(input);
        case 'validate_cfdi':
          return _validateCFDI(input);
        case 'validate_arca':
          return _validateARCA(input);
        default:
          return "Error: unknown tool '$name'";
      }
    } catch (e) {
      return 'Error executing tool: $e';
    }
  }

  // MARK: - Formatting helpers

  String _fmt(Decimal amount, [String? cur]) =>
      AiMoney.iso(amount, cur ?? currency);

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    // yyyy-MM-dd (lo que piden los schemas).
    return DateTime.tryParse(s.length == 10 ? '${s}T00:00:00' : s);
  }

  /// Rango [start, end] de un mes "yyyy-MM" (o el mes actual si null/ inválido).
  ({DateTime start, DateTime end}) _monthRange(String? monthStr) {
    final DateTime now = DateTime.now();
    if (monthStr != null && monthStr.length >= 7) {
      final int? y = int.tryParse(monthStr.substring(0, 4));
      final int? m = int.tryParse(monthStr.substring(5, 7));
      if (y != null && m != null && m >= 1 && m <= 12) {
        return (
          start: DateTime(y, m, 1),
          end: DateTime(y, m + 1, 0, 23, 59, 59),
        );
      }
    }
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  // MARK: - input coercion helpers

  String? _s(Map<String, dynamic> i, String k) {
    final dynamic v = i[k];
    if (v == null) return null;
    final String s = v.toString();
    return s.isEmpty ? null : s;
  }

  double? _d(Map<String, dynamic> i, String k) {
    final dynamic v = i[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _i(Map<String, dynamic> i, String k) {
    final dynamic v = i[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool? _b(Map<String, dynamic> i, String k) {
    final dynamic v = i[k];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return null;
  }

  /// Decimal exacto a partir de un double de entrada (vía string, evita el
  /// epsilon binario de `Decimal.parse(d.toString())`).
  Decimal _dec(double v) => Decimal.parse(v.toString());

  // MARK: - 1. Query Transactions

  Future<String> _queryTransactions(Map<String, dynamic> i) async {
    final DateTime from = _parseDate(_s(i, 'dateFrom')) ??
        DateTime.now().subtract(const Duration(days: 31));
    final DateTime to = _parseDate(_s(i, 'dateTo')) ?? DateTime.now();
    final int limit = (_i(i, 'limit') ?? 20).clamp(1, 50);

    var txs = await _txRepo.fetchRange(
        householdId: householdId, from: from, to: to, limit: 5000);

    final String? cat = _s(i, 'category');
    if (cat != null) {
      final String lc = cat.toLowerCase();
      txs = txs.where((t) => t.category.toLowerCase().contains(lc)).toList();
    }
    final String? type = _s(i, 'type');
    if (type != null) {
      final TxType tt =
          type.toUpperCase() == 'INGRESO' ? TxType.ingreso : TxType.gasto;
      txs = txs.where((t) => t.type == tt).toList();
    }
    final String? note = _s(i, 'noteContains');
    if (note != null) {
      final String lc = note.toLowerCase();
      txs =
          txs.where((t) => (t.note ?? '').toLowerCase().contains(lc)).toList();
    }
    final double? min = _d(i, 'amountMin');
    if (min != null) {
      txs = txs.where((t) => t.amount.toDouble() >= min).toList();
    }
    final double? max = _d(i, 'amountMax');
    if (max != null) {
      txs = txs.where((t) => t.amount.toDouble() <= max).toList();
    }

    final Decimal total =
        txs.fold(Decimal.zero, (Decimal acc, t) => acc + t.amount);
    final List<Transaction> display = txs.take(limit).toList();

    final List<String> lines = <String>[
      'Found ${txs.length} transactions. Total: ${_fmt(total)}.',
    ];
    if (txs.length > limit) lines.add('Showing first $limit:');
    lines.add('');
    for (final Transaction t in display) {
      final String sign = t.type == TxType.gasto ? '-' : '+';
      final String n =
          (t.note != null && t.note!.isNotEmpty) ? ' (${t.note})' : '';
      final String idShort = t.id.length >= 8 ? t.id.substring(0, 8) : t.id;
      lines.add(
          '• ${_fmtDate(t.date)}: $sign${_fmt(t.amount)} ${t.category}$n [id:$idShort]');
    }
    return lines.join('\n');
  }

  // MARK: - 2. Add Transaction

  Future<String> _addTransaction(Map<String, dynamic> i) async {
    final String? type = _s(i, 'type');
    final double? amountD = _d(i, 'amount');
    final String? categoryRaw = _s(i, 'category');
    if (type == null || amountD == null || categoryRaw == null) {
      return 'Error: missing required field (type, amount, or category)';
    }
    final TxType txType =
        type.toUpperCase() == 'INGRESO' ? TxType.ingreso : TxType.gasto;
    final DateTime date = _parseDate(_s(i, 'date')) ?? DateTime.now();
    final Decimal amount = _dec(amountD);
    final String category = _resolveCategory(categoryRaw);

    final NewTransactionInput input = NewTransactionInput(
      householdId: householdId,
      userId: userId,
      type: txType,
      amount: amount,
      currencyOriginal: currency,
      category: category,
      subcategory: _s(i, 'subcategory'),
      note: _s(i, 'note'),
      date: date,
    );
    final Transaction created = await _txRepo.insert(input);
    final String label = txType == TxType.gasto ? 'expense' : 'income';
    final String idShort =
        created.id.length >= 8 ? created.id.substring(0, 8) : created.id;
    return 'Transaction created: $label of ${_fmt(amount)} in $category on ${_fmtDate(date)}. ID: $idShort.';
  }

  // MARK: - 3. Update Transaction

  Future<String> _updateTransaction(Map<String, dynamic> i) async {
    final String? rawId = _s(i, 'transactionId');
    if (rawId == null) return 'Error: transactionId required';
    final Transaction? tx = await _resolveTransaction(rawId);
    if (tx == null) return 'Error: transaction not found.';

    final double? a = _d(i, 'amount');
    final String? c = _s(i, 'category');
    final String? sub = _s(i, 'subcategory');
    final String? n = _s(i, 'note');
    final DateTime? d = _parseDate(_s(i, 'date'));
    final String? type = _s(i, 'type');

    final Transaction updatedInput = tx.copyWith(
      amount: a != null ? _dec(a) : tx.amount,
      category: c != null ? _resolveCategory(c) : tx.category,
      subcategory: sub ?? tx.subcategory,
      note: n ?? tx.note,
      date: d ?? tx.date,
      type: type != null
          ? (type.toUpperCase() == 'INGRESO' ? TxType.ingreso : TxType.gasto)
          : tx.type,
    );
    final Transaction updated = await _txRepo.update(updatedInput);
    return 'Transaction updated: ${_fmt(updated.amount)} in ${updated.category} on ${_fmtDate(updated.date)}.';
  }

  // MARK: - 4. Delete Transaction

  Future<String> _deleteTransaction(Map<String, dynamic> i) async {
    final String? rawId = _s(i, 'transactionId');
    if (rawId == null) return 'Error: transactionId required';
    final Transaction? tx = await _resolveTransaction(rawId);
    if (tx == null) return 'Error: transaction not found.';
    await _txRepo.delete(tx.id);
    return 'Transaction deleted.';
  }

  // MARK: - 5. Financial Summary

  Future<String> _getFinancialSummary(Map<String, dynamic> i) async {
    final ({DateTime start, DateTime end}) range = _monthRange(_s(i, 'month'));
    final List<Transaction> txs = await _txRepo.fetchRange(
        householdId: householdId,
        from: range.start,
        to: range.end,
        limit: 5000);
    final TransactionTotals totals = _txRepo.totalsOf(txs);
    final Decimal balance = totals.balance;
    final int savingsRate = totals.ingresos > Decimal.zero
        ? (balance.toDouble() / totals.ingresos.toDouble() * 100).round()
        : 0;

    final List<String> lines = <String>[
      'Financial Summary:',
      '• Income: ${_fmt(totals.ingresos)}',
      '• Expenses: ${_fmt(totals.gastos)}',
      '• Balance: ${_fmt(balance)}',
      '• Savings rate: $savingsRate%',
    ];

    if (_b(i, 'includeComparison') == true) {
      final DateTime prevStart =
          DateTime(range.start.year, range.start.month - 1, 1);
      final DateTime prevEnd =
          DateTime(range.start.year, range.start.month, 0, 23, 59, 59);
      final TransactionTotals prev = await _txRepo.totals(
          householdId: householdId, from: prevStart, to: prevEnd);
      final Decimal dE = totals.gastos - prev.gastos;
      final Decimal dI = totals.ingresos - prev.ingresos;
      lines
        ..add('')
        ..add('vs Previous month:')
        ..add('• Income change: ${dI >= Decimal.zero ? '+' : ''}${_fmt(dI)}')
        ..add('• Expense change: ${dE >= Decimal.zero ? '+' : ''}${_fmt(dE)}');
    }

    final Map<String, Decimal> byCat = _expensesByCategory(txs);
    final List<MapEntry<String, Decimal>> sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isNotEmpty) {
      lines
        ..add('')
        ..add('Top categories:');
      for (int idx = 0; idx < sorted.length && idx < 7; idx++) {
        final MapEntry<String, Decimal> e = sorted[idx];
        final int pct = totals.gastos > Decimal.zero
            ? (e.value.toDouble() / totals.gastos.toDouble() * 100).round()
            : 0;
        lines.add('  ${idx + 1}. ${e.key}: ${_fmt(e.value)} ($pct%)');
      }
    }
    return lines.join('\n');
  }

  // MARK: - 6. Budget Status

  Future<String> _getBudgetStatus(Map<String, dynamic> i) async {
    final ({DateTime start, DateTime end}) range = _monthRange(_s(i, 'month'));
    // ensurePeriodForMonth crea el período si no existe (la única lectura
    // disponible en el repo). Equivale al "Create one in the Budget tab" de iOS,
    // sólo que ya queda creado vacío.
    final BudgetPeriod period = await _budgetRepo.ensurePeriodForMonth(
      householdId: householdId,
      year: range.start.year,
      month: range.start.month,
    );
    final List<BudgetAllocation> allocs =
        await _budgetRepo.fetchAllocations(period.id);
    final List<Transaction> txs = await _txRepo.fetchRange(
        householdId: householdId,
        from: range.start,
        to: range.end,
        limit: 5000);
    final Map<String, Decimal> spent = _expensesByCategory(txs);

    if (allocs.where((a) => a.allocated > Decimal.zero).isEmpty) {
      return 'No envelopes set for this month yet. Set one with set_budget_envelope or in the Budget tab.';
    }

    final List<String> lines = <String>[
      'Budget Status:',
      'Total allocated: ${_fmt(period.totalAllocated)}',
      'Ready to assign: ${_fmt(period.readyToAssign)}',
      '',
    ];
    final List<String> overBudget = <String>[];
    final List<String> nearLimit = <String>[];

    final List<BudgetAllocation> ordered = allocs
        .where((a) => a.allocated > Decimal.zero)
        .toList()
      ..sort((a, b) => b.allocated.compareTo(a.allocated));
    for (final BudgetAllocation a in ordered) {
      final Decimal s = spent[a.category] ?? Decimal.zero;
      final Decimal remaining = a.allocated - s;
      final double pct = s.toDouble() / a.allocated.toDouble() * 100;
      final String status;
      if (pct >= 100) {
        status = 'OVER';
        overBudget.add(a.category);
      } else if (pct >= 80) {
        status = 'WARNING';
        nearLimit.add(a.category);
      } else {
        status = 'OK';
      }
      lines.add(
          '• ${a.category}: ${_fmt(s)}/${_fmt(a.allocated)} (${pct.round()}%) [$status] remaining: ${_fmt(remaining)}');
    }
    if (overBudget.isNotEmpty) {
      lines.add('\nOver budget: ${overBudget.join(', ')}');
    }
    if (nearLimit.isNotEmpty) {
      lines.add('Near limit (80%+): ${nearLimit.join(', ')}');
    }
    return lines.join('\n');
  }

  // MARK: - 7. Net Worth

  Future<String> _getNetWorth() async {
    final List<Account> accounts = await _accountRepo.fetchAll(householdId);
    final List<Debt> debts = await _debtRepo.fetchAll(
        householdId: householdId, includeSettled: false);
    final DateTime now = DateTime.now();
    final DateTime start = now.subtract(const Duration(days: 365));
    final List<Transaction> txs = await _txRepo.fetchRange(
        householdId: householdId, from: start, to: now, limit: 10000);

    final List<String> lines = <String>['Net Worth Breakdown:'];
    Decimal totalAssets = Decimal.zero;
    Decimal totalLiabilities = Decimal.zero;

    lines.add('\nAssets:');
    for (final Account acc in accounts) {
      if (acc.type == AccountType.creditCard || acc.type == AccountType.loan) {
        continue;
      }
      final Decimal bal = BalanceCalculator.currentBalance(acc, txs);
      totalAssets += bal;
      lines.add(
          '  • ${acc.name} (${_accountTypeWire(acc.type)}): ${_fmt(bal, acc.currency)}');
    }

    lines.add('\nLiabilities:');
    for (final Account acc in accounts) {
      if (acc.type != AccountType.creditCard && acc.type != AccountType.loan) {
        continue;
      }
      final Decimal bal = BalanceCalculator.currentBalance(acc, txs);
      final Decimal owed = bal < Decimal.zero ? -bal : bal;
      totalLiabilities += owed;
      lines.add('  • ${acc.name}: ${_fmt(owed, acc.currency)}');
    }
    for (final Debt debt in debts) {
      totalLiabilities += debt.currentBalance;
      lines.add(
          '  • ${debt.creditor} (debt): ${_fmt(debt.currentBalance, debt.currency)}');
    }

    final Decimal netWorth = totalAssets - totalLiabilities;
    lines
      ..add('\nTotal Assets: ${_fmt(totalAssets)}')
      ..add('Total Liabilities: ${_fmt(totalLiabilities)}')
      ..add('Net Worth: ${_fmt(netWorth)}');
    return lines.join('\n');
  }

  // MARK: - 8. Health Score

  Future<String> _getHealthScore() async {
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month, 1);
    final DateTime monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final TransactionTotals totals = await _txRepo.totals(
        householdId: householdId, from: monthStart, to: monthEnd);
    final List<Goal> goals = await _goalRepo.fetchAll(
        householdId: householdId, includeCompleted: false);
    final List<Debt> debts = await _debtRepo.fetchAll(
        householdId: householdId, includeSettled: false);
    final List<Account> accounts = await _accountRepo.fetchAll(householdId);

    final Decimal balance = totals.balance;
    final double savingsRate = totals.ingresos > Decimal.zero
        ? balance.toDouble() / totals.ingresos.toDouble()
        : 0;

    Decimal monthlyDebt = Decimal.zero;
    for (final Debt d in debts) {
      monthlyDebt += (d.currentBalance / Decimal.fromInt(24))
          .toDecimal(scaleOnInfinitePrecision: 6);
    }
    final double debtRatio = totals.ingresos > Decimal.zero
        ? monthlyDebt.toDouble() / totals.ingresos.toDouble()
        : 0;

    Decimal liquid = Decimal.zero;
    for (final Account a in accounts) {
      if (a.type == AccountType.creditCard || a.type == AccountType.loan) {
        continue;
      }
      liquid += a.startingBalance;
    }
    final double monthsOfRunway = totals.gastos > Decimal.zero
        ? liquid.toDouble() / totals.gastos.toDouble()
        : 0;

    final double avgGoalProgress = goals.isEmpty
        ? 0
        : goals.fold(0.0, (double acc, g) => acc + g.progress) / goals.length;

    final int savingsScore = (savingsRate * 100).round().clamp(0, 20);
    final int debtScore = (20 - (debtRatio * 50).round()).clamp(0, 20);
    final int emergencyScore = (monthsOfRunway / 6.0 * 20).round().clamp(0, 20);
    final int goalScore = (avgGoalProgress * 20).round().clamp(0, 20);
    int budgetScore;
    try {
      final BudgetPeriod period = await _budgetRepo.ensurePeriodForMonth(
          householdId: householdId, year: now.year, month: now.month);
      final List<BudgetAllocation> allocs =
          await _budgetRepo.fetchAllocations(period.id);
      budgetScore = allocs.isEmpty ? 5 : 15;
    } catch (_) {
      budgetScore = 0;
    }

    final int total =
        savingsScore + debtScore + emergencyScore + goalScore + budgetScore;
    final List<String> lines = <String>[
      'Financial Health Score: $total/100',
      '',
      'Breakdown:',
      '  • Savings rate (${(savingsRate * 100).round()}%): $savingsScore/20',
      '  • Debt load (${(debtRatio * 100).round()}%): $debtScore/20',
      '  • Emergency fund (${monthsOfRunway.toStringAsFixed(1)} months): $emergencyScore/20',
      '  • Goal progress (${(avgGoalProgress * 100).round()}%): $goalScore/20',
      '  • Budget setup: $budgetScore/20',
    ];
    final String grade;
    if (total >= 80) {
      grade = 'Excellent';
    } else if (total >= 60) {
      grade = 'Good';
    } else if (total >= 40) {
      grade = 'Needs improvement';
    } else {
      grade = 'Critical - take action';
    }
    lines.add('\nGrade: $grade');
    return lines.join('\n');
  }

  // MARK: - 9. Project Scenario

  Future<String> _projectScenario(Map<String, dynamic> i) async {
    final String? scenario = _s(i, 'scenario');
    if (scenario == null) return 'Error: scenario description required';
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month, 1);
    final DateTime monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final int months = _i(i, 'months') ?? 3;

    final TransactionTotals totals = await _txRepo.totals(
        householdId: householdId, from: monthStart, to: monthEnd);
    Decimal projectedIncome = totals.ingresos;
    Decimal projectedExpenses = totals.gastos;

    final String? cat = _s(i, 'category');
    final double? pct = _d(i, 'percentChange');
    final double? fixed = _d(i, 'fixedAmountChange');
    if (cat != null && pct != null) {
      final List<Transaction> txs = await _txRepo.fetchRange(
          householdId: householdId,
          from: monthStart,
          to: monthEnd,
          limit: 5000);
      final Decimal catSpend = txs
          .where((t) =>
              t.type == TxType.gasto &&
              t.category.toLowerCase() == cat.toLowerCase())
          .fold(Decimal.zero, (Decimal acc, t) => acc + t.amount);
      final Decimal change = catSpend * _dec(pct / 100.0);
      projectedExpenses += change;
    } else if (fixed != null) {
      final Decimal fixedDec = _dec(fixed);
      if (fixedDec > Decimal.zero) {
        projectedIncome += fixedDec;
      } else {
        projectedExpenses += -fixedDec;
      }
    }

    final Decimal currentBalance = totals.balance;
    final Decimal projectedBalance = projectedIncome - projectedExpenses;
    final Decimal monthlyDelta = projectedBalance - currentBalance;
    final String s = monthlyDelta >= Decimal.zero ? '+' : '';

    return <String>[
      'Scenario: $scenario',
      '',
      'Current monthly:',
      '  Income: ${_fmt(totals.ingresos)}, Expenses: ${_fmt(totals.gastos)}, Balance: ${_fmt(currentBalance)}',
      '',
      'Projected monthly:',
      '  Income: ${_fmt(projectedIncome)}, Expenses: ${_fmt(projectedExpenses)}, Balance: ${_fmt(projectedBalance)}',
      '',
      'Monthly impact: $s${_fmt(monthlyDelta)}',
      '$months-month cumulative impact: $s${_fmt(monthlyDelta * Decimal.fromInt(months))}',
    ].join('\n');
  }

  // MARK: - 10. Spending Patterns

  Future<String> _detectSpendingPatterns(Map<String, dynamic> i) async {
    final int monthsBack = (_i(i, 'monthsBack') ?? 3).clamp(1, 12);
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month - monthsBack, now.day);

    var txs = await _txRepo.fetchRange(
        householdId: householdId, from: start, to: now, limit: 10000);
    txs = txs.where((t) => t.type == TxType.gasto).toList();
    final String? cat = _s(i, 'category');
    if (cat != null) {
      final String lc = cat.toLowerCase();
      txs = txs.where((t) => t.category.toLowerCase().contains(lc)).toList();
    }
    if (txs.isEmpty) {
      return 'No expense data found for the past $monthsBack months.';
    }

    final Map<String, Decimal> monthly = <String, Decimal>{};
    for (final Transaction t in txs) {
      final String key = _monthKey(t.date);
      monthly[key] = (monthly[key] ?? Decimal.zero) + t.amount;
    }
    final Map<int, Decimal> dow = <int, Decimal>{};
    for (final Transaction t in txs) {
      dow[t.date.weekday] = (dow[t.date.weekday] ?? Decimal.zero) + t.amount;
    }
    // weekday: 1=Mon..7=Sun (Dart). Mapeamos a etiquetas inglesas como iOS.
    const Map<int, String> dayNames = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final Map<String, Decimal> byCat = _expensesByCategory(txs);

    final List<String> lines = <String>[
      'Spending Patterns ($monthsBack months):',
      '',
      'Monthly trend:',
    ];
    final List<String> sortedMonths = monthly.keys.toList()..sort();
    for (final String k in sortedMonths) {
      lines.add('  $k: ${_fmt(monthly[k]!)}');
    }
    if (sortedMonths.length >= 2) {
      final Decimal first = monthly[sortedMonths.first]!;
      final Decimal last = monthly[sortedMonths.last]!;
      if (first > Decimal.zero) {
        final int growth =
            ((last - first).toDouble() / first.toDouble() * 100).round();
        lines.add('  Trend: $growth% change from first to last month');
      }
    }
    lines
      ..add('')
      ..add('By day of week:');
    for (int d = 1; d <= 7; d++) {
      lines.add('  ${dayNames[d]}: ${_fmt(dow[d] ?? Decimal.zero)}');
    }
    if (cat == null) {
      lines
        ..add('')
        ..add('Top categories:');
      final List<MapEntry<String, Decimal>> sorted = byCat.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (int idx = 0; idx < sorted.length && idx < 5; idx++) {
        lines.add(
            '  ${idx + 1}. ${sorted[idx].key}: ${_fmt(sorted[idx].value)}');
      }
    }
    return lines.join('\n');
  }

  // MARK: - 11. Savings Opportunities

  Future<String> _suggestSavings(Map<String, dynamic> i) async {
    final DateTime now = DateTime.now();
    final DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    final List<Transaction> txs = await _txRepo.fetchRange(
        householdId: householdId, from: threeMonthsAgo, to: now, limit: 10000);
    final List<Transaction> expenses =
        txs.where((t) => t.type == TxType.gasto).toList();

    final Map<String, Decimal> totalByCat = <String, Decimal>{};
    for (final Transaction t in expenses) {
      totalByCat[t.category] =
          (totalByCat[t.category] ?? Decimal.zero) + t.amount;
    }
    final List<MapEntry<String, Decimal>> catAvg = totalByCat.entries
        .map((e) => MapEntry<String, Decimal>(
            e.key,
            (e.value / Decimal.fromInt(3))
                .toDecimal(scaleOnInfinitePrecision: 6)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<String> lines = <String>[
      'Savings Opportunities (based on 3-month average):',
      '',
    ];
    final double? target = _d(i, 'targetSavings');
    lines
      ..add(
          'Target savings: ${target != null ? _fmt(_dec(target)) : 'unspecified'}')
      ..add('');

    const Set<String> discretionary = <String>{
      'Ocio',
      'Restaurantes',
      'Compras',
      'Suscripciones',
      'Delivery',
      'Entretenimiento',
    };
    Decimal potential = Decimal.zero;
    for (final MapEntry<String, Decimal> e in catAvg) {
      if (e.value <= Decimal.zero) continue;
      final Decimal suggestion;
      if (discretionary.contains(e.key)) {
        suggestion = (e.value * Decimal.fromInt(20) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 6);
        lines.add(
            '• ${e.key} (avg ${_fmt(e.value)}/mo): reduce 20% → save ${_fmt(suggestion)}/mo');
      } else {
        suggestion = (e.value * Decimal.fromInt(10) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 6);
        lines.add(
            '• ${e.key} (avg ${_fmt(e.value)}/mo): optimize 10% → save ${_fmt(suggestion)}/mo');
      }
      potential += suggestion;
    }
    lines
      ..add('')
      ..add('Total potential monthly savings: ${_fmt(potential)}');
    if (target != null) {
      final Decimal t = _dec(target);
      if (potential >= t) {
        lines.add('This exceeds your target of ${_fmt(t)}.');
      } else {
        lines.add(
            'Gap to target: ${_fmt(t - potential)} — consider additional income sources.');
      }
    }
    return lines.join('\n');
  }

  // MARK: - 12. Goals

  Future<String> _getGoals(Map<String, dynamic> i) async {
    final List<Goal> goals = await _goalRepo.fetchAll(
        householdId: householdId,
        includeCompleted: _b(i, 'includeCompleted') ?? false);
    if (goals.isEmpty) {
      return 'No active goals. Create one in More > Goals > + button.';
    }
    final List<String> lines = <String>['Goals (${goals.length}):'];
    for (final Goal g in goals) {
      final int pct = (g.progress * 100).round();
      final Decimal remaining = g.targetAmount - g.currentAmount;
      final Decimal rem = remaining > Decimal.zero ? remaining : Decimal.zero;
      var line =
          '• ${g.name}: ${_fmt(g.currentAmount, g.currency)}/${_fmt(g.targetAmount, g.currency)} ($pct%)';
      final DateTime? target = g.targetDate;
      if (target != null) {
        final int daysLeft = target.difference(DateTime.now()).inDays;
        line += ' — $daysLeft days left';
        if (rem > Decimal.zero && daysLeft > 0) {
          final int monthsLeft = (daysLeft ~/ 30).clamp(1, 1 << 30);
          final Decimal monthlyNeeded = (rem / Decimal.fromInt(monthsLeft))
              .toDecimal(scaleOnInfinitePrecision: 6);
          line += ', need ${_fmt(monthlyNeeded, g.currency)}/mo';
        }
      }
      lines.add(line);
    }
    return lines.join('\n');
  }

  // MARK: - 13. Accounts

  Future<String> _getAccounts(Map<String, dynamic> i) async {
    final List<Account> accounts = await _accountRepo.fetchAll(householdId,
        includingInactive: _b(i, 'includeInactive') ?? false);
    if (accounts.isEmpty) {
      return 'No accounts found. Add one in More > Accounts.';
    }
    final List<String> lines = <String>['Accounts (${accounts.length}):'];
    for (final Account acc in accounts) {
      final String status = acc.isActive ? '' : ' [inactive]';
      final String inst =
          (acc.institution != null && acc.institution!.isNotEmpty)
              ? ' (${acc.institution})'
              : '';
      final String idShort =
          acc.id.length >= 8 ? acc.id.substring(0, 8) : acc.id;
      lines.add(
          '• ${acc.name}$inst: ${_accountTypeWire(acc.type)} · ${_fmt(acc.startingBalance, acc.currency)}$status [id:$idShort]');
    }
    return lines.join('\n');
  }

  // MARK: - 14. Bills

  Future<String> _getBills(Map<String, dynamic> i) async {
    final int days = _i(i, 'daysAhead') ?? 30;
    final List<Bill> bills = await _billRepo.fetchUpcoming(
        householdId: householdId, daysAhead: days);
    if (bills.isEmpty) {
      return 'No upcoming bills in the next $days days.';
    }
    final List<String> lines = <String>['Upcoming Bills (${bills.length}):'];
    for (final Bill bill in bills) {
      final String urgency = switch (bill.urgency) {
        BillUrgencyLevel.overdue => 'OVERDUE',
        BillUrgencyLevel.dueToday => 'DUE TODAY',
        BillUrgencyLevel.dueSoon => 'Due soon',
        _ => '${bill.daysUntilDue}d',
      };
      final String idShort =
          bill.id.length >= 8 ? bill.id.substring(0, 8) : bill.id;
      lines.add(
          '• ${bill.title}: ${_fmt(bill.amount, bill.currency)} — ${_fmtDate(bill.dueDate)} [$urgency] [id:$idShort]');
    }
    return lines.join('\n');
  }

  // MARK: - 15. Inflation Impact

  Future<String> _analyzeInflation(Map<String, dynamic> i) async {
    final int monthsBack = _i(i, 'monthsBack') ?? 3;
    final DateTime now = DateTime.now();
    final DateTime recentStart = DateTime(now.year, now.month - 1, now.day);
    final DateTime oldStart =
        DateTime(now.year, now.month - (monthsBack + 1), now.day);
    final DateTime oldEnd = DateTime(now.year, now.month - monthsBack, now.day);

    final List<Transaction> recentTxs = await _txRepo.fetchRange(
        householdId: householdId, from: recentStart, to: now, limit: 5000);
    final List<Transaction> oldTxs = await _txRepo.fetchRange(
        householdId: householdId, from: oldStart, to: oldEnd, limit: 5000);
    final List<Transaction> recentExp =
        recentTxs.where((t) => t.type == TxType.gasto).toList();
    final List<Transaction> oldExp =
        oldTxs.where((t) => t.type == TxType.gasto).toList();
    final String? cat = _s(i, 'category');

    Map<String, ({Decimal total, int count})> aggregate(List<Transaction> txs) {
      final Map<String, ({Decimal total, int count})> result =
          <String, ({Decimal total, int count})>{};
      for (final Transaction t in txs) {
        if (cat != null &&
            !t.category.toLowerCase().contains(cat.toLowerCase())) {
          continue;
        }
        final ({Decimal total, int count}) existing =
            result[t.category] ?? (total: Decimal.zero, count: 0);
        result[t.category] =
            (total: existing.total + t.amount, count: existing.count + 1);
      }
      return result;
    }

    final Map<String, ({Decimal total, int count})> recent =
        aggregate(recentExp);
    final Map<String, ({Decimal total, int count})> old = aggregate(oldExp);

    final Decimal recentTotal =
        recentExp.fold(Decimal.zero, (Decimal a, t) => a + t.amount);
    final Decimal oldTotal =
        oldExp.fold(Decimal.zero, (Decimal a, t) => a + t.amount);

    final List<String> lines = <String>[
      'Inflation & Price Impact Analysis ($monthsBack months ago vs now):',
      '',
    ];
    if (oldTotal > Decimal.zero) {
      final int totalChange =
          ((recentTotal - oldTotal).toDouble() / oldTotal.toDouble() * 100)
              .round();
      lines.add('Overall spending change: $totalChange%');
    }
    lines.add('');

    final List<MapEntry<String, ({Decimal total, int count})>> sorted =
        recent.entries.toList()
          ..sort((a, b) => b.value.total.compareTo(a.value.total));
    for (final MapEntry<String, ({Decimal total, int count})> e in sorted) {
      final ({Decimal total, int count})? o = old[e.key];
      if (o == null || o.total <= Decimal.zero) continue;
      final int totalChange =
          ((e.value.total - o.total).toDouble() / o.total.toDouble() * 100)
              .round();
      final Decimal avgRecent = e.value.count > 0
          ? (e.value.total / Decimal.fromInt(e.value.count))
              .toDecimal(scaleOnInfinitePrecision: 6)
          : Decimal.zero;
      final Decimal avgOld = o.count > 0
          ? (o.total / Decimal.fromInt(o.count))
              .toDecimal(scaleOnInfinitePrecision: 6)
          : Decimal.zero;
      var line = '• ${e.key}: $totalChange% change';
      if (avgOld > Decimal.zero) {
        final int priceChange =
            ((avgRecent - avgOld).toDouble() / avgOld.toDouble() * 100).round();
        final int qtyChange = e.value.count - o.count;
        line += ' (avg price $priceChange%';
        if (qtyChange != 0) {
          line += ', qty ${qtyChange > 0 ? '+' : ''}$qtyChange';
        }
        line += ')';
      }
      lines.add(line);
    }
    lines
      ..add('')
      ..add(
          'Note: This compares your actual spending, not official inflation indexes. Price changes are approximated from average transaction amounts.');
    return lines.join('\n');
  }

  // MARK: - 16. Mark Bill Paid

  Future<String> _markBillPaid(Map<String, dynamic> i) async {
    final String? rawId = _s(i, 'billId');
    if (rawId == null) return 'Error: billId required';
    final Bill? bill = await _resolveBill(rawId);
    if (bill == null) {
      return '⚠️ No encontré esa factura. Usá get_bills para ver los IDs.';
    }
    await _billRepo.markPaid(bill.id);
    return '✅ Factura "${bill.title}" marcada como pagada.';
  }

  // MARK: - 17. Compare Periods

  Future<String> _comparePeriods(Map<String, dynamic> i) async {
    final String? a = _s(i, 'periodA');
    final String? b = _s(i, 'periodB');
    if (a == null || b == null) {
      return 'Error: periodA and periodB required (yyyy-MM)';
    }
    final ({DateTime start, DateTime end}) ra = _monthRange(a);
    final ({DateTime start, DateTime end}) rb = _monthRange(b);

    final TransactionTotals tA = await _txRepo.totals(
        householdId: householdId, from: ra.start, to: ra.end);
    final TransactionTotals tB = await _txRepo.totals(
        householdId: householdId, from: rb.start, to: rb.end);
    final List<Transaction> allA = await _txRepo.fetchRange(
        householdId: householdId, from: ra.start, to: ra.end, limit: 5000);
    final List<Transaction> allB = await _txRepo.fetchRange(
        householdId: householdId, from: rb.start, to: rb.end, limit: 5000);

    List<MapEntry<String, Decimal>> topCats(List<Transaction> txs) {
      final Map<String, Decimal> sums = _expensesByCategory(txs);
      final List<MapEntry<String, Decimal>> sorted = sums.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      return sorted.take(5).toList();
    }

    final Decimal balA = tA.balance;
    final Decimal balB = tB.balance;
    final int svgA = tA.ingresos > Decimal.zero
        ? (balA.toDouble() / tA.ingresos.toDouble() * 100).round()
        : 0;
    final int svgB = tB.ingresos > Decimal.zero
        ? (balB.toDouble() / tB.ingresos.toDouble() * 100).round()
        : 0;
    final Decimal dIng = tA.ingresos - tB.ingresos;
    final Decimal dGas = tA.gastos - tB.gastos;
    final Decimal dBal = balA - balB;
    String fd(Decimal d) => '${d >= Decimal.zero ? '+' : ''}${_fmt(d)}';

    final List<String> lines = <String>[
      '$a vs $b ($currency):',
      '• Ingresos: ${_fmt(tA.ingresos)} vs ${_fmt(tB.ingresos)} — Δ ${fd(dIng)}',
      '• Gastos: ${_fmt(tA.gastos)} vs ${_fmt(tB.gastos)} — Δ ${fd(dGas)}',
      '• Balance: ${_fmt(balA)} vs ${_fmt(balB)} — Δ ${fd(dBal)}',
      '• Savings rate: $svgA% vs $svgB%',
    ];
    final List<MapEntry<String, Decimal>> catsA = topCats(allA);
    final List<MapEntry<String, Decimal>> catsB = topCats(allB);
    if (catsA.isNotEmpty) {
      lines
        ..add('')
        ..add('Top categorías $a:');
      for (int idx = 0; idx < catsA.length; idx++) {
        lines.add('  ${idx + 1}. ${catsA[idx].key}: ${_fmt(catsA[idx].value)}');
      }
    }
    if (catsB.isNotEmpty) {
      lines
        ..add('')
        ..add('Top categorías $b:');
      for (int idx = 0; idx < catsB.length; idx++) {
        lines.add('  ${idx + 1}. ${catsB[idx].key}: ${_fmt(catsB[idx].value)}');
      }
    }
    return lines.join('\n');
  }

  // MARK: - 18. Set Budget Envelope

  Future<String> _setBudgetEnvelope(Map<String, dynamic> i) async {
    final String? categoryRaw = _s(i, 'category');
    final double? amountD = _d(i, 'amount');
    if (categoryRaw == null || amountD == null) {
      return 'Error: category and amount required';
    }
    if (amountD < 0) return 'Error: el monto debe ser >= 0';
    final String category = _resolveCategory(categoryRaw);
    final ({DateTime start, DateTime end}) range = _monthRange(_s(i, 'month'));

    final BudgetPeriod period = await _budgetRepo.ensurePeriodForMonth(
      householdId: householdId,
      year: range.start.year,
      month: range.start.month,
    );
    await _budgetRepo.upsertAllocation(
      periodId: period.id,
      category: category,
      subcategory: _s(i, 'subcategory') ?? '',
      allocated: _dec(amountD),
      currency: currency,
    );
    final String sub =
        (_s(i, 'subcategory') != null) ? ' > ${_s(i, 'subcategory')}' : '';
    final String periodLabel = _monthKey(period.periodStart);
    return '✅ Presupuesto seteado: $category$sub = ${_fmt(_dec(amountD))} para $periodLabel.';
  }

  // MARK: - 19. Transfer Between Accounts

  Future<String> _transferBetweenAccounts(Map<String, dynamic> i) async {
    final double? amountD = _d(i, 'amount');
    final String? fromRaw = _s(i, 'fromAccountId');
    final String? toRaw = _s(i, 'toAccountId');
    if (amountD == null || fromRaw == null || toRaw == null) {
      return 'Error: fromAccountId, toAccountId, amount required';
    }
    if (amountD <= 0) return 'Error: el monto debe ser mayor a cero';

    // Resolver cuentas por id (completo o prefijo de 8).
    final List<Account> accounts =
        await _accountRepo.fetchAll(householdId, includingInactive: true);
    final Account? from = _matchById(accounts, fromRaw, (a) => a.id);
    final Account? to = _matchById(accounts, toRaw, (a) => a.id);
    if (from == null || to == null) {
      return '⚠️ No pude resolver una de las cuentas. Usá get_accounts para ver los IDs.';
    }
    if (from.id == to.id) {
      return 'Error: la cuenta origen y destino no pueden ser la misma';
    }
    final Decimal amount = _dec(amountD);
    final DateTime now = DateTime.now();
    final String baseNote = (_s(i, 'note') != null)
        ? _s(i, 'note')!
        : 'Transferencia entre cuentas';

    final NewTransactionInput expense = NewTransactionInput(
      householdId: householdId,
      userId: userId,
      accountId: from.id,
      type: TxType.gasto,
      amount: amount,
      category: 'Transferencia',
      note: '→ $baseNote',
      date: now,
    );
    final NewTransactionInput income = NewTransactionInput(
      householdId: householdId,
      userId: userId,
      accountId: to.id,
      type: TxType.ingreso,
      amount: amount,
      category: 'Transferencia',
      note: '← $baseNote',
      date: now,
    );
    try {
      await _txRepo.insert(expense);
      await _txRepo.insert(income);
      return '✅ Transferencia ejecutada: ${_fmt(amount)} de ${from.name} a ${to.name}. Se crearon 2 transacciones linkeadas.';
    } catch (e) {
      return 'Error en la transferencia: $e. Si solo se ejecutó la primera pierna, corregí manualmente desde Movimientos.';
    }
  }

  // MARK: - 20. Categorize Transaction (pure heuristic)

  Future<String> _categorizeTransaction(Map<String, dynamic> i) async {
    final String text = (_s(i, 'text') ?? '').toLowerCase();
    if (text.isEmpty) {
      return 'Error: necesito un texto descriptivo para categorizar';
    }
    final ({String category, double confidence}) best = _classify(text);
    return 'Sugerencia: ${best.category} (confianza ${(best.confidence * 100).round()}%). Si no es correcto, indicame la categoría correcta.';
  }

  // MARK: - 21. Validate CFDI (Mexico)

  Future<String> _validateCFDI(Map<String, dynamic> i) async {
    final String input = (_s(i, 'qrText') ?? '').trim();
    if (input.isEmpty) {
      return 'Error: pasame el QR text o la URL de verificación del CFDI';
    }
    final RegExp uuidRe = RegExp(
        r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}');
    final RegExp rfcRe = RegExp(r'^[A-Z&Ñ]{3,4}[0-9]{6}[0-9A-Z]{3}$');

    String? uuid;
    String? rfcEmisor;
    String? rfcReceptor;
    String? total;

    if (input.contains('verificacfdi') ||
        input.contains('?id=') ||
        input.contains('&re=')) {
      final Uri? url = Uri.tryParse(input);
      if (url != null) {
        url.queryParameters.forEach((String k, String v) {
          switch (k.toLowerCase()) {
            case 'id':
              uuid = v;
            case 're':
              rfcEmisor = v;
            case 'rr':
              rfcReceptor = v;
            case 'tt':
              total = v;
          }
        });
      }
    }
    if (uuid == null && input.contains('id=')) {
      // QR text plano "…?id=…&re=…&rr=…&tt=…" sin schema válido para Uri.
      for (final String part in input.split(RegExp(r'[?&]'))) {
        final int eq = part.indexOf('=');
        if (eq <= 0) continue;
        final String key = part.substring(0, eq).toLowerCase();
        final String val = Uri.decodeComponent(part.substring(eq + 1));
        switch (key) {
          case 'id':
            uuid ??= val;
          case 're':
            rfcEmisor ??= val;
          case 'rr':
            rfcReceptor ??= val;
          case 'tt':
            total ??= val;
        }
      }
    }
    if (uuid == null) {
      final RegExpMatch? m = uuidRe.firstMatch(input);
      if (m != null) uuid = m.group(0);
    }

    final String? extractedUUID = uuid;
    if (extractedUUID == null) {
      return 'No detecté un UUID de CFDI válido en el input. Formato esperado: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (32 hex). El QR de una factura mexicana suele traer una URL de verificacfdi con parámetros id, re, rr, tt.';
    }
    final bool uuidValid =
        RegExp('^${uuidRe.pattern}\$').hasMatch(extractedUUID);
    bool? emisorValid;
    if (rfcEmisor != null) {
      rfcEmisor = rfcEmisor!.toUpperCase();
      emisorValid = rfcRe.hasMatch(rfcEmisor!);
    }
    bool? receptorValid;
    if (rfcReceptor != null) {
      rfcReceptor = rfcReceptor!.toUpperCase();
      receptorValid = rfcRe.hasMatch(rfcReceptor!);
    }

    final List<String> lines = <String>[
      '📄 CFDI 4.0 — datos extraídos:',
      '• UUID: $extractedUUID ${uuidValid ? '✓' : '⚠️ formato no válido'}',
    ];
    if (rfcEmisor != null) {
      lines.add(
          '• RFC Emisor: $rfcEmisor ${(emisorValid ?? false) ? '✓' : '⚠️'}');
    }
    if (rfcReceptor != null) {
      lines.add(
          '• RFC Receptor: $rfcReceptor ${(receptorValid ?? false) ? '✓' : '⚠️'}');
    }
    if (total != null) lines.add('• Total: \$$total MXN');

    if (rfcEmisor != null &&
        rfcReceptor != null &&
        total != null &&
        uuidValid) {
      lines
        ..add('')
        ..add('Para verificar estado vigente/cancelado contra SAT, abrí:')
        ..add(
            'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=$extractedUUID&re=$rfcEmisor&rr=$rfcReceptor&tt=$total');
    } else {
      lines
        ..add('')
        ..add(
            'Faltan datos (RFC emisor, RFC receptor o total) para armar la URL de verificación oficial.');
    }
    return lines.join('\n');
  }

  // MARK: - 22. Validate ARCA (Argentina)

  Future<String> _validateARCA(Map<String, dynamic> i) async {
    final String cae = (_s(i, 'cae') ?? '').trim();
    final bool caeValid = RegExp(r'^[0-9]{14}$').hasMatch(cae);

    final List<String> lines = <String>[
      '🇦🇷 ARCA — análisis de comprobante electrónico:',
      '• CAE: $cae ${caeValid ? '✓ formato válido (14 dígitos)' : '⚠️ formato inválido — el CAE son 14 dígitos sin guiones'}',
    ];
    if (caeValid) {
      final String prefix = cae.substring(0, 8);
      final DateTime? d = _parseYyyymmdd(prefix);
      if (d != null) {
        lines.add('• Posible fecha asociada al CAE: ${_fmtDate(d)}');
      }
    }
    final String? comprobante = _s(i, 'comprobante');
    if (comprobante != null) {
      final bool ok = RegExp(r'^[0-9]{4,5}-[0-9]{1,8}$').hasMatch(comprobante);
      lines.add(
          '• Comprobante: $comprobante ${ok ? '✓' : '⚠️ formato esperado: 0001-00000123'}');
      if (ok) {
        final List<String> parts = comprobante.split('-');
        lines
          ..add('  Punto de venta: ${parts[0]}')
          ..add('  Número: ${parts[1]}');
      }
    }
    final double? total = _d(i, 'total');
    if (total != null) {
      lines.add('• Total declarado: ${_fmt(_dec(total), 'ARS')}');
    }
    lines.add('');
    if (caeValid) {
      lines.add(
          '✅ Formato del CAE válido. La verificación contra los Web Services de ARCA (WSFEv1/WSFEX) requiere tu Clave Fiscal + certificado digital. Para activarlo en $_appName, andá a Ajustes → Integraciones fiscales (próximamente).');
    } else {
      lines.add(
          '⚠️ El formato del CAE no es válido. Verificá que copiaste los 14 dígitos completos del comprobante original (sin guiones, espacios ni letras).');
    }
    return lines.join('\n');
  }

  static const String _appName = 'Home Finance';

  // MARK: - Shared helpers

  Map<String, Decimal> _expensesByCategory(List<Transaction> txs) {
    final Map<String, Decimal> byCat = <String, Decimal>{};
    for (final Transaction t in txs) {
      if (t.type != TxType.gasto) continue;
      byCat[t.category] = (byCat[t.category] ?? Decimal.zero) + t.amount;
    }
    return byCat;
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _accountTypeWire(AccountType t) => switch (t) {
        AccountType.checking => 'checking',
        AccountType.savings => 'savings',
        AccountType.cash => 'cash',
        AccountType.creditCard => 'credit_card',
        AccountType.investment => 'investment',
        AccountType.loan => 'loan',
        AccountType.other => 'other',
      };

  DateTime? _parseYyyymmdd(String s) {
    if (s.length != 8) return null;
    final int? y = int.tryParse(s.substring(0, 4));
    final int? m = int.tryParse(s.substring(4, 6));
    final int? d = int.tryParse(s.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  /// Resuelve un Transaction por UUID completo o prefijo de 8 chars (lo que el
  /// modelo ve en `query_transactions`). Busca en una ventana amplia.
  Future<Transaction?> _resolveTransaction(String rawId) async {
    final DateTime now = DateTime.now();
    final DateTime start = now.subtract(const Duration(days: 365 * 2));
    final List<Transaction> txs = await _txRepo.fetchRange(
        householdId: householdId, from: start, to: now, limit: 10000);
    return _matchById(txs, rawId, (t) => t.id);
  }

  /// Resuelve un Bill por UUID completo o prefijo de 8 chars. Trae una ventana
  /// amplia de upcoming (1 año) — markPaid sólo aplica a pendientes.
  Future<Bill?> _resolveBill(String rawId) async {
    final List<Bill> bills =
        await _billRepo.fetchUpcoming(householdId: householdId, daysAhead: 365);
    return _matchById(bills, rawId, (b) => b.id);
  }

  /// Match genérico por UUID completo (case-insensitive) o prefijo de 8 chars.
  T? _matchById<T>(List<T> items, String rawId, String Function(T) idOf) {
    final String needle = rawId.trim().toLowerCase();
    for (final T it in items) {
      if (idOf(it).toLowerCase() == needle) return it;
    }
    if (needle.length >= 8) {
      for (final T it in items) {
        if (idOf(it).toLowerCase().startsWith(needle)) return it;
      }
    } else if (needle.isNotEmpty) {
      for (final T it in items) {
        if (idOf(it).toLowerCase().startsWith(needle)) return it;
      }
    }
    return null;
  }

  // MARK: - Category resolution (fuzzy keyword map es/en)

  /// Mapea un texto libre / categoría aproximada a una categoría canónica de la
  /// app. Si ya es una categoría reconocida la deja igual; si no, usa el
  /// clasificador de keywords. Espejo del `resolveCategory` de iOS.
  String _resolveCategory(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Otros';
    final String lc = trimmed.toLowerCase();
    // Si el texto ya casa (exacto) con una categoría canónica conocida, úsala
    // con su capitalización canónica.
    for (final String canonical in _canonicalCategories) {
      if (canonical.toLowerCase() == lc) return canonical;
    }
    // Si no, intentá clasificar por keywords; si la confianza es baja, devolvé
    // el texto original tal cual (respeta categorías custom del usuario).
    final ({String category, double confidence}) c = _classify(lc);
    if (c.confidence >= 0.85) return c.category;
    return trimmed;
  }

  static const List<String> _canonicalCategories = <String>[
    'Alimentación',
    'Restaurantes',
    'Transporte',
    'Servicios',
    'Streaming',
    'Salud',
    'Entretenimiento',
    'Hogar',
    'Educación',
    'Ropa',
    'Suscripciones',
    'Transferencia',
    'Sueldo',
    'Freelance',
    'Otros',
  ];

  /// Clasificador determinista por keywords (LATAM + es/en). Espejo del patrón
  /// de `categorizeTransaction` de iOS. Devuelve (categoría, confianza 0..1).
  ({String category, double confidence}) _classify(String text) {
    const List<({String category, List<String> keywords, double confidence})>
        patterns =
        <({String category, List<String> keywords, double confidence})>[
      (
        category: 'Alimentación',
        keywords: <String>[
          'super',
          'mercado',
          'verduleria',
          'carniceria',
          'panaderia',
          'almacen',
          'coto',
          'carrefour',
          'dia',
          'jumbo',
          'disco',
          'grocery',
          'supermarket',
        ],
        confidence: 0.92,
      ),
      (
        category: 'Restaurantes',
        keywords: <String>[
          'restaurante',
          'restaurant',
          'bar',
          'cafe',
          'café',
          'rappi',
          'pedidos ya',
          'uber eats',
          'delivery',
          'pizza',
          'sushi',
        ],
        confidence: 0.90,
      ),
      (
        category: 'Transporte',
        keywords: <String>[
          'uber',
          'cabify',
          'didi',
          'taxi',
          'subte',
          'colectivo',
          'tren',
          'ypf',
          'axion',
          'shell',
          'nafta',
          'combustible',
          'gas station',
          'estacionamiento',
          'peaje',
          'fuel',
          'parking',
        ],
        confidence: 0.92,
      ),
      (
        category: 'Servicios',
        keywords: <String>[
          'luz',
          'edenor',
          'edesur',
          'metrogas',
          'gas',
          'agua',
          'aysa',
          'internet',
          'fibertel',
          'telecentro',
          'movistar',
          'claro',
          'personal',
          'telecom',
          'utility',
          'electricity',
          'water',
        ],
        confidence: 0.94,
      ),
      (
        category: 'Streaming',
        keywords: <String>[
          'netflix',
          'spotify',
          'disney',
          'hbo',
          'amazon prime',
          'apple music',
          'youtube premium',
        ],
        confidence: 0.95,
      ),
      (
        category: 'Salud',
        keywords: <String>[
          'farmacia',
          'farmacity',
          'doctor',
          'clinica',
          'hospital',
          'obra social',
          'osde',
          'swiss medical',
          'pharmacy',
          'health',
        ],
        confidence: 0.92,
      ),
      (
        category: 'Entretenimiento',
        keywords: <String>[
          'cine',
          'cinema',
          'teatro',
          'concierto',
          'show',
          'boleto',
        ],
        confidence: 0.85,
      ),
      (
        category: 'Hogar',
        keywords: <String>[
          'sodimac',
          'easy',
          'ikea',
          'ferreteria',
          'mueble',
          'limpieza',
          'hardware',
          'furniture',
        ],
        confidence: 0.85,
      ),
      (
        category: 'Educación',
        keywords: <String>[
          'universidad',
          'curso',
          'udemy',
          'coursera',
          'libreria',
          'libro',
          'course',
          'book',
          'tuition',
        ],
        confidence: 0.88,
      ),
      (
        category: 'Ropa',
        keywords: <String>[
          'zara',
          'h&m',
          'indumentaria',
          'ropa',
          'calzado',
          'clothing',
          'shoes',
        ],
        confidence: 0.85,
      ),
      (
        category: 'Sueldo',
        keywords: <String>[
          'sueldo',
          'salario',
          'haberes',
          'pago mensual',
          'salary',
          'paycheck',
        ],
        confidence: 0.96,
      ),
      (
        category: 'Freelance',
        keywords: <String>['freelance', 'honorarios', 'factura', 'invoice'],
        confidence: 0.85,
      ),
    ];

    ({String category, double confidence}) best =
        (category: 'Otros', confidence: 0.3);
    for (final ({String category, List<String> keywords, double confidence}) p
        in patterns) {
      for (final String kw in p.keywords) {
        if (text.contains(kw) && p.confidence > best.confidence) {
          best = (category: p.category, confidence: p.confidence);
        }
      }
    }
    return best;
  }
}
