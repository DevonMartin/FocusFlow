//
//  FocusFlowApp.swift
//  FocusFlow
//
//  Created by Devon Martin on 1/2/2026.
//

import SwiftUI
import SwiftData

@main
struct FocusFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskRecord.self,
            SubtaskRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
