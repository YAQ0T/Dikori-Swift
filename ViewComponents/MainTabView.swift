//
//  MainNavBar.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case shop, favorites, notifications
    }

    @State private var selection: Tab = .shop

    var body: some View {
        TabView(selection: $selection) {
            Products()
                .tabItem {
                    Label("المتجر",
                          systemImage: selection == .shop
                          ? "bag.fill"
                          : "bag")
                }
                .tag(Tab.shop)

            FavoritesView()
                .tabItem {
                    Label("المفضلة",
                          systemImage: selection == .favorites
                          ? "heart.fill"
                          : "heart")
                }
                .tag(Tab.favorites)

            NotificationsView()
                .tabItem {
                    Label("الإشعارات",
                          systemImage: selection == .notifications
                          ? "bell.fill"
                          : "bell")
                }
                .tag(Tab.notifications)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .tint(Color.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager())
}
