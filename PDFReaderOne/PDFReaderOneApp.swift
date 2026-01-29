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

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PDFFormEditorView(pdfURL: URL(string: "https://mcforms.mayo.edu/mc0001-mc0099/mc0072-94.pdf")!)
            }
        }
    }
}


