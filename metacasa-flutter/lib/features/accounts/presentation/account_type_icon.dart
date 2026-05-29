import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/models.dart';

/// Ícono lucide por tipo de cuenta. Mapeo de los SF Symbols de iOS
/// (`AccountType.systemIcon`) a sus equivalentes lucide más cercanos:
///
/// | iOS SF Symbol                 | lucide          |
/// |-------------------------------|-----------------|
/// | banknote                      | banknote        |
/// | building.columns              | landmark        |
/// | dollarsign.circle.fill        | coins           |
/// | creditcard.fill               | creditCard      |
/// | chart.line.uptrend.xyaxis     | trendingUp      |
/// | arrow.down.circle             | arrowDownCircle |
/// | circle                        | circle          |
IconData accountTypeIcon(AccountType type) => switch (type) {
      AccountType.checking => LucideIcons.banknote,
      AccountType.savings => LucideIcons.landmark,
      AccountType.cash => LucideIcons.coins,
      AccountType.creditCard => LucideIcons.creditCard,
      AccountType.investment => LucideIcons.trendingUp,
      AccountType.loan => LucideIcons.arrowDownCircle,
      AccountType.other => LucideIcons.circle,
    };

/// Ícono lucide por pertenencia. Mapeo de los SF Symbols de iOS
/// (`AccountOwnership.icon`): person.fill → user, person.2.fill → users,
/// arrow.up.right.square → externalLink.
IconData ownershipIcon(AccountOwnership ownership) => switch (ownership) {
      AccountOwnership.personal => LucideIcons.user,
      AccountOwnership.shared => LucideIcons.users,
      AccountOwnership.external => LucideIcons.externalLink,
    };
