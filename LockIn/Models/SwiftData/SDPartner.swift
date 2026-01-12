//
//  SDPartner.swift
//  LockIn
//
//  SwiftData model for local caching of Partner data from Convex
//

import Foundation
import SwiftData

@Model
final class SDPartner {
    @Attribute(.unique) var convexId: String
    var userId: String
    var partnerId: String
    var partnerEmail: String
    var partnerName: String?
    var status: String  // "pending", "active", "declined"
    var createdAt: Double
    var lastSyncedAt: Date

    init(
        convexId: String,
        userId: String,
        partnerId: String,
        partnerEmail: String,
        partnerName: String?,
        status: String,
        createdAt: Double
    ) {
        self.convexId = convexId
        self.userId = userId
        self.partnerId = partnerId
        self.partnerEmail = partnerEmail
        self.partnerName = partnerName
        self.status = status
        self.createdAt = createdAt
        self.lastSyncedAt = Date()
    }

    /// Initialize from Convex Partner model
    convenience init(from partner: Partner) {
        self.init(
            convexId: partner.id,
            userId: partner.userId,
            partnerId: partner.partnerId,
            partnerEmail: partner.partnerEmail,
            partnerName: partner.partnerName,
            status: partner.status.rawValue,
            createdAt: partner.createdAt
        )
    }

    /// Update from Convex Partner model
    func update(from partner: Partner) {
        self.partnerEmail = partner.partnerEmail
        self.partnerName = partner.partnerName
        self.status = partner.status.rawValue
        self.lastSyncedAt = Date()
    }

    /// Convert back to Convex Partner model
    func toPartner() -> Partner {
        Partner(
            _id: convexId,
            userId: userId,
            partnerId: partnerId,
            partnerEmail: partnerEmail,
            partnerName: partnerName,
            status: PartnerStatus(rawValue: status) ?? .pending,
            createdAt: createdAt
        )
    }
}
