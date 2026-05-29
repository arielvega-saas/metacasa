/// Schemas de las tools en formato Anthropic (`{name, description, input_schema}`).
///
/// Port 1:1 de `AnthropicToolBuilder.allTools()` de iOS — las MISMAS 22 tools,
/// con idénticos nombres, descripciones y campos. Anthropic usa un subset de
/// JSON Schema para `input_schema`.
library;

/// Catálogo de tools del asistente.
abstract final class AiToolSchemas {
  const AiToolSchemas._();

  /// Las 22 tools, en el mismo orden que iOS.
  static List<Map<String, dynamic>> all() => <Map<String, dynamic>>[
        _queryTransactions(),
        _addTransaction(),
        _updateTransaction(),
        _deleteTransaction(),
        _getFinancialSummary(),
        _getBudgetStatus(),
        _getNetWorth(),
        _getHealthScore(),
        _projectScenario(),
        _detectSpendingPatterns(),
        _suggestSavings(),
        _getGoals(),
        _getAccounts(),
        _getBills(),
        _analyzeInflation(),
        _markBillPaid(),
        _comparePeriods(),
        _setBudgetEnvelope(),
        _transferBetweenAccounts(),
        _categorizeTransaction(),
        _validateCFDI(),
        _validateARCA(),
      ];

  // MARK: - Schema helpers

  static Map<String, dynamic> _tool(
    String name,
    String description,
    Map<String, dynamic> properties, {
    List<String> required = const <String>[],
  }) =>
      <String, dynamic>{
        'name': name,
        'description': description,
        'input_schema': <String, dynamic>{
          'type': 'object',
          'properties': properties,
          'required': required,
        },
      };

  static Map<String, dynamic> _str(String d) =>
      <String, dynamic>{'type': 'string', 'description': d};
  static Map<String, dynamic> _num(String d) =>
      <String, dynamic>{'type': 'number', 'description': d};
  static Map<String, dynamic> _int(String d) =>
      <String, dynamic>{'type': 'integer', 'description': d};
  static Map<String, dynamic> _bool(String d) =>
      <String, dynamic>{'type': 'boolean', 'description': d};

  // MARK: - Tool definitions

  static Map<String, dynamic> _queryTransactions() => _tool(
        'query_transactions',
        "Search and filter the user's transactions by category, date range, type, amount, or note. Use to answer questions about spending, income, specific purchases, or merchants.",
        <String, dynamic>{
          'category': _str(
              "Filter by category name (e.g. 'Alimentacion', 'Transporte')"),
          'dateFrom': _str('Start date in yyyy-MM-dd format'),
          'dateTo': _str('End date in yyyy-MM-dd format'),
          'type': _str(
              "Filter by type: 'GASTO' for expenses or 'INGRESO' for income"),
          'noteContains':
              _str('Search in transaction notes (merchant name, description)'),
          'amountMin': _num('Minimum amount'),
          'amountMax': _num('Maximum amount'),
          'limit': _int('Max results to return (default 20)'),
        },
      );

  static Map<String, dynamic> _addTransaction() => _tool(
        'add_transaction',
        'Create a new expense or income transaction. Always confirm details with the user before calling this tool.',
        <String, dynamic>{
          'type': _str(
              "Transaction type: 'GASTO' for expense, 'INGRESO' for income"),
          'amount': _num('Amount as a positive number'),
          'category': _str("Category name (e.g. 'Alimentacion', 'Sueldo')"),
          'subcategory': _str('Optional subcategory'),
          'note': _str('Optional note or merchant name'),
          'date': _str('Date in yyyy-MM-dd format. Today if omitted.'),
        },
        required: <String>['type', 'amount', 'category'],
      );

  static Map<String, dynamic> _updateTransaction() => _tool(
        'update_transaction',
        'Modify an existing transaction. First use query_transactions to find it. Only provided fields are changed.',
        <String, dynamic>{
          'transactionId': _str('UUID of the transaction to update'),
          'amount': _num('New amount'),
          'category': _str('New category'),
          'subcategory': _str('New subcategory'),
          'note': _str('New note'),
          'date': _str('New date in yyyy-MM-dd'),
          'type': _str("New type: 'GASTO' or 'INGRESO'"),
        },
        required: <String>['transactionId'],
      );

  static Map<String, dynamic> _deleteTransaction() => _tool(
        'delete_transaction',
        'Delete a transaction by ID. Always confirm with the user first.',
        <String, dynamic>{
          'transactionId': _str('UUID of the transaction to delete'),
        },
        required: <String>['transactionId'],
      );

  static Map<String, dynamic> _getFinancialSummary() => _tool(
        'get_financial_summary',
        'Get income, expenses, balance, savings rate, top categories, and previous-month comparison for a month.',
        <String, dynamic>{
          'month': _str('Month in yyyy-MM format (default: current month)'),
          'includeComparison': _bool('If true, include vs previous month'),
        },
      );

  static Map<String, dynamic> _getBudgetStatus() => _tool(
        'get_budget_status',
        'Get envelope budget status: allocated vs spent per category, over-budget and near-limit alerts.',
        <String, dynamic>{
          'month': _str('Month in yyyy-MM format (default: current month)'),
        },
      );

  static Map<String, dynamic> _getNetWorth() => _tool(
        'get_net_worth',
        'Calculate net worth: total assets minus liabilities, with breakdown by account.',
        <String, dynamic>{},
      );

  static Map<String, dynamic> _getHealthScore() => _tool(
        'get_financial_health_score',
        'Composite score 0-100 from savings rate, debt load, emergency fund, budget adherence, goal progress.',
        <String, dynamic>{},
      );

  static Map<String, dynamic> _projectScenario() => _tool(
        'project_scenario',
        'What-if projection: simulate impact of category cuts, raises, or fixed savings over months.',
        <String, dynamic>{
          'scenario': _str('Description of the scenario'),
          'category': _str('Category to modify (optional)'),
          'percentChange': _num('Percent change: e.g. -30 = 30% reduction'),
          'fixedAmountChange': _num('Fixed monthly amount change'),
          'months': _int('Months to project (default 3)'),
        },
        required: <String>['scenario'],
      );

  static Map<String, dynamic> _detectSpendingPatterns() => _tool(
        'detect_spending_patterns',
        'Analyze monthly trends, day-of-week patterns, category growth/decline.',
        <String, dynamic>{
          'monthsBack': _int('Months of history (default 3, max 12)'),
          'category': _str('Focus on a specific category (optional)'),
        },
      );

  static Map<String, dynamic> _suggestSavings() => _tool(
        'suggest_savings_opportunities',
        'Identify concrete savings opportunities based on spending patterns.',
        <String, dynamic>{
          'targetSavings': _num('Target monthly savings amount'),
        },
      );

  static Map<String, dynamic> _getGoals() => _tool(
        'get_goals',
        'Get all goals with progress, ETA, and contribution suggestions.',
        <String, dynamic>{
          'includeCompleted': _bool('Include completed goals'),
        },
      );

  static Map<String, dynamic> _getAccounts() => _tool(
        'get_accounts',
        'List financial accounts: checking, savings, cash, credit cards, investments, loans.',
        <String, dynamic>{
          'includeInactive': _bool('Include archived accounts'),
        },
      );

  static Map<String, dynamic> _getBills() => _tool(
        'get_bills',
        'Upcoming bills with due dates, amounts, and urgency.',
        <String, dynamic>{
          'daysAhead': _int('Days ahead to look (default 30)'),
        },
      );

  static Map<String, dynamic> _analyzeInflation() => _tool(
        'analyze_inflation_impact',
        'Inflation analysis: real purchasing power changes, price vs quantity changes per category.',
        <String, dynamic>{
          'monthsBack': _int('Months to compare (default 3)'),
          'category': _str('Focus on a category (optional)'),
        },
      );

  static Map<String, dynamic> _markBillPaid() => _tool(
        'mark_bill_paid',
        'Mark a bill as paid. Use get_bills first to find the UUID, then pass it here. Always confirm with the user before calling.',
        <String, dynamic>{
          'billId': _str('UUID of the bill to mark as paid'),
        },
        required: <String>['billId'],
      );

  static Map<String, dynamic> _comparePeriods() => _tool(
        'compare_periods',
        'Compare two months side by side: income, expenses, balance, savings rate, top categories with deltas. Periods in yyyy-MM.',
        <String, dynamic>{
          'periodA': _str('First period in yyyy-MM format (e.g. 2026-04)'),
          'periodB': _str(
              'Second period in yyyy-MM format (e.g. 2026-03 or 2025-04 for YoY)'),
        },
        required: <String>['periodA', 'periodB'],
      );

  static Map<String, dynamic> _setBudgetEnvelope() => _tool(
        'set_budget_envelope',
        'Set or update the allocated amount for a category in the envelope budget. Confirm with user before calling.',
        <String, dynamic>{
          'category': _str("Category name (e.g. 'Alimentacion')"),
          'amount': _num('Allocated amount, positive number'),
          'subcategory': _str('Optional subcategory'),
          'month': _str('Month in yyyy-MM format (default: current)'),
        },
        required: <String>['category', 'amount'],
      );

  static Map<String, dynamic> _transferBetweenAccounts() => _tool(
        'transfer_between_accounts',
        'Move money between two accounts. Creates a linked expense + income pair. Use get_accounts first to find UUIDs. Always confirm with user.',
        <String, dynamic>{
          'fromAccountId': _str('UUID of the source account'),
          'toAccountId': _str('UUID of the destination account'),
          'amount': _num('Amount to transfer, positive number'),
          'note': _str('Optional note for both legs'),
        },
        required: <String>['fromAccountId', 'toAccountId', 'amount'],
      );

  static Map<String, dynamic> _categorizeTransaction() => _tool(
        'categorize_transaction',
        'Suggest a category from text (merchant name, note). Returns category + confidence. Pure on-device heuristic, no network.',
        <String, dynamic>{
          'text': _str('Free-text description to classify'),
        },
        required: <String>['text'],
      );

  static Map<String, dynamic> _validateCFDI() => _tool(
        'validate_cfdi',
        'Parse and validate a Mexican CFDI 4.0 electronic invoice from QR text or verification URL. Extracts UUID, RFCs, total, validates formats. Returns verification URL for live status check at verificacfdi.sat.gob.mx.',
        <String, dynamic>{
          'qrText':
              _str('QR text or full verification URL from a CFDI 4.0 receipt'),
        },
        required: <String>['qrText'],
      );

  static Map<String, dynamic> _validateARCA() => _tool(
        'validate_arca',
        'Parse and validate an Argentine ARCA electronic invoice via CAE (14 digits) and optional invoice number (format XXXX-XXXXXXXX). Returns format validation + parsed components. Live verification against WSFEv1 requires user\'s Clave Fiscal + certificate.',
        <String, dynamic>{
          'cae': _str('The CAE of the invoice (14 digits)'),
          'comprobante':
              _str('Optional invoice number in format 0001-00000123'),
          'total': _num('Optional total amount of the invoice'),
        },
        required: <String>['cae'],
      );
}
