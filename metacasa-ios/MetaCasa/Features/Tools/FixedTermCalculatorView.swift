import SwiftUI

/// Calculadora de Plazo Fijo — port del `PlazoFijoCalc` de la PWA (App.jsx:16137+).
///
/// Simula la ganancia de un plazo fijo bancario a partir de:
/// - Capital inicial
/// - TNA (Tasa Nominal Anual, %)
/// - Plazo en días (o meses)
///
/// Fórmula: `interés = capital × TNA/100 × días/365`.
/// Muestra también la TEA equivalente para contexto.
@MainActor
struct FixedTermCalculatorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var capitalStr = ""
    @State private var tnaStr = "120"
    @State private var days: Double = 30
    @State private var unit: Unit = .days

    enum Unit: String, CaseIterable {
        case days, months

        var titleKey: LocalizedStringKey {
            switch self {
            case .days: return "fixedTerm.unit.days"
            case .months: return "fixedTerm.unit.months"
            }
        }
    }

    private var currency: String {
        appState.households.first(where: { $0.id == appState.currentHouseholdId })?.defaultCurrency ?? "USD"
    }

    private var capital: Decimal {
        CurrencyFormatter.parse(capitalStr) ?? 0
    }

    private var tna: Double {
        Double(tnaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Días totales de la inversión (según unidad).
    private var totalDays: Double {
        switch unit {
        case .days: return days
        case .months: return days * 30
        }
    }

    /// Interés ganado: `capital × tna/100 × días/365`.
    private var interest: Decimal {
        guard capital > 0, tna > 0, totalDays > 0 else { return 0 }
        let factor = (tna / 100) * (totalDays / 365)
        let factorDecimal = Decimal(factor)
        return capital * factorDecimal
    }

    private var total: Decimal {
        capital + interest
    }

    /// TEA (Tasa Efectiva Anual) = (1 + TNA * días/365 / 1)^(365/días) - 1.
    /// Para plazo único, approx: `(1 + interés/capital)^(365/días) - 1`.
    private var tea: Double {
        guard capital > 0, totalDays > 0 else { return 0 }
        let capitalD = (capital as NSDecimalNumber).doubleValue
        let interestD = (interest as NSDecimalNumber).doubleValue
        let ratio = interestD / capitalD
        return (pow(1 + ratio, 365.0 / totalDays) - 1) * 100
    }

    /// Ganancia mensual equivalente (para comparar con ingresos).
    private var monthlyEquivalent: Decimal {
        guard totalDays > 0 else { return 0 }
        let factor = Decimal(30.0 / totalDays)
        return interest * factor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        inputsCard
                        if capital > 0 && tna > 0 {
                            resultsCard
                            equivalentsCard
                            disclaimerCard
                        } else {
                            hintCard
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(Text("fixedTerm.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(Color.appSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sections

    private var inputsCard: some View {
        VStack(spacing: 14) {
            // Capital
            VStack(alignment: .leading, spacing: 6) {
                Text("fixedTerm.capital").font(.mcLabel).foregroundStyle(Color.textMuted)
                HStack {
                    Text(currency)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.appSurfaceInset)
                        .clipShape(Capsule())
                    TextField("0", text: $capitalStr)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Color.brandPrimary)
                }
                if let amt = CurrencyFormatter.parse(capitalStr), amt > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brandSuccess)
                        Text(Money.format(amt, currency: currency, style: .auto))
                            .font(.caption.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
            }

            Divider()

            // TNA
            VStack(alignment: .leading, spacing: 6) {
                Text("fixedTerm.tna").font(.mcLabel).foregroundStyle(Color.textMuted)
                HStack {
                    TextField("0", text: $tnaStr)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Color.brandSecondary)
                    Text("%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.textMuted)
                }
                Text("fixedTerm.tna.hint").font(.caption).foregroundStyle(Color.textMuted)
            }

            Divider()

            // Plazo
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("fixedTerm.term").font(.mcLabel).foregroundStyle(Color.textMuted)
                    Spacer()
                    Picker("", selection: $unit) {
                        ForEach(Unit.allCases, id: \.self) { u in
                            Text(u.titleKey).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                HStack {
                    Text("\(Int(days))")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Color.brandPrimary)
                        .frame(minWidth: 50)
                    Slider(value: $days, in: 7...(unit == .days ? 1095 : 36), step: 1)
                        .tint(Color.brandPrimary)
                }
                HStack {
                    ForEach(quickDurationOptions, id: \.0) { option in
                        Button {
                            days = option.0
                        } label: {
                            Text(option.1)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(days == option.0 ? Color.brandPrimary : Color.appSurfaceInset)
                                .foregroundStyle(days == option.0 ? Color.white : Color.textPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickDurationOptions: [(Double, String)] {
        switch unit {
        case .days:   return [(30, "30d"), (60, "60d"), (90, "90d"), (180, "180d"), (365, "1 año")]
        case .months: return [(1, "1m"), (3, "3m"), (6, "6m"), (12, "12m"), (24, "24m")]
        }
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("fixedTerm.result").font(.mcH2).foregroundStyle(Color.textPrimary)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("fixedTerm.interest").font(.mcLabel).foregroundStyle(Color.textMuted)
                    AmountLabel(amount: interest, currency: currency, kind: .ingreso)
                        .font(.mcSerifDisplay)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.brandSuccess)
            }
            Divider().overlay(Color.appBorder)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("fixedTerm.total").font(.mcLabel).foregroundStyle(Color.textMuted)
                    AmountLabel(amount: total, currency: currency, kind: .neutro)
                        .font(.mcSerifAmount)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("fixedTerm.tea").font(.mcLabel).foregroundStyle(Color.textMuted)
                    Text("\(String(format: "%.1f", tea))%")
                        .font(.mcSerifAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.brandSuccess.opacity(0.12), Color.brandPrimary.opacity(0.08), Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var equivalentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("fixedTerm.equivalents").font(.mcH2).foregroundStyle(Color.textPrimary)
            equivalentRow(icon: "calendar", labelKey: "fixedTerm.perMonth", amount: monthlyEquivalent)
            Divider()
            equivalentRow(
                icon: "calendar.day.timeline.left",
                labelKey: "fixedTerm.perDay",
                amount: totalDays > 0 ? interest / Decimal(totalDays) : 0
            )
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func equivalentRow(icon: String, labelKey: LocalizedStringKey, amount: Decimal) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color.brandPrimary)
            Text(labelKey).font(.subheadline.weight(.semibold))
            Spacer()
            AmountLabel(amount: amount, currency: currency, kind: .ingreso)
                .font(.mcSerifInline)
                .monospacedDigit()
        }
    }

    private var hintCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "number")
                .font(.largeTitle)
                .foregroundStyle(Color.brandPrimary.opacity(0.6))
            Text("fixedTerm.hint.title")
                .font(.mcBody.weight(.semibold))
            Text("fixedTerm.hint.body")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var disclaimerCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.textMuted)
            Text("fixedTerm.disclaimer")
                .font(.caption2)
                .foregroundStyle(Color.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
