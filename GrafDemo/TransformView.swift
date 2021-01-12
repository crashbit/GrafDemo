import Cocoa

class TransformView: NSView {

    fileprivate let kBig: CGFloat = 10000
    fileprivate let animationSteps: CGFloat = 15
    fileprivate var useContextTransforms = false
    
    fileprivate var animationTimer: Timer!
    
    fileprivate var translation = CGPoint() {
        didSet {
            needsDisplay = true
        }
    }
    
    fileprivate var rotation: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    fileprivate var scale = CGSize(width: 1.0, height: 1.0) {
        didSet {
            needsDisplay = true
        }
    }
    
    fileprivate var animationFunction: (() -> Bool)?  // returns true when finished

    // until get a fancy UI
    @objc var shouldTranslate = true
    @objc var shouldRotate = true
    @objc var shouldScale = true

    @objc func reset() {
        translation = CGPoint()
        rotation = 0
        scale = CGSize(width: 1.0, height: 1.0)
    }

    // TODO(markd 2015-07-07) this common stuff could use a nice refactoring.
    fileprivate func drawBackground() {
        let rect = bounds

        currentContext.protectGState {
            currentContext.addRect(rect)
            NSColor.white.set()
            currentContext.fillPath()
        }
    }
    
    
    fileprivate func drawBorder() {
        let context = currentContext
        
        context.protectGState {
            NSColor.black.set()
            context.stroke(bounds)
        }
    }
    
    fileprivate func drawGridLinesWithStride(_ strideLength: CGFloat, withLabels: Bool, context: CGContext) {
        let font = NSFont.systemFont(ofSize: 10.0)

        let darkGray = NSColor.darkGray.withAlphaComponent(0.3)

        let textAttributes: [String : AnyObject] = [ convertFromNSAttributedStringKey(NSAttributedString.Key.font) : font,
            convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): darkGray]

        // draw vertical lines
        for x in stride(from: bounds.minX - kBig, to: kBig, by: strideLength) {
            let start = CGPoint(x: x + 0.25, y: -kBig)
            let end = CGPoint(x: x + 0.25, y: kBig )
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
            if (withLabels) {
                var textOrigin = CGPoint(x: x + 0.25, y: bounds.minY + 0.25)
                textOrigin.x += 2.0
                let label = NSString(format: "%d", Int(x))
                label.draw(at: textOrigin,  withAttributes: convertToOptionalNSAttributedStringKeyDictionary(textAttributes))
            }
        }
        
        // draw horizontal lines
        for y in stride(from: bounds.minY - kBig, to: kBig, by: strideLength) {
            let start = CGPoint(x: -kBig, y: y + 0.25)
            let end = CGPoint(x: kBig, y: y + 0.25)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            if (withLabels) {
                var textOrigin = CGPoint(x: bounds.minX + 0.25, y: y + 0.25)
                textOrigin.x += 3.0
                
                let label = NSString(format: "%d", Int(y))
                label.draw(at: textOrigin,  withAttributes: convertToOptionalNSAttributedStringKeyDictionary(textAttributes))
            }
        }
    }
    
    fileprivate func drawGrid() {
        let context = currentContext
        
        context.protectGState {
            context.setLineWidth(0.5)
            
            let lightGray = NSColor.lightGray.withAlphaComponent(0.3)
            let darkGray = NSColor.darkGray.withAlphaComponent(0.3)

            
            // Light grid lines every 10 points
            
            // Performance hack - if the transform has a rotation, speed of drawing
            // plummets, so hide the inner lines when animating.
            if animationFunction == nil {
                lightGray.setStroke()
                drawGridLinesWithStride(10, withLabels: false, context: context)
            }
            
            // darker gray lines every 100 points
            darkGray.setStroke()
            drawGridLinesWithStride(100, withLabels: true, context: context)
            
            // black lines on cartesian axes
            // P.S. "AND MY AXE" -- Gimli
            let bounds = self.bounds
            
            let start = CGPoint(x: bounds.minX + 0.25, y: bounds.minY)
            let horizontalEnd = CGPoint(x: bounds.maxX + 0.25, y: bounds.minY)
            let verticalEnd = CGPoint(x: bounds.minX + 0.25, y: bounds.maxY)
            
            context.setLineWidth(2.0)
            NSColor.black.setStroke()
            context.move(to: CGPoint(x: -kBig, y: start.y))
            context.addLine(to: CGPoint(x: kBig, y: horizontalEnd.y))
            
            context.move(to: CGPoint(x: start.x, y: -kBig))
            context.addLine(to: CGPoint(x: verticalEnd.x, y: kBig))
            
            context.strokePath()
        }
    }
    
    fileprivate func applyTransforms() {
        
        if useContextTransforms {
            currentContext.translateBy(x: translation.x, y: translation.y)
            currentContext.rotate(by: rotation)
            currentContext.scaleBy(x: scale.width, y: scale.height)
            
        } else { // use matrix transforms
            let identity = CGAffineTransform.identity
            let shiftingCenter = identity.translatedBy(x: translation.x, y: translation.y)
            let rotating = shiftingCenter.rotated(by: rotation)
            let scaling = rotating.scaledBy(x: scale.width, y: scale.height)
            
            // makes experimentation a little easier - just set to the transform you want to apply
            // to see how it looks
            let lastTransform = scaling
            
            currentContext.concatenate(lastTransform)
        }
        
    }
    
    fileprivate func drawPath() {
        guard let hat = RanchLogoPath() else { return }

        var flipTransform = AffineTransform.identity
        let bounds = hat.bounds
        flipTransform.translate(x: 0.0, y: bounds.height * 4)
        flipTransform.scale(x: 2.0, y: -2.0)
        hat.transform(using: flipTransform as AffineTransform)

        NSColor.orange.set()
        hat.fill()
        
        NSColor.black.set()
        hat.stroke()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        drawBackground()
        currentContext.protectGState() {
            applyTransforms()
            drawGrid()
            drawPath()
        }
        drawBorder()
    }
    
    override var isFlipped : Bool{
        return true
    }
    
    @objc func tick(_ timer: Timer) {
        guard let animator = animationFunction else {
            return
        }
        if animator() {
            animationTimer.invalidate()
            animationTimer = nil
            animationFunction = nil
            needsDisplay = true
        }
    }
    
    
    @objc func translationAnimator(_ from: CGPoint, to: CGPoint) -> () -> Bool {
        translation = from

        let delta = CGPoint(x: (to.x - from.x) / animationSteps,
            y: (to.y - from.y) / animationSteps)
        
        return {
            self.translation.x += delta.x
            self.translation.y += delta.y
            
            self.needsDisplay = true

            // this is insufficient, if from.x == to.x
            if self.translation.x > to.x {
                return true
            } else {
                return false
            }
        }
    }
    
    
    @objc func rotationAnimator(_ from: CGFloat, to: CGFloat) -> () -> Bool {
        rotation = from
        
        let delta = (to - from) / animationSteps
        
        return {
            self.rotation += delta
            
            if self.rotation > to {
                return true
            } else {
                return false
            }
        }
    }
    

    @objc func scaleAnimator(_ from: CGSize, to: CGSize) -> () -> Bool {
        scale = from

        let delta = CGSize(width: (to.width - from.width) / animationSteps,
            height: (to.height - from.height) / animationSteps)
        
        return {
            self.scale.width += delta.width
            self.scale.height += delta.height
            
            self.needsDisplay = true
            
            // this is insufficient, if from.height == to.height
            if self.scale.width > to.width {
                return true
            } else {
                return false
            }
        }
    }
    
    func compositeAnimator(_ animations: [ () -> Bool ]) -> () -> Bool {
        guard var currentAnimation = animations.first else {
            return {
                return true // no animations, so we're done
            }
        }
        
        var animatorIndex = 0
        
        return {
            if currentAnimation() {
                // move to the next one
                animatorIndex += 1

                // run out?
                if animatorIndex >= animations.count {
                    return true
                }
                
                // otherwise, tick over
                currentAnimation = animations[animatorIndex]
                return false // not done
            } else {
                return false // not done
            }
        }
    }
    
    
    @objc func startAnimation() {
        // The worst possible way to animate, but I'm in a hurry right now prior
        // to cocoaconf/columbus. ++md 2015-07-07
        
        let translateFrom = CGPoint()
        let translateTo = CGPoint(x: 200, y: 100)
        let translator = translationAnimator(translateFrom, to: translateTo)
        
        let rotator = rotationAnimator(0.0, to: rotation + π / 12)
        
        let scaleFrom = CGSize(width: 1.0, height: 1.0)
        let scaleTo = CGSize(width: 1.5, height: 0.75)
        let scaler = scaleAnimator(scaleFrom, to: scaleTo)
        
        var things: [(() -> Bool)] = []

        if shouldScale {
            things += [scaler]
        }
        if shouldRotate {
            things += [rotator]
        }
        if shouldTranslate {
            things += [translator]
        }
        
        animationFunction = compositeAnimator(things)

        animationTimer = Timer.scheduledTimer(timeInterval: 1 / 30, target: self, selector: #selector(TransformView.tick(_:)), userInfo: nil, repeats: true)
    }
    
    
/*
    For now giving up on core animation since I don't have a layer subclass.

    func startAnimation() {
        let anim = CABasicAnimation()
        anim.keyPath = "translateX"
        anim.fromValue = 0
        anim.toValue = 100
        anim.repeatCount = 1
        anim.duration = 3
        layer!.style = [ "translateX" : 0 ]
        layer!.addAnimation(anim, forKey: "translateX")
        
        Swift.print ("blah \(layer!.style)")
    
    /*
        let translateAnimation = CAKeyframeAnimation(keyPath: "translateX")
        translateAnimation.values = [ 200 ]
        translateAnimation.keyTimes = [ 100 ]
        translateAnimation.duration = 2.0
        translateAnimation.additive = true
        layer?.addAnimation(translateAnimation, forKey: "translate X")
      */  
    }
    
    override func actionForLayer(layer: CALayer, forKey event: String) -> CAAction? {
        Swift.print("flonk \(event)")
        return super.actionForLayer(layer, forKey: event)
    }
    
    */
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
