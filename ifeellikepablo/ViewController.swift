//  ViewController.swift
//  ifeellikepablo
//
//  Created by nick barr on 2/4/17.
//  Copyright © 2017 poemsio. All rights reserved.

// THREE BIG TODOS

// TODO: Good animations for uploading, someone is typing, etc.
    // A reasonable way to do this?
    // As soon as the drawing completes, animate the drawView to the top left (ie., in a new cell)
    // and gray it out or somehow indicate that it's still uploading.
    // when it's complete (ie, not just uploaded but downloaded) replace it with the actual pablo.
    // We could do this by adding something to the observe method that checks if the ID is the same
    // as the "most recently uploaded pablo from this device." (we should maybe have an array of IDs,
    // since a user might draw many Pablos while one is uploading, ugh... so maybe we just show a simple indicator that
    // an upload is taking place?? so much worse. but maybe that's where we start?)
    // When we actually ship the app we'll need to revisit whether we can just stream in Pablos. We
    // probably can't. That's fine.

// TODO: Smarter behavior for infinity animation. The Game Loop should be responsible for tacking on another pablo if we're at the end of our array; otherwise, we're tacking one on in our listener. Cool, but this is harder than it sounds... how do we keep the "rollup cgpath" updated?

// TODO: Enable peek / pop



import UIKit
import Firebase
import FirebaseStorage
import FirebaseDatabase

//# MARK: - Extensions

// rob mayoff's CGPath.foreach
extension CGPath {
    func forEach( body: @convention(block) (CGPathElement) -> Void) {
        typealias Body = @convention(block) (CGPathElement) -> Void
        func callback(info: UnsafeMutableRawPointer?, element: UnsafePointer<CGPathElement>) {
            let body = unsafeBitCast(info, to: Body.self)
            body(element.pointee)
        }
        let unsafeBody = unsafeBitCast(body, to: UnsafeMutableRawPointer.self)
        
        self.apply(info: unsafeBody, function: callback)
    }
}

// Finds the first point in a path
extension UIBezierPath {
    func firstPoint() -> CGPoint? {
        var firstPoint: CGPoint? = nil
        
        self.cgPath.forEach { element in
            // Just want the first one, but we have to look at everything
            guard firstPoint == nil else { return }
            assert(element.type == .moveToPoint, "Expected the first point to be a move")
            firstPoint = element.points.pointee
        }
        return firstPoint
    }
}

class ViewController: UIViewController, SwiftyDrawViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, CAAnimationDelegate{//, UIViewControllerPreviewingDelegate{
    
    
    //# MARK: - Variables
    
    var database: FIRDatabase!
    var storage: FIRStorage!
    var drawView: SwiftyDrawView!
    var dummyButton: UIButton!
    var infinityButton: UIButton!
    var collectionView: UICollectionView!
    var viewImage: UIImage!
    var refresher:UIRefreshControl!

    //var searches = [UIImage]()
    
    var pablos = [Pablo]()
    var selectedIndexPath: IndexPath!
    
    let shapeLayer = CAShapeLayer()
    
    var trackingLayer = CALayer()
    
    var pathToAnimate: CGPath? = nil

    private let cellReuseIdentifier = "collectionCell"
    
    var tapRecognizer: UITapGestureRecognizer!
    var expandedImageView: UIImageView!
    var modalView: UIView!
    var modalVC: UIViewController!
    var dismissButton: UIButton!
    
    //bullshit
    var pabloImageWidth: CGFloat!
    var appendedPath = UIBezierPath()
    var yTrans:CGFloat = 0.0
    var xTrans:CGFloat = 0.0
    var imagePathStartPoint:CGPoint!
    var imagePathEndPoint:CGPoint!
    var oldImagePathEndPoint:CGPoint!
    var bigSquare:UIView!
    var bgSquare:UIView!
    
    var updater = CADisplayLink()
    
    var scene: GameScene!
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    //# MARK: - View Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let drawFrame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.width)
        drawView = SwiftyDrawView(frame: drawFrame)
        self.view.addSubview(drawView)
        drawView.center = view.center
        drawView.delegate = self
        drawView.lineWidth = CGFloat(2.0)
        drawView.backgroundColor = UIColor.white
        self.view.backgroundColor = UIColor.black
        
        dummyButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        dummyButton.center.x = view.center.x
        dummyButton.backgroundColor = UIColor.blue
        dummyButton.addTarget(self, action:#selector(self.pressed), for: .touchUpInside)
        //dummyButton says "Submit"
        dummyButton.setImage(UIImage(named: "draw"), for: UIControlState.selected)
        dummyButton.setImage(UIImage(named: "grid"), for: UIControlState.normal)
        self.view.addSubview(dummyButton)
        
        infinityButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        infinityButton.center.x = view.center.x + 100
        infinityButton.backgroundColor = UIColor.red
        infinityButton.addTarget(self, action:#selector(self.infinityButtonPressed), for: .touchUpInside)
     //   self.view.addSubview(infinityButton)
        
        storage = FIRStorage.storage()
        database = FIRDatabase.database()
        
        //peek
//        if traitCollection.forceTouchCapability == .available {
//            registerForPreviewing(with: self, sourceView: view)
//        }
        
        
        self.setUpCollectionView()
        collectionView.isHidden = true
        
        self.listenForNewDrawings()
        
        
        
    }
    
    func infinityButtonPressed(){
        
        self.doInfinityAnimation()
    }
    
    
    //# MARK: - Collection View Methods
    
    func loadData()
    {
        self.collectionView?.reloadData()

        stopRefresher()         //Call this to stop refresher
    }
    
    func stopRefresher()
    {
        refresher.endRefreshing()
    }
    
    func setUpCollectionView(){
        let flowLayout = UICollectionViewFlowLayout()
        collectionView = UICollectionView(frame: self.view.bounds, collectionViewLayout: flowLayout)
        
        collectionView.register(PabloFeedCollectionViewCell.self, forCellWithReuseIdentifier: PabloFeedCollectionViewCell.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = UIColor.white
        
        
        let bgView = UIView(frame: collectionView.frame)
        let loadingIndicator = UILabel(frame: CGRect(x: 0, y: 40, width: 100, height: 20))
        loadingIndicator.text = "Loading..."
        loadingIndicator.textAlignment = .center
      //  loadingIndicator.center = collectionView.center
        loadingIndicator.textColor = UIColor.black
        collectionView.backgroundView = bgView
        collectionView.backgroundView?.addSubview(loadingIndicator)
        
        self.view.insertSubview(collectionView, belowSubview: dummyButton)
        
        refresher = UIRefreshControl()
        self.collectionView?.alwaysBounceVertical = true
        refresher.tintColor = UIColor.black
        refresher.addTarget(self, action: #selector(self.loadData), for: .valueChanged)
        collectionView!.addSubview(refresher)
        
    }
    
    //2
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return pablos.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PabloFeedCollectionViewCell.identifier,
            for: indexPath
            ) as! PabloFeedCollectionViewCell
        
        cell.backgroundColor = UIColor.black
        // Configure the cell
        //cell.image = searches[indexPath.row]
        //cell.image = pablos[indexPath.row].image
        cell.image = pablos[indexPath.row].image
        //print("image index is \(searches[indexPath.row])")
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // handle tap events
        // PRESENT A MODAL WITH THE IMAGE. ALSO BE ABLE TO PASS ON THE IMAGE METADATA, VIA ???
        
        //let image = searches[indexPath.row]
        let cellImage = pablos[indexPath.row].image
        let imagePath = pablos[indexPath.row].path
        
        //let's say it's (100,100). and we want it to be at (140,40), which is the endpoint. we transform it (+40,-60), ie., abs(startpoint.x-oldEndpoint.x), y)
        
        // now lets say it's still (100.100) and we want it to be at (10,40)...
        imagePathStartPoint = UIBezierPath(cgPath: imagePath).firstPoint()
        
        
        if oldImagePathEndPoint == nil{
            print("no old image path")
            oldImagePathEndPoint = imagePathStartPoint
        }
        else {
            print("setting old imagepath")
            oldImagePathEndPoint = imagePathEndPoint
        }
        

        //this shouldn't be abs btw
        xTrans = oldImagePathEndPoint.x - imagePathStartPoint.x
        yTrans = oldImagePathEndPoint.y - imagePathStartPoint.y
        print("oldEnd:\(oldImagePathEndPoint), imageStart:\(imagePathStartPoint), imageEnd:\(imagePathEndPoint)")
        print("x: \(xTrans). y: \(yTrans)")

        
        
      //  var transformedPath = imagePath
     //   UIBezierPath(cgPath: transformedPath).apply(CGAffineTransform(translationX: xTrans, y: yTrans))
        
        var fuckTransform = CGAffineTransform(translationX: xTrans, y: yTrans)
       // let fuckPath = imagePath.mutableCopy()
        //fuckPath?.move(to: oldImagePathEndPoint)
        let newShittyPath = imagePath.copy(using: &fuckTransform)
        
        imagePathEndPoint = newShittyPath!.currentPoint

        //you need to save the transformed path here
        appendedPath.append(UIBezierPath(cgPath: newShittyPath!))
        
        
        
        self.presentModalWithImageAndPath(image: cellImage, imagePath: imagePath)

        
        
//        imagePath.apply(info: nil) { (_, elementPointer) in
//            let element = elementPointer.pointee
//            let command: String
//            let pointCount: Int
//            switch element.type {
//            case .moveToPoint: command = "moveTo"; pointCount = 1
//            case .addLineToPoint: command = "lineTo"; pointCount = 1
//            case .addQuadCurveToPoint: command = "quadCurveTo"; pointCount = 2
//            case .addCurveToPoint: command = "curveTo"; pointCount = 3
//            case .closeSubpath: command = "close"; pointCount = 0
//            }
//            let points = Array(UnsafeBufferPointer(start: element.points, count: pointCount))
//            Swift.print("\(command) \(points)")
//        }
//        
        
        print("You selected cell #\(indexPath.item)!")
        if selectedIndexPath != nil && selectedIndexPath == indexPath as IndexPath
        {
            print("normal")
            selectedIndexPath = nil //Trigger large cell set back to normal
        }
        else {
            print("selected")
            selectedIndexPath = indexPath as IndexPath! //User selected cell at this index
        }
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.view.frame.size.width/3, height: self.view.frame.size.width/3)

//        if selectedIndexPath != nil { //We know that we have to enlarge at least one cell
//            if indexPath == selectedIndexPath {
//                return CGSize(width: self.view.frame.size.width, height: self.view.frame.size.width)
//                print("enlarge")
//            }
//            else {
//                return CGSize(width: self.view.frame.size.width/3.0, height: self.view.frame.size.width/3.0)
//                print("huh")
//            }
//        }
//        else {
//            return CGSize(width: self.view.frame.size.width/3.0, height: self.view.frame.size.width/3.0)
//            print("ok")
//        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    
    
    //    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    //        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    //    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    
    //# MARK: - Collection View Cell Setup

    //# MARK: - Firebase Downloading
    func listenForNewDrawings(){
        
        let dbRef = database.reference().child("myFiles")
        let orderedQuery = dbRef.queryOrdered(byChild: "dateCreated")
        let limitedQuery = orderedQuery.queryLimited(toLast: 50)
        

        DispatchQueue.global(qos: .userInitiated).async {
            limitedQuery.observe(.childAdded, with: { (snapshot) -> Void in
                
                let dict = snapshot.value as! NSDictionary
                let downloadURL = dict["url"] as! String
                let timeCreated = dict["dateCreated"] as! Double
                let timeCreatedAsDate = NSDate(timeIntervalSince1970: timeCreated)
                
                //TODO: HOW TO MAKE THIS SHIT OPTIONAL
                let pathString = dict["path"] as! String
                let decodedData = NSData(base64Encoded: pathString, options: NSData.Base64DecodingOptions(rawValue: 0))
                
                let decodedBezierPath:UIBezierPath = NSKeyedUnarchiver.unarchiveObject(with: decodedData as! Data) as! UIBezierPath
                let decodedCgPath = decodedBezierPath.cgPath
                
                
                
                let storageRef = self.storage.reference(forURL: downloadURL)
                
                storageRef.data(withMaxSize: 1 * 1024 * 1024, completion: { (data, error) -> Void in
                    // Create a UIImage, add it to the array
                    let pic = UIImage(data: data!)
                    //self.searches.append(pic!)
                    //TODO: How to sort by time created?
                    self.pablos.append(Pablo(uid: snapshot.key, image: pic, path: decodedCgPath, dateCreated: timeCreatedAsDate))
                    self.pablos.sort(by: { $0.dateCreated.compare($1.dateCreated as Date) == .orderedDescending })
                    self.collectionView.reloadData()
                    print("new pablo")

                })
                
                //print("pablos: \(self.pablos)")
  
            })
        }
    }

    
    // MARK: - Miscellaneous
    
    func presentModalWithImageAndPath(image: UIImage, imagePath: CGPath){
        
       
        modalView = UIView(frame: self.view.frame)
        modalView.backgroundColor = UIColor.black
        expandedImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.width))
        expandedImageView.center = self.view.center
        expandedImageView.image = image
        modalView.addSubview(expandedImageView)
        modalVC = UIViewController()
        modalVC.view = modalView
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapDetectedSoAnimatePath))
        pabloImageWidth = image.size.width
        pathToAnimate = imagePath
        modalView.addGestureRecognizer(tapRecognizer)
        self.present(modalVC, animated: false) {
            //stuff
        }
        
        dismissButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        dismissButton.setImage(UIImage(named: "grid"), for: UIControlState.normal)

        dismissButton.center.x = view.center.x
        dismissButton.backgroundColor = UIColor.blue
        dismissButton.addTarget(self, action:#selector(self.dismissButtonPressed), for: .touchUpInside)
        self.modalView.addSubview(dismissButton)

    }
    
    func dismissButtonPressed(){

            modalVC.dismiss(animated: false, completion: nil)

    }
    func tapDetectedSoAnimatePath() {
        print("tap!")
        
        
        let animateView = UIView(frame: expandedImageView.frame)
        animateView.backgroundColor = UIColor.white
        animateView.alpha = 1.0
        animateView.center = expandedImageView.center
        expandedImageView.image = nil
        modalView.insertSubview(animateView, belowSubview: dismissButton)
        
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.lineCap = kCALineCapRound
        
        // trying to scale animations
        // shapeLayer.bounds = animateView.bounds
        // shapeLayer.position = CGPoint(x: animateView.bounds.midX, y: animateView.bounds.midY)
        // shapeLayer.fillColor = UIColor.blue.cgColor
        
        
        animateView.layer.addSublayer(shapeLayer)
        
        
        var pathToAnimateScaled = pathToAnimate!
        var scaleRatio:CGFloat = 1.0
        
        //TODO: this isn't working because it's only looking at the little rectangle that bounds the path.
        //When that rectangle is very small (because the drawing is very small), it will blow up the drawing.
        // Does CGPath have a position or something that we could use? How can we scale it according to its parent view, 
        // while keeping its relationship with the parent view intact?
        // eg., could we take the start point coordinate? is it true that as long as that coordinate is correct the drawing
        // will have the right scale? (no)
        
        //hey, try using image size
        
        //What we want is to scale the cgpath according to the box it was originally drawn in
        //path bigger: path = 15, box = 10. set path to 10. 10/15 * 15 = 10
        // box is bigger : path = 10, box = 15. set path to 15. 10 * 15/10 = 15
     //   print(pathToAnimate?.currentPoint)
     //   print(pabloImageWidth)
        //640 on 5 (2x width)
        //1242 on 7+ (3x width)
     //   print(animateView.frame.width)
        // 414 on 7
        // 320 on 5
        
        //TODO: Bryan can help? This is sometimes nil (I think only on bad old stuff)
        let imageWidth = ScreenWidth.initWith(pixelWidth: pabloImageWidth)
        let animateLayerWidth = animateView.frame.width
        
        if imageWidth == nil{
            scaleRatio = 1
        }
        else {
            scaleRatio = animateLayerWidth/pabloImageWidth*imageWidth!.resolution
        }
        //print("device: \(imageWidth), realPixels: \(imageWidth.pixelWidth), currentScreenWidth: \(animateLayerWidth)")
    
        
//        if pabloImageWidth == 640{ //made on iPhone 5
//            if animateView.frame.width == 414{ // displaying on iPhone 7+
//                scaleRatio = animateView.frame.width / pabloImageWidth * 2
//            
//            }
//        }
//        
//        if pabloImageWidth == 1242{
//            if animateView.frame.width == 320{
//                scaleRatio = animateView.frame.width / pabloImageWidth * 3 //compare pixels vs whatever
//
//            }
//        }
//        
        
        
//        if pabloImageWidth > animateView.frame.width{
//            scaleRatio = animateView.frame.width / pabloImageWidth
//
//        }
//        else {
//            scaleRatio = pabloImageWidth / animateView.frame.width
//
//        }
        print(scaleRatio)
        let bez = UIBezierPath(cgPath: pathToAnimateScaled)
        bez.apply(CGAffineTransform(scaleX: scaleRatio, y: scaleRatio))
        //bez.apply(CGAffineTransform(translationX: CGFloat, y: CGFloat)
        pathToAnimateScaled = bez.cgPath
        
        shapeLayer.path = pathToAnimateScaled //pathToAnimate//drawView.path

        
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.delegate = self
        
        /* set up animation */
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 2.5
        shapeLayer.add(animation, forKey: "drawLineAnimation")

    
    }
    
    func animationDidStart(_ anim: CAAnimation) {
        print("started \(anim)")
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        print("stopped \(anim)")
    }
    
    
    
    func pressed(sender: UIButton!){
        print("pressed")
        

        self.collectionView.setContentOffset(CGPoint.zero, animated: false)
        
        self.collectionView.isHidden = !self.collectionView.isHidden
        self.dummyButton.isSelected = !self.dummyButton.isSelected
        
        if self.collectionView.isHidden{
            drawView.clearCanvas()
            drawView.drawingEnabled = true
        }
        else {
            
//            let animation = CABasicAnimation(keyPath: "position")
//            
//            animation.fromValue = [drawView.frame.origin.x, drawView.frame.origin.y]
//            animation.toValue = [-100, -100]
//            animation.duration = 1.0
//            
//            drawView.layer.add(animation, forKey: "basic")

//            fuck this
//            let transitionTop: CATransition = CATransition()
//            transitionTop.duration = 1.0
//            transitionTop.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
//            transitionTop.type = kCATransitionReveal
//            transitionTop.subtype = kCATransitionFromBottom
//            
//            let transitionLeft: CATransition = CATransition()
//            transitionLeft.duration = 1.0
//            transitionLeft.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
//            transitionLeft.type = kCATransitionReveal
//            transitionLeft.subtype = kCATransitionFromRight
//            
//            drawView.window!.layer.add(transitionTop, forKey: nil)
//            drawView.window!.layer.add(transitionLeft, forKey: nil)
        }
        


        
    }
    
    
    
    func doInfinityAnimation(){
        
        //TODO: Do this earlier in the process...
        
//        let pabloReference = self.database.reference().child("myFiles")
//        let midQuery = pabloReference.queryOrdered(byChild: "dateCreated")
//        let infinityQuery = midQuery.queryLimited(toLast: 3)
//        
//        appendedPath = UIBezierPath()
//        infinityQuery.observe(.childAdded, with: { (snapshot) -> Void in
//                let dict = snapshot.value as! NSDictionary
//                let pathString = dict["path"] as! String
//                let decodedData = NSData(base64Encoded: pathString, options: NSData.Base64DecodingOptions(rawValue: 0))
//                
//                let decodedBezierPath:UIBezierPath = NSKeyedUnarchiver.unarchiveObject(with: decodedData as! Data) as! UIBezierPath
//                let decodedCgPath = decodedBezierPath.cgPath
//                
//                self.imagePathStartPoint = UIBezierPath(cgPath: decodedCgPath).firstPoint()
//                
//                if self.oldImagePathEndPoint == nil{
//                    print("no old image path")
//                    self.oldImagePathEndPoint = self.imagePathStartPoint
//                }
//                else {
//                    print("setting old imagepath")
//                    self.oldImagePathEndPoint = self.imagePathEndPoint
//                }
//                
//                self.xTrans = self.oldImagePathEndPoint.x - self.imagePathStartPoint.x
//                self.yTrans = self.oldImagePathEndPoint.y - self.imagePathStartPoint.y
//               // print("oldEnd:\(oldImagePathEndPoint), imageStart:\(imagePathStartPoint), imageEnd:\(imagePathEndPoint)")
//              //  print("x: \(xTrans). y: \(yTrans)")
//                
//                var pathTransform = CGAffineTransform(translationX: self.xTrans, y: self.yTrans)
//                let transformedPath = decodedCgPath.copy(using: &pathTransform)
//                
//                self.imagePathEndPoint = transformedPath!.currentPoint
//                
//                //you need to save the transformed path here
//                self.appendedPath.append(UIBezierPath(cgPath: transformedPath!))
//
//
//                
//                print("snapshot done")
//            })
        
        // instead of doing a separate query just do the first few in pablos
        
        if self.pablos.isEmpty == false{
            for pablo in self.pablos[1...10] {
                self.imagePathStartPoint = UIBezierPath(cgPath: pablo.path).firstPoint()
                
                if self.oldImagePathEndPoint == nil{
                    print("no old image path")
                    self.oldImagePathEndPoint = self.imagePathStartPoint
                }
                else {
                    print("setting old imagepath")
                    self.oldImagePathEndPoint = self.imagePathEndPoint
                }
                
                self.xTrans = self.oldImagePathEndPoint.x - self.imagePathStartPoint.x
                self.yTrans = self.oldImagePathEndPoint.y - self.imagePathStartPoint.y
                // print("oldEnd:\(oldImagePathEndPoint), imageStart:\(imagePathStartPoint), imageEnd:\(imagePathEndPoint)")
                //  print("x: \(xTrans). y: \(yTrans)")
                
                var pathTransform = CGAffineTransform(translationX: self.xTrans, y: self.yTrans)
                let transformedPath = pablo.path.copy(using: &pathTransform)
                
                self.imagePathEndPoint = transformedPath!.currentPoint
                
                //you need to save the transformed path here
                self.appendedPath.append(UIBezierPath(cgPath: transformedPath!))
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(0), execute: {
                let pathToAnimate = self.appendedPath.cgPath
                self.startInfinityAnimation(pathToAnimateScaled: pathToAnimate)
            })
        }
        
        
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Drawing Methods
    
    func SwiftyDrawDidBeginDrawing(view: SwiftyDrawView) {
        print("started drawing")
    }
    
    func SwiftyDrawDidFinishDrawing(view: SwiftyDrawView) {
        
        // Called when the SwiftyDrawView detects touches have ended for the particular line segment
        
        
        print("finished drawing")
        
        self.drawView.drawingEnabled = false
        

        
        
        let size = drawView.layer.frame.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        viewImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let data = UIImagePNGRepresentation(viewImage) as Data?

        //TODO: THIS IS OK IN THE V SHORT TERM BUT NEED TO DE-DUPE ETC

        let storageRef = storage.reference(forURL: "gs://pablo-9fa92.appspot.com")
        
        // Create a reference to the file you want to upload
        let uuid = NSUUID().uuidString
        let riversRef = storageRef.child("images/\(uuid).jpg")
        
        // TODO: put this inside async?
        // Upload the file to the path "images/rivers.jpg"
        let uploadTask = riversRef.put(data!, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                // Uh-oh, an error occurred!
                return
            }
            // Metadata contains file metadata such as size, content-type, and download URL.
            // let downloadURL = metadata.downloadURL
        }
        
        
        // Create the file metadata
        let metadata = FIRStorageMetadata()
        metadata.contentType = "image/jpeg"
        
        self.pressed(sender: dummyButton)
        
        
        // Listen for state changes, errors, and completion of the upload.
        uploadTask.observe(.resume) { snapshot in
            // Upload resumed, also fires when the upload starts
        }
        
        uploadTask.observe(.pause) { snapshot in
            // Upload paused
        }
        
        uploadTask.observe(.progress) { snapshot in
            // Upload reported progress
            let percentComplete = 100.0 * Double(snapshot.progress!.completedUnitCount)
                / Double(snapshot.progress!.totalUnitCount)
        }
        
        uploadTask.observe(.success) { snapshot in
            // Upload completed successfully
            
            // When the image has successfully uploaded, we get its download URL
            let downloadURL = snapshot.metadata?.downloadURL()?.absoluteString
            let dateCreated = snapshot.metadata?.timeCreated?.timeIntervalSince1970
            
            
            let bezierPath = UIBezierPath(cgPath: self.drawView.path!)
            let pathData = NSKeyedArchiver.archivedData(withRootObject: bezierPath)
            let pathDataAsBase64String = pathData.base64EncodedString()

            // Write the download URL to the Realtime Database
            
            //TODO: should this UUID match the other one? How else can we match up pablos?
            
            let uuid = NSUUID().uuidString
            //self.ref.child("users").child(user.uid).setValue(["username": username])
            let dbRef = self.database.reference().child("myFiles/\(uuid)")
            dbRef.setValue(["dateCreated": dateCreated, "url": downloadURL, "path" : pathDataAsBase64String])

        }
        
        uploadTask.observe(.failure) { snapshot in
            if let error = snapshot.error as? NSError {
                switch (FIRStorageErrorCode(rawValue: error.code)!) {
                case .objectNotFound:
                    // File doesn't exist
                    break
                case .unauthorized:
                    // User doesn't have permission to access file
                    break
                case .cancelled:
                    // User canceled the upload
                    break
                    
                    /* ... */
                    
                case .unknown:
                    // Unknown error occurred, inspect the server response
                    break
                default:
                    // A separate error occurred. This is a good place to retry the upload.
                    break
                }
            }
        }
        
    }
    
    
    
    func SwiftyDrawDidCancelDrawing(view: SwiftyDrawView) {
        
        // Called if SwiftyDrawView detects issues with the gesture recognizers and cancels the drawing
        
    }
    
    func gameLoop(){
        print("loop")
        if let fp = trackingLayer.presentation()?.position{
            print(fp)
            let cp = shapeLayer.presentation()?.value(forKey: "strokeEnd") as! Float
            if cp != 1.0{
                
                
                //bigSquare?.center = fp
                //UIWindow *mainWindow = [[UIApplication sharedApplication] keyWindow];
                //CGPoint pointInWindowCoords = [mainWindow convertPoint:pointInScreenCoords fromWindow:nil]
                //CGPoint pointInViewCoords = [myView convertPoint:pointInWindowCoords fromView:mainWindow];

                
                let mainWindow = UIApplication.shared.keyWindow
                let pointInWindow = mainWindow!.convert(fp, from: nil)
                let pointInView = view.convert(pointInWindow, from: mainWindow)
                
                UIView.animate(withDuration: 1.0, animations: {
                    self.bigSquare.center.y = self.view.center.y-pointInWindow.y + self.view.frame.width/2
                    self.bigSquare.center.x = self.view.center.x-pointInWindow.x + self.view.frame.width/2
                })
                
                //view?.center = (self.view?.layer.convert(fp, from: trackingLayer))!
                
                //                let intermediate = shapeLayer.convert(fp, from: trackingLayer)
                //                view?.center = (self.view?.layer.convert(intermediate, from: shapeLayer))!
                
                print(self.view.center)
            }
            else{
                print("animation done")
                //   print(cp)
            }
        }
    }
    
    func startInfinityAnimation(pathToAnimateScaled: CGPath){
        
        bgSquare = UIView(frame: self.view.frame)
        bgSquare.backgroundColor = UIColor.black
        self.view.addSubview(bgSquare)
        
        bigSquare = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.width))
        bigSquare.backgroundColor = UIColor.black
        self.view.addSubview(bigSquare)
        bigSquare.center = view.center
        
        updater = CADisplayLink(target: self, selector: #selector(ViewController.gameLoop))
        updater.preferredFramesPerSecond = 60
        updater.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
        
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.lineCap = kCALineCapRound
        shapeLayer.frame = self.view!.frame
        bigSquare.layer.addSublayer(shapeLayer)
        shapeLayer.path = pathToAnimateScaled
        
        trackingLayer.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        trackingLayer.backgroundColor = UIColor.clear.cgColor // UIColor.red.cgColor
        shapeLayer.addSublayer(trackingLayer)
        
        
        //CATransaction.begin()
        
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.delegate = self
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 40
      //  animation.beginTime = CACurrentMediaTime()
        shapeLayer.add(animation, forKey: "drawLineAnimation")
        
     //   pathAnimation.calculationMode = kCAAnimationPaced;
    // resizeAnimation.fromValue = [NSNumber numberWithDouble:1.0];
        
        
//        CAAnimationGroup *group = [CAAnimationGroup animation];
//        group.fillMode = kCAFillModeForwards;
//        group.removedOnCompletion = YES;
//        [group setAnimations:[NSArray arrayWithObjects: pathAnimation, resizeAnimation, nil]];
//        group.duration = 3.7f;
//        group.delegate = self;
//        [group setValue:self.myView forKey:@"imageViewBeingAnimated"];

        let followPathAnimation = CAKeyframeAnimation(keyPath: "position")
        followPathAnimation.path = shapeLayer.path
        followPathAnimation.duration = animation.duration
        followPathAnimation.calculationMode = kCAAnimationPaced
     //   followPathAnimation.beginTime = animation.beginTime
        trackingLayer.add(followPathAnimation, forKey: "positionAnimation")
        
        //CATransaction.commit()
        
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
            //   print ("number of points in array:\(points.count)")
        }
    }
    
    // MARK: 3d touch delegation methods
    
//    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
//        
//        guard let indexPath = collectionView?.indexPathForItem(at: location) else { return nil }
//        
//        guard let cell = collectionView?.cellForItem(at: indexPath) else { return nil }
//        
//        guard let detailVC = modalVC else { return nil }
//        
//     //   let photo = photos[indexPath.row]
//     //   detailVC.photo = photo
//        
//        detailVC.preferredContentSize = CGSize(width: 0.0, height: 300)
//        
//        previewingContext.sourceRect = cell.frame
//        
//        return detailVC
//    }
//    
//    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
//        show(viewControllerToCommit, sender: self)
//    }
//    

    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            if self.bigSquare == nil{
                self.doInfinityAnimation()
            }
            else {
                self.bgSquare.removeFromSuperview()
                self.bigSquare.removeFromSuperview()
                self.bigSquare = nil
                updater.remove(from: RunLoop.current, forMode: RunLoopMode.commonModes)
                
            }
            
        }
    }
    
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        print("Device was shaken!")
    }
    


}

