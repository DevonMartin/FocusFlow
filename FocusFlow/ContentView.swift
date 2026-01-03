//
//  ContentView.swift
//  FocusFlow
//
//  Created by Devon Martin on 1/2/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TaskListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TaskRecord.self, inMemory: true)
}
