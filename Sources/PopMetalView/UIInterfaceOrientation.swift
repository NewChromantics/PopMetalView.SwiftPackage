import SwiftUI

//	polyfill orientation instead of making a proprietry orientation
#if os(macOS)
public enum UIInterfaceOrientation
{
	case unknown
	case portrait
	case portraitUpsideDown
	case landscapeLeft
	case landscapeRight
}
#endif

//	window orientation polyfill
#if os(macOS)
struct WindowScenePolyfill
{
	var interfaceOrientation : UIInterfaceOrientation
}

extension NSWindow
{
	var windowScene : WindowScenePolyfill?	{	nil	}
}
#endif

