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
            CBUFFER_END

            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv12 : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldLightDir : TEXCOORD2;
                float3 worldViewDir : TEXCOORD3;
                float4 uvOffsetLight : TEXCOORD4;
                float4 uvOffsetBackLight : TEXCOORD5;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = GetWorldSpaceViewDir(o.worldPos);
                o.worldLightDir = normalize(_MainLightPosition.xyz);
                float3 worldTangent = TransformObjectToWorld(v.tangent);
                float2 uv = TRANSFORM_TEX(v.uv, _NoiseTex);

                float2 uvPanner1 = uv + _CloudSpeed * float2(_CloudDirX + 0.02, _CloudDirZ + 0.02) * _Time.y * _Offset1;
                float2 uvPanner2 = uv + _CloudSpeed * float2(_CloudDirX - 0.02, _CloudDirZ - 0.02) * _Time.y * _Offset2;

                o.uv12.xy = uvPanner1;
                o.uv12.zw = uvPanner2;


                float3 lightOffset = o.worldLightDir * worldTangent * _OffsetDistance;
                o.uvOffsetLight.xy = o.uv12.xy + lightOffset;
                o.uvOffsetLight.zw = o.uv12.zw + lightOffset;

                o.uvOffsetBackLight.xy = o.uv12.xy - lightOffset;
                o.uvOffsetBackLight.zw = o.uv12.zw - lightOffset;
                
                return o;
            }

            //TODO: SSSCol
            float4 frag (v2f i) : SV_Target
            {
                float4 col1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv12.xy);
                float4 col2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv12.zw);
                float4 col = col1 * col2;

                float fallOff = pow(saturate(abs(_MidY - i.worldPos.y) / (_CloudHeight * 0.25)), _TaperPower);
                clip(col.r - fallOff - _Cutoff);

                float4 lightCol1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetLight.xy);
                float4 lightCol2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetLight.zw);
                float light = saturate(col1.r + col2.r - lightCol1 - lightCol2);

                float4 backLightCol1 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetBackLight.xy);
                float4 backLightCol2 = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uvOffsetBackLight.zw);
                float backLight = saturate(col1.r + col2.r - backLightCol1 - backLightCol2);

                float edgeLight = pow((1 - col.r), _EdgePower) * _EdgeStrength;

                float4 finalCol = lerp(_Color, _MainLightColor, light + backLight + edgeLight);
                
                return finalCol;
            }
            ENDHLSL
        }
    }
}
