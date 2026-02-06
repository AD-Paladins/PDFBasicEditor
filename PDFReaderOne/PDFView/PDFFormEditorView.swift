//
//  PDFFormEditorView.swift
//  PDFReaderOne
//
//  Created by andres paladines on 1/28/26.
//

import SwiftUI
import PDFKit

func removeButtonAnnotation(from pdfDocument: PDFDocument, buttonFieldName: String...) {
    for i in 0..<pdfDocument.pageCount {
        if let page = pdfDocument.page(at: i) {
            for annotation in page.annotations {
                
                print(annotation.fieldName ?? "No Name")
                print(annotation.widgetFieldType.rawValue)
                print(annotation.widgetStringValue ?? "No Value")
                print("")
                // Check if the annotation matches the button you want to remove
                if let fieldName = annotation.fieldName, buttonFieldName.contains(fieldName) && annotation.widgetFieldType == .button {
                    page.removeAnnotation(annotation)
                    print("Removed button: \(buttonFieldName) from page \(i + 1)")
                    return // Exit if you only need to remove one specific button
                }
            }
        }
    }
}

struct PDFFormEditorView: View {
    let pdfURL: URL
    
    @StateObject private var controller = PDFEditorController()
    @State private var showSignaturePad = false

    var body: some View {
        PDFKitView(controller: controller)
            .navigationTitle("Edit PDF")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign") {
                        showSignaturePad = true
                    }
                }
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
            .sheet(isPresented: $showSignaturePad) {
                SignatureSheet { drawing in
                    controller.addSignature(drawing: drawing)
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
                removeButtonAnnotation(from: document, buttonFieldName: "Complete and print", "Print", "Reset Form", "Signature Required")
                controller.configure(with: document)
            }
        } catch {
            print("Failed to load PDF:", error)
        }
    }
}

extension PDFFormEditorView {
    func savePDF() {
        guard let document = controller.pdfView.document else { return }

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
        guard let document = controller.pdfView.document else { return }

        let printController = UIPrintInteractionController.shared
        printController.printingItem = document.dataRepresentation()
        printController.present(animated: true)
    }
}


struct PDFKitView: UIViewRepresentable {
    @ObservedObject var controller: PDFEditorController

    func makeUIView(context: Context) -> PDFView {
        controller.pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

import PDFKit
import UIKit
import Combine

final class PDFEditorController: ObservableObject {
    @Published var pdfView = PDFView()
    private var panGesture: UIPanGestureRecognizer?
    private var draggingAnnotation: PDFAnnotation?
    private var lastPanLocationInPage: CGPoint?

    func configure(with document: PDFDocument) {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.isUserInteractionEnabled = true

        if panGesture == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.minimumNumberOfTouches = 1
            pan.cancelsTouchesInView = false
            pdfView.addGestureRecognizer(pan)
            panGesture = pan
        }
    }

    func addSignature(drawing: PKDrawing) {
        guard let page = pdfView.currentPage else { return }
        
        let pageBounds = page.bounds(for: .mediaBox)
        
        let signatureRect = CGRect(
            x: pageBounds.midX - 100,
            y: pageBounds.minY + 80,
            width: 200,
            height: 80
        )
        
        let inkAnnotation = PDFAnnotation(
            bounds: signatureRect,
            forType: .ink,
            withProperties: nil
        )
        
        let drawingBounds = drawing.bounds
        let sx = signatureRect.width / max(drawingBounds.width, 1)
        let sy = signatureRect.height / max(drawingBounds.height, 1)
        let scale = min(sx, sy)
        let offsetX = (signatureRect.width - drawingBounds.width * scale) / 2
        let offsetY = (signatureRect.height - drawingBounds.height * scale) / 2
        
        for stroke in drawing.strokes {
            let path = UIBezierPath()
            let count = stroke.path.count
            guard count > 0 else { continue }

            // First point
            let p0 = stroke.path[0].location
            let nx0 = p0.x - drawingBounds.minX
            let ny0 = p0.y - drawingBounds.minY
            let flippedY0 = drawingBounds.height - ny0
            let local0 = CGPoint(x: offsetX + nx0 * scale, y: offsetY + flippedY0 * scale)
            path.move(to: local0)

            if count > 1 {
                for i in 1..<count {
                    let p = stroke.path[i].location
                    let nx = p.x - drawingBounds.minX
                    let ny = p.y - drawingBounds.minY
                    let flippedY = drawingBounds.height - ny
                    let local = CGPoint(x: offsetX + nx * scale, y: offsetY + flippedY * scale)
                    path.addLine(to: local)
                }
            }

            inkAnnotation.add(path)
        }
        
        inkAnnotation.color = .black
        let border = PDFBorder()
        border.lineWidth = 2
        inkAnnotation.border = border
        
        page.addAnnotation(inkAnnotation)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: pdfView)
        guard let page = pdfView.page(for: location, nearest: true) else { return }
        let pagePoint = pdfView.convert(location, to: page)

        switch gesture.state {
        case .began:
            // Find the topmost annotation at the touch point
            if let hit = page.annotations.last(where: { $0.bounds.contains(pagePoint) }) {
                draggingAnnotation = hit
                lastPanLocationInPage = pagePoint
            }
        case .changed:
            if let dragging = draggingAnnotation, let last = lastPanLocationInPage {
                let dx = pagePoint.x - last.x
                let dy = pagePoint.y - last.y
                var newBounds = dragging.bounds
                newBounds.origin.x += dx
                newBounds.origin.y += dy
                dragging.bounds = newBounds
                lastPanLocationInPage = pagePoint
            }
        default:
            draggingAnnotation = nil
            lastPanLocationInPage = nil
        }
    }
}



import PencilKit
import SwiftUI

struct SignatureSheet: View {
    let onConfirm: (PKDrawing) -> Void
    @Environment(\.dismiss) private var dismiss
    let captureView = SignatureCaptureView()
    
    var body: some View {
        VStack {
            captureView
                .frame(height: 300)
                .border(.gray)
            
            Button("Confirm") {
                let drawing = captureView.drawing()
                onConfirm(drawing)
                dismiss()
            }
        }
        .padding()
    }
}

struct SignatureCaptureView: UIViewRepresentable {
    let canvasView = PKCanvasView()

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func drawing() -> PKDrawing {
        canvasView.drawing
    }
}
