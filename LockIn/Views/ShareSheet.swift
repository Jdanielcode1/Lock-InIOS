//
//  ShareSheet.swift
//  LockIn
//
//  Created by Claude on 28/12/25.
//

import SwiftUI
import UIKit
import Photos

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
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Title
            Text("Share to")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 24)

            // App icons grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                // WhatsApp
                ShareAppButton(
                    icon: "WhatsAppIcon",
                    systemIcon: "message.fill",
                    label: "WhatsApp",
                    color: Color(red: 37/255, green: 211/255, blue: 102/255)
                ) {
                    shareToWhatsApp()
                }

                // Instagram
                ShareAppButton(
                    icon: "InstagramIcon",
                    systemIcon: "camera.fill",
                    label: "Instagram",
                    gradientColors: [
                        Color(red: 131/255, green: 58/255, blue: 180/255),
                        Color(red: 253/255, green: 29/255, blue: 29/255),
                        Color(red: 252/255, green: 176/255, blue: 69/255)
                    ]
                ) {
                    shareToInstagram()
                }

                // X (Twitter)
                ShareAppButton(
                    icon: "XIcon",
                    systemIcon: "xmark",
                    label: "X",
                    color: .white
                ) {
                    shareToX()
                }

                // Save to Camera Roll
                ShareAppButton(
                    icon: nil,
                    systemIcon: "square.and.arrow.down.fill",
                    label: "Save",
                    color: .blue
                ) {
                    onSaveToPhotos?()
                    isPresented = false
                }

                // More (Native Share Sheet)
                ShareAppButton(
                    icon: nil,
                    systemIcon: "ellipsis",
                    label: "More",
                    color: .gray
                ) {
                    showNativeShareSheet()
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            // Cancel button
            Button {
                isPresented = false
            } label: {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.12))
        )
        .alert("Share", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Share Functions

    private func shareToWhatsApp() {
        // WhatsApp doesn't support direct video sharing via URL scheme
        // Use native share sheet with WhatsApp as target
        showNativeShareSheet()
    }

    private func shareToInstagram() {
        // Check if Instagram is installed
        guard let instagramURL = URL(string: "instagram-stories://share") else {
            alertMessage = "Could not open Instagram"
            showingAlert = true
            return
        }

        if UIApplication.shared.canOpenURL(instagramURL) {
            // Share to Instagram Stories
            shareToInstagramStories()
        } else {
            alertMessage = "Instagram is not installed"
            showingAlert = true
        }
    }

    private func shareToInstagramStories() {
        // Read video data
        guard let videoData = try? Data(contentsOf: videoURL) else {
            alertMessage = "Could not read video file"
            showingAlert = true
            return
        }

        // Instagram Stories requires video in pasteboard
        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundVideo": videoData]
        ]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // 5 minutes
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // Open Instagram Stories
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

    private func shareToX() {
        // X doesn't support direct video sharing via URL scheme
        // Use native share sheet
        showNativeShareSheet()
    }

    private func showNativeShareSheet() {
        let activityVC = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )

        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }

        isPresented = false
    }
}

// MARK: - Share App Button Component

struct ShareAppButton: View {
    let icon: String?
    let systemIcon: String
    let label: String
    var color: Color = .white
    var gradientColors: [Color]?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Background
                    if let gradientColors = gradientColors {
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        color
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    // Icon
                    Group {
                        if label == "X" {
                            // Custom X logo
                            Text("𝕏")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: systemIcon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(label == "Save" || label == "More" ? .white : .white)
                        }
                    }
                )

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Share Sheet Modifier

extension View {
    func shareSheet(isPresented: Binding<Bool>, videoURL: URL, onSaveToPhotos: (() -> Void)? = nil) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    ZStack(alignment: .bottom) {
                        // Dimmed background
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isPresented.wrappedValue = false
                            }

                        // Share sheet
                        ShareSheet(
                            videoURL: videoURL,
                            isPresented: isPresented,
                            onSaveToPhotos: onSaveToPhotos
                        )
                        .transition(.move(edge: .bottom))
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented.wrappedValue)
                }
            }
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
