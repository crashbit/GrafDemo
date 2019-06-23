import Cocoa


class PDFView: NSView {

    var pdfDocument : CGPDFDocument? {
        willSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.white.set()
        bounds.fill()
        
        if let pdf = pdfDocument {
            let page1 = pdf.page(at: 1)
 
            currentContext.drawPDFPage(page1!)
        }
        
        NSColor.black.set()
        bounds.frame()
    }
}

