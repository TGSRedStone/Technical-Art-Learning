Shader "Else/SimpleSubsurfaceScattering"
{
    Properties
    {
        _Color ("Color", color) = (1, 1, 1, 1)
        _SSSColor ("SSSColor", color) = (1, 1, 1, 1)
        _SpecularCol ("SpecularCol", color) = (1, 1, 1 ,1)
        _BackSubsurfaceDistortion ("BackSubsurfaceDistortion", float) = 1
        _FrontSSSStength ("FrontSSSStength", float) = 1
        _FrontSubsurfaceDistortion ("FrontSubsurfaceDistortion", float) = 1
        _SSSPower ("SSSPower", float) = 1
        _SSSStength ("SSSStength", float) = 1
        _Gloss ("Gloss", float) = 25
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float4 _SSSColor;
            float4 _SpecularCol;
            float _BackSubsurfaceDistortion;
            float _FrontSubsurfaceDistortion;
            float _SSSStength;
            float _SSSPower;
            float _FrontSSSStength;
            float _Gloss;
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
                float3 worldNormal : NORMAL;
                float3 worldViewDir : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.uv = v.uv;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldViewDir = GetCameraPositionWS() - worldPos;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLightDir = normalize(_MainLightPosition.xyz);
                float3 worldViewDir = normalize(i.worldViewDir);
                float NdotL = max(0.0, dot(worldNormal, worldLightDir));

                float3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                float3 diffuse = lerp(ambient * _Color.rgb, _MainLightColor.rgb * _Color.rgb, NdotL);

                float3 h = normalize(worldLightDir + worldViewDir);
                float3 specularColor = pow(max(0, dot(worldNormal, h)), _Gloss) * _SpecularCol.rgb;
                
                float3 frontLightDir = worldNormal * _FrontSubsurfaceDistortion - worldLightDir;
                float3 backLightDir = worldNormal * _BackSubsurfaceDistortion + worldLightDir;
                float frontSSS = saturate(dot(worldViewDir, -frontLightDir));
                float backSSS = saturate(dot(worldViewDir, -backLightDir));
                float SSSresult = saturate(frontSSS * _FrontSSSStength + backSSS);

                float3 sssCol = _SSSColor.rgb * saturate(pow(abs(SSSresult), _SSSPower)) * _SSSStength;

                return float4(sssCol + diffuse + specularColor, 1);
            }
            ENDHLSL
        }
    }
}
