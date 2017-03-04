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
        print(currentPoint)
    }
    
    func doTheThing(pathToAnimateScaled: CGPath){
        let shapeLayer = CAShapeLayer()
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
        
    }
}
