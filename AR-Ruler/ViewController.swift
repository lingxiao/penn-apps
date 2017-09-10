//
//  ViewController.swift
//  AR-Ruler
//
//  Created by Xiao Ling on 9/7/17.
//  Copyright © 2017 Xiao Ling. All rights reserved.
//
// sources:
// https://blog.pusher.com/building-an-ar-app-with-arkit-and-scenekit/
// 
// 

import UIKit
import ARKit
import SceneKit
import Foundation
import SceneKit
import Firebase

class ViewController
	: UIViewController 
	, ARSCNViewDelegate    
	, UIImagePickerControllerDelegate
	, UINavigationControllerDelegate
	{

    @IBOutlet weak var sceneView: ARSCNView!
    
    // firebase database hooks
	var rootRef    : DatabaseReference!
	var contentRef : DatabaseReference!
    var imageRef   : DatabaseReference!
    var storage    : Storage!
    var storageRef : StorageReference!

    // random ID Generator
    let randID = NSUUID()

	// store stuff from user inputs
	var currentText: String!
	var chosenImage: UIImage!

	var last_msg_is_image : Bool = false

	let picker = UIImagePickerController()
    
    override func viewDidLoad() {

        super.viewDidLoad()

        // setup database
        self.rootRef    = Database.database().reference()
        self.contentRef = Database.database().reference().child("contentObj")
        self.imageRef   = Database.database().reference().child("imageObj")
        
        self.storage = Storage.storage()
        self.storageRef = self.storage.reference()

        // set delegates
        picker.delegate = self

        // debug database
        // conditionRef.setValue("hello world")

        // debug options
        // show world origin will put coordinate frame on world coordinate
        // showFeaturePoints will display some sort of feature points
        sceneView.debugOptions = [ ARSCNDebugOptions.showWorldOrigin
                                 , ARSCNDebugOptions.showFeaturePoints
                                 ]

        // although on, does not display anything worthwhile right now
        sceneView.showsStatistics              = true
    	sceneView.autoenablesDefaultLighting   = true

		/*
			If this value is YES (the default), the view automatically creates one or more 
			SCNLight objects and add them to the scene, and update their propeerties to reflected estimated 
			lighting condition in scenen
		*/
    	sceneView.automaticallyUpdatesLighting = true

    	// register to database
    	syncData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    /*
    	Event listeners ======================================================================
    */ 
    override func viewWillAppear(_ animated: Bool){

    	super.viewWillAppear(animated)

    	// run the AR session
    	let config = ARWorldTrackingConfiguration()

    	// detect planes
    	config.planeDetection = ARWorldTrackingSessionConfiguration.PlaneDetection.horizontal 

    	// print("config.planeDetection: ", config.planeDetection)

    	// these options appear standard
    	sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    /*
    	Sync data on view Load ================================================================

		when syncData is called, all markers in the backend are pulled to the front
		and displayed as text boxes in appropriate frame
    */ 
    func syncData(){

        contentRef.observe(.childAdded, with: {(snapshot) -> Void in

            let text      = snapshot.childSnapshot(forPath: "data").value as! String
            let locArray  = snapshot.childSnapshot(forPath: "loc").value as! [Float]
            let transform = SCNMatrix4.init(m11: locArray[0], m12: locArray[1], m13: locArray[2], m14: locArray[3], m21: locArray[4], m22: locArray[5], m23: locArray[6], m24: locArray[7], m31: locArray[8], m32: locArray[9], m33: locArray[10], m34: locArray[11], m41: locArray[12], m42: locArray[13], m43: locArray[14], m44: locArray[15])
            self.recreateText(text: text, transform: transform)

    	})

    	imageRef.observe(.childAdded, with: {(snapshot) -> Void in

            let img_url   = snapshot.childSnapshot(forPath: "data").value as! String
            let locArray  = snapshot.childSnapshot(forPath: "loc").value as! [Float]
            let transform = SCNMatrix4.init(m11: locArray[0], m12: locArray[1], m13: locArray[2], m14: locArray[3], m21: locArray[4], m22: locArray[5], m23: locArray[6], m24: locArray[7], m31: locArray[8], m32: locArray[9], m33: locArray[10], m34: locArray[11], m41: locArray[12], m42: locArray[13], m43: locArray[14], m44: locArray[15])
            self.recreateImage(url: img_url, transform: transform)

    	})
    }

    func recreateText(text: String, transform: SCNMatrix4){

		let text     = self.configureText(message: text)
		let textNode = SCNNode(geometry: text)
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue

		textNode.transform = transform
        
		// attach to node
		sceneView.scene.rootNode.addChildNode(textNode)

		print("recreated text! **************************** ")
    }


    func recreateImage(url: String, transform: SCNMatrix4){


		DispatchQueue.global().async {

            let data = try? Data(contentsOf: URL(string: url)!) 

            if data != nil {

			    DispatchQueue.main.async {

			        let image = UIImage(data: data!)!
			        print("got image!!: ", image, type(of: image))

			        // recreate image plane
			        let width_img  = image.size.width
			        let height_img = image.size.height
			        
			        let scale = 200 / max(width_img, height_img)

			        var plane = SCNPlane(width: width_img*scale, height: height_img*scale)

					// set text node properties
					let planeNode       = SCNNode(geometry: plane)
					planeNode.transform = transform

			        planeNode.geometry?.firstMaterial?.diffuse.contents = image
					self.sceneView.scene.rootNode.addChildNode(planeNode)

			    }
            }
		}

    }

	// MARK: - Event Listener ***********************************************************

    /*
    	place some stuff on the screen on tap
    */
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {

    	let tapLocation = sender.location(in : sceneView)

		/*
			Searches for real world objects or AR anchors in camera image
			in this case get some feature point in image at tapLocation
    	*/
    	let phiAtHit = sceneView.hitTest(tapLocation, types: .featurePoint)

    	if let results = phiAtHit.first {

    		if last_msg_is_image {

    			print("you picked an image!!!! ******************************")

    			// make plane and put image on it
    			dropImage(results: results)


    		} else {

	    		if self.currentText != nil {

	    			dropText(message: self.currentText!, results: results)

	    		} else {

	    			print("No text saved!!!")
	    		}
    		}

	
    	} else {

    		print("no phi found")
    	}
    }

    /*
    	display image in scene and save to backend
    */
    func dropImage(results: ARHitTestResult){

    	let width_img = chosenImage.size.width
        let height_img = chosenImage.size.height
        
        let scale = 200 / max(width_img, height_img)

        var plane = SCNPlane(width: width_img*scale, height: height_img*scale)

		// get position of hit
		let position = SCNVector3.positionFrom(matrix: results.worldTransform)

		var transform = sceneView.session.currentFrame?.camera.transform
        transform?.columns.3.x = 0.0
        transform?.columns.3.y = 0.0
        transform?.columns.3.z = 0.0

		// set text node properties
		let planeNode       = SCNNode(geometry: plane)
		planeNode.geometry  = plane
		planeNode.position  = position
		planeNode.transform = SCNMatrix4Mult(SCNMatrix4.init(transform!), planeNode.transform)
		planeNode.transform = SCNMatrix4Mult(SCNMatrix4MakeScale(0.005,0.005,0.005), planeNode	.transform)
        	

        planeNode.geometry?.firstMaterial?.diffuse.contents = self.chosenImage

        print("image: *********************************************")

        print(self.chosenImage)

        print("image: *********************************************")
        
		sceneView.scene.rootNode.addChildNode(planeNode)


		// Now save image
        let randName   = self.randID.uuidString
        let imageDbRef = self.storageRef.child("images/" + randName + ".jpg")

        var downloadURL : URL!

        let uploadTask = imageDbRef.putData(
        	  UIImageJPEGRepresentation(self.chosenImage, 0.5)!
        	, metadata: nil)
        	
        	// callback
        	{(metadata, error) in guard let metadata = metadata else {
                print("There was an error in uploading the image!")
                return
            }
                downloadURL = metadata.downloadURL()
                print("downloadURL: ", downloadURL)


                var data : NSDictionary
		        
		        var T = [ planeNode.transform.m11
		                , planeNode.transform.m12
		                , planeNode.transform.m13
		                , planeNode.transform.m14
		            
		                , planeNode.transform.m21
		                , planeNode.transform.m22
		                , planeNode.transform.m23
		                , planeNode.transform.m24
		            
		                , planeNode.transform.m31
		                , planeNode.transform.m32
		                , planeNode.transform.m33
		                , planeNode.transform.m34
		            
		                , planeNode.transform.m41
		                , planeNode.transform.m42
		                , planeNode.transform.m43
		                , planeNode.transform.m44
		                ]
		        

		        data  = [ "type": "image", "loc": T, "data": downloadURL.absoluteString ]
		        self.imageRef.childByAutoId().setValue(data)
            }
    }

    /*
    	swipe right to open camera
    */
    @IBAction func swipeRightToCamera(_ sender: UISwipeGestureRecognizer) {
		
		picker.sourceType             = UIImagePickerControllerSourceType.camera
        picker.cameraCaptureMode      = .photo
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true, completion: nil)


        // some clever tricks with grabbing raw feed from arkit
        // let img = sceneView.session.currentFrame?.capturedImage
        // let ciimg = img as? CIImage
        // print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")

        // print("image: ", type(of: img))
        // // print("CIimage: ", type(of: ciimg), ciimg)
        // print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")

        // capturedImage

    }
    
    @IBAction func swipeLeftToText(_ sender: UISwipeGestureRecognizer) {
        showInputDialog()
    }
    
    
    /*
    	message dialogue
    */
	func showInputDialog(){

	    //Creating UIAlertController and
	    //Setting title and message for the alert dialog
	    let alertController = UIAlertController(
	    	  title   : "Drop a message!"
	    	, message : ""
	    	, preferredStyle: .alert
	    	)
	    
	    //the cancel action doing nothing
	    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }

	    alertController.addTextField { (textField) in
	        textField.placeholder = "Enter Text"
	    }

	    //the confirm action taking the inputs
	    let confirmAction = UIAlertAction(title: "Enter", style: .default) { (_) in
	        
	        //getting the input values from user
	        let msg          = alertController.textFields?[0].text
	        self.currentText = msg
	        self.last_msg_is_image = false

	    }	    
	    
	    //adding the action to dialogbox
	    alertController.addAction(confirmAction)
	    alertController.addAction(cancelAction)

	    //finally presenting the dialog box
	    self.present(alertController, animated: true, completion: nil)
	}    

	// MARK: - Image picker Logic ***********************************************************

	func imagePickerController(_ picker: UIImagePickerController, 
      didFinishPickingMediaWithInfo info: [String : Any]) {

		print("delgate fired! *********************************************")

		let chosenImage   = info[UIImagePickerControllerOriginalImage] as! UIImage 
		self.chosenImage  = chosenImage
		self.last_msg_is_image = true

		// myImageView.contentMode = .scaleAspectFit //3
		// myImageView.image = chosenImage //4
		picker.dismiss(animated: true)


	}

	// MARK: - create objects ***********************************************************

	func configureText(message: String) -> SCNText {

		let text  = SCNText(string: message, extrusionDepth: 0.1)
		text.font = UIFont(name: "Helvetica", size: 40)
		return text

	}

    func dropText(message: String, results: ARHitTestResult){

		// get position of hit
		let position = SCNVector3.positionFrom(matrix: results.worldTransform)
		let text     = self.configureText(message: message)

		var transform = sceneView.session.currentFrame?.camera.transform
        transform?.columns.3.x = 0.0
        transform?.columns.3.y = 0.0
        transform?.columns.3.z = 0.0

		// set text node properties
		let textNode       = SCNNode(geometry: text)
		textNode.geometry  = text
		textNode.position  = position
		textNode.transform = SCNMatrix4Mult(SCNMatrix4.init(transform!), textNode.transform)
		textNode.transform = SCNMatrix4Mult(SCNMatrix4MakeScale(0.005,0.005,0.005), textNode.transform)
        	

        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        

		// attach to node
		sceneView.scene.rootNode.addChildNode(textNode)

		print("dropped text! **************************** ")

		// save to data base
		writeToDataBase( text: message
			           , transform: textNode.transform
			           )
	}

    /*
		drop a cube so that it's axis aligned with current camera pose
    */
    func dropCube(results: ARHitTestResult){

		let position = SCNVector3.positionFrom(matrix: results.worldTransform)

		// get transform from world to current camera pose
		// and zero out non-rotation part of matrix
        var transform = sceneView.session.currentFrame?.camera.transform
        transform?.columns.3.x = 0.0
        transform?.columns.3.y = 0.0
        transform?.columns.3.z = 0.0


		/*
			declare a cube
		*/
		let cubeNode = SCNNode( geometry: 
			                    SCNBox( width: 0.1
			                    	  , height: 0.1
			                    	  , length: 0.1
			                    	  , chamferRadius: 0)
			                  )

		// set the cube's position and immediately transform it to camera-pose aligned position
		cubeNode.position  = position
        cubeNode.transform = SCNMatrix4Mult(SCNMatrix4.init(transform!), cubeNode.transform)
        
		// attach to the AR-Scene
		sceneView.scene.rootNode.addChildNode(cubeNode)

		// flip boolean flag in debug mode
		if false {

	        print("********************************************")
	        print("currentFrame: ", sceneView.session.currentFrame?.camera.transform)
	        print("********************************************")

			print("position: ", position)
			print("results.worldTransform: ", results.worldTransform)    

		}
	}

	// MARK: - write to database ***********************************************************

	func writeToDataBase(text: String, transform: SCNMatrix4){

		var data : NSDictionary

		// put numbers into array manually, wow dumb!
		var T = [ transform.m11
		        , transform.m12
		        , transform.m13
		        , transform.m14

				, transform.m21
		        , transform.m22
		        , transform.m23
		        , transform.m24

				, transform.m31
		        , transform.m32
		        , transform.m33
		        , transform.m34

				, transform.m41
		        , transform.m42
		        , transform.m43
		        , transform.m44
		        ]

		data  = ["type": "text", "loc": T, "data": text]

		self.contentRef.childByAutoId().setValue(data)
	}

	// MARK: - listen to database ***********************************************************

	func FIRDataEventTypeChildAdded(){

		print("child added ***********************************************")
	}

}

/*
	Entensions
*/

extension SCNVector3 {

    func distance(to destination: SCNVector3) -> CGFloat {
        let dx = destination.x - x
        let dy = destination.y - y
        let dz = destination.z - z
        return CGFloat(sqrt(dx*dx + dy*dy + dz*dz))
    }
	
	// question: what exactly does this do again???
	// what does it mean to take the third column of this 4x4 matrix?
    static func positionFrom(matrix: matrix_float4x4) -> SCNVector3 {

        let column = matrix.columns.3
        return SCNVector3(column.x, column.y, column.z)

    }

}















