Shader "VertexEffect/BillBoard"
{
    Properties
    {
        _MainTex ("MainTex", 2d) = "white" {}
        [HideInInspector]_BillboardRotation("Rotation", vector) = (0,0,0,0)
        [HideInInspector]_BillboardScale("Scale", vector) = (1,1,1,0)
        [HideInInspector]_BillboardMatrix0("Matrix1", vector) = (0,0,0,0)
        [HideInInspector]_BillboardMatrix1("Matrix2", vector) = (0,0,0,0)
        [HideInInspector]_BillboardMatrix2("Matrix3", vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            cull back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile None XAxis YAxis ZAxis

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _BillboardMatrix0;
            half4 _BillboardMatrix1;
            half4 _BillboardMatrix2;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

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

            v2f vert(appdata v)
            {
                v2f o;
                float3x3 m;
                m[0] = _BillboardMatrix0.xyz;
                m[1] = _BillboardMatrix1.xyz;
                m[2] = _BillboardMatrix2.xyz;
                float3 objTransform = mul(m, v.vertex.xyz);
                #if defined(None)
                    float3 center = TransformWorldToView(unity_ObjectToWorld._14_24_34);
                    o.vertex = mul(UNITY_MATRIX_P, float4(objTransform + center, 1));
                    #else
                        float3 center = unity_ObjectToWorld._14_24_34;
                        float3 viewDir = normalize((_WorldSpaceCameraPos.xyz - center));
                    #if defined(XAxis)
                        float3 viewRight = normalize(cross(viewDir * float3(0, 1, 1) ,float3(1, 0, 0)));
                        float3 viewUp = cross(viewRight, viewDir);
                    
                        float3x3 r;
                        r[0] = float3(viewRight.x, viewUp.x, viewDir.x);
                        r[1] = float3(viewRight.y, viewUp.y, viewDir.y);
                        r[2] = float3(viewRight.z, viewUp.z, viewDir.z);
                    
                        o.vertex = mul(UNITY_MATRIX_VP, float4(mul(r, objTransform) + center, 1));
                    #elif defined(YAxis)
                        float3 viewRight = normalize(cross(viewDir * float3(1, 0, 1) ,float3(0, 1, 0)));
                        float3 viewUp = cross(viewRight, viewDir);
                    
                        float3x3 r;
                        r[0] = float3(viewRight.x, viewUp.x, viewDir.x);
                        r[1] = float3(viewRight.y, viewUp.y, viewDir.y);
                        r[2] = float3(viewRight.z, viewUp.z, viewDir.z);
                    
                        o.vertex = mul(UNITY_MATRIX_VP, float4(mul(r, objTransform) + center, 1));
                    #elif defined(ZAxis)
                        float3 viewRight = normalize(cross(viewDir * float3(1, 1, 0) ,float3(0, 0, 1)));
                        float3 viewUp = cross(viewRight, viewDir);
                    
                        float3x3 r;
                        r[0] = float3(viewRight.x, viewUp.x, viewDir.x);
                        r[1] = float3(viewRight.y, viewUp.y, viewDir.y);
                        r[2] = float3(viewRight.z, viewUp.z, viewDir.z);
                    
                        o.vertex = mul(UNITY_MATRIX_VP, float4(mul(r, objTransform) + center, 1));
                    #endif
                #endif
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                return col;
            }
            ENDHLSL
        }
    }
    CustomEditor "BillBoardGUI"
}