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

vertex VertexOut FloorPlaneVertex(device const VertexIn* vertices [[buffer(0)]],
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

fragment float4 FloorPlaneFragment(VertexOut in [[stage_in]])
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
