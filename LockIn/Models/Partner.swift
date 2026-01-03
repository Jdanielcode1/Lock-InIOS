//
//  Partner.swift
//  LockIn
//
//  Created by Claude on 02/01/26.
//

import Foundation

struct Partner: Identifiable, Codable {
    let _id: String
    let userId: String
    let partnerId: String
    let partnerEmail: String
    let partnerName: String?
    let status: PartnerStatus
    let createdAt: Double

    var id: String { _id }

    var displayName: String {
        partnerName ?? partnerEmail
    }

    var initials: String {
        if let name = partnerName, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return String(partnerEmail.prefix(2)).uppercased()
    }
}

enum PartnerStatus: String, Codable {
    case pending
    case active
    case declined

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .active: return "Active"
        case .declined: return "Declined"
        }
    }
}
