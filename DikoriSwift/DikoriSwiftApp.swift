//
//  DikoriSwiftApp.swift
//  DikoriSwift
//
//  Created by Ahmad Salous on 21/10/2025.
//

import SwiftUI

@main
struct DikoriSwiftApp: App {
    init() {
        RecaptchaManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
