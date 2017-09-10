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
	, ARSCNViewDelegate    // we need to track status of ARSCN
	{

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var boomButton: UIButton!
    
    // firebase database hooks
	var rootRef    : DatabaseReference!
	var contentRef : DatabaseReference!
    
    // declare variable for T init storage
    var T_init : SCNMatrix4!
    let NODE_NAME = "regen_text"

	// initialization phase
	// todo: what if we reopen app, is it in init phase?
	var initPhase : Bool = true

    override func viewDidLoad() {

        super.viewDidLoad()

        // setup database
        self.rootRef    = Database.database().reference()
        self.contentRef = Database.database().reference().child("contentObj")

        // store initialization transform
        self.T_init = SCNMatrix4Identity

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


    	// initailize with cube
    	// makeCube()
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
            // let snap = snapshot.value as! [String: Any]
    		// print("snapshot added: ", snapshot)
            let text      = snapshot.childSnapshot(forPath: "data").value as! String
            let locArray  = snapshot.childSnapshot(forPath: "loc").value as! [Float]
            let transform = SCNMatrix4.init(m11: locArray[0], m12: locArray[1], m13: locArray[2], m14: locArray[3], m21: locArray[4], m22: locArray[5], m23: locArray[6], m24: locArray[7], m31: locArray[8], m32: locArray[9], m33: locArray[10], m34: locArray[11], m41: locArray[12], m42: locArray[13], m43: locArray[14], m44: locArray[15])
            self.recreateText(text: text, transform: transform)
    	})
    }

    func recreateText(text: String, transform: SCNMatrix4){
    	// set text properties
		let text  = SCNText(string: "hello world", extrusionDepth: 1.0)
		text.font = UIFont(name: "Optima", size: 5)    // dfault is helvetica 36

		let textNode = SCNNode(geometry: text)
		textNode.transform = transform
        
        // set name for regenerated nodes for later transformations
        textNode.name = NODE_NAME

		// attach to node
		sceneView.scene.rootNode.addChildNode(textNode)

		print("recreated text! **************************** ")
    }


	// MARK: - Event Listener ***********************************************************

	/*
		toggle app from init state to demo state
	*/
    @IBAction func onInit(_ sender: UIButton) {
        
        // print("BOOOM")
        let T_init_new = SCNMatrix4.init(sceneView.session.currentFrame!.camera.transform)
        
        updateContent(T_init_new: T_init_new)
        
        self.T_init = T_init_new

    }
    
    func updateContent(T_init_new: SCNMatrix4){
        for node in sceneView.scene.rootNode.childNodes{
            if node.name != nil{
                node.transform = SCNMatrix4Mult(SCNMatrix4Invert(self.T_init), node.transform)
                node.transform = SCNMatrix4Mult(T_init_new, node.transform)
            }
        }
    }
    

    /*
    	place some stuff on the screen on tap
    */
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {

    	// print("ping tap")
    	let tapLocation = sender.location(in : sceneView)

    	/*
			Searches for real world objects or AR anchors in camera image
			in this case get some feature point in image at tapLocation
    	*/
    	let phiAtHit = sceneView.hitTest(tapLocation, types: .featurePoint)

        /*
        	if we found features at this point,
        	we declare a node at this point so that: node = (C_i, T_i^0)
        	where C_i is the coordinate from of this node, and T_i^0 is:
        		C_o = T_i^o C_i
        	where C_o is body frame coordinate
        */
    	if let results = phiAtHit.first {

	    	/*
				At initalization phase we drop a box ontop of 
				existing box in scene and fix world coordinates
	    	*/
	    	dropText(results: results)

    	} else {

    		print("no phi found")
    	}
    }
    
	
	// MARK: - create objects ***********************************************************

    func dropText(results: ARHitTestResult){

		// get position of hit
		let position = SCNVector3.positionFrom(matrix: results.worldTransform)

        var transform = sceneView.session.currentFrame?.camera.transform
        transform?.columns.3.x = 0.0
        transform?.columns.3.y = 0.0
        transform?.columns.3.z = 0.0
        // transform?.columns.3.w = 0.05

		// set text properties
		let text  = SCNText(string: "hello world", extrusionDepth: 1.0)
		text.font = UIFont(name: "Optima", size: 5)    // dfault is helvetica 36

		// textGeometry.firstMaterial?.diffuse.contents = UIColor.black 		

		// set text node properties
		let textNode = SCNNode(geometry: text)
		textNode.geometry  = text
		textNode.position  = position
		textNode.transform = SCNMatrix4Mult(SCNMatrix4.init(transform!), textNode.transform)
		textNode.transform = SCNMatrix4Mult(SCNMatrix4MakeScale(0.005,0.005,0.005), textNode.transform)

		// attach to node
		sceneView.scene.rootNode.addChildNode(textNode)

		print("dropped text! **************************** ")

		// save to data base
		writeToDataBase( text: "hello world from front"
			           , transform: textNode.transform
			           )
	}

	func makeCube(){

		let position = SCNVector3Make(0.0,0.0,0)

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

		sceneView.scene.rootNode.addChildNode(cubeNode)


		print("added init cube")



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

	// MARK: - ARSCNViewDelegate ***********************************************************

	// add a node at position: anchor
	public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

		print("this may work???")

		guard let anchor = anchor as? ARPlaneAnchor else { 
			
			print("no anchor")
			return 

		}

		print("anchor.extant: ", anchor.extent)
	}


	func session(_ session: ARSession
		                  , cameraDidChangeTrackingState camera: ARCamera){

    	print("loading ===============================")

        switch camera.trackingState {

    		case ARCamera.TrackingState.notAvailable:
    			print("status notAvailable")

    		case ARCamera.TrackingState.limited(_):
    			print("Analyzing")

    		case ARCamera.TrackingState.normal:
    			print("reading")

    	}

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















