import SwiftUI
import MetalKit

#if canImport(UIKit)//ios

extension UIView
{
	var theLayer: CALayer? { get{ self.layer } }
}

#else
import AppKit
public typealias UIView = NSView
public typealias UIColor = NSColor
public typealias UIRect = NSRect
public typealias UIViewRepresentable = NSViewRepresentable

extension UIView
{
	var theLayer: CALayer? { get{ self.layer } }
}
extension MTKView
{
	var backgroundColor : UIColor { get { UIColor.clear } set {} }
}

#endif


public protocol ContentRenderer
{
	//	setup clear colour, targets etc - before first draw()
	@MainActor
	func SetupView(metalView:MTKView)

	@MainActor
	func Draw(metalView:MTKView,size:CGSize,commandEncoder:any MTLRenderCommandEncoder) throws
}


//	gr: this should really tie to a MTL device
public class MetalContentBase
{
	var commandQueue : MTLCommandQueue? = nil
	
	//	does first initialisation
	@MainActor 
	func GetCommandQueue(metalView: MTKView) throws -> MTLCommandQueue
	{
		//	init
		guard let commandQueue else
		{
			guard let device = metalView.device else
			{
				throw MetalError("Missing device")
			}
			
			self.commandQueue = device.makeCommandQueue()
			guard let commandQueue else
			{
				throw MetalError("Failed to make command queue")
			}
			
			return commandQueue
		}
		
		return commandQueue
	}
}

struct Float2
{
	var x : Float
	var y : Float
	
	var lengthSquared : Float	{	return (x*x)+(y*y)	}
	var length : Float			{	return sqrtf(lengthSquared)	}
	
	public func normalised(_ length:Float=1.0) -> Float2
	{
		let currentLength = self.length
		let mult = length / currentLength
		return Float2(x: x*mult, y: y*mult)
	}
}

struct InstanceData
{
	var x : Float
	var y : Float
	var cardHeight : Float
	var random01 : Float
	var velocity : Float2
}

import CoreMotion

class MotionManager
{
	var lastXY : Float2? = nil
#if os(iOS)
	var motionManager = CMMotionManager()
#endif
	
	init()
	{
#if os(iOS)
		motionManager.deviceMotionUpdateInterval = 0.05
		motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) 
		{ 
			(data, error) in
			guard let newData = data?.gravity else { return }
			self.lastXY = Float2(x:Float(newData.x), y:Float(-newData.y))
			/*
			 if let myData = data
			 {
			 myData.gra
			 var Pitch = myData.attitude.pitch * 180 / Double.pi
			 var Roll = myData.attitude.roll * 180 / Double.pi
			 var Yaw = myData.attitude.yaw * 180 / Double.pi
			 self.lastXY = Float2(x:Float(Pitch),y:Float(Roll)) 
			 }
			 */
		}
#endif
	}
	
}

func clamp(_ value:Float,_ Min:Float,_ Max:Float) -> Float
{
	var v = min( Max, value )
	v = max( Min, v )
	return v
}


/*
	wrapper to MetalViewDirect with some niceities on top
	- fps counter
	- auto error display
*/
public struct MetalView : View 
{
	var contentRenderer : ContentRenderer
	@State var lastError : Error?
	var lastFps : String {	String(format:"%0.2f",self.frameCounter.lastAverageCountPerSec)	}
	@StateObject var frameCounter = FrameCounter()
	
	public init(contentRenderer: ContentRenderer)
	{
		self.contentRenderer = contentRenderer
	}
	
	public var body: some View 
	{
		MetalViewDirect(contentRenderer: self.contentRenderer,onRenderFinished: self.OnRenderFinished )
			.overlay
		{
			VStack(alignment: .leading)
			{
				Text("\(lastFps) fps")
					.padding(10)
					.background(.black.opacity(0.70))
					.foregroundStyle(.white.opacity(0.70))
				
				if let lastError
				{
					Text("Error \(lastError.localizedDescription)")
						.padding(10)
						.background(.red.opacity(0.70))
						.foregroundStyle(.white.opacity(0.70))
				}
			}
			.frame(maxWidth: .infinity,maxHeight: .infinity, alignment: .topLeading)
		}
	}
	
	func OnRenderFinished(error:Error?)
	{
		self.lastError = error
		self.frameCounter.Add()
	}
}


public struct MetalViewDirect : UIViewRepresentable 
{
	var contentRenderer : ContentRenderer
	var metalCore = MetalContentBase()
	internal var onRenderFinished : (Error?)->Void
	
	public init(contentRenderer: ContentRenderer,onRenderFinished:@escaping ((Error?)->Void)=OnRenderFinishedNoop)
	{
		self.contentRenderer = contentRenderer
		self.onRenderFinished = onRenderFinished
	}

	public static func OnRenderFinishedNoop(error:Error?)
	{
		if let error
		{
			//	render error in Renderer
			print("Renderer error; \(error.localizedDescription)")
		}
	}
	
	
	public typealias UIViewType = MTKView
	public typealias NSViewType = MTKView
	
	public func makeNSView(context: Context) -> NSViewType 
	{
		return makeUIView(context: context)
	}
	
	public func updateNSView(_ nsView: MTKView, context: Context) 
	{
		updateUIView( nsView, context: context )
	}
	
	
	public func makeUIView(context: Context) -> UIViewType 
	{
		let view = MTKView()
		
		view.device = MTLCreateSystemDefaultDevice()
		view.delegate = context.coordinator
		
		//	this may be macos only
		view.theLayer?.isOpaque = false
		
		//	helps blending, but still off
		//view.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
		//view.isOpaque = false
		view.backgroundColor = UIColor.clear

		//	setup metal view before drawing
		self.contentRenderer.SetupView(metalView: view)

		return view
	}
	
	public func updateUIView(_ view: MTKView, context: Context) {
		// Update the view
	}
	
	public func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	public class Coordinator: NSObject, MTKViewDelegate 
	{
		var parent : MetalViewDirect
		
		init(_ parent: MetalViewDirect) {
			self.parent = parent
		}
		
		@MainActor
		public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) 
		{
			// Handle drawable size change
		}
		
		@MainActor 
		public func draw(in metalView: MTKView)
		{
			let canvasBounds = metalView.bounds.size
			
			do
			{
				let commandQueue = try parent.metalCore.GetCommandQueue(metalView: metalView)
				guard let drawable = metalView.currentDrawable else
				{
					throw MetalError("View is missing drawable")
				}
				guard let descriptor = metalView.currentRenderPassDescriptor else
				{
					throw MetalError("View is missing pass descriptor")
				}
				
				// Make the command buffer and encoder
				guard let commandBuffer = commandQueue.makeCommandBuffer() else
				{
					throw MetalError("Failed to make command buffer")
				}
				guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else
				{
					throw MetalError("Failed to make command encoder")
				}

				//	if this throws, endEncoding() MUST still be called
				do
				{
					try self.parent.contentRenderer.Draw(metalView: metalView, size: canvasBounds, commandEncoder: commandEncoder)
					commandEncoder.endEncoding()
				}
				catch
				{
					// End encoding, present the drawable view, and commit the buffer
					commandEncoder.endEncoding()
					throw error
				}
				
				commandBuffer.present(drawable)
				commandBuffer.commit()
				
				parent.onRenderFinished(nil)
			}
			catch
			{
				parent.onRenderFinished(error)
			}
		}
	}
}

struct MetalError : LocalizedError
{
	let description: String
	
	public init(_ description: String) 
	{
		self.description = description
	}
	
	public var errorDescription: String? 
	{
		description
	}
}



class PreviewRenderer : ContentRenderer
{
	var quadPipeline : MTLRenderPipelineDescriptor?
	var quadShader : MTLLibrary?
	
	let vertexShader = """
#include <metal_stdlib>
using namespace metal;


struct VertexIn 
{
 packed_float2 localPosition;
};

struct VertexOut 
{
 //	gr: view or screen?
 float4 viewPosition [[position]];
 float2 uv;
};

vertex VertexOut vertex_main(device const VertexIn* vertices [[buffer(0)]],
  uint vertexId [[vertex_id]],
  uint instanceId [[instance_id]],
 constant float2& screenSizexx[[buffer(1)]]
  ) 
{
 VertexOut out;
 out.uv = vertices[vertexId].localPosition;
 float2 localPosition = out.uv;
 float2 viewportPosition = localPosition;

 //	gr: wtf is with this viewport - is screensize wrong?
 float2 viewPos = mix( float2(-1,0), float2(1,2.0), viewportPosition );
 float z = 0;

 //	view -> screen reprojection
 out.viewPosition = float4( viewPos.x, viewPos.y, z, 1);
 out.viewPosition.y = 1.0 - out.viewPosition.y;

 return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]])
{
 return float4( in.uv, 0.0, 1.0 );
}
"""
	
	@MainActor func MakeQuadPipeline(metalView:MTKView) throws -> (MTLRenderPipelineState)
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
		/*
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
		 */
		pipelineDescriptor.vertexFunction = quadShader.makeFunction(name: "vertex_main")
		pipelineDescriptor.fragmentFunction = quadShader.makeFunction(name: "fragment_main")
		let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		return pipelineState
	}
	
	@MainActor
	func SetupView(metalView:MTKView)
	{
		metalView.clearColor = MTLClearColor(red: 1.2, green: 0.9, blue: 1.0, alpha: 1.0)
	}
	
	@MainActor 
	func Draw(metalView: MTKView, size: CGSize,commandEncoder:any MTLRenderCommandEncoder) throws 
	{
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
		
		let screenSizeBufferIndex = 1
		let screenSizeFloat2 = [Float(size.width),Float(size.height)]
		commandEncoder.setVertexBytes(screenSizeFloat2, length: screenSizeFloat2.count * MemoryLayout<Float>.stride, index:screenSizeBufferIndex )
		
		
		commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4 )
	}
}

class PreviewErrorRenderer : ContentRenderer
{
	func SetupView(metalView: MTKView) 
	{
	}
	
	func Draw(metalView: MTKView, size: CGSize, commandEncoder: any MTLRenderCommandEncoder) throws {
		throw MetalError("Preview Error")
	}
	
	
}


#Preview
{
	MetalView(contentRenderer: PreviewErrorRenderer())
		.frame(minWidth:100,minHeight:100)
	
	MetalView(contentRenderer: PreviewRenderer())
		.frame(minWidth:100,minHeight:100)
		.frame(maxWidth: .infinity,maxHeight: .infinity)
}
