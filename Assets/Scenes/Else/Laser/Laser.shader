Shader "Shaders/Else/Laser"
{
    Properties
    {
        _LUT ("LUT", 2D) = "white" {}
        _MainTex ("MainTex", 2d) = "white" {}
        _NormalTex ("NormalTex", 2D) = "bump" {}
        _Saturation ("Saturation", range(0, 1)) = 0.5
        _Brightness ("Brightness", range(0, 1)) = 0.5
        _LightOffset ("LightOffset", range(0, 1)) = 0
        _LocalNormal ("LocalNormal", range(0, 1)) = 0.5
    }
    SubShader
    {
        HLSLINCLUDE

            float _Saturation;
            float _Brightness;
            float _LightOffset;
        
            float3 HUEToRGB(float H)
            {
                float R = abs(H * 6 - 3) - 1;
                float G = 2 - abs(H * 6 - 2);
                float B = 2 - abs(H * 6 - 4);
                return saturate(float3(R, G, B));
            }
    
            float3 HSVToRGB(float3 HSV)
            {
                float3 RGB = HUEToRGB(HSV.x);
                return ((RGB - 1) * HSV.y + 1) * HSV.z;
            }
        ENDHLSL
        
        Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
//            Blend DstColor Zero
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/PBRInclude.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangentDir : TEXCOORD3;
                float3 worldBitangentDir : TEXCOORD4;
            };

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // float4 Albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 worldNormal = normalize(i.worldNormal);
                float3 normalTex = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);
                float3 worldNormalTex = mul(normalTex, tangentTransform);
                float3 finiNormal = lerp(worldNormal, worldNormalTex, _LocalNormal);
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                float NDotV = saturate(dot(finiNormal, worldViewDir)) + 1e-5f;
                float H = (1 - NDotV) * 0.5 + _LightOffset;
                float3 Albedo = HSVToRGB(float3(H, _Saturation, _Brightness));
                return float4(Albedo, 1);
            }
            ENDHLSL
        }
        
        Pass
        {
            Blend One One
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shaders/PBRInclude.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldTangentDir : TEXCOORD3;
                float3 worldBitangentDir : TEXCOORD4;
            };

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldTangentDir = normalize(TransformObjectToWorld(v.tangent.xyz));
                o.worldBitangentDir = normalize(cross(o.worldNormal, o.worldTangentDir) * v.tangent.w);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // float4 Albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldViewDir = normalize(GetWorldSpaceViewDir(i.worldPos));
                float3 normalTex = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv));
                float3x3 tangentTransform = float3x3(i.worldTangentDir, i.worldBitangentDir, i.worldNormal);
                float3 worldNormalTex = mul(normalTex, tangentTransform);
                float3 finiNormal = lerp(worldNormal, worldNormalTex, _LocalNormal);
                float NDotV = saturate(dot(finiNormal, worldViewDir)) + 1e-5f;
                float H = (1 - NDotV) * 0.5 + _LightOffset;
                float3 Albedo = HSVToRGB(float3(H, _Saturation, _Brightness));
                float4 col = PBR(finiNormal, worldViewDir, Albedo, 0.9, 1);
                return col;
            }
            ENDHLSL
        }
    }
}
