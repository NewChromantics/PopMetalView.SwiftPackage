import simd
import MetalKit
import Foundation
import SwiftUI	//	Angle


public class FloorPlaneActor : @preconcurrency PopActor
{
	var quadPipeline : MTLRenderPipelineDescriptor?
	var quadShader : MTLLibrary?
	
	let vertexShader = """
#include <metal_stdlib>
using namespace metal;

constant float PlaneSize = 10.0;

struct VertexIn 
{
 packed_float2 localPosition;
};

struct VertexOut 
{
 float4 clipPosition [[position]];	//	clip space
 float2 uv;
 float3 worldPosition;
};

vertex VertexOut vertex_main(device const VertexIn* vertices [[buffer(0)]],
  uint vertexId [[vertex_id]],
  uint instanceId [[instance_id]],
 constant float4x4& localToWorld[[buffer(1)]],
 constant float4x4& worldToView[[buffer(2)]]
  ) 
{
	VertexOut out;
	out.uv = vertices[vertexId].localPosition;
	float3 localPosition = float3( out.uv.x-0.5, 0, out.uv.y-0.5 ) * PlaneSize;
	float4 worldPosition = localToWorld * float4(localPosition,1);
	out.worldPosition = worldPosition.xyz;
	float4 viewportPosition = worldToView * float4(worldPosition);
	out.clipPosition = viewportPosition;
	return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]])
{
	//	how close to a 1m unit are we
	float EdgeSize = 0.05;
	float2 xy = fmod( abs(in.worldPosition.xz), float2(1,1) );

	float distance0 = min( xy.x, xy.y );
	float distance1 = min( 1-xy.x, 1-xy.y );
	float distance = min(distance0,distance1);

	//	calculate an anti-alias alpha with smoothstep using a curve for a threshold very close to our edge width
	//	todo: put AA threshold should be in in screen space!
	float aa = EdgeSize * 0.10;
	float alpha = smoothstep( EdgeSize+aa, EdgeSize-aa, distance );
	alpha = clamp(0.0,1.0,alpha);
	return float4(1,1,1,alpha);
}
"""
	
	public var id = UUID() 
	public var translation = simd_float3(0,0,0)
	public var rotationPitch = Angle(degrees:0)
	public var rotationYaw = Angle(degrees:0)
	
	@MainActor 
	public func Render(camera: PopRenderCamera, metalView: MTKView, commandEncoder: any MTLRenderCommandEncoder) throws 
	{
		//metalView.clearColor = MTLClearColor(red: 1.2, green: 0.9, blue: 1.0, alpha: 1.0)
		
		let quadPipeline = try MakeQuadPipeline(metalView: metalView)
		
		let vertexData: [Float] = [ 0, 0,
									1, 0, 
									0, 1, 
									1, 1
		]
		commandEncoder.setRenderPipelineState( quadPipeline )
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
	func MakeQuadPipeline(metalView:MTKView) throws -> (MTLRenderPipelineState)
	{
		guard let device = metalView.device else
		{
			throw MetalError("Missing device")
		}
		
		if quadShader == nil
		{
			self.quadShader = try device.makeLibrary(source: vertexShader, options: nil)
		}
		
		guard let quadShader else
		{
			throw MetalError("Failed to make quad shader")
		}
		
		
		//	do once
		//let library = device.makeDefaultLibrary()!
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		let attachment = pipelineDescriptor.colorAttachments[0]!
		attachment.pixelFormat = metalView.colorPixelFormat
		
		//	enable alpha blend
		attachment.isBlendingEnabled = true
		attachment.rgbBlendOperation = .add
		attachment.alphaBlendOperation = .add
		//	this combo looks good for triangles, but background is over the top
		attachment.sourceRGBBlendFactor = .sourceAlpha
		attachment.sourceAlphaBlendFactor = .one
		attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
		attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
		//print("\(metalView.colorPixelFormat)")
		//metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
		
		pipelineDescriptor.vertexFunction = quadShader.makeFunction(name: "vertex_main")
		pipelineDescriptor.fragmentFunction = quadShader.makeFunction(name: "fragment_main")
		let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		return pipelineState
	}
	
}

