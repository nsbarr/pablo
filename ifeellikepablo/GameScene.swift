//
//  GameScene.swift
//  fakegame
//
//  Created by Nick Barr on 2/27/17.
//  Copyright © 2017 Nick Barr. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, CAAnimationDelegate {
    
    var viewController: ViewController!
    var currentPoint = CGPoint.zero
    
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    
    let cam = SKCameraNode()
    let shapeLayer = CAShapeLayer()

    
    override func didMove(to view: SKView) {
        
        self.camera = cam
        self.addChild(cam)
        cam.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        
    }
    

    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        
        
      //  let moveCamera = SKAction.move(to: currentPoint, duration: 0)
     //   cam.run(moveCamera, completion:  {() -> Void in
            //doneskis
     //   })

        cam.position = currentPoint
        //print(currentPoint)
        //let strokeValue:CGFloat = Float(shapeLayer.value(forKey: "strokeEnd") as! Float)
        
       // print(strokeValue)
        
    //    let cp = shapeLayer.presentation()?.bounds
    //    print(cp)
    }
    
    func doTheThing(pathToAnimateScaled: CGPath){
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.lineCap = kCALineCapRound
        self.view?.layer.addSublayer(shapeLayer)
        shapeLayer.path = pathToAnimateScaled
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.delegate = self
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 2.5
        shapeLayer.add(animation, forKey: "drawLineAnimation")
        
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
                    }
                }
                
        
        
    }
}
