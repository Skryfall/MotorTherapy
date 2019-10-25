//
//  ViewController.swift
//  MotorTherapy
//
//  Created by Alejandro Ibarra on 10/9/19.
//  Copyright © 2019 Schlafenhase. All rights reserved.
//

import UIKit
import ARKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController, ARSessionDelegate {
    
    // -------------------- ATTRIBUTES -------------------- //

    // Main UI views
    @IBOutlet var arView: ARView!
    @IBOutlet weak var messageLabel: MessageLabel!
    
    // Anchors and entities
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [0, 0, 0] // Offset robot position
    let characterAnchor = AnchorEntity()
    var box: Entity?
    var realityAnchor = AnchorEntity()
    
    // A tracked raycast which is used to place the character accurately
    // in the scene wherever the user taps.
    var placementRaycast: ARTrackedRaycast?
    var tapPlacementAnchor: AnchorEntity?
    
    // Reality Composer scene
    var experienceScene = Experience.Scene()
    
    // -------------------- FUNCTIONS -------------------- //
    
    
    // Loads default elements in AR
    func loadReality() {
        // Create new anchor to append entities
        realityAnchor.addChild(experienceScene.box!)
        arView.scene.addAnchor(realityAnchor)
        
        // Add body tracked character
        arView.scene.addAnchor(characterAnchor)
    }
    
    // Loads body tracked robot character
    func loadRobot() {
        // Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "models/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                // Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()
            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent screen lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Name anchors
        characterAnchor.name = "Character Anchor"
        realityAnchor.name = "Reality Anchor"
        
        // Load Reality Composer scene
        experienceScene = try! Experience.loadScene()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arView.session.delegate = self
        
        // If the iOS device doesn't support body tracking, raise a developer error.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configuration.
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticSkeletonScaleEstimationEnabled = true
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        
        // Load AR elements
        loadRobot()
        loadReality()
        
        print("ANCHORS ONE")
        print(arView.scene.anchors)
        print("END ONE")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Print when new anchor is added
        if !anchors.isEmpty {
            anchors.forEach { (anchor) in
                print("""
                      The Type Of Anchor = \(anchor.classForCoder)
                      The Anchor Identifier = \(anchor.identifier)
                      The Anchor Translation = X: \(anchor.transform.columns.3.x), Y: \(anchor.transform.columns.3.y), Z: \(anchor.transform.columns.3.z)
                      """)
            }
        }
        
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            
            print("PLANE ANCHOR HAS BEEN ADDED")
            
            // Measure plane dimensions
            let width = CGFloat(planeAnchor.extent.x)
            let height = CGFloat(planeAnchor.extent.z)
            let plane = SCNPlane(width: width, height: height)
            
            // Change plane material/color
            plane.materials.first?.diffuse.contents = UIColor.blue
            
            // 4
            let planeNode = SCNNode(geometry: plane)
            
            // 5
            let x = CGFloat(planeAnchor.center.x)
            let y = CGFloat(planeAnchor.center.y)
            let z = CGFloat(planeAnchor.center.z)
            planeNode.position = SCNVector3(x,y,z)
            planeNode.eulerAngles.x = -.pi / 2
            
            // 6
            //node.addChildNode(planeNode)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        print("ANCHORS TWO")
        print(arView.scene.anchors)
        print("END TWO")
        
//        print("ANCHORS THREE")
//        print(anchors)
//        print("END THREE")
        
        for anchor in anchors {
            print("READING ANCHOR")
            print(anchor)
            print("READ ANCHOR")
            if anchor is ARBodyAnchor {
                let bodyAnchor = anchor
                
                // Update the position of the character anchor's position.
                let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
                characterAnchor.position = bodyPosition
                    //+ characterOffset

                // Also copy over the rotation of the body anchor, because the skeleton's pose
                // in the world is relative to the body anchor's rotation.
                characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation

                if let character = character, character.parent == nil {
                    // Attach the character to its anchor as soon as
                    // 1. the body anchor was detected and
                    // 2. the character was loaded.
                    characterAnchor.addChild(character)
                }
            } else if anchor is ARPlaneAnchor {
                
                print("PLANE ANCHOR DETECTED")
                print(anchor)
                print("END PLANE ANCHOR DETECTION")
                
                let planeAnchor = anchor
                
                let planePos = simd_make_float3(planeAnchor.transform.columns.3)
                realityAnchor.position = planePos
            }
        }
    }

}
