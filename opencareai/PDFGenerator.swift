//
//  PDFGenerator.swift
//  opencareai
//
//  Created by Shruthi Sathya on 7/21/25.
//

import SwiftUI
import Foundation

@MainActor
class PDFGenerator {
    static func generate(from view: some View) -> URL? {
        let renderer = ImageRenderer(content: view)
        
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard US Letter size
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("HealthReport.pdf")

        renderer.render { size, context in
            var box = pageBounds
            
            guard let pdf = CGContext(temporaryURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdf.beginPDFPage(nil)
            
            context(pdf)
            
            pdf.endPDFPage()
            pdf.closePDF()
            
            print("PDF Saved to: \(temporaryURL.path)")
        }
        
        return temporaryURL
    }
}
