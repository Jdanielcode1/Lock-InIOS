//
//  ShareSheet.swift
//  LockIn
//
//  Created by Claude on 28/12/25.
//

import SwiftUI
import UIKit
import Photos

// MARK: - Share Platform Enum

enum SharePlatform: CaseIterable {
    case instagram
    case tiktok
    case whatsapp
    case x
    case messages
    case more

    var name: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .whatsapp: return "WhatsApp"
        case .x: return "X"
        case .messages: return "Messages"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .whatsapp: return "phone.fill"
        case .x: return "xmark"
        case .messages: return "message.fill"
        case .more: return "ellipsis"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .instagram: return .clear // Uses gradient
        case .tiktok: return .black
        case .whatsapp: return Color(red: 37/255, green: 211/255, blue: 102/255)
        case .x: return .black
        case .messages: return Color(red: 52/255, green: 199/255, blue: 89/255)
        case .more: return Color(white: 0.3)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .instagram, .tiktok, .whatsapp, .x, .messages, .more:
            return .white
        }
    }

    var gradient: [Color]? {
        switch self {
        case .instagram:
            return [
                Color(red: 131/255, green: 58/255, blue: 180/255),
                Color(red: 253/255, green: 29/255, blue: 29/255),
                Color(red: 252/255, green: 176/255, blue: 69/255)
            ]
        default:
            return nil
        }
    }
}

// MARK: - Share App Icon Component

struct ShareAppIcon: View {
    let platform: SharePlatform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Background
                    if let gradient = platform.gradient {
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        platform.backgroundColor
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Group {
                        if platform == .x {
                            Text("𝕏")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        } else if platform == .tiktok {
                            // TikTok-style icon
                            ZStack {
                                Image(systemName: "music.note")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(red: 0/255, green: 242/255, blue: 234/255))
                                    .offset(x: -1, y: -1)
                                Image(systemName: "music.note")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color(red: 255/255, green: 0/255, blue: 80/255))
                                    .offset(x: 1, y: 1)
                                Image(systemName: "music.note")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Image(systemName: platform.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(platform.foregroundColor)
                        }
                    }
                )

                Text(platform.name)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    var onSaveToPhotos: (() -> Void)?

    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // App icons row (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ShareAppIcon(platform: .instagram) { shareToInstagram() }
                    ShareAppIcon(platform: .tiktok) { shareToTikTok() }
                    ShareAppIcon(platform: .whatsapp) { shareToWhatsApp() }
                    ShareAppIcon(platform: .x) { shareToX() }
                    ShareAppIcon(platform: .messages) { shareToMessages() }
                    ShareAppIcon(platform: .more) { showNativeShareSheet() }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Save to Photos button
            Button {
                onSaveToPhotos?()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Save to Photos")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .alert("Share", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Share Functions

    private func shareToWhatsApp() {
        // Check if WhatsApp is installed
        guard let whatsappURL = URL(string: "whatsapp://"),
              UIApplication.shared.canOpenURL(whatsappURL) else {
            alertMessage = "WhatsApp is not installed"
            showingAlert = true
            return
        }

        // WhatsApp URL schemes don't support video attachments
        // Native share sheet is the only reliable method for video sharing
        showNativeShareSheet()
    }

    private func shareToInstagram() {
        guard let instagramURL = URL(string: "instagram-stories://share") else {
            alertMessage = "Could not open Instagram"
            showingAlert = true
            return
        }

        if UIApplication.shared.canOpenURL(instagramURL) {
            shareToInstagramStories()
        } else {
            alertMessage = "Instagram is not installed"
            showingAlert = true
        }
    }

    private func shareToInstagramStories() {
        guard let videoData = try? Data(contentsOf: videoURL) else {
            alertMessage = "Could not read video file"
            showingAlert = true
            return
        }

        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundVideo": videoData]
        ]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        if let url = URL(string: "instagram-stories://share?source_application=com.lockin.app") {
            UIApplication.shared.open(url) { success in
                if !success {
                    DispatchQueue.main.async {
                        alertMessage = "Could not open Instagram Stories"
                        showingAlert = true
                    }
                }
            }
        }

        isPresented = false
    }

    private func shareToTikTok() {
        // Check if TikTok is installed
        guard let tiktokURL = URL(string: "snssdk1233://"),
              UIApplication.shared.canOpenURL(tiktokURL) else {
            alertMessage = "TikTok is not installed"
            showingAlert = true
            return
        }

        // Save video to Photos first, then open TikTok
        saveVideoThenOpenApp(urlScheme: "snssdk1233://")
    }

    private func shareToX() {
        // Check if X is installed
        guard let xURL = URL(string: "twitter://"),
              UIApplication.shared.canOpenURL(xURL) else {
            alertMessage = "X is not installed"
            showingAlert = true
            return
        }

        // Save video to Photos first, then open X
        saveVideoThenOpenApp(urlScheme: "twitter://")
    }

    private func shareToMessages() {
        // Messages is always available, use native share sheet
        showNativeShareSheet()
    }

    private func saveVideoThenOpenApp(urlScheme: String) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.alertMessage = "Photo library access required"
                    self.showingAlert = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoURL)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        if let url = URL(string: urlScheme) {
                            UIApplication.shared.open(url)
                        }
                        self.isPresented = false
                    } else {
                        self.alertMessage = "Could not save video"
                        self.showingAlert = true
                    }
                }
            }
        }
    }

    private func showNativeShareSheet() {
        let activityVC = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }

        isPresented = false
    }
}

// MARK: - Share Sheet Modifier

extension View {
    func shareSheet(
        isPresented: Binding<Bool>,
        videoURL: URL,
        onSaveToPhotos: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            ZStack(alignment: .bottom) {
                // Dimmed background
                if isPresented.wrappedValue {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isPresented.wrappedValue = false
                            }
                        }
                        .transition(.opacity)
                }

                // Share sheet
                if isPresented.wrappedValue {
                    ShareSheet(
                        videoURL: videoURL,
                        isPresented: isPresented,
                        onSaveToPhotos: onSaveToPhotos
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented.wrappedValue)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ShareSheet(
            videoURL: URL(string: "file:///test.mov")!,
            isPresented: .constant(true)
        )
    }
}
