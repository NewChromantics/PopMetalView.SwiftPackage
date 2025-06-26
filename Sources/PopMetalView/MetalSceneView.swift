import SwiftUI
import Metal
import MetalKit

/*
 
	These are all a simple "scene" API, which are really abstracted away from metal...
	Lets renamed this away from "Pop" - Content?
 
*/


public struct PopCamera
{
	//var viewportPixelSize : CGSize
}

public struct PopRenderCamera
{
	public var camera : PopCamera
	public var viewportPixelSize : CGSize
	public var viewportPixelSizeSimd : SIMD2<Int>	{	SIMD2<Int>( Int(viewportPixelSize.width), Int(viewportPixelSize.height) )	}
}


public protocol PopActor : ObservableObject
{
	//	helpers for now
	//	setters for UI
	var translation : simd_float3	{	get set	}
	var rotationPitch : Angle	{	get set }
	var rotationYaw : Angle	{	get set	}
	
	func Render(camera:PopRenderCamera,metalView:MTKView,commandEncoder:any MTLRenderCommandEncoder) throws
}

public extension PopActor
{
	var localToWorldTransform : simd_float4x4	
	{
		let rotationMatrixX = matrix4x4_rotation(radians: Float(rotationPitch.radians), axis: SIMD3<Float>(1, 0, 0) )
		let rotationMatrixY = matrix4x4_rotation(radians: Float(rotationYaw.radians), axis: SIMD3<Float>(0, 1, 0) )
		let translationMatrix = matrix4x4_translation( translation.x, translation.y, translation.z )
		let localToWorld = translationMatrix * rotationMatrixY * rotationMatrixX
		return localToWorld
	}
}

public protocol PopScene
{
	var actors : [any PopActor]	{	get	}
}



public struct MetalSceneView : View, ContentRenderer
{
	var scene : any PopScene
	var camera = PopCamera()
	
	public init(scene: any PopScene)
	{
		self.scene = scene
	}

	public var body: some View 
	{
		MetalView(contentRenderer: self)
	}
	
	public func Draw(metalView: MTKView, size: CGSize, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
		metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
		//metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
		metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm
		metalView.clearDepth = 1.0
		//	splats need to blend with black
		metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
		metalView.sampleCount = 1
		
		let renderCamera = PopRenderCamera(camera: self.camera, viewportPixelSize: size)
		
		//	render each actor
		for sceneActor in scene.actors
		{
			try sceneActor.Render(camera: renderCamera, metalView: metalView, commandEncoder: commandEncoder)
		}
	}
	
}



struct DummyScene : PopScene
{
	var actors : [any PopActor]
	
	init()
	{
		self.actors = []
		
		//	todo: populate with some simple actors that can render a quad etc
	}
}

#Preview 
{
	MetalSceneView(scene: DummyScene())
}
