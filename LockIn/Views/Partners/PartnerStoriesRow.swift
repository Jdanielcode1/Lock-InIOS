//
//  PartnerStoriesRow.swift
//  LockIn
//
//  Instagram Stories-style horizontal row of partner avatars
//

import SwiftUI

struct PartnerStoriesRow: View {
    let partners: [Partner]
    let hasNewVideos: (String) -> Bool
    let onTapUser: () -> Void
    let onTapPartner: (Partner) -> Void
    let onTapAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // "You" avatar - first position
                StoryAvatarButton(
                    name: "You",
                    identifier: "current-user",
                    hasNew: false,
                    isCurrentUser: true,
                    action: onTapUser
                )

                // Partner avatars
                ForEach(partners) { partner in
                    StoryAvatarButton(
                        name: partner.displayName,
                        identifier: partner.partnerId,
                        hasNew: hasNewVideos(partner.partnerId),
                        isCurrentUser: false,
                        action: { onTapPartner(partner) }
                    )
                }

                // Add partner button
                AddStoryButton(action: onTapAdd)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Story Avatar Button

struct StoryAvatarButton: View {
    let name: String
    let identifier: String
    let hasNew: Bool
    let isCurrentUser: Bool
    let action: () -> Void

    private let size: CGFloat = 68
    private let borderWidth: CGFloat = 3

    private var initials: String {
        if isCurrentUser { return "You" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    private var gradientColors: [Color] {
        if isCurrentUser {
            return [.accentColor, .purple]
        }
        let hash = abs(identifier.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.12).truncatingRemainder(dividingBy: 1.0)
        return [
            Color(hue: hue1, saturation: 0.55, brightness: 0.92),
            Color(hue: hue2, saturation: 0.65, brightness: 0.82)
        ]
    }

    private var ringGradient: LinearGradient {
        if hasNew {
            // Colorful gradient ring for new content (like IG)
            return LinearGradient(
                colors: [.pink, .orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Subtle gray ring for viewed
            return LinearGradient(
                colors: [Color(.systemGray4), Color(.systemGray5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            VStack(spacing: 6) {
                // Avatar with ring
                ZStack {
                    // Ring (gradient border)
                    Circle()
                        .stroke(ringGradient, lineWidth: borderWidth)
                        .frame(width: size + borderWidth * 2, height: size + borderWidth * 2)

                    // Avatar background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)

                    // Inner highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.35), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: size * 0.7
                            )
                        )
                        .frame(width: size, height: size)

                    // Initials or icon
                    if isCurrentUser {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.35, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(initials)
                            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                    }
                }

                // Name label
                Text(isCurrentUser ? "You" : name.components(separatedBy: " ").first ?? name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: size + 8)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Add Story Button

struct AddStoryButton: View {
    let action: () -> Void

    private let size: CGFloat = 68

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Dashed circle border
                    Circle()
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                        .foregroundStyle(Color(.systemGray3))
                        .frame(width: size, height: size)

                    // Plus icon
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                }

                Text("Add")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PartnerStoriesRow(
            partners: [
                Partner(_id: "1", userId: "u1", partnerId: "p1", partnerEmail: "alex@email.com", partnerName: "Alex Chen", status: .active, createdAt: 0),
                Partner(_id: "2", userId: "u1", partnerId: "p2", partnerEmail: "sarah@email.com", partnerName: "Sarah Kim", status: .active, createdAt: 0),
                Partner(_id: "3", userId: "u1", partnerId: "p3", partnerEmail: "mike@email.com", partnerName: "Mike Johnson", status: .active, createdAt: 0)
            ],
            hasNewVideos: { id in id == "p1" || id == "p2" },
            onTapUser: { print("Tapped user") },
            onTapPartner: { print("Tapped \($0.displayName)") },
            onTapAdd: { print("Add partner") }
        )
        .background(Color(.systemGroupedBackground))
    }
}
