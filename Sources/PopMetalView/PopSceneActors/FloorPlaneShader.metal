#include <metal_stdlib>
using namespace metal;


struct FloorPlaneParams
{
	float4 lineColour = float4(1,1,1,1);
	float lineThickness = 0.1;
	float lineSpacing = 1.0;
	float discardMaxAlpha = 0.9;
};

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


constant float2 quadPositions[] = 
{
	float2(0,0),
	float2(1,0),
	float2(0,1),
	float2(1,1)
};


vertex VertexOut FloorPlaneVertex( uint vertexId [[vertex_id]],
							 uint instanceId [[instance_id]],
							 constant float4x4& localToWorld[[buffer(1)]],
							 constant float4x4& worldToView[[buffer(2)]],
							  constant FloorPlaneParams& Params[[buffer(0)]]
							 ) 
{
	VertexOut out;
	out.uv = quadPositions[vertexId];
	float3 localPosition = float3( out.uv.x-0.5, 0, out.uv.y-0.5 ) * Params.lineSpacing;
	float4 worldPosition = localToWorld * float4(localPosition,1);
	out.worldPosition = worldPosition.xyz;
	float4 viewportPosition = worldToView * float4(worldPosition);
	out.clipPosition = viewportPosition;
	return out;
}

fragment float4 FloorPlaneFragment(VertexOut in [[stage_in]],
								   constant FloorPlaneParams& Params[[buffer(0)]]
)
{
	//	how close to a 1m unit are we
	float EdgeSize = Params.lineThickness;
	float2 xy = fmod( abs(in.worldPosition.xz), float2(1,1) );
	
	float distance0 = min( xy.x, xy.y );
	float distance1 = min( 1-xy.x, 1-xy.y );
	float distance = min(distance0,distance1);
	
	//	calculate an anti-alias alpha with smoothstep using a curve for a threshold very close to our edge width
	//	todo: put AA threshold should be in in screen space!
	float aa = EdgeSize * 0.10;
	float alpha = smoothstep( EdgeSize+aa, EdgeSize-aa, distance );
	
	float4 Colour = Params.lineColour;
	Colour.w = clamp(0.0,1.0,Colour.w*alpha);
	
	//	todo: shouldn't need this, need to be rendering transparent objects after opaque
	if ( alpha < Params.discardMaxAlpha )
	{
		discard_fragment();
	}
	
	return Colour;
}
