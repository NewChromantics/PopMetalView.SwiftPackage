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
	
	public var worldToViewTransform : simd_float4x4
	{
		//	todo: world to camera
		let worldToCamera = camera.localToWorldTransform.inverse
		
		//	camera to clip/view space
		let projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float(camera.fovVertical.radians),
															 aspectRatio: Float(viewportPixelSize.width / viewportPixelSize.height),
															 nearZ: camera.nearZ,
															 farZ: camera.farZ)
		
		return projectionMatrix * worldToCamera
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
