//
//  MainNavBar.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case shop, favorites, account
    }

    @EnvironmentObject private var appearanceManager: AppearanceManager
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

            AccountView()
                .tabItem {
                    Label("حسابي",
                          systemImage: selection == .account
                          ? "person.crop.circle.fill"
                          : "person.crop.circle")
                }
                .tag(Tab.account)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .applyTabBarColorScheme(appearanceManager.activeScheme)
        .tint(Color.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SessionManager.preview())
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(AppearanceManager.preview)
}

private extension View {
    @ViewBuilder
    func applyTabBarColorScheme(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            toolbarColorScheme(scheme, for: .tabBar)
        } else {
            self
        }
    }
}
