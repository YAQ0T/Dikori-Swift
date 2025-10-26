//
//  ContentView.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var notificationsManager = NotificationsManager()

    var body: some View {
        MainTabView()
            .environmentObject(favoritesManager)
            .environmentObject(notificationsManager)
    }
}

#Preview {
    ContentView()
}
