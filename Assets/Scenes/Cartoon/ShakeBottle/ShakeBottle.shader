Shader "Cartoon/ShakeBottle"
{
    Properties
    {
        _TopLayerColor ("TopLayerColor", color) = (1, 1, 1, 1)
        _BottomLayerColor ("BottomLayerColor", color) = (1, 1, 1, 1)
        _BackLayerColor ("BackLayerColor", color) = (1, 1, 1, 1)
        _RimColor ("RimColor", color) = (1, 1, 1, 1)
        _FillAmount ("FillAmount", float) = 1
        _LayerDepth ("LayerDepth", range(0, 0.5)) = 0.1
        _RimPower ("RimPower", float) = 1
        
        _GlassRimColor("GlassRimColor", color) = (1, 1, 1, 1)
        _SpecularCol("SpecularCol", color) = (1, 1, 1, 1)
        _GlossBaseColor("GlossBaseColor", color) = (1, 1, 1, 1)
        _GlassRimPower ("GlassRimPower", float) = 1
        _GlassThickness("GlassThickness", float) = 1
        _Gloss("Gloss", float) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            Tags{"RenderType" = "Opauqe" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline" "LightMode" = "UniversalForward"}
            cull off
            ZWrite on
            AlphaToMask on
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _TopLayerColor;
            float4 _BottomLayerColor;
            float4 _BackLayerColor;
            float4 _RimColor;
            float _WobbleX;
            float _WobbleZ;
            float _FillAmount;
            float _LayerDepth;
            float _RimPower;
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
                float fillEdge : TEXCOORD1;
                float3 worldViewDir : TEXCOORD2;
                float3 worldNormal : NORMAL;
            };

            float4 RotateAroundYInDegress(float4 vertex, float degrees)
            {
                float alpha = degrees * 3.1415926 / 180;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, sina, -sina, cosa);
                return float4(vertex.yz, mul(m, vertex.xz)).xzyw;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = _WorldSpaceCameraPos.xyz - worldPos;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                float3 vertexPosX = RotateAroundYInDegress(float4(v.vertex.xyz, 0), 360).xyz;
                float3 vertexPosZ = vertexPosX.yzx;
                float3 vertexPosAdjusted = (vertexPosX * _WobbleX) + (vertexPosZ * _WobbleZ) + worldPos;
                o.fillEdge = vertexPosAdjusted.y + _FillAmount;
                return o;
            }

            float4 frag (v2f i, half face : VFACE) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 viewDir = normalize(i.worldViewDir);
                float rim = 1 - saturate(dot(worldNormal, viewDir));
                rim = pow(rim, _RimPower);
                
                float alpha = step(i.fillEdge, 0.5);
                float topLayer = alpha - step(i.fillEdge, 0.5 - _LayerDepth);
                float bottomLayer = alpha - topLayer;
                float4 frontCol = topLayer * _TopLayerColor + bottomLayer * _BottomLayerColor;
                frontCol.rgb += rim * _RimColor.rgb;
                float4 backLayerCol = float4(_BackLayerColor.rgb, alpha);
                
                return face > 0 ? frontCol : backLayerCol;
            }
            ENDHLSL
        }
        
        pass
        {
            Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" "LightMode" = "LightweightForward"}
            
            blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _GlassRimColor;
            float4 _SpecularCol;
            float4 _GlossBaseColor;
            float _GlassRimPower;
            float _GlassThickness;
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
                float3 worldLigthDir : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                v.vertex.xyz += _GlassThickness * v.normal;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.worldViewDir = _WorldSpaceCameraPos.xyz - worldPos;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldLigthDir = _MainLightPosition.xyz;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldviewDir = normalize(i.worldViewDir);
                float3 worldLightDir = normalize(i.worldLigthDir);

                float3 h = normalize(worldLightDir + worldviewDir);
                float4 specularColor = pow(max(0, dot(worldNormal, h)), _Gloss) * _SpecularCol;
                
                float rim = 1 - saturate(dot(worldNormal, worldviewDir));
                float4 rimColor = pow(rim, _GlassRimPower) * _GlassRimColor;
                
                return specularColor + rimColor + _GlossBaseColor;
            }

            ENDHLSL
        }
    }
}
