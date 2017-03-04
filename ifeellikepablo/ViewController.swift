//  ViewController.swift
//  ifeellikepablo
//
//  Created by nick barr on 2/4/17.
//  Copyright © 2017 poemsio. All rights reserved.

// THREE BIG TODOS
// TODO: Figure out a better way to load in pablos
// TODO: Properly handle pablo paths of different sizes (eg., 5 loading on 7; 7 loading on 5
// TODO: Come up with the magic animation thing


import UIKit
import Firebase
import FirebaseStorage
import FirebaseDatabase
import SpriteKit

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

class ViewController: UIViewController, SwiftyDrawViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, CAAnimationDelegate{
    
    
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
    
    
    var scene: GameScene!
    
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
        self.view.backgroundColor = UIColor.gray
        
        dummyButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        dummyButton.center.x = view.center.x
        dummyButton.backgroundColor = UIColor.blue
        dummyButton.addTarget(self, action:#selector(self.pressed), for: .touchUpInside)
        self.view.addSubview(dummyButton)
        
        infinityButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        infinityButton.center.x = view.center.x + 100
        infinityButton.backgroundColor = UIColor.red
        infinityButton.addTarget(self, action:#selector(self.infinityButtonPressed), for: .touchUpInside)
        self.view.addSubview(infinityButton)
        
        storage = FIRStorage.storage()
        database = FIRDatabase.database()
        
        self.setUpCollectionView()
        collectionView.isHidden = true
        
        self.listenForNewDrawings()
        
        //self.ohStopIt()
        
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
        
        self.view.insertSubview(collectionView, belowSubview: dummyButton)
        
        refresher = UIRefreshControl()
        self.collectionView?.alwaysBounceVertical = true
        refresher.tintColor = UIColor.blue
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
        
        
        

        DispatchQueue.global(qos: .userInitiated).async {
            dbRef.observe(.childAdded, with: { (snapshot) -> Void in
                
                //TODO: BRYAN CAN HELP, CREATE AN OBJECT HERE WITH THE PROPERTIES WE WANT
                let dict = snapshot.value as! NSDictionary
                //print(dict)
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
        dismissButton.center.x = view.center.x
        dismissButton.backgroundColor = UIColor.blue
        dismissButton.addTarget(self, action:#selector(self.dismissButtonPressed), for: .touchUpInside)
        self.modalView.addSubview(dismissButton)

    }
    
    func dismissButtonPressed(){
        modalVC.dismiss(animated: false) { 
            
        }
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
        
        if self.collectionView.isHidden{
            drawView.clearCanvas()
            drawView.drawingEnabled = true

        }
        


        
    }
    
    func doInfinityAnimation(){
        //present a new full screen view
        //concat some paths
        // animate the path
        let gameView = SKView(frame: self.view.frame)
        view.addSubview(gameView)
        

            if let gameScene = GameScene(fileNamed: "GameScene") {
                // Set the scale mode to scale to fit the window
                gameScene.scaleMode = .aspectFill
                self.scene = gameScene

                // Present the scene
                gameView.presentScene(gameScene)
            }
 
       // print("appended path is \(appendedPath)")
       // self.presentModalWithImageAndPath(image: UIImage(named: "face.jpg")!, imagePath: appendedPath.cgPath)
        let pathToAnimate = appendedPath.cgPath
        self.scene.doTheThing(pathToAnimateScaled: pathToAnimate)

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
        
        //searches.insert(viewImage, at: 0)
        //TODO: Append the latest drawing to pablos, with just pic and path
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

            //let path = snapshot.metadata?.customMetadata = ["path" : pathDataAsBase64String]

            
            // Write the download URL to the Realtime Database
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


}

