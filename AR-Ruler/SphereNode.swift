//
//  SphereNode.swift
//  AR-Ruler
//
//  Created by Xiao Ling on 9/8/17.
//  Copyright © 2017 Xiao Ling. All rights reserved.
//

import UIKit
import SceneKit

/*
	This class contains infromation about object frame, and transformation 
	to parent frame
*/
class SphereNode: SCNNode {

	init(position: SCNVector3){

		super.init()

		// the object now also carries a renderable object
		//  and texture
		let sphereGeometry = SCNSphere(radius: 0.005)

		// declare material and specify materiality
		let material       = SCNMaterial()
		material.diffuse.contents = UIColor.red
		material.lightingModel    = .physicallyBased
		sphereGeometry.materials  = [material]

		// note cannot put these on top due to inheritance
		self.geometry = sphereGeometry
		self.position = position

		

	}

	required init?(coder aDecoder: NSCoder){

		fatalError("init(coder:) not implemented")
	}

}
