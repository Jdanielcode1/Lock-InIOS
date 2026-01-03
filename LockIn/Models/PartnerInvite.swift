//
//  PartnerInvite.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import Foundation

struct PartnerInvite: Identifiable, Codable {
    let _id: String
    let fromUserId: String
    let fromUserEmail: String
    let fromUserName: String?
    let toEmail: String
    let toUserId: String?
    let status: InviteStatus
    let createdAt: Double
    let expiresAt: Double

    var id: String { _id }

    var senderDisplayName: String {
        fromUserName ?? fromUserEmail
    }

    var isExpired: Bool {
        Date().timeIntervalSince1970 * 1000 > expiresAt
    }

    var timeUntilExpiry: TimeInterval {
        let expiryDate = Date(timeIntervalSince1970: expiresAt / 1000)
        return expiryDate.timeIntervalSinceNow
    }

    var expiryDescription: String {
        if isExpired {
            return "Expired"
        }
        let days = Int(timeUntilExpiry / 86400)
        if days > 0 {
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        }
        let hours = Int(timeUntilExpiry / 3600)
        if hours > 0 {
            return "Expires in \(hours) hour\(hours == 1 ? "" : "s")"
        }
        return "Expires soon"
    }
}

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }
}
