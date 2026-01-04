//
//  PartnerAvatar.swift
//  LockIn
//
//  Gradient mesh avatar component for accountability partners
//

import SwiftUI

struct PartnerAvatar: View {
    let name: String
    let odentifier: String
    let size: CGFloat
    var showOnlineIndicator: Bool = false
    var isOnline: Bool = false

    init(partner: Partner, size: CGFloat = 52, showOnlineIndicator: Bool = false, isOnline: Bool = false) {
        self.name = partner.displayName
        self.odentifier = partner.partnerId
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
        self.isOnline = isOnline
    }

    init(name: String, identifier: String, size: CGFloat = 52, showOnlineIndicator: Bool = false, isOnline: Bool = false) {
        self.name = name
        self.odentifier = identifier
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
        self.isOnline = isOnline
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var gradientColors: [Color] {
        // Generate unique gradient based on identifier hash
        let hash = abs(odentifier.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.12).truncatingRemainder(dividingBy: 1.0)
        return [
            Color(hue: hue1, saturation: 0.55, brightness: 0.92),
            Color(hue: hue2, saturation: 0.65, brightness: 0.82)
        ]
    }

    private var shadowColor: Color {
        gradientColors[0].opacity(0.35)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main avatar
            ZStack {
                // Base gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner highlight for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.35), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.7
                        )
                    )

                // Initials
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: shadowColor, radius: size * 0.15, y: size * 0.08)

            // Online indicator
            if showOnlineIndicator && isOnline {
                Circle()
                    .fill(.green)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.systemBackground), lineWidth: size * 0.05)
                    )
                    .offset(x: size * 0.04, y: size * 0.04)
            }
        }
    }
}

// MARK: - Invite Avatar (Orange theme for pending invites)

struct InviteAvatar: View {
    let name: String
    let size: CGFloat

    init(name: String, size: CGFloat = 48) {
        self.name = name
        self.size = size
    }

    init(invite: PartnerInvite, size: CGFloat = 48) {
        self.name = invite.fromUserName ?? invite.fromUserEmail
        self.size = size
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    var body: some View {
        ZStack {
            // Orange gradient for invites
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.9),
                            Color.orange.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.3), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )

            // Initials
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Color.orange.opacity(0.3), radius: size * 0.12, y: size * 0.06)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            PartnerAvatar(name: "John Doe", identifier: "abc123", size: 60, showOnlineIndicator: true, isOnline: true)
            PartnerAvatar(name: "Jane Smith", identifier: "def456", size: 60)
            PartnerAvatar(name: "Alex", identifier: "ghi789", size: 60)
        }

        HStack(spacing: 20) {
            InviteAvatar(name: "Mike Johnson", size: 52)
            InviteAvatar(name: "Sarah", size: 52)
        }
    }
    .padding()
}
