
using namespace metal;

struct ColoredVertex
{
	float4 position [[position]];
	float4 color;
};

vertex ColoredVertex basicVertex(constant float4 *position [[buffer(0)]],
								 constant float4 *color [[buffer(1)]],
								 uint vid [[vertex_id]])
{
	ColoredVertex vert;
	vert.position = position[vid];
	vert.color = color[vid];
	return vert;
}

fragment float4 basicFragment(ColoredVertex vert [[stage_in]])
{
	return vert.color;
}
