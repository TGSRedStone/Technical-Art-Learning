//reference : https://alexanderameye.github.io/notes/rendering-outlines/
Shader "Cartoon/OutLine/ExtrusionOutLine/StencilOutLine"
{
    Properties
    {
        _Color ("Color", color) = (1, 1, 1, 1)
        _OutLineColor ("OutLineColor", color) = (1, 1, 1, 1)
        _Width ("Width", float) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        Pass
        {
            Tags{ "LightMode" = "UniversalForward" }
            
            Stencil
            {
                Ref 1
                Comp always
                Pass replace
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {;
                return _Color;
            }
            ENDHLSL
        }
        
        Pass
        {
            Tags{ "LightMode" = "LightweightForward" }
            
            Stencil
            {
                Ref 1
                Comp notequal
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _OutLineColor;
            float _Width;
            CBUFFER_END

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                v.vertex.xyz *= _Width * 0.1;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return _OutLineColor;
            }
            ENDHLSL
        }
    }
}
