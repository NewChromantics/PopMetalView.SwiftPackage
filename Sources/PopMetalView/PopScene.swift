/*
 
	These are all a simple "scene" API, which are really abstracted away from metal...
	Lets renamed this away from "Pop" - Content?
 
*/
import Foundation
import simd
import SwiftUI	//	Angle
import MetalKit



typealias simd_plane = simd_float4




public extension simd_float4
{
	//	simd4.xyz swizzle
	var xyz : simd_float3
	{
		return simd_float3(x,y,z)
	}
	
	mutating func Normalise()
	{
		self = simd.normalize(self)
	}
}




public struct Frustum
{
	//	normalised planes for view space
	var left = simd_plane()
	var right = simd_plane()
	var top = simd_plane()
	var bottom = simd_plane()
	var near = simd_plane()
	var far = simd_plane()
	
	mutating func NormalisePlanes()
	{
		left.Normalise()
		right.Normalise()
		top.Normalise()
		bottom.Normalise()
		near.Normalise()
		far.Normalise()
	}

	public func IsInside(center:simd_float3,radius:Float) -> Bool
	{
		//	now get distance from that plane - and see if it's inside
		return true
	}
}


extension PopRenderCamera
{
	//	from https://stackoverflow.com/a/34960913/355753
	//	https://github.com/NewChromantics/PopEngineCommon/blob/73d9525a0d781046c9720b4b3f736178d82fcbe2/Math.js
	public func GetFrustumPlanes(localToView:simd_float4x4) -> Frustum
	{
		let mat = localToView
		var frustum = Frustum()
		
		//	fill each component
		for i in 0..<4
		{
			frustum.left[i]		= mat[i,3] + mat[i,0]
			frustum.right[i]	= mat[i,3] - mat[i,0]
			frustum.bottom[i]	= mat[i,3] + mat[i,1]
			frustum.top[i]		= mat[i,3] - mat[i,1]
			frustum.near[i]		= mat[i,3] + mat[i,2]
			frustum.far[i]		= mat[i,3] - mat[i,2]
		}
		
		frustum.NormalisePlanes()
		return frustum
	}
}

public struct PopRenderCamera
{
	public var camera : PopCamera
	public var viewportPixelSize : CGSize
	public var viewportPixelSizeSimd : SIMD2<Int>	{	SIMD2<Int>( Int(viewportPixelSize.width), Int(viewportPixelSize.height) )	}
	public var viewportOrientation : UIInterfaceOrientation// = .unknown
	
	public var worldToCameraTransform : simd_float4x4
	{
		let worldToCamera = camera.localToWorldTransform.inverse
		return worldToCamera
	}
	
	public var worldToViewTransform : simd_float4x4
	{
		let worldToCamera = camera.localToWorldTransform.inverse
		//	most cameras wont need to apply orientation
		//	the ARKit camera does... but why? because the local to world is rotated? (I dont think so?)
		let cameraToView = localToViewTransform
		return cameraToView * worldToCamera
	}

	public var localToViewTransform : simd_float4x4
	{
		let cameraToView = camera.GetLocalToViewTransform(viewportSize: viewportPixelSize, orientation: viewportOrientation)
		return cameraToView
	}
}


public protocol PopActor : ObservableObject, Identifiable
{
	var id : UUID	{	get	}
	//	helpers for now
	//	setters for UI
	var translation : simd_float3	{	get set	}
	var rotationPitch : Angle	{	get set }
	var rotationYaw : Angle	{	get set	}
	var localToWorldTransform : simd_float4x4	{	get	}
	
	@MainActor func Render(camera:PopRenderCamera,metalView:MTKView,commandEncoder:any MTLRenderCommandEncoder) throws
}


public extension PopActor
{
	var name : String	{	id.uuidString	}

	//	this shouldnt be required, change the storage of translation in camera(or anything that overrides localToWorld!)
	func GetPosition() -> simd_float3
	{
		let originWorld = localToWorldTransform * simd_float4(0,0,0,1)
		return originWorld.xyz
	}
	
	var localToWorldTransform : simd_float4x4	{	GetLocalToWorldTransform()	}
	func GetLocalToWorldTransform() -> simd_float4x4	
	{
		let rotationMatrixX = matrix4x4_rotation(radians: Float(rotationPitch.radians), axis: SIMD3<Float>(1, 0, 0) )
		let rotationMatrixY = matrix4x4_rotation(radians: Float(rotationYaw.radians), axis: SIMD3<Float>(0, 1, 0) )
		let translationMatrix = matrix4x4_translation( translation.x, translation.y, translation.z )
		let localToWorld = translationMatrix * rotationMatrixY * rotationMatrixX
		return localToWorld
	}
	
	var worldForwardDirection : simd_float3
	{
		let localToWorld = localToWorldTransform
		let forward4 = localToWorld * simd_float4(0,0,1,0);
		return simd_float3(forward4.x,forward4.y,forward4.z)
	}
	
	var worldUpDirection : simd_float3
	{
		let localToWorld = localToWorldTransform
		let forward4 = localToWorld * simd_float4(0,1,0,0);
		return simd_float3(forward4.x,forward4.y,forward4.z)
	}
	
	var worldRightDirection : simd_float3
	{
		let localToWorld = localToWorldTransform
		let forward4 = localToWorld * simd_float4(1,0,0,0);
		return simd_float3(forward4.x,forward4.y,forward4.z)
	}
	
	//	move relative to our view
	func MoveRelative(_ x:Float,_ y:Float,_ z:Float)
	{
		let right = self.worldRightDirection
		translation += right * x
		
		let up = self.worldUpDirection
		translation += up * y
		
		let forward = self.worldForwardDirection
		translation += forward * z
	}
	
	func enableDepthReadWrite(_ commandEncoder:(any MTLRenderCommandEncoder))
	{
		//	should cache this descriptor
		let depthStateDescriptor = MTLDepthStencilDescriptor()
		
		depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
		depthStateDescriptor.isDepthWriteEnabled = true
		
		let depthState = commandEncoder.device.makeDepthStencilState(descriptor:depthStateDescriptor)!
		commandEncoder.setDepthStencilState(depthState)
	}
}

public protocol PopScene
{
	var actors : [any PopActor]	{	get	}
}


public extension PopScene
{
	func Actors(withUids:[UUID]) -> [any PopActor]
	{
		actors.filter 
		{
			actor in
			withUids.contains(actor.id)
		}
	}
}
