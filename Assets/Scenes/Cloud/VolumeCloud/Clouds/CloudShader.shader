Shader "Shaders/Cloud"
{
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float LightSteps;
            float DarknessThreshold;
            float AbsorbedIntensity;
            float CloudDensityMultiplier;
            float RandomDstTravelOffsetIntensity;

            float3 BoundsMin;
            float3 BoundsMax;

            float BaseCloudScale;
            float3 BaseCloudOffset;
            float DetailCloudScale;
            float3 DetailCloudOffset;

            float4 BaseShapeNoiseWeights;
            float BaseCloudDensityThreshold;
            float DetailCloudDensityThreshold;

            float ScatterForward;
            float ScatterBackward;
            float ScatterWeight;

            float4 ColorDark;
            float4 ColorCentral;
            float4 ColorBright;
            float ColorCentralOffset;

            TEXTURE2D(_ColorTexture);
            SAMPLER(sampler_ColorTexture);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_BlueNoise);
            SAMPLER(sampler_BlueNoise);
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
            TEXTURE3D(_BaseNoise);
            SAMPLER(sampler_BaseNoise);
            TEXTURE3D(_DetailNoise);
            SAMPLER(sampler_DetailNoise);

            // Debug settings:
            int debugViewMode; // 0 = off; 1 = shape tex; 2 = detail tex; 3 = weathermap
            int debugGreyscale;
            int debugShowAllChannels;
            float debugNoiseSliceDepth;
            float4 debugChannelWeight;
            float debugTileAmount;
            float viewerSize;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewWorldVector : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                float3 viewWorldVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
                o.viewWorldVector = mul(unity_CameraToWorld, float4(viewWorldVector, 0));
                return o;
            }

            float beer(float density, float absorbedIntensity = 1)
            {
                return exp(-density * absorbedIntensity);
            }

            float beerPowder(float density, float absorbedIntensity = 1)
            {
                return 2.0 * exp(-density * absorbedIntensity) * (1.0 - exp(-density * 2.0));
            }

            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + ((original_value - original_min) / (original_max - original_min)) * (new_max -
                    new_min);
            }

            float3 Interpolation3(float3 value1, float3 value2, float3 value3, float x, float offset = 0.5)
            {
                offset = clamp(offset, 0.0001, 0.9999);
                return lerp(lerp(value1, value2, min(x, offset) / offset), value3, max(0, x - offset) / (1.0 - offset));
            }

            float henyeyGreenstein(float angle, float g)
            {
                float g2 = g * g;
                return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * angle, 1.5));
            }

            float hgScatterLerp(float angle, float g1, float g2, float weight)
            {
                return 1 + lerp(henyeyGreenstein(angle, g1), henyeyGreenstein(angle, -g2), weight);
            }

            float2 slabs(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRayDir)
            {
                // Adapted from: http://jcgt.org/published/0007/03/04/
                float3 t0 = (boundsMin - rayOrigin) * invRayDir;
                float3 t1 = (boundsMax - rayOrigin) * invRayDir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));
                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float sampleDensity(float3 position)
            {
                float3 boundSize = BoundsMax - BoundsMin;
                float3 boundCenter = (BoundsMax + BoundsMin) * 0.5;

                float3 uvw = (boundSize * 0.5 + position) * 0.001;
                float3 baseNoiseUVW = uvw * BaseCloudScale + BaseCloudOffset;
                float3 detailNoiseUVW = uvw * DetailCloudScale + DetailCloudOffset;

                float xFade = min(100, min(position.x - BoundsMin.x, BoundsMax.x - position.x));
                float zFade = min(100, min(position.z - BoundsMin.z, BoundsMax.z - position.z));
                float edgeFade = min(xFade, zFade) / 100;

                float2 weatherUV = boundSize.xz * 0.5 + (position.xz - boundCenter.xz) / max(boundSize.x, boundSize.z);
                float weatherMap = SAMPLE_TEXTURE2D_LOD(_WeatherMap, sampler_WeatherMap, weatherUV, 0).r;
                float hMin = remap(weatherMap, 0, 1, 0.1, 0.5);
                float hMax = remap(weatherMap, 0, 1, hMin, 0.9);
                float hPercent = (position.y - BoundsMin.y) / boundSize.y;
                float hGeadient = saturate(remap(hPercent, 0, hMin, 0, 1)) * saturate(remap(hPercent, 1, hMax, 0, 1));

                float4 baseNoise = SAMPLE_TEXTURE3D_LOD(_BaseNoise, sampler_BaseNoise, baseNoiseUVW, 0);
                float4 normalizedBaseShapeWeights = BaseShapeNoiseWeights / dot(BaseShapeNoiseWeights, 1);
                float baseNoiseFBM = dot(baseNoise, normalizedBaseShapeWeights) * edgeFade * hGeadient;
                // float baseNoiseFBM = dot(baseNoise, float3(0.625, 0.25, 0.125)) * edgeFade * hGeadient;

                // float baseShape = saturate(remap(baseNoise.r, saturate(1.0 - baseNoiseFBM), 1.0, 0, 1.0));
                float cloudDensity = (baseNoiseFBM + BaseCloudDensityThreshold * 0.1);

                if (cloudDensity > 0)
                {
                    float4 detailNoise = SAMPLE_TEXTURE3D_LOD(_DetailNoise, sampler_DetailNoise, detailNoiseUVW, 0);
                    float detailNoiseFBM = dot(detailNoise.yzx, float3(0.625, 0.25, 0.125));

                    float oneMinusShape = 1 - baseNoiseFBM;
                    float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
                    cloudDensity = cloudDensity - (1 - detailNoiseFBM) * detailErodeWeight * DetailCloudDensityThreshold;

                    // cloudDensity = remap(cloudDensity, detailNoiseFBM * DetailCloudDensityThreshold, 1.0, 0.0, 1.0);
                    return cloudDensity * CloudDensityMultiplier * 0.1;
                }
                return 0;
            }

            float lightMarch(float3 position, float3 toLightDir)
            {
                float dstInsideBox = slabs(BoundsMin, BoundsMax, position, 1 / toLightDir).y;

                float stepSize = dstInsideBox / LightSteps;
                float LumDensity = 0;

                for (int i = 0; i < LightSteps; i++)
                {
                    LumDensity += max(0, sampleDensity(position) * stepSize);
                    position += toLightDir * stepSize;
                }

                float lum = beerPowder(LumDensity, AbsorbedIntensity);
                return DarknessThreshold + lum * (1 - DarknessThreshold);
            }

            float4 debugDrawNoise(float2 uv)
            {
                float4 channels = 0;
                float3 samplePos = float3(uv.x, uv.y, debugNoiseSliceDepth);

                if (debugViewMode == 1)
                {
                    channels = SAMPLE_TEXTURE3D_LOD(_BaseNoise, sampler_BaseNoise, samplePos, 0);
                }
                else if (debugViewMode == 2)
                {
                    channels = SAMPLE_TEXTURE3D_LOD(_DetailNoise, sampler_DetailNoise, samplePos, 0);
                }
                else if (debugViewMode == 3)
                {
                    channels = SAMPLE_TEXTURE2D(_WeatherMap, sampler_WeatherMap, samplePos.xy);
                }

                if (debugShowAllChannels)
                {
                    return channels;
                }
                else
                {
                    float4 maskedChannels = (channels * debugChannelWeight);
                    if (debugGreyscale || debugChannelWeight.w == 1)
                    {
                        return dot(maskedChannels, 1);
                    }
                    else
                    {
                        return maskedChannels;
                    }
                }
            }

            float4 frag(v2f i) : SV_Target
            {
                if (debugViewMode != 0)
                {
                    float width = _ScreenParams.x;
                    float height = _ScreenParams.y;
                    float minDim = min(width, height);
                    float x = i.uv.x * width;
                    float y = (1 - i.uv.y) * height;

                    if (x < minDim * viewerSize && y < minDim * viewerSize)
                    {
                        return debugDrawNoise(float2(x / (minDim * viewerSize) * debugTileAmount,
                                     y / (minDim * viewerSize) * debugTileAmount));
                    }
                }

                Light mainLight = GetMainLight();
                float3 viewDirWS = normalize(i.viewWorldVector);
                float3 lightDirWS = normalize(mainLight.direction);
                float3 rayOrigin = GetCameraPositionWS();
                float3 rayPos = rayOrigin;

                float4 col = SAMPLE_TEXTURE2D(_ColorTexture, sampler_ColorTexture, i.uv);
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float depth = LinearEyeDepth(rawDepth, _ZBufferParams) * length(i.viewWorldVector);

                float2 rayBoxInfo = slabs(BoundsMin, BoundsMax, rayOrigin, 1 / viewDirWS);
                float dstToBox = rayBoxInfo.x;
                float dstInsideBox = rayBoxInfo.y;

                float phase = hgScatterLerp(dot(viewDirWS, lightDirWS), ScatterForward, ScatterBackward, ScatterWeight);

                float randomDstTravelOffset = SAMPLE_TEXTURECUBE_LOD(_BlueNoise, sampler_BlueNoise, i.uv, 0).r *
                    RandomDstTravelOffsetIntensity;

                float stepSize = 11;
                float dstLimit = min(depth - dstToBox, dstInsideBox);
                float dstTravelled = randomDstTravelOffset;

                float3 sumLum = 0;
                float lightAttenuation = 1.0;
                float3 entryPos = rayPos + viewDirWS * dstToBox;
                while (dstTravelled < dstLimit)
                {
                    rayPos = entryPos + viewDirWS * dstTravelled;
                    float density = sampleDensity(rayPos) * stepSize;
                    if (density > 0.01)
                    {
                        float lum = lightMarch(rayPos, lightDirWS);
                        float3 cloudColor = Interpolation3(ColorDark.rgb, ColorCentral.rgb, ColorBright.rgb,
                              saturate(lum), ColorCentralOffset) * mainLight.color;
                        sumLum += lightAttenuation * cloudColor * density * phase;
                        lightAttenuation *= beer(density, AbsorbedIntensity);
                        if (lightAttenuation < 0.01)
                        {
                            break;
                        }
                    }
                    dstTravelled += stepSize;
                }
                
                return float4(col.rgb * lightAttenuation + sumLum, 1);
            }
            ENDHLSL
        }
    }
}