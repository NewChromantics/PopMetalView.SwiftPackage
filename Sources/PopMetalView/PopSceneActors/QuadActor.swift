import simd
import MetalKit
import Foundation
import SwiftUI	//	Angle


open class QuadActor : @preconcurrency PopActor
{
	public var id = UUID() 
	public var translation : simd_float3
	public var rotationPitch = Angle(degrees:0)
	public var rotationYaw = Angle(degrees:0)
	
	var geometryPipeline : MTLRenderPipelineDescriptor?
	
	public init(translation:simd_float3=simd_float3(0,0,0))
	{
		self.translation = translation
	}
	
	@MainActor 
	open func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
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
		
		commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4 )
	}
	
	@MainActor 
	open func CreateGeometryPipelineDescriptor(metalView:MTKView) throws -> MTLRenderPipelineDescriptor
	{
		guard let device = metalView.device else
		{
			throw MetalError("Missing device")
		}
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		
		let shaderLibrary = try device.makeDefaultLibrary(bundle: Bundle.module)
		pipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "QuadVertex")
		pipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "QuadFragment")
		
		pipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
		
		let attachment = pipelineDescriptor.colorAttachments[0]!
		attachment.pixelFormat = metalView.colorPixelFormat
		/*
		 attachment.isBlendingEnabled = true
		 attachment.rgbBlendOperation = .add
		 attachment.alphaBlendOperation = .add
		 //	this combo looks good for triangles, but background is over the top
		 attachment.sourceRGBBlendFactor = .sourceAlpha
		 attachment.sourceAlphaBlendFactor = .one
		 attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
		 attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
		 */
		return pipelineDescriptor
	}
		
	
	
}

