import SwiftUI
import Metal
import MetalKit
import MouseTracking




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
	/*@Binding*/ var scene : any PopScene
	var showGizmosOnActors : [UUID]
	
	@Binding var camera : PopCamera
	
	var isDraggingCamera : Bool	{	return draggingLeftMouseFrom != nil || draggingRightMouseFrom != nil || draggingMiddleMouseFrom != nil	}
	@State var draggingLeftMouseFrom : CGPoint? 
	@State var draggingRightMouseFrom : CGPoint? 
	@State var draggingMiddleMouseFrom : CGPoint? 
	@State var draggingLastGestureFrom : CGSize? 
	@State var rotationLastGestureFrom : Angle? 
	
	public init<SceneType:PopScene>(scene:SceneType,camera:Binding<PopCamera>,showGizmosOnActors:[UUID])
	{
		//self._scene = Binding<any PopScene>( get: {scene.wrappedValue}, set:{_ in} )
		self.scene = scene
		self.showGizmosOnActors = showGizmosOnActors
		self._camera = camera
	}
	/*
	 public init(scene:Binding<any PopScene>,camera:Binding<PopCamera>,showGizmosOnActors:[UUID])
	 {
	 self._scene = scene
	 self.showGizmosOnActors = showGizmosOnActors
	 self._camera = camera
	 }
	 */
	

	
	public var body: some View 
	{
		MetalView(contentRenderer: self)
			.mouseTracking(OnCameraMouseControl,onScroll: OnCameraMouseControl)
			.gesture(cameraDragGesture)
			.gesture(cameraRotateGesture)
			.gesture(cameraZoomGesture)
			.overlay
		{
			//	showing gizmos in future will require a camera to do 2d<>3d stuff
			let gizmoActorUids = isDraggingCamera ? [] : showGizmosOnActors
			let gizmoActors = scene.Actors(withUids:gizmoActorUids)
			//	these need to be a concrete type... how do we do this... damn you lack of virtual types
			ForEach(gizmoActors, id:\.id)
			{
				actor in
				let actorWrapper = AnyPopActor(actor)
				ActorGizmo(actor: actorWrapper)
			}
		}
	}
	
	
	var cameraDragGesture : some Gesture
	{
		DragGesture()
			.onChanged 
		{ 
			value in
			draggingLastGestureFrom = draggingLastGestureFrom ?? value.translation
			let x = value.translation.width - draggingLastGestureFrom!.width
			let y = value.translation.height - draggingLastGestureFrom!.height
			//	move camera
			let moveScalarX = -0.001
			let moveScalarY = 0.001
			//print("move camera \(x), \(y)")
			camera.MoveRelative( Float(x*moveScalarX), Float(y*moveScalarY), 0 )
			draggingLastGestureFrom = value.translation
		}
		.onEnded 
		{ 
			_ in
			draggingLastGestureFrom = nil
		}
	}
	
	var cameraRotateGesture : some Gesture
	{
		//	RotateGesture3D vision os
		RotateGesture()
			.onChanged
		{
			gesture in
			//	gr: not sure what gesture makes this happen, but sometimes get a nan
			if gesture.rotation.degrees.isNaN
			{
				return
			}
			
			rotationLastGestureFrom = rotationLastGestureFrom ?? gesture.rotation
			let rotation = gesture.rotation - rotationLastGestureFrom!
			camera.rotationYaw += rotation
			rotationLastGestureFrom = gesture.rotation
		}
		.onEnded
		{
			_ in
			rotationLastGestureFrom = nil
		}
	}
	
	var cameraZoomGesture : some Gesture
	{
		//	not triggering
		MagnifyGesture(minimumScaleDelta: 0)
			.onChanged
		{
			magnify in
			
			print("zoom camera \(magnify.magnification)")
			
			let zMove = magnify.magnification * -0.5
			camera.MoveRelative( 0, 0, Float(zMove) )
		}
	}
	
	func OnCameraMouseControl(_ mouseState:MouseState)
	{
		if mouseState.rightDown
		{
			draggingRightMouseFrom = draggingRightMouseFrom ?? mouseState.position
			let x = mouseState.position.x - draggingRightMouseFrom!.x
			let y = mouseState.position.y - draggingRightMouseFrom!.y
			//	pixel to world
			//	minus depends where we're facing
			let moveScalarX = -0.01
			let moveScalarY = -0.01
			camera.MoveRelative( Float(x*moveScalarX), Float(y*moveScalarY), 0 )
			draggingRightMouseFrom = mouseState.position
		}
		else
		{
			draggingRightMouseFrom = nil
		}
		
		if mouseState.leftDown
		{
			draggingLeftMouseFrom = draggingLeftMouseFrom ?? mouseState.position
			let x = mouseState.position.x - draggingLeftMouseFrom!.x
			let y = mouseState.position.y - draggingLeftMouseFrom!.y
			//	pixel to world
			//	minus depends where we're facing
			let moveScalarX = -1.0
			let moveScalarY = 1.0
			camera.rotationPitch += Angle(degrees:y*moveScalarY)
			camera.rotationYaw += Angle(degrees:x*moveScalarX)
			draggingLeftMouseFrom = mouseState.position
		}
		else
		{
			draggingLeftMouseFrom = nil
		}
	}
	
	func OnCameraMouseControl(_ scroll:MouseScrollEvent)
	{
		let zMove = scroll.scrollDelta * -0.5
		camera.MoveRelative( 0, 0, Float(zMove) )
	}
	
	@MainActor
	public func SetupView(metalView:MTKView)
	{
		metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float//_stencil8
		
		//	fixes warning in profiler https://stackoverflow.com/questions/76158347/change-storage-mode-of-mtkviews-depth-texture
		//	defaults to private
		metalView.depthStencilStorageMode = MTLStorageMode.memoryless

		//metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
		metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm
		metalView.clearDepth = 1.0
		//	splats need to blend with black
		metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
		metalView.sampleCount = 1
	}

	@MainActor
	public func Draw(metalView: MTKView, size: CGSize, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
		//let orientation = UIApplication.shared.statusBarOrientation
		let orientation = metalView.window?.windowScene?.interfaceOrientation ?? UIInterfaceOrientation.unknown
		let renderCamera = PopRenderCamera(camera: self.camera, viewportPixelSize: size, viewportOrientation: orientation)
		
		//	render each actor
		for sceneActor in scene.actors
		{
			try sceneActor.Render(camera: renderCamera, metalView: metalView, commandEncoder: commandEncoder)
		}
	}
	
}



struct DummyScene : PopScene
{
	var quad = QuadActor(translation: simd_float3(-1.5,0,-0.5) )
	var cube = CubeActor(translation: simd_float3(-2,0,-2) )
	var floor = FloorPlaneActor()
	var camera1 = PopCamera()
	var camera2 = PopCamera(translation:simd_float3(1,0.5,-1))
	var actors : [any PopActor]
	{
		[
			floor,
			cube,
			quad,
			camera1,
			camera2
		]
	}
	
	init()
	{
	}
}

#Preview 
{
	@Previewable @State var scene = DummyScene()
	@Previewable @State var useCamera1 = true
	var cameraBinding = Binding<PopCamera>(
		get:{
			useCamera1 ? scene.camera1 : scene.camera2
		},
		set:	{_ in}//_ in 	useCamera1 ? scene.camera1 : scene.camera2	}
	)
	MetalSceneView(scene: scene, camera:cameraBinding, showGizmosOnActors: scene.actors.map{$0.id})
		.background(.blue)
		.overlay
	{
		VStack
		{
			Spacer()
			Toggle(isOn: $useCamera1)
			{
				Text("Use camera 1")
					.foregroundStyle(.white)
			}
			.padding(5)
			.background(.black)
		}
	}
}
