import AuthenticationServices
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(CookingStore.self) private var cooking
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("temperatureUnit") private var temperatureUnit = "celsius"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var showsAbout = false
    @State private var requestsNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    accountCard
                    cookingCard
                    notificationsCard
                    aboutCard
                }
                .frame(maxWidth: 580)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(DesignSystem.Colors.cream)
            .navigationTitle("Réglages")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() }.accessibilityIdentifier("settings.close") } }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(DesignSystem.Colors.ink)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: account.isSignedIn)
            .sheet(isPresented: $showsAbout) {
                AboutPetitChefView()
            }
            .alert("Compte Apple", isPresented: Binding(
                get: { account.errorMessage != nil },
                set: { if !$0 { account.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { account.errorMessage = nil }
            } message: {
                Text(account.errorMessage ?? "")
            }
            .task { await cooking.refreshNotifications() }
        }
        .accessibilityIdentifier("settings.screen")
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                Image(systemName: account.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 35, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.isSignedIn ? account.displayName : "Compte Apple")
                        .font(.system(.headline, design: .rounded))
                    Text(account.isSignedIn ? "Connecté avec Apple" : "Le compte est facultatif.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.secondaryInk)
                }
                Spacer(minLength: 0)
            }

            if account.isSignedIn {
                Button {
                    account.signOut()
                } label: {
                    Text("Se déconnecter")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("settings.signOut")
            } else {
                SignInWithAppleButton(.signIn) { request in
                    account.beginAuthorization()
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    account.handleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(Capsule())
                .disabled(account.isAuthenticating)
                .accessibilityIdentifier("settings.signInWithApple")
            }
        }
        .preferencesCard()
    }

    private var cookingCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                preferenceLabel("Température", symbol: "thermometer.medium")
                Spacer(minLength: 4)
                Picker("Température", selection: $temperatureUnit) {
                    Text("°C").tag("celsius")
                    Text("°F").tag("fahrenheit")
                }
                .pickerStyle(.segmented)
                .frame(width: 116)
                .accessibilityIdentifier("settings.temperatureUnit")
            }
            .padding(.vertical, 4)

            preferenceDivider

            Toggle(isOn: $hapticsEnabled) {
                preferenceLabel("Retours tactiles", symbol: "hand.tap")
            }
            .tint(DesignSystem.Colors.accent)
            .onChange(of: hapticsEnabled) { _, enabled in
                if enabled { UISelectionFeedbackGenerator().selectionChanged() }
            }
            .accessibilityIdentifier("settings.haptics")

        }
        .preferencesCard()
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if notificationPermissionGranted {
                Toggle(isOn: Binding(
                    get: { cooking.notificationsEnabled },
                    set: { cooking.setNotificationsEnabled($0) }
                )) {
                    preferenceLabel("Alertes minuteurs", symbol: "bell.badge")
                }
                .tint(DesignSystem.Colors.accent)
                .accessibilityIdentifier("settings.timerAlerts")
                Text("Pour être prévenu quand l’écran est verrouillé.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)

                Button("Réglages des alarmes") { openNotificationSettings() }
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("settings.systemNotifications")
            } else {
                preferenceLabel("Alertes minuteurs", symbol: "bell.badge")
                Text(cooking.notificationAuthorization == .denied
                     ? "Autoriser les alarmes dans les réglages de l’iPhone."
                     : "Minuteurs sur l’écran verrouillé et dans la Dynamic Island.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if cooking.notificationAuthorization == .notDetermined {
                        requestsNotifications = true
                        Task {
                            await cooking.requestNotificationPermission()
                            requestsNotifications = false
                        }
                    } else {
                        openNotificationSettings()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if requestsNotifications { ProgressView().controlSize(.small) }
                        Text(cooking.notificationAuthorization == .notDetermined
                             ? "Activer les alertes" : "Ouvrir les réglages")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .disabled(requestsNotifications)
                .accessibilityIdentifier("settings.enableNotifications")
            }

            if let error = cooking.notificationError {
                Text(error)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .preferencesCard()
    }

    private var aboutCard: some View {
        Button {
            showsAbout = true
        } label: {
            HStack(spacing: 12) {
                preferenceLabel("À propos de Petit Chef", symbol: "info.circle")
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(20)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 28))
        .accessibilityIdentifier("settings.about")
    }

    private var notificationPermissionGranted: Bool {
        switch cooking.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    private var preferenceDivider: some View {
        Divider()
            .overlay(DesignSystem.Colors.ink.opacity(0.04))
            .padding(.leading, 35)
            .padding(.vertical, 15)
    }

    private func preferenceLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .frame(width: 23)
                .foregroundStyle(DesignSystem.Colors.secondaryInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct AboutPetitChefView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(DesignSystem.Colors.secondaryInk)
                        Text("Cuisine guidée.")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                        Text("Petit Chef · Version \(version)")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(DesignSystem.Colors.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .preferencesCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Confidentialité", systemImage: "lock")
                            .font(.system(.headline, design: .rounded))
                        Text("Les recettes, tes préférences et ta session de cuisine restent sur cet iPhone. Aucun outil publicitaire ni suivi d’utilisation.")
                        Text("Le compte Apple est facultatif. Seuls ton identifiant Apple propre à l’app et ton nom sont conservés dans le trousseau sécurisé de cet iPhone. La connexion est gérée par Apple.")
                        Text("Les minuteurs utilisent les alarmes système d’iOS. La cuisine fonctionne sans connexion ; le compte Apple nécessite Internet.")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.secondaryInk)
                    .lineSpacing(3)
                    .preferencesCard()
                }
                .frame(maxWidth: 580)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.Colors.cream)
            .foregroundStyle(DesignSystem.Colors.ink)
            .navigationTitle("Petit Chef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private extension View {
    func preferencesCard() -> some View {
        self
            .padding(22)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.ink.opacity(0.025), lineWidth: 1)
            }
    }
}
