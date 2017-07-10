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

// TODO: Improve Draw Icon

// TODO: Autoplay drawing when you select a pablo

import UIKit
import ReplayKit
import Firebase
import FirebaseStorage
import FirebaseDatabase
import Changeset

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

class ViewController: UIViewController, SwiftyDrawViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, CAAnimationDelegate, RPPreviewViewControllerDelegate, UIWebViewDelegate{//, UIViewControllerPreviewingDelegate{
    
    
    //# MARK: - Variables
    
    var database: FIRDatabase!
    var storage: FIRStorage!
    var drawView: SwiftyDrawView!
    var dummyButton: UIButton!
    var infinityButton: UIButton!
    var igButton: UIButton!
    var cancelButton: UIButton!
    var collectionView: UICollectionView!
    var viewImage: UIImage!
    var refresher:UIRefreshControl!

    //var searches = [UIImage]()
    
    var pablos = [Pablo]()
    var selectedIndexPath: IndexPath!
    
    var shapeLayer = CAShapeLayer()
    
    var trackingLayer = CALayer()
    var pathToAnimate: CGPath? = nil
    
    var coveringWindow: UIWindow?


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
    var animateView:UIView!
    var hidingView:UIView!
    var hidingViewTwo:UIView!
    var previousContentOffset:CGFloat = 0
    
    var updater = CADisplayLink()
    var currentPabloIndex = 0
    var scene: GameScene!
    var infinityViewEnabled = false
    var isRecording = false
    var saveButton: UIButton!
    
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
        dummyButton.backgroundColor = UIColor.clear
        dummyButton.addTarget(self, action:#selector(self.pressed), for: .touchUpInside)
        //dummyButton says "Submit"
        dummyButton.setImage(UIImage(named: "draw_dark"), for: UIControlState.selected)
        dummyButton.setImage(UIImage(named: "grid"), for: UIControlState.normal)
        self.view.addSubview(dummyButton)
        
        
        infinityButton = UIButton(frame: dummyButton.frame)
        infinityButton.frame.size = CGSize(width: 40, height: 40)
        infinityButton.frame.origin.x = self.view.frame.width - 80
        infinityButton.center.y = dummyButton.center.y
        infinityButton.setImage(UIImage(named: "infinity"), for: UIControlState.normal)
        infinityButton.addTarget(self, action: #selector(self.infinityButtonPressed), for: .touchUpInside)
        infinityButton.isHidden = true
        self.view.addSubview(infinityButton)
        
        igButton = UIButton(frame: dummyButton.frame)
        igButton.frame.size = CGSize(width: 40, height: 40)
        igButton.frame.origin.x = 40
        igButton.center.y = dummyButton.center.y
        igButton.setImage(UIImage(named: "ig"), for: UIControlState.normal)
        igButton.addTarget(self, action: #selector(self.igButtonPressed), for: .touchUpInside)
        igButton.isHidden = true
        self.view.addSubview(igButton)
        
        
        
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
    
        self.presentModalWithImageAndPath(image: cellImage, imagePath: imagePath)

    
        
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
                    //var newPablos = self.pablos
                    self.pablos.append(Pablo(uid: snapshot.key, image: pic, path: decodedCgPath, dateCreated: timeCreatedAsDate))
                    self.pablos.sort(by: { $0.dateCreated.compare($1.dateCreated as Date) == .orderedDescending })
                    
                    // get a changeset between old and new using Changeset
                    //let changeset = Changeset<[Pablo]>(source: self.pablos, target: newPablos)
                    //self.collectionView.updateWithEdits(changeset.edits, inSection: 0)
                    self.collectionView?.reloadData()
                    //TODO: how did this used to work?
                    print("new pablo")

                })
                
                //print("pablos: \(self.pablos)")
  
            })
        }
    }

    
    
    
    // MARK: - Miscellaneous
    
    func igButtonPressed(){
        
        let webViewController = UIViewController()
        let webView = UIWebView(frame:CGRect(x: 0, y: 20, width: self.view.frame.width, height: self.view.frame.height-20))
        webViewController.view = webView
        //webView.delegate = self
        if let url = URL(string: "https://instagram.com/pablo_oneline"){
            let request = URLRequest(url:url)
            webView.loadRequest(request)
        }
        
        let navController = UINavigationController(rootViewController: webViewController)
        webViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.dismissVc))
        
        self.present(navController, animated: true, completion: nil)

        
    }
    
    
    func dismissVc(){
        self.dismiss(animated: true, completion: nil)
    }
    func presentModalWithImageAndPath(image: UIImage, imagePath: CGPath){
        
        
        modalView = UIView(frame: self.view.frame)

        dismissButton = UIButton(frame: CGRect(x: 0, y: self.view.frame.height - 100, width: 55, height: 55))
        dismissButton.setImage(UIImage(named: "grid"), for: UIControlState.normal)
        
        dismissButton.center.x = view.center.x
        dismissButton.backgroundColor = UIColor.blue
        dismissButton.addTarget(self, action:#selector(self.dismissButtonPressed), for: .touchUpInside)
        self.modalView.addSubview(dismissButton)
        
        
       
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
        expandedImageView.isUserInteractionEnabled = true
        expandedImageView.addGestureRecognizer(tapRecognizer)
        self.present(modalVC, animated: false) {
            //stuff
        }
        

        
        saveButton = UIButton(frame: CGRect(x: 0, y: expandedImageView.frame.origin.y + expandedImageView.frame.height + 10, width: 44*2.836, height: 44))
        saveButton.setImage(UIImage(named: "save"), for: UIControlState.normal)
        saveButton.setImage(UIImage(named: "saving"), for: UIControlState.selected)
        saveButton.addTarget(self, action: #selector(self.saveButtonTapped), for: UIControlEvents.touchUpInside)
        self.modalView.addSubview(saveButton)

    }
    
    func coverEverything() {
//        coveringWindow = UIWindow(frame: UIScreen.main.bounds)
//        
//        if let coveringWindow = coveringWindow {
//            coveringWindow.windowLevel = UIWindowLevelAlert + 1
//            coveringWindow.isHidden = false
//            coveringWindow.backgroundColor = UIColor.clear
//            coveringWindow.isUserInteractionEnabled = false
//            let maskedView = UIView(frame: coveringWindow.bounds)
//            maskedView.backgroundColor = UIColor.blue
//            let maskLayer = CAShapeLayer()
//            let maskRect = CGRect(x: 0, y: (self.view.frame.height-self.view.frame.width)/2, width: self.view.frame.width, height: self.view.frame.width)
//            let path = CGPath(rect: maskRect, transform: nil)
//            maskLayer.path = path
//            maskedView.layer.mask = maskLayer
//            coveringWindow.addSubview(maskedView)
//        }
        
//        hidingView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: (self.view.frame.height-self.view.frame.width)/2))
//        hidingView.backgroundColor = UIColor.black
//        self.modalView.addSubview(hidingView)
//        
//        hidingViewTwo = UIView(frame: CGRect(x: 0, y: (self.view.frame.height-self.view.frame.width)/2+self.view.frame.width, width: self.view.frame.width, height: (self.view.frame.height-self.view.frame.width)/2))
//        hidingViewTwo.backgroundColor = UIColor.black
//        self.modalView.addSubview(hidingViewTwo)
//        
        
    }
    
    func saveButtonTapped(sender : UIButton){
        print("save tapped!")
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        let recorder = RPScreenRecorder.shared()
        
        self.coverEverything()
        
//        coveringWindow.isUserInteractionEnabled = false
//        coveringWindow.isHidden = false
//        coveringWindow.windowLevel = UIWindowLevelAlert
//        coveringWindow.makeKeyAndVisible()
        
        recorder.startRecording{ [unowned self] (error) in
            
            if let unwrappedError = error {
                print(unwrappedError.localizedDescription)
            } else {
                self.isRecording = true
                self.saveButton.isSelected = true
                self.saveButton.isUserInteractionEnabled = false
                //TODO: when the user doesn't allow, this is still showing as true??
                self.tapDetectedSoAnimatePath()
            }
        }
    }
    
    func infinityButtonPressed(){
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        if self.bigSquare == nil{
            infinityViewEnabled = true
            self.doInfinityAnimation()
        }
        
    }
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        print("ok")
        dismiss(animated: true)
    }
//

    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let currentOffset = scrollView.contentOffset.y
        
        if (currentOffset > self.previousContentOffset) && (currentOffset > 4){
            //scrolldown
            UIView.animate(withDuration: 0.4, animations: {
                self.dummyButton.center.y = self.view.frame.height + 200
                self.infinityButton.center.y = self.dummyButton.center.y
                self.igButton.center.y = self.dummyButton.center.y
            })
        }
        else if (currentOffset < self.previousContentOffset - 6){
            //scrollup
            UIView.animate(withDuration: 0.4, animations: {
                self.dummyButton.center.y = (self.view.frame.height - 100 + (55/2))
                self.infinityButton.center.y = self.dummyButton.center.y
                self.igButton.center.y = self.dummyButton.center.y

            })

        }
        self.previousContentOffset = currentOffset
    }

//    
//    //    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
//    //        print("started decel")
//    //        if collectionView == scrollView{
//    //            dummyButton.isHidden = true
//    //        }
//    //
//    //    }
//    
//    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        print("ended decel")
//        if collectionView == scrollView{
//            dummyButton.isHidden = false
//        }
//    }
    


    
    func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        self.isRecording = false
        
        recorder.stopRecording { [unowned self] (preview, error) in
            
            if preview != nil {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                preview?.previewControllerDelegate = self
                let alertController = UIAlertController(title: "Recording", message: "Save a recording of this Pablo?", preferredStyle: .alert)
                
                let discardAction = UIAlertAction(title: "Discard", style: .default) { (action: UIAlertAction) in
                    RPScreenRecorder.shared().discardRecording(handler: { () -> Void in
                        // Executed once recording has successfully been discarded
                    })
                }
                
                let viewAction = UIAlertAction(title: "Preview", style: .default, handler: { (action: UIAlertAction) -> Void in
                    self.modalVC.present(preview!, animated: true, completion: nil)
                })
                
                alertController.addAction(discardAction)
                alertController.addAction(viewAction)
                self.saveButton.isSelected = false
                self.saveButton.isUserInteractionEnabled = true
//                self.hidingView.removeFromSuperview()
//                self.hidingViewTwo.removeFromSuperview()

                self.modalVC.present(alertController, animated: true, completion: nil)
                
//                self.shareButton.removeTarget(self, action: #selector(self.stopRecording), for: .touchUpInside)
//                self.shareButton.addTarget(self, action: #selector(self.startRecording), for: .touchUpInside)
//                self.shareButton.setImage(UIImage(named: "play"), for: UIControlState.normal)
                //should.setTitle("Start Recording", forState: .Normal)
                //sender.setTitleColor(UIColor.blueColor(), forState: .Normal)
            } else {
                // Handle error
                print("some kind of error: \(error)")
            }
        }
    }
    

    
    
    
    func dismissButtonPressed(){

            modalVC.dismiss(animated: false, completion: nil)

    }
    func tapDetectedSoAnimatePath() {
        print("tap!")
        
        
        animateView = UIView(frame: expandedImageView.frame)
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
        
        let foo = UIBezierPath(cgPath: pathToAnimateScaled).elements

        
        //TODO: Bryan can help? This is sometimes nil (I think only on bad old stuff)
        let imageWidth = ScreenWidth.initWith(pixelWidth: pabloImageWidth)
        let animateLayerWidth = animateView.frame.width
        
        if imageWidth == nil{
            scaleRatio = 1
        }
        else {
            scaleRatio = animateLayerWidth/pabloImageWidth*imageWidth!.resolution
        }

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
        var duration = foo.count/120
        if duration > 15{
            duration = 15
        }
        animation.duration = CFTimeInterval(duration)
        shapeLayer.add(animation, forKey: "drawLineAnimation")

    
    }
    

    
    
    func pressed(sender: UIButton!){
        print("pressed")
        

        self.collectionView.setContentOffset(CGPoint.zero, animated: false)
        
        self.collectionView.isHidden = !self.collectionView.isHidden
        self.dummyButton.isSelected = !self.dummyButton.isSelected
        
        if self.collectionView.isHidden{
            drawView.clearCanvas()
            drawView.drawingEnabled = true
            infinityButton.isHidden = true
            igButton.isHidden = true
        }
        else {
            infinityButton.isHidden = false
            igButton.isHidden = false
        }
    
        
    }
    
    
    
    func doInfinityAnimation(){
        
        if self.pablos.isEmpty == false{
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(0), execute: {

                self.beginInfinityMode()
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
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

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
       // print("loop")
        if let fp = trackingLayer.presentation()?.position{
            //print(fp)
            let cp = shapeLayer.presentation()?.value(forKey: "strokeEnd") as! Float
            if cp != 1.0{
                
                
                let mainWindow = UIApplication.shared.keyWindow
                let pointInWindow = mainWindow!.convert(fp, from: nil)
                let pointInView = view.convert(pointInWindow, from: mainWindow)
                
                UIView.animate(withDuration: 1.0, animations: {
                    self.bigSquare.center.y = self.view.center.y-pointInWindow.y + self.view.frame.width/2
                    self.bigSquare.center.x = self.view.center.x-pointInWindow.x + self.view.frame.width/2
                })
            
            
            //    print(self.view.center)
            }
            else{
              //  print("animation done")
                //   print(cp)
            }
        }
    }
    
    func animationDidStart(_ anim: CAAnimation) {
        print("started \(anim)")
        if infinityViewEnabled == true{
            let modifiedNextPath = self.transformPathToFitWithEndpoint(imagePath:pablos[currentPabloIndex+1].path)
            pablos[currentPabloIndex+1].path = modifiedNextPath
        }
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        print("stopped \(anim)")
        /*
         better scalable solution
         if([[animation valueForKey:@"animationID"] isEqual:@"animation1"]) {
         //animation is animation1
         */
 
        if infinityViewEnabled == true{
            currentPabloIndex = currentPabloIndex + 1
            if currentPabloIndex == 10 { // silly way to run forever for now
                currentPabloIndex = 0
            }
            self.startInfinityAnimation(pathToAnimateScaled: pablos[currentPabloIndex].path)
        }
        else{
            print("was recording, now will stop")
            self.stopRecording()
           //TODO: UNFUCK
            //animateView?.alpha = 0.0
            shapeLayer.strokeEnd = 1

            
        }


    }
    
    func transformPathToFitWithEndpoint(imagePath:CGPath) -> CGPath {

        imagePathStartPoint = UIBezierPath(cgPath: imagePath).firstPoint()
        
        
        if oldImagePathEndPoint == nil{
            print("no old image path")
            oldImagePathEndPoint = pablos[currentPabloIndex].path.currentPoint
        }
        else {
            print("setting old imagepath")
            oldImagePathEndPoint = imagePathEndPoint
        }
        
        xTrans = oldImagePathEndPoint.x - imagePathStartPoint.x
        yTrans = oldImagePathEndPoint.y - imagePathStartPoint.y
        //print("oldEnd:\(oldImagePathEndPoint), imageStart:\(imagePathStartPoint), imageEnd:\(imagePathEndPoint)")
        //print("x: \(xTrans). y: \(yTrans)")
        
        var pathTransform = CGAffineTransform(translationX: xTrans, y: yTrans)

        let transformedPath = imagePath.copy(using: &pathTransform)
        
        imagePathEndPoint = transformedPath!.currentPoint
        
        return transformedPath!
    }
    
    func beginInfinityMode(){
        
        bgSquare = UIView(frame: self.view.frame)
        bgSquare.backgroundColor = UIColor.black
        self.view.addSubview(bgSquare)
        
        bigSquare = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.width))
        bigSquare.backgroundColor = UIColor.black
        self.view.addSubview(bigSquare)
        bigSquare.center = view.center
        
        cancelButton = UIButton(frame: self.infinityButton.frame)
        cancelButton.frame.size = CGSize(width: 40, height: 40)
        cancelButton.setImage(UIImage(named: "cancel"), for: UIControlState.normal)
        cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), for: .touchUpInside)
        bgSquare.addSubview(cancelButton)
        
        updater = CADisplayLink(target: self, selector: #selector(ViewController.gameLoop))
        updater.preferredFramesPerSecond = 60
        updater.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
        currentPabloIndex = 0
        self.startInfinityAnimation(pathToAnimateScaled: pablos[currentPabloIndex].path)

        
        
        // MONDAY
        // animate the first pablo
        // when that's done, if there's another one ready, animate that one (completion block)
        // the (first pablo is its own CAShapeLayer hanging out in the background)
        // We know the endpoint of pablo[1] before it completes, that point needs to become the start point of pablo [2]
        // array of pablos (fifo queue for pablos)
        
        // PabloQueue
        // var currentPablo: Int = 0
        // var queue: [Pablos] = []
        // func enqueue(pablo: Pablo) // adds one to the end
        // func advance() -> Pablo? // increments currentPablo and... something?
        
        /*
         func advance() -> Pablo? {
         guard !queue.isEmpty else { return nil }
         
         guard newIndex < queue.count else {
         currentPablo = min(0, currentPablo - 10)
         return advance()
         }
         currentPablo += 1
         return queue[newIndex]
         }
         */
        
        // InfinityView
        //
        // let pabloQueue: PabloQueue
        // var currentAnimation: CABasicAnimation?
        // func startAnimations()
        // func animate(pablo: Pablo)
        // CAAnimation.delegate.animationDidStart(_)
        // CAAnimation.delegate.animationDidStop(_:finished:) needs to be called here somewhere,
        // func pabloDidFinishDrawing(pablo: Pablo) // schedule the next pablo to be drawn, and create a new CAShapeLayer to hold the previous Pablo
    }

    
    
    func cancelButtonPressed(){
        infinityViewEnabled = false
        self.bgSquare.removeFromSuperview()
        self.bigSquare.removeFromSuperview()
        self.bigSquare = nil
        updater.remove(from: RunLoop.current, forMode: RunLoopMode.commonModes)
        //maybe something hacky like remove delegate :/
        
    }

    
    func startInfinityAnimation(pathToAnimateScaled: CGPath){
        
        let newShapeLayer = CAShapeLayer()
        newShapeLayer.strokeColor = UIColor.white.cgColor
        newShapeLayer.fillColor = UIColor.clear.cgColor
        newShapeLayer.lineWidth = 2.0
        newShapeLayer.lineCap = kCALineCapRound
        newShapeLayer.frame = self.view!.frame
        bigSquare.layer.addSublayer(newShapeLayer)
        newShapeLayer.path = pathToAnimateScaled
        
        trackingLayer.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        trackingLayer.backgroundColor = UIColor.clear.cgColor // UIColor.red.cgColor
        newShapeLayer.addSublayer(trackingLayer)
        
        //self.view.bringSubview(toFront: cancelButton)
        
        
        //CATransaction.begin()
        shapeLayer = newShapeLayer
        
        
        let foo = UIBezierPath(cgPath: shapeLayer.path!).elements
        print ("number of elements:\(foo.count)")
        
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
              //  Swift.print("\(command) \(points)")
                //add points to the arrayOfPoints but there's some C function pointer
            }
         //      print ("number of points in array:\(points.count)")
         //   print("point count = \(pointCount)")
         //   print("element count = \(foo.elements)")
        }
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.delegate = self
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = CFTimeInterval(foo.count/80)
        
        //we want the duration to be a function of the length; eg., we want something like 1 s / segment
        //so number of elements looks like 50 all the way to 1300
        //just divide by... what? take a fraction of it? ie., if we wanted those to take 1 s/ 50, then we'd just divide by 50. start there I guess?
        
        
        newShapeLayer.add(animation, forKey: "drawLineAnimation")
        
        
        let followPathAnimation = CAKeyframeAnimation(keyPath: "position")
        //followPathAnimation.delegate = self
        followPathAnimation.path = shapeLayer.path
        followPathAnimation.duration = animation.duration
        followPathAnimation.calculationMode = kCAAnimationPaced
        trackingLayer.add(followPathAnimation, forKey: "positionAnimation")
        
        
        
        

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
                infinityViewEnabled = true
                self.doInfinityAnimation()
            }
            else {
                infinityViewEnabled = false
                self.bgSquare.removeFromSuperview()
                self.bigSquare.removeFromSuperview()
                self.bigSquare = nil
                updater.remove(from: RunLoop.current, forMode: RunLoopMode.commonModes)
                //maybe something hacky like remove delegate :/
                
            }
            
        }
    }
    
    override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
        print("Device was shaken!")
    }

}

