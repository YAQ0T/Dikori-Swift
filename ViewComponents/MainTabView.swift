//
//  MainNavBar.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case shop, categories, account
    }

    @EnvironmentObject private var appearanceManager: AppearanceManager
    @State private var selection: Tab = .shop

    var body: some View {
        TabView(selection: $selection) {
            Products(mainCategory: nil, subCategory: nil)
                .tabItem {
                    Label("المتجر",
                          systemImage: selection == .shop
                          ? "bag.fill"
                          : "bag")
                }
                .tag(Tab.shop)

            CategoriesView()
                .tabItem {
                    Label("الفئات",
                          systemImage: selection == .categories
                          ? "square.grid.2x2.fill"
                          : "square.grid.2x2")
                }
                .tag(Tab.categories)

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
