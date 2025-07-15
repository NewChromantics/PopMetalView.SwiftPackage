import simd
import MetalKit
import Foundation
import SwiftUI	//	Angle


public class FloorPlaneActor : @preconcurrency PopActor
{
	public var id = UUID() 
	public var translation = simd_float3(0,0,0)
	public var rotationPitch = Angle(degrees:0)
	public var rotationYaw = Angle(degrees:0)
	
	var geometryPipeline : MTLRenderPipelineDescriptor?
	
	public init()
	{
	}
	
	@MainActor 
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
		self.geometryPipeline = try geometryPipeline ?? CreateGeometryPipelineDescriptor(metalView: metalView)
		let pipelineState = try metalView.device!.makeRenderPipelineState(descriptor: geometryPipeline!)
		
		let vertexData: [Float] = [ 0, 0,
									1, 0, 
									0, 1, 
									1, 1
		]
		commandEncoder.setRenderPipelineState( pipelineState )
		//commandEncoder.setVertexBuffer( quad.1, offset: 0, index: 0)
		let vertexBufferIndex = 0
		commandEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: vertexBufferIndex)
		
		var localToWorld = self.localToWorldTransform
		let localToWorldBufferIndex = 1
		commandEncoder.setVertexBytes(&localToWorld, length: MemoryLayout<simd_float4x4>.stride, index:localToWorldBufferIndex )

		var worldToView = camera.worldToViewTransform
		let worldToViewBufferIndex = 2
		commandEncoder.setVertexBytes(&worldToView, length: MemoryLayout<simd_float4x4>.stride, index:worldToViewBufferIndex )
		
		commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4 )
		
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
		pipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "FloorPlaneVertex")
		pipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "FloorPlaneFragment")
		
		let attachment = pipelineDescriptor.colorAttachments[0]!
		attachment.pixelFormat = metalView.colorPixelFormat

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

