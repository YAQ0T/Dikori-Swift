//
//  ContentView.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var notificationsManager = NotificationsManager()
    @StateObject private var ordersManager = OrdersManager()
    @StateObject private var appearanceManager = AppearanceManager()

    var body: some View {
        AuthFlowView()
            .environmentObject(sessionManager)
            .environmentObject(favoritesManager)
            .environmentObject(notificationsManager)
            .environmentObject(ordersManager)
            .environmentObject(appearanceManager)
            .preferredColorScheme(appearanceManager.preferredColorScheme)
    }
}

#Preview {
    ContentView()
}
