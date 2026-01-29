//
//  PDFFormEditorView.swift
//  PDFReaderOne
//
//  Created by andres paladines on 1/28/26.
//

import SwiftUI
import PDFKit

struct PDFFormEditorView: View {
    let pdfURL: URL
    @State private var pdfDocument: PDFDocument?

    var body: some View {
        VStack {
            if let document = pdfDocument {
                PDFKitView(document: document)
            } else {
                ProgressView("Loading PDF…")
            }
        }
        .navigationTitle("Edit PDF")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Print") {
                    printPDF()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePDF()
                }
            }
        }
        .task {
            await loadPDF()
        }
    }
}

extension PDFFormEditorView {

    func loadPDF() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: pdfURL)
            if let document = PDFDocument(data: data) {
                pdfDocument = document
            }
        } catch {
            print("Failed to load PDF:", error)
        }
    }
}

extension PDFFormEditorView {

    func savePDF() {
        guard let document = pdfDocument else { return }

        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = docsURL.appendingPathComponent("filled-form.pdf")

        if document.write(to: destinationURL) {
            print("Saved to:", destinationURL)
        } else {
            print("Failed to save PDF")
        }
    }
}

extension PDFFormEditorView {

    func printPDF() {
        guard let document = pdfDocument else { return }

        let printController = UIPrintInteractionController.shared
        printController.printingItem = document.dataRepresentation()
        printController.present(animated: true)
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.isUserInteractionEnabled = true

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
