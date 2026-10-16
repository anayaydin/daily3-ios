import SwiftData

enum Daily3Storage {
    // App Groups must not redirect the existing SwiftData store to a new location.
    static let configuration = ModelConfiguration(groupContainer: .none)

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: DailyEntry.self,
            DailyTaskItem.self,
            configurations: configuration
        )
    }
}
