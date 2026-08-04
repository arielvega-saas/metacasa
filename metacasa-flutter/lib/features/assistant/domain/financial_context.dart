import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/bill_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/debt_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';
import 'ai_money_format.dart';

/// Snapshot financiero del hogar para el contexto del asistente.
///
/// Port de `FinancialContext.swift` (data) + de las secciones
/// `financialDataSection` / `enrichedSignals` de `AISystemPromptV2.swift`
/// (render). Se reconstruye en CADA mensaje para que las respuestas reflejen el
/// estado actual. Todos los montos se redondean a enteros y los rankings se
/// cortan a top-5 (igual que el snapshot de iOS).
///
/// Nota de paridad: la **detección de anomalías** (`AnomalyDetector` en iOS) NO
/// está portada en esta wave — el bloque de anomalías se omite (el resto del
/// snapshot es idéntico). El historial de conversaciones (`pastSummaries`)
/// tampoco: no hay persistencia de chat todavía.
class FinancialContext {
  const FinancialContext({
    required this.householdName,
    required this.currency,
    required this.ingresosMonth,
    required this.gastosMonth,
    required this.prevMonthIngresos,
    required this.prevMonthGastos,
    required this.topCategories,
    required this.activeGoalsCount,
    required this.activeGoalsSummary,
    required this.upcomingBillsCount,
    required this.activeDebtsCount,
    required this.biggestExpense,
    required this.weeklySpending,
    required this.envelopesOverBudget,
    required this.envelopesNearLimit,
    required this.debtLoadRatio,
    required this.recentTransactionsPreview,
    required this.liquidAssets,
  });

  /// Snapshot vacío (sin hogar / sin datos). Render produce string vacío.
  factory FinancialContext.empty() => const FinancialContext(
        householdName: 'Hogar',
        currency: 'USD',
        ingresosMonth: null,
        gastosMonth: null,
        prevMonthIngresos: null,
        prevMonthGastos: null,
        topCategories: <CategoryTotal>[],
        activeGoalsCount: 0,
        activeGoalsSummary: <GoalSummary>[],
        upcomingBillsCount: 0,
        activeDebtsCount: 0,
        biggestExpense: null,
        weeklySpending: <Decimal>[],
        envelopesOverBudget: <String>[],
        envelopesNearLimit: <String>[],
        debtLoadRatio: 0,
        recentTransactionsPreview: <String>[],
        liquidAssets: null,
      );

  final String householdName;
  final String currency;

  // Usamos `Decimal?` con null = 0 para que `empty()` pueda ser `const` (no
  // existe un `Decimal` literal const). El render trata null como cero.
  final Decimal? ingresosMonth;
  final Decimal? gastosMonth;
  final Decimal? prevMonthIngresos;
  final Decimal? prevMonthGastos;

  final List<CategoryTotal> topCategories;
  final int activeGoalsCount;
  final List<GoalSummary> activeGoalsSummary;
  final int upcomingBillsCount;
  final int activeDebtsCount;

  final ExpenseSignal? biggestExpense;
  final List<Decimal> weeklySpending; // más reciente primero, ≤4 buckets
  final List<String> envelopesOverBudget;
  final List<String> envelopesNearLimit;
  final double debtLoadRatio;
  final List<String> recentTransactionsPreview;
  final Decimal? liquidAssets;

  Decimal get _ingresos => ingresosMonth ?? Decimal.zero;
  Decimal get _gastos => gastosMonth ?? Decimal.zero;
  Decimal get _prevIngresos => prevMonthIngresos ?? Decimal.zero;
  Decimal get _prevGastos => prevMonthGastos ?? Decimal.zero;
  Decimal get balanceMonth => _ingresos - _gastos;

  /// Renderiza el snapshot a los bloques de texto del system prompt:
  /// `=== LIVE USER FINANCIAL DATA ===` + `=== ENRICHED SIGNALS ===`.
  /// Devuelve '' si no hay nada significativo (el prompt omite el bloque).
  String render() {
    final bool hasAnything = _ingresos > Decimal.zero ||
        _gastos > Decimal.zero ||
        topCategories.isNotEmpty ||
        activeGoalsSummary.isNotEmpty ||
        upcomingBillsCount > 0 ||
        activeDebtsCount > 0 ||
        recentTransactionsPreview.isNotEmpty;
    if (!hasAnything) return '';

    final String data = _financialDataSection();
    final String enriched = _enrichedSignals();
    final StringBuffer buf = StringBuffer()
      ..writeln('=== LIVE USER FINANCIAL DATA ===')
      ..writeln()
      ..write(data);
    if (enriched.isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(enriched);
    }
    return buf.toString();
  }

  // MARK: - Render: financial data section

  String _financialDataSection() {
    final String cur = currency;
    final String topCat = topCategories.isEmpty
        ? '  (no expenses loaded this month)'
        : topCategories.take(7).toList().asMap().entries.map((e) {
            final int i = e.key;
            final CategoryTotal item = e.value;
            final int share = _gastos > Decimal.zero
                ? (item.total.toDouble() / _gastos.toDouble() * 100).round()
                : 0;
            return '  ${i + 1}. ${item.category}: ${AiMoney.iso(item.total, cur)} ($share%)';
          }).join('\n');

    final String goalsBlock = activeGoalsSummary.isEmpty
        ? '  (no active goals)'
        : activeGoalsSummary.map((g) {
            final int pct = (g.progress * 100).round();
            return '  • ${g.name}: $pct% done, ${AiMoney.iso(g.remaining, g.currency)} remaining';
          }).join('\n');

    final int savingsRate = _ingresos > Decimal.zero
        ? (balanceMonth.toDouble() / _ingresos.toDouble() * 100).round()
        : 0;

    final Decimal deltaG = _gastos - _prevGastos;
    final Decimal deltaI = _ingresos - _prevIngresos;
    final String signI = deltaI >= Decimal.zero ? '+' : '';
    final String signG = deltaG >= Decimal.zero ? '+' : '';

    return '''
Household: $householdName · Currency: $cur

Current month:
• Income: ${AiMoney.iso(_ingresos, cur)} (Δ vs prev: $signI${AiMoney.iso(deltaI, cur)})
• Expenses: ${AiMoney.iso(_gastos, cur)} (Δ vs prev: $signG${AiMoney.iso(deltaG, cur)})
• Balance: ${AiMoney.iso(balanceMonth, cur)} · Savings rate: $savingsRate%

Top expense categories:
$topCat

Active goals ($activeGoalsCount):
$goalsBlock

Upcoming bills: $upcomingBillsCount · Active debts: $activeDebtsCount''';
  }

  // MARK: - Render: enriched signals

  String _enrichedSignals() {
    final String cur = currency;
    final List<String> blocks = <String>[];

    final ExpenseSignal? b = biggestExpense;
    if (b != null) {
      final String note =
          (b.note != null && b.note!.isNotEmpty) ? ' (${b.note})' : '';
      blocks.add(
          'Largest single expense: ${AiMoney.iso(b.amount, cur)} in ${b.category} on ${_shortDate(b.date)}$note.');
    }

    if (weeklySpending.length == 4) {
      final List<Decimal> w = weeklySpending; // index 0 = this week
      const List<String> labels = <String>[
        '4 weeks ago',
        '3 weeks ago',
        '2 weeks ago',
        'this week',
      ];
      final List<String> lines = <String>['Weekly spending (chronological):'];
      final List<Decimal> chrono = w.reversed.toList(); // oldest first
      for (int i = 0; i < 4; i++) {
        lines.add('  ${labels[i]}: ${AiMoney.iso(chrono[i], cur)}');
      }
      final Decimal prevAvg = ((w[1] + w[2] + w[3]) / Decimal.fromInt(3))
          .toDecimal(scaleOnInfinitePrecision: 6);
      if (prevAvg > Decimal.zero) {
        final int pct =
            ((w[0] - prevAvg).toDouble() / prevAvg.toDouble() * 100).round();
        final String trend =
            pct > 20 ? 'ACCELERATING' : (pct < -20 ? 'DECELERATING' : 'STABLE');
        final String sign = pct >= 0 ? '+' : '';
        lines.add('  Trend: $trend ($sign$pct% vs 3-week avg)');
      }
      blocks.add(lines.join('\n'));
    }

    if (envelopesOverBudget.isNotEmpty || envelopesNearLimit.isNotEmpty) {
      final List<String> lines = <String>['Envelope budget alerts:'];
      if (envelopesOverBudget.isNotEmpty) {
        lines.add('  OVER BUDGET: ${envelopesOverBudget.join(', ')}');
      }
      if (envelopesNearLimit.isNotEmpty) {
        lines.add('  Near limit (80%+): ${envelopesNearLimit.join(', ')}');
      }
      blocks.add(lines.join('\n'));
    }

    if (debtLoadRatio > 0) {
      final int pct = (debtLoadRatio * 100).round();
      final String flag = debtLoadRatio > 0.4
          ? 'HIGH'
          : (debtLoadRatio > 0.2 ? 'moderate' : 'healthy');
      blocks.add('Debt load ratio: ~$pct% of monthly income ($flag).');
    }

    if (recentTransactionsPreview.isNotEmpty) {
      blocks
          .add('Last 5 transactions:\n${recentTransactionsPreview.join('\n')}');
    }

    final Decimal liquid = liquidAssets ?? Decimal.zero;
    if (liquid > Decimal.zero) {
      blocks.add(
          'Liquid assets (non-credit/loan accounts): ${AiMoney.iso(liquid, cur)}.');
    }

    if (blocks.isEmpty) return '';
    return '=== ENRICHED SIGNALS ===\n\n${blocks.join('\n\n')}';
  }

  /// "MMM d" en inglés (igual que el `DateFormatter "MMM d"` de iOS).
  static String _shortDate(DateTime d) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}';
  }
}

/// Par (categoría, total) del breakdown de gastos. Espejo de `CategoryTotal`.
class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});
  final String category;
  final Decimal total;
}

/// Resumen de una meta para el snapshot. Espejo de `GoalSummary`.
class GoalSummary {
  const GoalSummary({
    required this.name,
    required this.progress,
    required this.remaining,
    required this.currency,
  });
  final String name;
  final double progress; // 0..1
  final Decimal remaining;
  final String currency;
}

/// Señal de gasto único (el mayor del mes). Espejo de `ExpenseSignal`.
class ExpenseSignal {
  const ExpenseSignal({
    required this.category,
    required this.amount,
    required this.date,
    this.note,
  });
  final String category;
  final Decimal amount;
  final DateTime date;
  final String? note;
}

/// Ensamblador del [FinancialContext] desde los repos. Port de
/// `FinancialContextBuilder.build` de iOS, adaptado a Riverpod (`Ref`).
abstract final class FinancialContextBuilder {
  const FinancialContextBuilder._();

  /// Construye el snapshot del hogar activo + período actual del reloj. Degrada
  /// a [FinancialContext.empty] si no hay hogar. Cada fetch secundario degrada a
  /// vacío ante error (mismo criterio de los `try?` de iOS) para no tumbar el
  /// asistente por una entidad caída.
  static Future<FinancialContext> build(Ref ref) async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) return FinancialContext.empty();

    final Household? household =
        await ref.read(currentHouseholdProvider.future);
    final String currency = household?.defaultCurrency ?? 'USD';
    final String name = household?.name ?? 'Hogar';

    final txRepo = ref.read(transactionRepositoryProvider);
    final goalRepo = ref.read(goalRepositoryProvider);
    final billRepo = ref.read(billRepositoryProvider);
    final debtRepo = ref.read(debtRepositoryProvider);
    final accountRepo = ref.read(accountRepositoryProvider);
    final budgetRepo = ref.read(budgetRepositoryProvider);

    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final DateTime prevStart = DateTime(now.year, now.month - 1, 1);
    final DateTime prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final DateTime fourWeeksAgo = now.subtract(const Duration(days: 28));

    // Fetch en paralelo, degradando cada uno ante error.
    final Future<List<Transaction>> monthTxsF = txRepo
        .fetchRange(householdId: householdId, from: start, to: end, limit: 5000)
        .catchError((_) => <Transaction>[]);
    final Future<TransactionTotals> prevTotalsF = txRepo
        .totals(householdId: householdId, from: prevStart, to: prevEnd)
        .catchError((_) => TransactionTotals.zero);
    final Future<List<Transaction>> recentTxsF = txRepo
        .fetchRange(
            householdId: householdId, from: fourWeeksAgo, to: now, limit: 5000)
        .catchError((_) => <Transaction>[]);
    final Future<List<Goal>> goalsF = goalRepo
        .fetchAll(householdId: householdId, includeCompleted: false)
        .catchError((_) => <Goal>[]);
    final Future<List<Bill>> billsF = billRepo
        .fetchUpcoming(householdId: householdId, daysAhead: 30)
        .catchError((_) => <Bill>[]);
    final Future<List<Debt>> debtsF = debtRepo
        .fetchAll(householdId: householdId, includeSettled: false)
        .catchError((_) => <Debt>[]);
    final Future<List<Account>> accountsF =
        accountRepo.fetchAll(householdId).catchError((_) => <Account>[]);

    final List<Transaction> monthTxs = await monthTxsF;
    final TransactionTotals prev = await prevTotalsF;
    final List<Transaction> recentTxs = await recentTxsF;
    final List<Goal> goals = await goalsF;
    final List<Bill> bills = await billsF;
    final List<Debt> debts = await debtsF;
    final List<Account> accounts = await accountsF;

    // Totales del mes (sobre monthTxs en memoria).
    final TransactionTotals totals = txRepo.totalsOf(monthTxs);

    // Top categorías de gasto del mes.
    final Map<String, Decimal> byCat = <String, Decimal>{};
    for (final Transaction tx in monthTxs.excludingTransfers) {
      if (tx.type != TxType.gasto) continue;
      byCat[tx.category] = (byCat[tx.category] ?? Decimal.zero) + tx.amount;
    }
    final List<CategoryTotal> top = byCat.entries
        .map((e) => CategoryTotal(category: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    // Resumen de metas (top 5).
    final List<GoalSummary> goalSummaries = goals.take(5).map((g) {
      final Decimal remaining = g.targetAmount - g.currentAmount;
      return GoalSummary(
        name: g.name,
        progress: g.progress,
        remaining: remaining > Decimal.zero ? remaining : Decimal.zero,
        currency: g.currency,
      );
    }).toList();

    // Mayor gasto único del mes.
    ExpenseSignal? biggest;
    for (final Transaction tx in monthTxs.excludingTransfers) {
      if (tx.type != TxType.gasto) continue;
      if (biggest == null || tx.amount > biggest.amount) {
        biggest = ExpenseSignal(
          category: tx.category,
          amount: tx.amount,
          date: tx.date,
          note: tx.note,
        );
      }
    }

    // Weekly spending: 4 buckets, index 0 = esta semana.
    final List<Decimal> weekly =
        List<Decimal>.filled(4, Decimal.zero, growable: false);
    for (final Transaction tx in recentTxs) {
      if (tx.type != TxType.gasto) continue;
      final int daysAgo = now.difference(tx.date).inDays;
      final int idx = (daysAgo ~/ 7).clamp(0, 3);
      weekly[idx] = weekly[idx] + tx.amount;
    }

    // Envelope health: allocations del período del mes vs gasto por categoría.
    final List<String> overBudget = <String>[];
    final List<String> nearLimit = <String>[];
    try {
      final BudgetPeriod period = await budgetRepo.ensurePeriodForMonth(
        householdId: householdId,
        year: now.year,
        month: now.month,
      );
      final List<BudgetAllocation> allocs =
          await budgetRepo.fetchAllocations(period.id);
      // Asignado por categoría (sumando subcategorías).
      final Map<String, Decimal> allocByCat = <String, Decimal>{};
      for (final BudgetAllocation a in allocs) {
        allocByCat[a.category] =
            (allocByCat[a.category] ?? Decimal.zero) + a.allocated;
      }
      allocByCat.forEach((String cat, Decimal allocated) {
        if (allocated <= Decimal.zero) return;
        final Decimal spent = byCat[cat] ?? Decimal.zero;
        final double pct = spent.toDouble() / allocated.toDouble();
        if (pct >= 1.0) {
          overBudget.add(cat);
        } else if (pct >= 0.8) {
          nearLimit.add(cat);
        }
      });
    } catch (_) {
      // Presupuesto no disponible — sin alertas de envelope.
    }

    // Debt load ratio: Σ(currentBalance/24) / ingresos del mes (heurística iOS).
    Decimal monthlyDebt = Decimal.zero;
    for (final Debt d in debts) {
      monthlyDebt += (d.currentBalance / Decimal.fromInt(24))
          .toDecimal(scaleOnInfinitePrecision: 6);
    }
    final double debtLoadRatio = totals.ingresos > Decimal.zero
        ? (monthlyDebt.toDouble() / totals.ingresos.toDouble())
            .clamp(0.0, double.infinity)
        : 0.0;

    // Recent transactions preview (últimas 5 del mes).
    final List<String> recentPreview = monthTxs.take(5).map((tx) {
      final String sign = tx.type == TxType.gasto ? '−' : '+';
      final String note =
          (tx.note != null && tx.note!.isNotEmpty) ? ' — ${tx.note}' : '';
      final String c = tx.currencyOriginal ?? currency;
      return '  ${_dayMonth(tx.date)}: $sign${AiMoney.iso(tx.amount, c)} ${tx.category}$note';
    }).toList();

    // Liquid assets: Σ startingBalance de cuentas no-credit/loan.
    Decimal liquid = Decimal.zero;
    for (final Account a in accounts) {
      if (a.type == AccountType.creditCard || a.type == AccountType.loan) {
        continue;
      }
      liquid += a.startingBalance;
    }

    return FinancialContext(
      householdName: name,
      currency: currency,
      ingresosMonth: totals.ingresos,
      gastosMonth: totals.gastos,
      prevMonthIngresos: prev.ingresos,
      prevMonthGastos: prev.gastos,
      topCategories: top,
      activeGoalsCount: goals.length,
      activeGoalsSummary: goalSummaries,
      upcomingBillsCount: bills.length,
      activeDebtsCount: debts.length,
      biggestExpense: biggest,
      weeklySpending: weekly,
      envelopesOverBudget: overBudget,
      envelopesNearLimit: nearLimit,
      debtLoadRatio: debtLoadRatio,
      recentTransactionsPreview: recentPreview,
      liquidAssets: liquid,
    );
  }

  /// "d MMM" en es (similar al `ddMMM` localizado de iOS).
  static String _dayMonth(DateTime d) {
    const List<String> m = <String>[
      'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }
}
