Shader "Else/Tessellation/BasedOnDistanceTessellation"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
    	
    	_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
    	_MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
        
        _WireframeColor ("Wireframe Color", color) = (0, 0, 0)
        _WireframeSmoothing ("Wireframe Smoothing", range(0, 10)) = 1
        _WireframeThickness ("Wireframe Thickness", range(0, 10)) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex tessVert
			#pragma hull hull
			#pragma domain domain
            #pragma geometry geometry
			#pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float4 _WireframeColor;
            float _WireframeSmoothing;
            float _WireframeThickness;
            float _TessellationUniform;
            float _MaxTessDistance;
            float _MinTessDistance;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
	            float4 vertex : SV_POSITION;
            	float2 uv : TEXCOORD0;
            };
			
			struct TessellationFactors 
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float2 barycentricCoordinators : TEXCOORD1;
            };

            struct tessInput
            {
	            float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
	            v2f o;
            	o.vertex = TransformObjectToHClip(v.vertex.xyz);
            	o.uv = v.uv;
                return o;
            }

            tessInput tessVert(appdata v)
            {
	            tessInput o;
            	o.vertex = v.vertex;
            	o.uv = v.uv;
            	return o;
            }

            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPosition,  GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return (f);
            }
			
			TessellationFactors patchConstantFunction (InputPatch<tessInput, 3> patch)
			{
				TessellationFactors f;

            	float edge0 = CalcDistanceTessFactor(patch[0].vertex, _MinTessDistance, _MaxTessDistance, _TessellationUniform);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, _MinTessDistance, _MaxTessDistance, _TessellationUniform);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, _MinTessDistance, _MaxTessDistance, _TessellationUniform);
            	
				f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
				return f;
			}
			
			[domain("tri")]
			[outputcontrolpoints(3)]
			[outputtopology("triangle_cw")]
			[partitioning("fractional_odd")]
			[patchconstantfunc("patchConstantFunction")]
			tessInput hull (InputPatch<tessInput, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}
			
			[domain("tri")]
			v2f domain (TessellationFactors factors, OutputPatch<tessInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
			{
				appdata v;
			
				#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) v.fieldName = \
					patch[0].fieldName * barycentricCoordinates.x + \
					patch[1].fieldName * barycentricCoordinates.y + \
					patch[2].fieldName * barycentricCoordinates.z;
			
				MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
				MY_DOMAIN_PROGRAM_INTERPOLATE(uv)

				return vert(v);
			}

            [maxvertexcount(3)]
            void geometry(triangle v2f i[3], inout TriangleStream<g2f> stream)
            {
                g2f g0, g1, g2;
                g0.uv = i[0].uv;
                g1.uv = i[1].uv;
                g2.uv = i[2].uv;
                g0.vertex = i[0].vertex;
                g1.vertex = i[1].vertex;
                g2.vertex = i[2].vertex;
                g0.barycentricCoordinators = float2(1, 0);
                g1.barycentricCoordinators = float2(0, 1);
                g2.barycentricCoordinators = float2(0, 0);
                stream.Append(g0);
                stream.Append(g1);
                stream.Append(g2);
            }

            float4 frag (g2f i) : SV_Target
            {
                float3 barys;
                barys.xy = i.barycentricCoordinators;
                barys.z = 1 - barys.x - barys.y;
                float3 deltas = fwidth(barys);
                float3 smoothing = deltas * _WireframeSmoothing;
                float3 thickness = deltas * _WireframeThickness;
                barys = smoothstep(thickness, thickness + smoothing, barys);
                float minBary = min(barys.x, min(barys.y, barys.z));
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                return lerp(_WireframeColor, col, minBary);
            }
            ENDHLSL
        }
    }
}
