//
//  GameScene.swift
//  fakegame
//
//  Created by Nick Barr on 2/27/17.
//  Copyright © 2017 Nick Barr. All rights reserved.
//

import SpriteKit
import UIKit
import GameplayKit



public enum PathElement {
    case moveToPoint(CGPoint)
    case addLineToPoint(CGPoint)
    case addQuadCurveToPoint(CGPoint, CGPoint)
    case addCurveToPoint(CGPoint, CGPoint, CGPoint)
    case closeSubpath
    
    init(element: CGPathElement) {
        switch element.type {
        case .moveToPoint:
            self = .moveToPoint(element.points[0])
        case .addLineToPoint:
            self = .addLineToPoint(element.points[0])
        case .addQuadCurveToPoint:
            self = .addQuadCurveToPoint(element.points[0], element.points[1])
        case .addCurveToPoint:
            self = .addCurveToPoint(element.points[0], element.points[1], element.points[2])
        case .closeSubpath:
            self = .closeSubpath
        }
    }
}



extension PathElement: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .moveToPoint(point):
            return "moveto \(point)"
        case let .addLineToPoint(point):
            return "lineto \(point)"
        case let .addQuadCurveToPoint(point1, point2):
            return "quadcurveto \(point1), \(point2)"
        case let .addCurveToPoint(point1, point2, point3):
            return "curveto \(point1), \(point2), \(point3)"
        case .closeSubpath:
            return "closepath"
        }
    }
}

extension PathElement : Equatable {
    public static func ==(lhs: PathElement, rhs: PathElement) -> Bool {
        switch(lhs, rhs) {
        case let (.moveToPoint(l), .moveToPoint(r)):
            return l == r
        case let (.addLineToPoint(l), .addLineToPoint(r)):
            return l == r
        case let (.addQuadCurveToPoint(l1, l2), .addQuadCurveToPoint(r1, r2)):
            return l1 == r1 && l2 == r2
        case let (.addCurveToPoint(l1, l2, l3), .addCurveToPoint(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.closeSubpath, .closeSubpath):
            return true
        case (_, _):
            return false
        }
    }
}

extension UIBezierPath {
    var elements: [PathElement] {
        var pathElements = [PathElement]()
        withUnsafeMutablePointer(to: &pathElements) { elementsPointer in
            let rawElementsPointer = UnsafeMutableRawPointer(elementsPointer)
            cgPath.apply(info: rawElementsPointer) { userInfo, nextElementPointer in
                let nextElement = PathElement(element: nextElementPointer.pointee)
                let elementsPointer = userInfo?.assumingMemoryBound(to: [PathElement].self)
                elementsPointer?.pointee.append(nextElement)
            }
        }
        return pathElements
    }
}

//extension UIBezierPath{
//    var length: CGFloat{
//        var pathLength:CGFloat = 0.0
//        var current = CGPoint.zero
//        var first   = CGPoint.zero
//        
//        self.cgPath.forEach{ element in
//            pathLength += element.distance(to: current, startPoint: first)
//            
//            if element.type == .moveToPoint{
//                first = element.point
//            }
//            if element.type != .closeSubpath{
//                current = element.point
//            }
//        }
//        return pathLength
//    }
//}
class GameScene: SKScene, CAAnimationDelegate {
    
    var viewController: ViewController!
    var currentPoint = CGPoint.zero
    
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    
    let cam = SKCameraNode()
    let shapeLayer = CAShapeLayer()
    var trackingLayer = CALayer()

    
    override func didMove(to view: SKView) {
        
        self.camera = cam
        self.addChild(cam)
        cam.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        print(view.frame)
        view.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
        view.backgroundColor = UIColor.black
        
    }
    

    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        
        
      //  let moveCamera = SKAction.move(to: currentPoint, duration: 0)
     //   cam.run(moveCamera, completion:  {() -> Void in
            //doneskis
     //   })

        //print(currentPoint)
        //let strokeValue:CGFloat = Float(shapeLayer.value(forKey: "strokeEnd") as! Float)
        
       // print(strokeValue)
        
        
       // print("strokeEnd: \(cp)")
        
        if let fp = trackingLayer.presentation()?.position{
            print(fp)
            let cp = shapeLayer.presentation()?.value(forKey: "strokeEnd") as! Float
            if cp != 1.0{
                
                //we always want the trackinglayer to be at the center of what we see
                //ie., view.center = trackingLayer.position
                //not working so some conversion stuff necessary?
                //tracking layer sublayer of shape layer
                //shape layer sublayer of view layer
                //assumption that view layer = view
                
                
                //view?.center = fp
                
                //view?.center = (self.view?.layer.convert(fp, from: trackingLayer))!
                
//                let intermediate = shapeLayer.convert(fp, from: trackingLayer)
//                view?.center = (self.view?.layer.convert(intermediate, from: shapeLayer))!
                
                print(view?.center)
            }
            else{
                print("animation done")
             //   print(cp)
            }
        }
       
    }
    
    func doTheThing(pathToAnimateScaled: CGPath){
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.lineCap = kCALineCapRound
        shapeLayer.frame = (self.view?.frame)!
        self.view?.layer.addSublayer(shapeLayer)
        shapeLayer.path = pathToAnimateScaled
        
        CATransaction.begin()

        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.delegate = self
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 10
        shapeLayer.add(animation, forKey: "drawLineAnimation")
        
        
        trackingLayer.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        trackingLayer.backgroundColor = UIColor.red.cgColor
        shapeLayer.addSublayer(trackingLayer)
        
        let followPathAnimation = CAKeyframeAnimation(keyPath: "position")
        followPathAnimation.path = shapeLayer.path
        followPathAnimation.duration = animation.duration
        trackingLayer.add(followPathAnimation, forKey: "positionAnimation")
        
        CATransaction.commit()
        
        var arrayOfPoints = [CGPoint]()
        
        let foo = UIBezierPath(cgPath: shapeLayer.path!).elements
        print (foo.count)
        
                shapeLayer.path!.apply(info: nil) { (_, elementPointer) in
                    let element = elementPointer.pointee
                    let command: String
                    let pointCount: Int
                    switch element.type {
                    case .moveToPoint: command = "moveTo"; pointCount = 1
                    case .addLineToPoint: command = "lineTo"; pointCount = 1
                    case .addQuadCurveToPoint: command = "quadCurveTo"; pointCount = 2
                    case .addCurveToPoint: command = "curveTo"; pointCount = 3
                    case .closeSubpath: command = "close"; pointCount = 0
                    }
                    let points = Array(UnsafeBufferPointer(start: element.points, count: pointCount))
                    if command == "moveTo"{
                        Swift.print("\(command) \(points)")
                        //add points to the arrayOfPoints but there's some C function pointer
                    }
                    print ("number of points in array:\(points.count)")
                }
    }
}
