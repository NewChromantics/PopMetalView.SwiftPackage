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
	
	@Published public var fovVertical = Angle(degrees: 65)
	@Published public var nearZ : Float = 0.001
	@Published public var farZ : Float = 1000.0

	init(translation: simd_float3=simd_float3(0,1,3))
	{
		self.translation = translation
	}
	
	public func GetProjectionMatrix(viewportSize:CGSize) -> simd_float4x4	{	GetLocalToViewTransform(viewportSize:viewportSize)	}
	
	public func GetLocalToViewTransform(viewportSize:CGSize) -> simd_float4x4
	{
		return GetLocalToViewTransform(viewAspectRatio: Float(viewportSize.width / viewportSize.height) )
	}
	
	public func GetLocalToViewTransform(viewAspectRatio:Float) -> simd_float4x4
	{
		let projectionMatrix = matrix_perspective_right_hand(fovyRadians: Float(fovVertical.radians),
															 aspectRatio: viewAspectRatio,
															 nearZ: nearZ,
															 farZ: farZ)
		return projectionMatrix
	}
	
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws
	{

	}
	
}

