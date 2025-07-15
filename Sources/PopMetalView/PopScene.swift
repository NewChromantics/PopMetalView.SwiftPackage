/*
 
	These are all a simple "scene" API, which are really abstracted away from metal...
	Lets renamed this away from "Pop" - Content?
 
*/
import Foundation
import simd
import SwiftUI	//	Angle
import MetalKit

public struct PopRenderCamera
{
	public var camera : PopCamera
	public var viewportPixelSize : CGSize
	public var viewportPixelSizeSimd : SIMD2<Int>	{	SIMD2<Int>( Int(viewportPixelSize.width), Int(viewportPixelSize.height) )	}
	
	public var worldToCameraTransform : simd_float4x4
	{
		let worldToCamera = camera.localToWorldTransform.inverse
		return worldToCamera
	}
	
	public var worldToViewTransform : simd_float4x4
	{
		let worldToCamera = camera.localToWorldTransform.inverse
		let cameraToView = camera.GetLocalToViewTransform(viewportSize: viewportPixelSize)
		return cameraToView * worldToCamera
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
	
	func Render(camera:PopRenderCamera,metalView:MTKView,commandEncoder:any MTLRenderCommandEncoder) throws
}

public extension PopActor
{
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
