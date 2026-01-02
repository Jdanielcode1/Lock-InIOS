//
//  FirebaseAuthProvider.swift
//  LockIn
//
//  Custom AuthProvider implementation for Firebase Authentication with Convex
//

import Foundation
import ConvexMobile
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import CryptoKit

/// Firebase user wrapper that holds the authenticated user and ID token
public struct FirebaseAuthResult {
    let user: User
    let idToken: String
}

/// Authentication provider for Firebase that conforms to Convex's AuthProvider protocol
public class FirebaseAuthProvider: AuthProvider {
    public typealias T = FirebaseAuthResult

    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<FirebaseAuthResult, Error>?

    public init() {}

    // MARK: - AuthProvider Protocol

    /// Trigger login - this will be called from AuthModel which handles the UI
    /// For Firebase, we provide specific login methods instead
    public func login() async throws -> FirebaseAuthResult {
        // This is a fallback - typically you'd call specific methods like signInWithApple()
        // For anonymous login as default
        return try await signInAnonymously()
    }

    /// Re-authenticate using cached Firebase session
    public func loginFromCache() async throws -> FirebaseAuthResult {
        guard let currentUser = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }

        // Get fresh ID token
        let idToken = try await currentUser.getIDToken()
        return FirebaseAuthResult(user: currentUser, idToken: idToken)
    }

    /// Extract the JWT ID token from the auth result
    public func extractIdToken(from authResult: FirebaseAuthResult) -> String {
        return authResult.idToken
    }

    /// Sign out of Firebase
    public func logout() async throws {
        try Auth.auth().signOut()
    }

    // MARK: - Sign-In Methods

    /// Sign in anonymously (guest mode)
    public func signInAnonymously() async throws -> FirebaseAuthResult {
        let result = try await Auth.auth().signInAnonymously()
        let idToken = try await result.user.getIDToken()
        return FirebaseAuthResult(user: result.user, idToken: idToken)
    }

    /// Sign in with Google
    @MainActor
    public func signInWithGoogle() async throws -> FirebaseAuthResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw FirebaseAuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw FirebaseAuthError.missingGoogleIdToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseIdToken = try await authResult.user.getIDToken()
        return FirebaseAuthResult(user: authResult.user, idToken: firebaseIdToken)
    }

    /// Sign in with Apple - returns the credential for use with Firebase
    @MainActor
    public func signInWithApple() async throws -> FirebaseAuthResult {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()
        authorizationController.delegate = delegate

        // Get the presenting window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            throw FirebaseAuthError.noRootViewController
        }

        authorizationController.presentationContextProvider = ApplePresentationContext(window: window)

        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            delegate.nonce = nonce
            authorizationController.performRequests()
        }
    }

    /// Get a fresh ID token for the current user
    public func refreshToken() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUserLoggedIn
        }
        return try await currentUser.getIDToken(forcingRefresh: true)
    }

    /// Check if a user is currently signed in
    public var isUserSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }

    /// Get the current user if signed in
    public var currentUser: User? {
        return Auth.auth().currentUser
    }

    // MARK: - Helper Methods

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    var continuation: CheckedContinuation<FirebaseAuthResult, Error>?
    var nonce: String?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = nonce else {
            continuation?.resume(throwing: FirebaseAuthError.invalidAppleCredential)
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Task {
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                let firebaseIdToken = try await authResult.user.getIDToken()
                continuation?.resume(returning: FirebaseAuthResult(user: authResult.user, idToken: firebaseIdToken))
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }
}

// MARK: - Apple Presentation Context

private class ApplePresentationContext: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window
    }
}

// MARK: - Errors

public enum FirebaseAuthError: LocalizedError {
    case noUserLoggedIn
    case noRootViewController
    case missingGoogleIdToken
    case invalidAppleCredential

    public var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        case .noRootViewController:
            return "Could not find root view controller for authentication"
        case .missingGoogleIdToken:
            return "Google Sign-In did not return an ID token"
        case .invalidAppleCredential:
            return "Invalid Apple Sign-In credential"
        }
    }
}
