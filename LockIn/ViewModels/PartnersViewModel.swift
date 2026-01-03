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
    private let convexService = ConvexService.shared

    init() {
        waitForAuthThenSubscribe()
    }

    private func waitForAuthThenSubscribe() {
        isLoading = true

        convexClient.authState
            .compactMap { state -> Bool? in
                switch state {
                case .authenticated:
                    return true
                case .unauthenticated, .loading:
                    return nil
                }
            }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.subscribeToPartners()
            }
            .store(in: &cancellables)
    }

    private func subscribeToPartners() {
        // Subscribe to active partners
        convexService.listPartners()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] partners in
                self?.partners = partners
                self?.isLoading = false
            }
            .store(in: &cancellables)

        // Subscribe to sent invites
        convexService.listSentInvites()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] invites in
                self?.sentInvites = invites
            }
            .store(in: &cancellables)

        // Subscribe to received invites
        convexService.listReceivedInvites()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] invites in
                self?.receivedInvites = invites
            }
            .store(in: &cancellables)

        // Subscribe to pending invite count (for badge)
        convexService.getPendingInviteCount()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.pendingInviteCount = count
            }
            .store(in: &cancellables)

        // Subscribe to videos shared with me
        convexService.listSharedWithMe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.sharedWithMe = videos
            }
            .store(in: &cancellables)
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
