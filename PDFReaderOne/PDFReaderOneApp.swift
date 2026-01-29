//
//  PDFReaderOneApp.swift
//  PDFReaderOne
//
//  Created by andres paladines on 1/28/26.
//

import SwiftUI
import SwiftData

@main
struct PDFReaderOneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            PDFFormEditorView(pdfURL: URL(string: "https://www.uscis.gov/sites/default/files/document/forms/i-130.pdf")!)
        }
        .modelContainer(sharedModelContainer)
    }
}


