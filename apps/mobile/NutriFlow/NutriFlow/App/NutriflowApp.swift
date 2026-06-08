import SwiftUI

@main
struct NutriflowApp: App {

    private let container = AppDependencyContainer()
    private let coordinator: AppCoordinator

    init() {
        self.coordinator = AppCoordinator(container: container)
    }

    var body: some Scene {
        WindowGroup {
            coordinator.startView()
                .task {
                    await coordinator.bootstrap()
                }
        }
    }
}


/*
Ок, вот финальная версия твоей структуры с учётом всех исправлений: **удалены сервисы внутри Features, добавлены Factory, State оставлены только для UI, Core-сервисы централизованы, Shared оптимизирован**.

---

Nutriflow/
├── App/
│   ├── NutriflowApp.swift           — @main
│   └── AppDelegate.swift            — опционально, push/lifecycle

├── Core/
│   ├── Config/
│   │   └── Config.swift             — глобальные настройки
│   ├── Theme/
│   │   └── AppTheme.swift           — цвета, шрифты
│   ├── Storage/
│   │   ├── KeychainService.swift    — хранение токенов/данных
│   │   └── TokenStorage.swift       — реализация токенов
│   ├── Networking/
│   │   ├── HTTPClient.swift         — протокол
│   │   ├── URLSessionHTTPClient.swift
│   │   ├── APIRequest.swift
│   │   ├── APIError.swift
│   │   └── Endpoints/               — все эндпоинты
│   │       ├── AuthEndpoints.swift
│   │       ├── ProfileEndpoints.swift
│   │       ├── FoodEndpoints.swift
│   │       ├── WaterTrackingEndpoints.swift
│   │       ├── DailySummaryEndpoints.swift
│   │       └── UsersEndpoints.swift
│   ├── DI/
│   │   ├── AppDependency.swift      — протокол зависимостей
│   │   └── AppDependencyContainer.swift — создаёт сервисы + фабрики
│   ├── Navigation/
│   │   ├── AppRouter.swift          — enum + маршруты
│   │   └── AppCoordinator.swift     — логика навигации
│   └── Extensions/
│       ├── View+Extensions.swift
│       └── Color+Extensions.swift

├── Features/
│   ├── Auth/
│   │   ├── Factory/
│   │   │   └── AuthFactory.swift    — создаёт AuthView + ViewModel с Core сервисами
│   │   ├── Models/
│   │   │   └── AuthModel.swift
│   │   ├── State/
│   │   │   └── AuthState.swift
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   ├── Views/
│   │   │   └── AuthView.swift
│   │   └── Components/
│   │       ├── AppTextField.swift
│   │       ├── AppCard.swift
│   │       ├── AuthHeaderView.swift
│   │       ├── AuthPasswordField.swift
│   │       └── PrimaryButton.swift

│   ├── Profile/
│   │   ├── Factory/
│   │   │   └── ProfileFactory.swift
│   │   ├── Models/
│   │   │   └── ProfileModel.swift
│   │   ├── State/
│   │   │   └── ProfileState.swift
│   │   ├── ViewModels/
│   │   │   └── ProfileViewModel.swift
│   │   ├── Views/
│   │   │   ├── EditProfileView.swift
│   │   │   ├── ProfileFormView.swift
│   │   │   ├── ProfileDisplayView.swift
│   │   │   ├── ProfileTabView.swift
│   │   │   └── ProfileTabFlow.swift
│   │   └── Components/
│   │       └── ProfileInfoCard.swift

│   ├── Food/
│   │   ├── Factory/
│   │   │   └── FoodFactory.swift
│   │   ├── Models/
│   │   │   └── FoodModels.swift
│   │   ├── State/
│   │   │   └── FoodState.swift
│   │   ├── ViewModels/
│   │   │   └── FoodViewModel.swift
│   │   ├── Views/
│   │   │   └── AddFoodView.swift
│   │   └── Components/
│   │       ├── FoodCard.swift
│   │       └── FoodSection.swift

│   ├── WaterTracking/
│   │   ├── Factory/
│   │   │   └── WaterTrackingFactory.swift
│   │   ├── Models/
│   │   │   └── WaterModels.swift
│   │   ├── State/
│   │   │   └── WaterState.swift
│   │   ├── ViewModels/
│   │   │   └── WaterViewModel.swift
│   │   ├── Views/
│   │   │   └── AddWaterView.swift
│   │   └── Components/
│   │       ├── WaterCard.swift
│   │       └── WaterSection.swift

│   ├── DailySummary/
│   │   ├── Factory/
│   │   │   └── DailySummaryFactory.swift
│   │   ├── Models/
│   │   │   └── DailySummaryModels.swift
│   │   ├── State/
│   │   │   └── DailySummaryState.swift
│   │   ├── ViewModels/
│   │   │   └── DailySummaryViewModel.swift
│   │   ├── Views/
│   │   │   ├── StatisticsView.swift
│   │   │   ├── StatisticsTabFlow.swift
│   │   │   └── Charts/
│   │   │       ├── CaloriesChartView.swift
│   │   │       ├── NutritionChartView.swift
│   │   │       ├── WaterChartView.swift
│   │   │       ├── PeriodSelectorView.swift
│   │   │       └── CustomCalendarView.swift
│   │   └── Components/
│   │       ├── DailySummaryCard.swift
│   │       └── DailySummarySection.swift

│   ├── Home/
│   │   ├── Factory/
│   │   │   └── HomeFactory.swift
│   │   ├── ViewModels/
│   │   │   └── HomeViewModel.swift
│   │   ├── Views/
│   │   │   ├── HomeView.swift
│   │   │   └── HomeTabFlow.swift
│   │   └── Components/
│   │       ├── HomeTabView.swift
│   │       ├── CustomTabBar.swift
│   │       └── TabBarButton.swift

│   └── Settings/
│       ├── Factory/
│       │   └── SettingsFactory.swift
│       ├── Models/
│       ├── State/
│       │   └── SettingsState.swift
│       ├── ViewModels/
│       │   └── SettingsViewModel.swift
│       ├── Views/
│       │   ├── SettingsView.swift
│       │   └── SettingsTabFlow.swift
│       └── Components/
│           └── SettingsRow.swift

├── Shared/
│   ├── Common/
│   │   ├── LoadingView.swift
│   │   └── ErrorView.swift
│   └── Protocols/
│       ├── ViewModelProtocol.swift
│       └── ServiceProtocols.swift

├── Preview/
│   └── MockServices.swift

└── Resources/
└── Assets.xcassets/

---

Если хочешь, я могу нарисовать **схему зависимостей сервисов → Factory → ViewModel → View**, чтобы было видно, что **никакая ViewModel не знает про другие Features**, и где Factory используется для изоляции.

Хочешь, чтобы я сделал такую визуализацию?
*/
