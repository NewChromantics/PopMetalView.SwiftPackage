import Foundation
import simd
import SwiftUI	//	angle
import MetalKit


public class PopCamera : @preconcurrency PopActor
{
	public var id = UUID()
	@Published public var translation = simd_float3(0,1,3)
	@Published public var rotationPitch = Angle(degrees: -30)
	@Published public var rotationYaw = Angle(degrees:0)
	
	@Published public var fovVertical = Angle(degrees: 65)
	@Published public var nearZ : Float = 0.001
	@Published public var farZ : Float = 100.0

	var geometryPipeline : MTLRenderPipelineDescriptor?

	
	public init(translation: simd_float3=simd_float3(0,1,3))
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
	
	@MainActor
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws
	{
		//	if we're rendering through ourselves, dont draw our projection (it'll just be on-screen)
		if camera.camera.id == self.id
		{
			return
		}
		
		self.geometryPipeline = try geometryPipeline ?? CreateGeometryPipelineDescriptor(metalView: metalView)
		let pipelineState = try metalView.device!.makeRenderPipelineState(descriptor: geometryPipeline!)
		
		commandEncoder.setRenderPipelineState( pipelineState )
		
		enableDepthReadWrite(commandEncoder)
		
		var localToWorld = self.localToWorldTransform
		let localToWorldBufferIndex = 1
		commandEncoder.setVertexBytes(&localToWorld, length: MemoryLayout<simd_float4x4>.stride, index:localToWorldBufferIndex )
		
		var worldToView = camera.worldToViewTransform
		let worldToViewBufferIndex = 2
		commandEncoder.setVertexBytes(&worldToView, length: MemoryLayout<simd_float4x4>.stride, index:worldToViewBufferIndex )
		
		var viewToLocal = self.GetLocalToViewTransform(viewportSize: CGSize(width: 1,height: 1)).inverse
		let viewToLocalBufferIndex = 3
		commandEncoder.setVertexBytes(&viewToLocal, length: MemoryLayout<simd_float4x4>.stride, index:viewToLocalBufferIndex )
		
		commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3*2*6 )
	}
	
	@MainActor 
	func CreateGeometryPipelineDescriptor(metalView:MTKView) throws -> MTLRenderPipelineDescriptor
	{
		guard let device = metalView.device else
		{
			throw MetalError("Missing device")
		}
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		
		let shaderLibrary = try device.makeDefaultLibrary(bundle: Bundle.module)
		pipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "ProjectedCubeVertex")
		pipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "EdgedCubeFragment")
		
		let attachment = pipelineDescriptor.colorAttachments[0]!
		attachment.pixelFormat = metalView.colorPixelFormat
		
		pipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat

		attachment.isBlendingEnabled = true
		attachment.rgbBlendOperation = .add
		attachment.alphaBlendOperation = .add
		attachment.sourceRGBBlendFactor = .sourceAlpha
		attachment.sourceAlphaBlendFactor = .one
		attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
		attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

		return pipelineDescriptor
	}
	
}

