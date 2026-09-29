import AuthenticationServices
import Foundation
import Observation
import OSLog
import Security

/// The optional Apple identity is kept only on this device. It never gates cooking.
@MainActor
@Observable
final class AccountStore {
    private(set) var isAuthenticating = false
    private(set) var isRefreshing = false
    var errorMessage: String?

    private var account: StoredAppleAccount?
    @ObservationIgnored private var identityRevision = 0
    @ObservationIgnored private var revocationTask: Task<Void, Never>?

    var isSignedIn: Bool { account != nil }
    var displayName: String { account?.displayName ?? "Compte Apple" }

    init() {
        do {
            account = try AppleAccountKeychain.load()
        } catch {
            // An unavailable keychain (including an unsigned simulator) does not
            // mean an account exists. Only an explicit sign-in presents an alert.
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "PetitChef", category: "Account")
                .error("L’identité Apple locale n’a pas pu être restaurée.")
        }

        revocationTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ASAuthorizationAppleIDProvider.credentialRevokedNotification
            )
            for await _ in notifications {
                guard !Task.isCancelled else { break }
                await self?.refreshCredentialState()
            }
        }
    }

    deinit {
        revocationTask?.cancel()
    }

    func beginAuthorization() {
        errorMessage = nil
        isAuthenticating = true
    }

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        isAuthenticating = false
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  !credential.user.isEmpty else {
                errorMessage = "Apple n’a pas renvoyé de compte valide. Réessaie dans un instant."
                return
            }

            let name = credential.fullName.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let previousName = account?.userID == credential.user ? account?.displayName : nil
            let savedAccount = StoredAppleAccount(
                userID: credential.user,
                displayName: name.flatMap { $0.isEmpty ? nil : $0 } ?? previousName
            )

            do {
                try AppleAccountKeychain.save(savedAccount)
                identityRevision += 1
                account = savedAccount
                errorMessage = nil
            } catch {
                errorMessage = "La connexion a réussi, mais le compte n’a pas pu être enregistré sur cet iPhone. Réessaie."
            }

        case .failure(let error):
            // Dismissing Apple's own sheet is a normal action, not an error.
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                errorMessage = nil
                return
            }
            errorMessage = "La connexion Apple n’a pas abouti. Tu peux réessayer ou cuisiner sans compte."
        }
    }

    /// Network failures preserve the local identity; confirmed revocations remove it.
    func refreshCredentialState() async {
        guard let userID = account?.userID, !isRefreshing else { return }
        let revision = identityRevision
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let state = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>) in
                ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: state)
                    }
                }
            }
            guard !Task.isCancelled, revision == identityRevision, account?.userID == userID else { return }

            switch state {
            case .authorized:
                break
            case .revoked, .notFound, .transferred:
                do {
                    try AppleAccountKeychain.remove()
                    identityRevision += 1
                    account = nil
                    errorMessage = "Reconnecte ton compte Apple quand tu le souhaites."
                } catch {
                    // A revoked identity must not continue appearing as signed in.
                    identityRevision += 1
                    account = nil
                    errorMessage = "Le compte Apple a été déconnecté. Son enregistrement local n’a pas pu être effacé."
                }
            @unknown default:
                break
            }
        } catch {
            // Cooking remains available offline. Retry on the next foreground entry.
        }
    }

    /// This clears this app's local identity, without changing the user's Apple account.
    func signOut() {
        do {
            try AppleAccountKeychain.remove()
            identityRevision += 1
            account = nil
            errorMessage = nil
        } catch {
            errorMessage = "Le compte n’a pas pu être effacé de cet iPhone. Réessaie."
        }
    }
}

private struct StoredAppleAccount: Codable {
    let userID: String
    let displayName: String?
}

private enum AppleAccountKeychain {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(Bundle.main.bundleIdentifier ?? "PetitChef").apple-account",
            kSecAttrAccount as String: "current-user"
        ]
    }

    static func load() throws -> StoredAppleAccount? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainFailure(status: status)
        }
        return try JSONDecoder().decode(StoredAppleAccount.self, from: data)
    }

    static func save(_ account: StoredAppleAccount) throws {
        let data = try JSONEncoder().encode(account)
        let values: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainFailure(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainFailure(status: status)
        }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainFailure(status: status)
        }
    }

    private struct KeychainFailure: Error {
        let status: OSStatus
    }
}
