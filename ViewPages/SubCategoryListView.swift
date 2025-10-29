import SwiftUI

struct SubCategoryListView: View {
    let category: ProductCategoryGroup

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @EnvironmentObject private var notificationsManager: NotificationsManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appearanceManager: AppearanceManager

    private var hasSubCategories: Bool { !category.sortedSubCategories.isEmpty }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    Products(mainCategory: category.mainCategory, subCategory: nil)
                        .environmentObject(favoritesManager)
                        .environmentObject(notificationsManager)
                        .environmentObject(sessionManager)
                        .environmentObject(appearanceManager)
                } label: {
                    Label("كل المنتجات", systemImage: "rectangle.3.offgrid")
                        .labelStyle(TitleAndIconLabelStyle())
                }
            }

            if hasSubCategories {
                Section("الفئات الفرعية") {
                    ForEach(category.sortedSubCategories, id: \.self) { subCategory in
                        NavigationLink {
                            Products(mainCategory: category.mainCategory, subCategory: subCategory)
                                .environmentObject(favoritesManager)
                                .environmentObject(notificationsManager)
                                .environmentObject(sessionManager)
                                .environmentObject(appearanceManager)
                        } label: {
                            Text(subCategory)
                        }
                    }
                }
            } else {
                Section {
                    Text("لا توجد فئات فرعية")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.displayName)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        SubCategoryListView(
            category: ProductCategoryGroup(
                mainCategory: "الأبواب",
                subCategories: ["مفصلات", "مقابض", "إكسسوارات"]
            )
        )
        .environmentObject(SessionManager.preview())
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(AppearanceManager.preview)
    }
}
