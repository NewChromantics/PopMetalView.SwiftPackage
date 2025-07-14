import Foundation
import simd
import SwiftUI	//	angle
import MetalKit


public class PopCamera : PopActor
{
	public var id = UUID()
	@Published public var translation = simd_float3(0,1,3)
	@Published public var rotationPitch = Angle(degrees: -30)
	@Published public var rotationYaw = Angle(degrees:0)
	
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws
	{
		//	draw projection wireframe for debugging
	}
	
	@Published public var fovVertical = Angle(degrees: 65)
	@Published public var nearZ : Float = 0.001
	@Published public var farZ : Float = 1000.0

	//	move relative to our view
	public func MoveRelative(_ x:Float,_ y:Float,_ z:Float)
	{
		let right = self.worldRightDirection
		translation += right * x
		
		let up = self.worldUpDirection
		translation += up * y
		
		let forward = self.worldForwardDirection
		translation += forward * z
	}
}

