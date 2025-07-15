#include <metal_stdlib>
using namespace metal;


struct VertexIn 
{
	packed_float2 localPosition;
};

struct VertexOut 
{
	float4 clipPosition [[position]];	//	clip space
	float2 uv;
};


constant float2 quadPositions[] = 
{
	float2(0,0),
	float2(1,0),
	float2(0,1),
	float2(1,1)
};

vertex VertexOut QuadVertex( uint vertexId [[vertex_id]],
							 uint instanceId [[instance_id]],
							 constant float4x4& localToWorld[[buffer(1)]],
							 constant float4x4& worldToView[[buffer(2)]]
							 ) 
{
	VertexOut out;
	out.uv = quadPositions[vertexId];
	float2 localPosition = out.uv;
	float4 worldPosition = localToWorld * float4(localPosition,0,1);
	float4 viewportPosition = worldToView * float4(worldPosition);
	out.clipPosition = viewportPosition;
	return out;
}

fragment float4 QuadFragment(VertexOut in [[stage_in]])
{
	return float4( in.uv, 0.0, 1.0 );
}
