import SwiftUI
import PopMetalView
import simd


//	like Equatable
public protocol Addable
{
	static func + (lhs: Self, rhs: Self) -> Self
}

extension Float : Addable
{
}

extension PitchYaw : Addable
{
}

extension simd_float3 : Addable
{
}




public struct GenericGizmo<PropertyType> : View where PropertyType:Addable
{
	//typealias PropertyType = Float
	
	@Binding var propertyValue : PropertyType
	
	@State var dragStartValue : PropertyType?
	@State var hovering : Bool = false
	var dragging : Bool	{	dragStartValue != nil }
	var gizmoSize : CGFloat = 40.0
	var imagePadding : CGFloat { gizmoSize*0.20 }
	var iconCornerRadius : CGFloat	{ gizmoSize*0.10 }
	var foregroundColour = Color.white
	var foregroundIdleColour = Color.white
	var backgroundColour = Color.cyan
	var backgroundIdleColour = Color.black
	
	var icon : Image
	
	var GetDeltaFromDrag : (Double,Double)->PropertyType
	/*
	func GetDeltaFromDrag(deltaX:Double,deltaY:Double) -> PropertyType
	{
		return Float(deltaY)*dragSpeedScale
	}
	 */
	
	public var body: some View 
	{
		//rotate.3d.circle.fill
		let drag = DragGesture()
			.onChanged 
		{ 
			dragMeta in
			dragStartValue = dragStartValue ?? self.propertyValue
			let delta = GetDeltaFromDrag(dragMeta.translation.width, dragMeta.translation.height)
			if let dragStartValue
			{
				self.propertyValue = dragStartValue + delta
			}
		}
		.onEnded 
		{ 
			dragMeta in
			dragStartValue = nil
		}
		
		let fgColour = (hovering || dragging) ? foregroundColour : foregroundIdleColour
		let bgColour = (hovering || dragging) ? backgroundColour : backgroundIdleColour
		
		let opacity = dragging ? 0.9 : hovering ? 0.5 : 0.2
		
		RoundedRectangle(cornerRadius: iconCornerRadius)
			.stroke(fgColour.opacity(opacity))
			.fill(bgColour.opacity(opacity))
			.frame(width: gizmoSize,height: gizmoSize)
			.gesture(drag)
			.onHover(perform: self.OnHover)
			.overlay
		{
			icon
				.resizable()
				.scaledToFit()
				.foregroundStyle(fgColour.opacity(1.0))
				.padding(imagePadding)
				.allowsHitTesting(false)
		}
	}
	
	func OnHover(_ nowHovering:Bool)
	{
		self.hovering = nowHovering
		DispatchQueue.main.async
		{
#if os(macOS)
			if (self.hovering) 
			{
				NSCursor.pointingHand.push()
			}
			else 
			{
				NSCursor.pop()
			}
#endif
		}
	}
}



public struct TranslateGizmo : View
{
	@Binding var xyz : simd_float3
	
	var dragXScale = 0.01
	var dragYScale = -0.02
	
	public var body: some View 
	{
		GenericGizmo(propertyValue: $xyz, icon:Image(systemName: "move.3d"))
		{
			deltaX,deltaY in
			let x = Float( deltaX*dragXScale )
			let y = Float( deltaY*dragYScale )
			let z = Float(0)
			return simd_float3(x,y,z)
		}
	}
}


public struct TranslateZGizmo : View
{
	@Binding var z : Float
	
	var dragSpeedScale = 0.1

	public var body: some View 
	{
		GenericGizmo(propertyValue: $z, icon:Image(systemName: "arrow.up.right"))
		{
			deltaX,deltaY in
			return Float(deltaY * dragSpeedScale)
		}
	}
}


public struct RotateGizmo : View
{
	@Binding var pitchYaw : PitchYaw
	
	var dragPixelToDegree = 0.1
	
	public var body: some View 
	{
		GenericGizmo(propertyValue: $pitchYaw, icon:Image(systemName: "rotate.3d"))
		{
			deltaX,deltaY in
			let pitch = Angle(degrees: deltaY * dragPixelToDegree)
			let yaw = Angle(degrees: deltaX * dragPixelToDegree )
			return PitchYaw( pitch:pitch, yaw:yaw )
		}
	}
}


//	only used for GUI simplification
struct PitchYaw
{
	var pitch : Angle
	var yaw : Angle
	
	static func + (lhs: PitchYaw, rhs: PitchYaw) -> PitchYaw 
	{
		return PitchYaw( pitch:lhs.pitch+rhs.pitch, yaw: lhs.yaw+rhs.yaw )
	}
}


extension PopActor
{
	var pitchYaw : PitchYaw
	{
		get
		{
			PitchYaw(pitch: self.rotationPitch, yaw: self.rotationYaw)
		}
		set
		{
			self.rotationPitch = newValue.pitch
			self.rotationYaw = newValue.yaw
		}
	}
}


//	because the peripheral is a class, it needs it's own view 
//	with @StateObject in order to see changes
public struct ActorGizmo<PopActorType> : View where PopActorType:PopActor 
{
	@StateObject var actor : PopActorType
	
	public init(actor: PopActorType)
	{
		self._actor = StateObject(wrappedValue: actor)
	}
	
	public var body: some View 
	{
		HStack
		{
			TranslateGizmo( xyz:self.$actor.translation )
			TranslateZGizmo( z: self.$actor.translation.z )
			RotateGizmo( pitchYaw: self.$actor.pitchYaw )
		}
	}
}

