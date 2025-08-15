import simd
import MetalKit
import Foundation
import SwiftUI	//	Angle


public struct FloorPlaneParams
{
	var lineColour : simd_float4 = simd_float4(0,0.3,1,0.4)
	var lineThickness : Float = 0.01
	var lineSpacing : Float = 10.0
	var discardMaxAlpha : Float = 0.9
}


open class FloorPlaneActor : PopActor
{
	public var id = UUID() 
	public var translation = simd_float3(0,0,0)
	public var rotationPitch = Angle(degrees:0)
	public var rotationYaw = Angle(degrees:0)
	
	@Published var params = FloorPlaneParams()
	
	var geometryPipeline : MTLRenderPipelineDescriptor?
	
	public init()
	{
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

		let vertBuffer_params = 0
		let fragBuffer_params = 0
		commandEncoder.setVertexBytes(&params, length: MemoryLayout<FloorPlaneParams>.stride, index:vertBuffer_params )
		commandEncoder.setFragmentBytes(&params, length: MemoryLayout<FloorPlaneParams>.stride, index:fragBuffer_params )
		
		
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
		pipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "FloorPlaneVertex")
		pipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "FloorPlaneFragment")
		
		pipelineDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
		
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

