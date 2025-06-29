import SwiftUI
import Metal
import MetalKit


//	wrapper to interface with protocol
public class AnyPopActor : PopActor
{
	public var translation : simd_float3	{	get{	wrapped.translation	}		set{	wrapped.translation = newValue	}	}
	public var rotationPitch: Angle		{	get{	wrapped.rotationPitch	}	set{	wrapped.rotationPitch = newValue	}	}
	public var rotationYaw: Angle			{	get{	wrapped.rotationYaw	}		set{	wrapped.rotationYaw = newValue	}	}
	
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
	}
	
	public var id = UUID()
	var wrapped : any PopActor
	
	public init(_ actor:any PopActor)
	{
		self.wrapped = actor
	}
}

public struct MetalSceneView : View, ContentRenderer
{
	var scene : any PopScene
	var showGizmosOnActors : [UUID]
	var camera = PopCamera()
	
	public init(scene: any PopScene,showGizmosOnActors:[UUID])
	{
		self.scene = scene
		self.showGizmosOnActors = showGizmosOnActors
	}

	public var body: some View 
	{
		MetalView(contentRenderer: self)
			.overlay
		{
			//	showing gizmos in future will require a camera to do 2d<>3d stuff
			var gizmoActors = scene.Actors(withUids:showGizmosOnActors)
			//	these need to be a concrete type... how do we do this... damn you lack of virtual types
			ForEach(gizmoActors, id:\.id)
			{
				actor in
				let actorWrapper = AnyPopActor(actor)
				ActorGizmo(actor: actorWrapper)
			}
	
		}
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
	MetalSceneView(scene: DummyScene(), showGizmosOnActors: [])
}
