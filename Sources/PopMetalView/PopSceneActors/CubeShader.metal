#include <metal_stdlib>
using namespace metal;


//	make this a variable!
//	this is the distance to extend the non-infinite projection
constant float ProjectionRenderFar = 2.0;
constant float ProjectionRenderNear = 0.1;
constant float4 ProjectedCubeColour = float4(1,0.4,0,1.0);

struct VertexIn 
{
	float x;
	float y;
	float z;
	packed_float2 uv;
};

struct CubeVertexOut 
{
	float4 clipPosition [[position]];	//	clip space
	float2 uv;
	float z;	//	for projection really, but its the face's non-uv extent
};

struct ProjectedCubeVertexOut 
{
	float4 ClipPosition [[position]];	//	clip space
	float3 LocalPosition;
	
	//	in local space
	float3 Cube_000;
	float3 Cube_100;
	float3 Cube_010;
	float3 Cube_110;
	float3 Cube_001;
	float3 Cube_101;
	float3 Cube_011;
	float3 Cube_111;
};



constant VertexIn cubeVertexes[] = 
{
	//	back
	VertexIn{	0, 0, 0, float2(0,0)	},
	VertexIn{	1, 0, 0, float2(1,0)	},
	VertexIn{	0, 1, 0, float2(0,1)	},
	VertexIn{	1, 0, 0, float2(1,0)	},
	VertexIn{	0, 1, 0, float2(0,1)	},
	VertexIn{	1, 1, 0, float2(1,1)	},
	
	//	front
	VertexIn{	0, 0, 1, float2(0,0)	},
	VertexIn{	1, 0, 1, float2(1,0)	},
	VertexIn{	0, 1, 1, float2(0,1)	},
	VertexIn{	1, 0, 1, float2(1,0)	},
	VertexIn{	0, 1, 1, float2(0,1)	},
	VertexIn{	1, 1, 1, float2(1,1)	},

	//	bottom
	VertexIn{	0, 0, 0, float2(0,0)	},
	VertexIn{	1, 0, 0, float2(1,0)	},
	VertexIn{	0, 0, 1, float2(0,1)	},
	VertexIn{	1, 0, 0, float2(1,0)	},
	VertexIn{	0, 0, 1, float2(0,1)	},
	VertexIn{	1, 0, 1, float2(1,1)	},

	//	top
	VertexIn{	0, 1, 0, float2(0,0)	},
	VertexIn{	1, 1, 0, float2(1,0)	},
	VertexIn{	0, 1, 1, float2(0,1)	},
	VertexIn{	1, 1, 0, float2(1,0)	},
	VertexIn{	0, 1, 1, float2(0,1)	},
	VertexIn{	1, 1, 1, float2(1,1)	},
	
	//	left
	VertexIn{	0, 0, 0, float2(0,0)	},
	VertexIn{	0, 1, 0, float2(1,0)	},
	VertexIn{	0, 0, 1, float2(0,1)	},
	VertexIn{	0, 1, 0, float2(1,0)	},
	VertexIn{	0, 0, 1, float2(0,1)	},
	VertexIn{	0, 1, 1, float2(1,1)	},
	
	//	right
	VertexIn{	1, 0, 0, float2(0,0)	},
	VertexIn{	1, 1, 0, float2(1,0)	},
	VertexIn{	1, 0, 1, float2(0,1)	},
	VertexIn{	1, 1, 0, float2(1,0)	},
	VertexIn{	1, 0, 1, float2(0,1)	},
	VertexIn{	1, 1, 1, float2(1,1)	},
};

vertex CubeVertexOut CubeVertex( uint vertexId [[vertex_id]],
							 uint instanceId [[instance_id]],
							 constant float4x4& localToWorld[[buffer(1)]],
							 constant float4x4& worldToView[[buffer(2)]]
							 ) 
{
	CubeVertexOut out;
	VertexIn vert = cubeVertexes[vertexId];
	out.uv = vert.uv;
	out.z = vert.z;

	float3 localPosition = float3(vert.x,vert.y,vert.z);
	float4 worldPosition = localToWorld * float4(localPosition,1);
	float4 viewportPosition = worldToView * float4(worldPosition);
	out.clipPosition = viewportPosition;
	return out;
}



fragment float4 CubeFragment(CubeVertexOut in [[stage_in]])
{
	return float4( in.uv, 0.0, 1.0 );
}


float TimeAlongLine3(float3 Position,float3 Start,float3 End)
{
	float3 Direction = End - Start;
	float DirectionLength = length(Direction);
	if ( DirectionLength < 0.0001 )
		return 0.0;
	float Projection = dot( Position - Start, Direction) / (DirectionLength*DirectionLength);
	
	return Projection;
}

float3 NearestToLine3(float3 Position,float3 Start,float3 End)
{
	float Projection = TimeAlongLine3( Position, Start, End );
	
	//	clip to start & end of line
	Projection = clamp( Projection, 0.0, 1.0 );
	
	float3 Near = mix( Start, End, Projection );
	return Near;
}

float DistanceToLine(float3 Position,float3 Start,float3 End)
{
	float3 NearestPoint = NearestToLine3(Position, Start, End );
	return length( Position - NearestPoint );
}

fragment float4 EdgedCubeFragment(ProjectedCubeVertexOut in [[stage_in]])
{
	float distance = 999;
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_000, in.Cube_100 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_100, in.Cube_110 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_110, in.Cube_010 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_010, in.Cube_000 ) );
	
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_001, in.Cube_101 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_101, in.Cube_111 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_111, in.Cube_011 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_011, in.Cube_001 ) );
	
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_000, in.Cube_010 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_010, in.Cube_011 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_011, in.Cube_001 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_001, in.Cube_000 ) );
	
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_100, in.Cube_110 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_110, in.Cube_111 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_111, in.Cube_101 ) );
	distance = min( distance, DistanceToLine( in.LocalPosition, in.Cube_101, in.Cube_100 ) );

	float EdgeSize = ProjectionRenderNear * 0.30;
	
	//	calculate an anti-alias alpha with smoothstep using a curve for a threshold very close to our edge width
	//	todo: put AA threshold should be in in screen space!
	float aa = EdgeSize * 0.10;
	float alpha = smoothstep( EdgeSize+aa, EdgeSize-aa, distance );
	//float alpha = distance;
	alpha = clamp(0.0,1.0,alpha);
	
	//	todo: shouldn't need this, need to be rendering transparent objects after opaque
	if ( alpha < 0.1 )
	{
		discard_fragment();
	}
	
	return float4( ProjectedCubeColour.xyz, ProjectedCubeColour.w*alpha );
}

float3 GetProjectionDir(float x,float y,float4x4 viewToLocal)
{
	float4 near = viewToLocal * float4(x,y,0,1);
	float4 far = viewToLocal * float4(x,y,1,1);
	float3 near3 = near.xyz * near.www;
	float3 far3 = far.xyz * far.www;
	float3 dir = near3 - far3;
	return normalize(dir);
}

float3 GetProjectedLocalPosition(float u,float v,float z,float4x4 projection)
{
	//	calculate projection space directions
	float2 viewxy = mix( float2(-1), float2(1), float2(u,v) );
	float3 dir = GetProjectionDir(viewxy.x,viewxy.y,projection);
	float3 localPosition = dir * mix( ProjectionRenderNear, ProjectionRenderFar, z );
	return localPosition;
}

vertex ProjectedCubeVertexOut ProjectedCubeVertex( uint vertexId [[vertex_id]],
									 uint instanceId [[instance_id]],
									 constant float4x4& localToWorld[[buffer(1)]],
									 constant float4x4& worldToView[[buffer(2)]],
									 constant float4x4& projection[[buffer(3)]]
									 ) 
{
	ProjectedCubeVertexOut out;
	VertexIn vert = cubeVertexes[vertexId];
	
	//	calculate projection space directions
	float2 viewxy = mix( float2(-1), float2(1), float2(vert.x,vert.y) );
	float3 dir = GetProjectionDir(viewxy.x,viewxy.y,projection);
	float3 localPosition = dir * mix( ProjectionRenderNear, ProjectionRenderFar, vert.z );

	out.LocalPosition = GetProjectedLocalPosition( vert.x,vert.y, vert.z, projection );
	out.Cube_000 = GetProjectedLocalPosition( 0,0,0, projection );
	out.Cube_100 = GetProjectedLocalPosition( 1,0,0, projection );
	out.Cube_010 = GetProjectedLocalPosition( 0,1,0, projection );
	out.Cube_110 = GetProjectedLocalPosition( 1,1,0, projection );
	out.Cube_001 = GetProjectedLocalPosition( 0,0,1, projection );
	out.Cube_101 = GetProjectedLocalPosition( 1,0,1, projection );
	out.Cube_011 = GetProjectedLocalPosition( 0,1,1, projection );
	out.Cube_111 = GetProjectedLocalPosition( 1,1,1, projection );
	
	float4 worldPosition = localToWorld * float4(localPosition,1);
	float4 viewportPosition = worldToView * float4(worldPosition);
	out.ClipPosition = viewportPosition;
	return out;
}
