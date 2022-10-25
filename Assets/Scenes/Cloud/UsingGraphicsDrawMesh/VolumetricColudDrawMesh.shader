Shader "Cloud/VolumetricColudDrawMesh"
{
    Properties
    {
        _NoiseTex ("NoiseTex", 2d) = "white" {}
        _Color ("Color", color) = (1, 1, 1, 1)
        _CloudSpeed ("CloudSpeed", float) = 1
        _CloudDirX ("CloudDirX", float) = 1
        _CloudDirZ ("CloudDirZ", float) = 1
        _Offset1 ("Offset1", range(0.01, 3)) = 0.05
        _Offset2 ("Offset2", range(0.01, 3)) = 0.05
        _Cutoff ("Cutoff", range(0, 1)) = 0.5
        _TaperPower ("TaperPower", float) = 1
        _OffsetDistance ("OffsetDistance", float) = 0.1
        _EdgePower ("EdgePower", float) = 1
        _EdgeStrength ("EdgeStrength", float) = 1
        
        _SSSColor ("SSSColor", color) = (1, 1, 1, 1)
        _SubsurfaceDistortion ("SubsurfaceDistortion", float) = 1
        _SSSStength("SSSStength", float) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        cull off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _NoiseTex_ST;
            float4 _Color;
            float4 _SSSColor;
            float _CloudSpeed;
            float _CloudDirX;
            float _CloudDirZ;
            float _Offset1;
            float _Offset2;
            float _Cutoff;
            float _MidY;
            float _CloudHeight;
            float _TaperPower;
            float _OffsetDistance;
            float _EdgePower;
            float _EdgeStrength;

            float _SubsurfaceDistortion;
            float _SSSStength;
            CBUFFER_END

            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 tangent : TANGENT;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv12 : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldLightDir : TEXCOORD2;
                float4 uvOffsetLight : TEXCOORD3;
                float4 uvOffsetBackLight : TEXCOORD4;
                float3 worldNormal : TEXCOORD5;
                float3 worldViewDir : TEXCOORD6;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldLightDir = normalize(_MainLightPosition.xyz);
                o.worldViewDir = GetCameraPositionWS() - o.worldPos;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 worldTangent = TransformObjectToWorld(v.tangent);
                float2 uv = TRANSFORM_TEX(v.uv, _NoiseTex);

                float2 uvPanner1 = uv + _CloudSpeed * float2(_CloudDirX + 0.02, _CloudDirZ + 0.02) * _Time.y * _Offset1;
                float2 uvPanner2 = uv + _CloudSpeed * float2(_CloudDirX - 0.02, _CloudDirZ - 0.02) * _Time.y * _Offset2;

                o.uv12.xy = uvPanner1;
                o.uv12.zw = uvPanner2;


                float3 lightOffset = o.worldLightDir * worldTangent * _OffsetDistance;
                o.uvOffsetLight.xy = o.uv12.xy + lightOffset.xy;
                o.uvOffsetLight.zw = o.uv12.zw + lightOffset.xy;

                o.uvOffsetBackLight.xy = o.uv12.xy - lightOffset.xy;
                o.uvOffsetBackLight.zw = o.uv12.zw - lightOffset.xy;
                
                return o;
            }

            //Day #007CC9
            //Night #2E4865
            //SSS #B6D0F7
            
            //TODO: SSSCol
            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLightDir = normalize(i.worldLightDir);
                float3 worldViewDir = normalize(i.worldViewDir);

                float4 col1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv12.xy);
                float4 col2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv12.zw);
                float4 col = col1 * col2;

                float fallOff = pow(saturate(abs(_MidY - i.worldPos.y) / (_CloudHeight * 0.5)), _TaperPower);
                clip(col.r - fallOff - _Cutoff);

                float lightCol1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetLight.xy).r;
                float lightCol2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetLight.zw).r;
                float light = saturate(col1.r + col2.r - lightCol1 - lightCol2);

                float backLightCol1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetBackLight.xy).r;
                float backLightCol2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetBackLight.zw).r;
                float backLight = saturate(col1.r + col2.r - backLightCol1 - backLightCol2);

                float edgeLight = pow(abs(1 - col.r), _EdgePower) * _EdgeStrength;

                float3 backLightDir = worldNormal * _SubsurfaceDistortion + worldLightDir;
                float backSSS = saturate(dot(worldViewDir, -backLightDir));
                backSSS = saturate(dot(pow(backSSS, 1.6), _SSSStength));

                float3 finalCol = lerp(_Color + backSSS * _SSSColor, _MainLightColor, light + backLight + edgeLight);
                
                return float4(finalCol, 1);
            }
            ENDHLSL
        }
    }
}
