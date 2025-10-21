//
//  MainNavBar.swift
//  DikoriLearn
//
//  Created by Ahmad Salous on 18/10/2025.
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case shop, cart, account
    }

    @State private var selection: Tab = .shop

    var body: some View {
        TabView(selection: $selection) {
            // MARK: Shop
            Color.clear // استبدل بـ ShopView()
                .tabItem {
                    Label("Shop",
                          systemImage: selection == .shop
                          ? "rectangle.on.rectangle.circle.fill"
                          : "rectangle.on.rectangle.circle")
                }
                .tag(Tab.shop)

            // MARK: Cart
            Color.clear // استبدل بـ CartView()
                .tabItem {
                    Label("Cart",
                          systemImage: selection == .cart
                          ? "cart.fill"
                          : "cart")
                }
                .tag(Tab.cart)
                .badge(2) // عدّل الرقم أو احذفه

            // MARK: Account
            Color.clear // استبدل بـ AccountView()
                .tabItem {
                    Label("Account",
                          systemImage: selection == .account
                          ? "person.crop.circle.fill"
                          : "person.crop.circle")
                }
                .tag(Tab.account)
        }
        // ستايل أنيق للتاب بار
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .tint(Color.blue) // لون العنصر المحدد
        .frame(height: 50)
    }
}

#Preview {
    MainTabView()
}
