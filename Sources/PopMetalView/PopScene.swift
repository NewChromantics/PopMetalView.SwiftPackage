/*
 
	These are all a simple "scene" API, which are really abstracted away from metal...
	Lets renamed this away from "Pop" - Content?
 
*/
import Foundation
import simd
import SwiftUI	//	Angle
import MetalKit

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
