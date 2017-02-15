//  ViewController.swift
//  ifeellikepablo
//
//  Created by nick barr on 2/4/17.
//  Copyright © 2017 poemsio. All rights reserved.


import UIKit
import Firebase
import FirebaseStorage
import FirebaseDatabase

class ViewController: UIViewController, SwiftyDrawViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, CAAnimationDelegate{
    
    
    //# MARK: - Variables
    
    var database: FIRDatabase!
    var storage: FIRStorage!
    var drawView: SwiftyDrawView!
    var dummyButton: UIButton!
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

    
    //# MARK: - View Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let drawFrame = CGRect(x: 0, y: 0, width: 300, height: 300)
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
        
        storage = FIRStorage.storage()
        database = FIRDatabase.database()
        
        self.setUpCollectionView()
        collectionView.isHidden = true
        
        self.listenForNewDrawings()
        
        //self.ohStopIt()
        
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
        expandedImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        expandedImageView.center = self.view.center
        expandedImageView.image = image
        modalView.addSubview(expandedImageView)
        modalVC = UIViewController()
        modalVC.view = modalView
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapDetectedSoAnimatePath))
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
        
        animateView.layer.addSublayer(shapeLayer)
        
        shapeLayer.path = pathToAnimate//drawView.path
        
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
    
//    func ohStopIt(){
//        
//        
//        if (drawView.path != nil){ // TODO: ASK BRYAN
//            let bezierPath = UIBezierPath(cgPath: drawView.path!)
//            let pathData = NSKeyedArchiver.archivedData(withRootObject: bezierPath)
//            let pathDataAsString = String(data: pathData, encoding: .utf8)
//            let pathDataAsBase64String = pathData.base64EncodedString()
//            //print(pathDataAsBase64String)
//            
//            
//            let decodedData = NSData(base64Encoded: pathDataAsBase64String, options: NSData.Base64DecodingOptions(rawValue: 0))
//            
//            let decodedBezierPath:UIBezierPath = NSKeyedUnarchiver.unarchiveObject(with: decodedData as! Data) as! UIBezierPath
//            let decodedCgPath = decodedBezierPath.cgPath
//            
//            let dumbView = UIView(frame: collectionView.frame)
//            collectionView.addSubview(dumbView)
//            
//            shapeLayer.strokeColor = UIColor.black.cgColor
//            shapeLayer.fillColor = UIColor.clear.cgColor
//            shapeLayer.lineWidth = 2.0
//            shapeLayer.lineCap = kCALineCapRound
//            
//            dumbView.layer.addSublayer(shapeLayer)
//            
//            shapeLayer.path = decodedCgPath//drawView.path
//            
//            let animation = CABasicAnimation(keyPath: "strokeEnd")
//            /* set up animation */
//            animation.fromValue = 0.0
//            animation.toValue = 1.0
//            animation.duration = 2.5
//            shapeLayer.add(animation, forKey: "drawLineAnimation")
//        }
//    }
    
    
    func pressed(sender: UIButton!){
        print("pressed")
        
        //TODO: ASK BRYAN
        
        //GOAL: ALWAYS PUT THE ONE YOU JUST CREATED AT TOP. THE REST REVERSE CHRON SORT. NEVER DUPE.
//        searches.append(viewImage)
//
//        let indexPath = IndexPath(item: 1, section: 1)
//        self.collectionView.insertItems(at: [indexPath])
        
        //self.ohStopIt()


        
        self.collectionView.reloadData()
        self.collectionView.isHidden = !self.collectionView.isHidden
        
        if self.collectionView.isHidden{
            drawView.clearCanvas()
            drawView.drawingEnabled = true

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
            
            
            //TODO: UGH SAVE CGPATH TO [STRING: STRING]
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

