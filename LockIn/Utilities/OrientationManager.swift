//
//  OrientationManager.swift
//  LockIn
//
//  Created by Claude on 26/12/25.
//

import SwiftUI

class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    func lockToPortrait() {
        allowedOrientations = .portrait

        // Force rotation back to portrait using modern API
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                print("Orientation update error: \(error.localizedDescription)")
            }
        }
    }

    func allowAllOrientations() {
        allowedOrientations = .allButUpsideDown

        // Notify system that supported orientations changed
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown)) { error in
                print("Orientation update error: \(error.localizedDescription)")
            }
        }

        UIViewController.attemptRotationToDeviceOrientation()
    }
}
