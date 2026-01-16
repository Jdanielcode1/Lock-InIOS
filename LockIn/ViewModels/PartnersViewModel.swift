//
//  PartnersViewModel.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import Foundation
import Combine
import ConvexMobile
import UIKit

@MainActor
class PartnersViewModel: ObservableObject {
    @Published var partners: [Partner] = []
    @Published var sentInvites: [PartnerInvite] = []
    @Published var receivedInvites: [PartnerInvite] = []
    @Published var sharedWithMe: [SharedVideo] = []
    @Published var pendingInviteCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var dataSubscriptions = Set<AnyCancellable>()  // Separate subscriptions for data (can be cancelled on auth loss)
    private var isSubscribed = false  // Track subscription state to avoid duplicates
    private let convexService = ConvexService.shared

    init() {
        monitorAuthAndSubscribe()
    }

    /// Continuously monitor auth state and subscribe/unsubscribe accordingly
    /// This ensures we recover from auth token expiration
    private func monitorAuthAndSubscribe() {
        isLoading = true

        convexClient.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }

                switch state {
                case .authenticated:
                    // Only subscribe if not already subscribed (avoid duplicates)
                    if !self.isSubscribed {
                        print("🔄 PartnersViewModel: Auth recovered, re-subscribing...")
                        self.subscribeToPartners()
                    }
                case .unauthenticated:
                    // Cancel data subscriptions on auth loss (will re-subscribe on recovery)
                    self.cancelDataSubscriptions()
                case .loading:
                    // Keep current state while loading
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToPartners() {
        isSubscribed = true

        // Subscribe to active partners
        convexService.listPartners()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] partners in
                self?.partners = partners
                self?.isLoading = false
            }
            .store(in: &dataSubscriptions)

        // Subscribe to sent invites
        convexService.listSentInvites()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] invites in
                self?.sentInvites = invites
            }
            .store(in: &dataSubscriptions)

        // Subscribe to received invites
        convexService.listReceivedInvites()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] invites in
                self?.receivedInvites = invites
            }
            .store(in: &dataSubscriptions)

        // Subscribe to pending invite count (for badge)
        convexService.getPendingInviteCount()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.pendingInviteCount = count
            }
            .store(in: &dataSubscriptions)

        // Subscribe to videos shared with me
        convexService.listSharedWithMe()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                // Deduplicate by ID to prevent any duplicate entries
                var seen = Set<String>()
                let uniqueVideos = videos.filter { seen.insert($0.id).inserted }
                self?.sharedWithMe = uniqueVideos
            }
            .store(in: &dataSubscriptions)
    }

    private func cancelDataSubscriptions() {
        dataSubscriptions.removeAll()
        isSubscribed = false
        // Don't clear data - keep showing cached data
        print("⚠️ PartnersViewModel: Auth lost, subscriptions cancelled (keeping cached data)")
    }

    // MARK: - Actions

    func sendInvite(email: String) async -> Bool {
        do {
            _ = try await convexService.sendPartnerInvite(email: email)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            ErrorAlertManager.shared.show(.saveFailed("Couldn't send invite. Please try again."))
            return false
        }
    }

    func acceptInvite(_ invite: PartnerInvite) async {
        do {
            try await convexService.acceptPartnerInvite(inviteId: invite.id)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            ErrorAlertManager.shared.show(.saveFailed("Couldn't accept invite. Please try again."))
        }
    }

    func declineInvite(_ invite: PartnerInvite) async {
        do {
            try await convexService.declinePartnerInvite(inviteId: invite.id)
        } catch {
            errorMessage = error.localizedDescription
            ErrorAlertManager.shared.show(.saveFailed("Couldn't decline invite. Please try again."))
        }
    }

    func cancelInvite(_ invite: PartnerInvite) async {
        do {
            try await convexService.cancelPartnerInvite(inviteId: invite.id)
        } catch {
            errorMessage = error.localizedDescription
            ErrorAlertManager.shared.show(.saveFailed("Couldn't cancel invite. Please try again."))
        }
    }

    func removePartner(_ partner: Partner) async {
        do {
            try await convexService.removePartner(partnerId: partner.id)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            ErrorAlertManager.shared.show(.saveFailed("Couldn't remove partner. Please try again."))
        }
    }
}
