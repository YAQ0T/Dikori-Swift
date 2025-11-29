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
    @StateObject private var cartManager = CartManager()

    var body: some View {
        AuthFlowView()
            .environmentObject(sessionManager)
            .environmentObject(favoritesManager)
            .environmentObject(notificationsManager)
            .environmentObject(ordersManager)
            .environmentObject(appearanceManager)
            .environmentObject(cartManager)
            .preferredColorScheme(appearanceManager.activeScheme)
    }
}

#Preview {
    ContentView()
}
