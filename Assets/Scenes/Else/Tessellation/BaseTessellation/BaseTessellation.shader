Shader "Else/Tessellation/BaseTessellation"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
    	
    	_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
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
			#pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float4 _WireframeColor;
            float _WireframeSmoothing;
            float _WireframeThickness;
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
			
			float _TessellationUniform;
			
			TessellationFactors patchConstantFunction (InputPatch<tessInput, 3> patch)
			{
				TessellationFactors f;
				f.edge[0] = _TessellationUniform;
				f.edge[1] = _TessellationUniform;
				f.edge[2] = _TessellationUniform;
				f.inside = _TessellationUniform;
				return f;
			}
			
			[domain("tri")]
			[outputcontrolpoints(3)]
			[outputtopology("triangle_cw")]
			[partitioning("integer")]
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

            float4 frag (g2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                return col;
            }
            ENDHLSL
        }
    }
}
