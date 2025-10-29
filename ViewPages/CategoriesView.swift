import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @EnvironmentObject private var notificationsManager: NotificationsManager
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var appearanceManager: AppearanceManager

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var categories: [ProductCategoryGroup] = []

    var body: some View {
        NavigationStack {
            switch viewState {
            case .loading:
                loadingView
            case .error(let message):
                errorView(message: message)
            case .empty:
                emptyStateView
            case .content:
                categoriesList
            }
        }
        .navigationTitle("الفئات")
        .background(Color(.systemGroupedBackground))
        .task {
            await loadCategories()
        }
        .refreshable {
            await loadCategories(force: true)
        }
    }

    @MainActor
    private func loadCategories(force: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        errorMessage = nil

        do {
            categories = try await ProductService.shared.fetchCategoryGroups()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private enum ViewState {
        case loading
        case error(String)
        case empty
        case content
    }

    private var viewState: ViewState {
        if isLoading && categories.isEmpty {
            return .loading
        }

        if let message = errorMessage, categories.isEmpty {
            return .error(message)
        }

        if categories.isEmpty {
            return .empty
        }

        return .content
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("لا توجد فئات متاحة حالياً")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var categoriesList: some View {
        List {
            ForEach(categories) { category in
                NavigationLink {
                    SubCategoryListView(category: category)
                        .environmentObject(favoritesManager)
                        .environmentObject(notificationsManager)
                        .environmentObject(sessionManager)
                        .environmentObject(appearanceManager)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.displayName)
                                .font(.headline)
                            Text("\(category.sortedSubCategories.count) فئة فرعية")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundColor(.tertiaryLabel)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    CategoriesView()
        .environmentObject(SessionManager.preview())
        .environmentObject(FavoritesManager())
        .environmentObject(NotificationsManager.preview())
        .environmentObject(OrdersManager.preview())
        .environmentObject(AppearanceManager.preview)
}
