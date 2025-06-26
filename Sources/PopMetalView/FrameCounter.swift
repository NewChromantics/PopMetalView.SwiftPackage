import SwiftUI

//	todo: move to PopCommon

public struct FrameCounterModel
{
	var counter : Int = 0
	var lapFrequency : TimeInterval = 1	//	TimeInterval = seconds
	var lastLapTime : Date? = nil
	var onLap : (CGFloat)->Void
	var timeSinceLap : TimeInterval?
	{
		if let lastLapTime
		{
			return Date().timeIntervalSince(lastLapTime)
		}
		return nil
	}
	
	public init(OnLap:@escaping(CGFloat)->Void)
	{
		self.onLap = OnLap
	}
	
	mutating func Add(increment:Int=1)
	{
		counter += increment
		//	check if it's time to lap
		if let timeSinceLap
		{
			if timeSinceLap > lapFrequency
			{
				Lap(timeSinceLap:timeSinceLap)
			}
		}
		else // first call
		{
			lastLapTime = Date()
		}
	}
	
	mutating func Lap(timeSinceLap:TimeInterval)
	{
		//	report
		let duration = max(0.0001,timeSinceLap)	//	shouldn't be zero, but being safe
		let countPerSec = CGFloat(counter) / duration	//	ideally this is count/1
		
		//	reset (we do this before resetting date in case the callback is super long
		lastLapTime = Date()
		counter = 0

		onLap(countPerSec)
	}
}



@MainActor	//	make whole object in MainActor, in order to use MainActor in task
public class FrameCounter : ObservableObject
{
	@Published public var lastAverageCountPerSec : CGFloat = 0
	
	//var counter = FrameCounterModel(OnLap: self.OnLap)
	var counter : FrameCounterModel!
	
	public init()
	{
		counter = FrameCounterModel(OnLap:self.OnLap)
	}
	
	
	private func OnLap(_ countPerSec:CGFloat)
	{
		Task
		{
			@MainActor
			in
			self.lastAverageCountPerSec = countPerSec
		}
	}
	
	public func Add(increment:Int=1)
	{
		counter.Add(increment: increment)
	}

}


