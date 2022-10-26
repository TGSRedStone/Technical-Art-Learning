Shader "SkyBox/ProceduralSkyBox"
{
    Properties
    {
        _MoonTex ("MoonTex", 2d) = "white" {}
        _StarTex ("StarTex", 2d) = "white" {}
        _NoiseTex ("NoiseTex", 2d) = "white" {}
        [HDR]_SunColor ("SunColor", color) = (1, 1, 1, 1)
        _SunSetColor ("SunSetColor", color) = (1, 1, 1, 1)
        _DayTopColor ("DayTopColor", color) = (1, 1, 1, 1)
        _DayBottomColor ("DayBottomColor", color) = (1, 1, 1, 1)
        _NightTopColor ("NightTopColor", color) = (1, 1, 1, 1)
        _NightBottomColor ("NightBottomColor", color) = (1, 1, 1, 1)
        _HorizonDayColor ("HorizonDayColor", color) = (1, 1, 1, 1)
        _HorizonNightColor ("HorizonNightColor", color) = (1, 1, 1, 1)
    	_SkyGradientDayColTime ("SkyGradientDayColTime", range(0, 1)) = 0.4
        _SunSize ("SunSize", range(0, 1)) = 0.05
        _SunGlow ("SunGlow", range(1, 10)) = 1
        _MoonSize ("MoonSize", float) = 1
	    _MoonGlowSize ("MoonGlowSize", float) = 1
        [HDR]_MoonColor ("MoonColor", color) = (1, 1, 1, 1)
	    _MoonGlowColor ("MoonGlowColor", color) = (1, 1, 1, 1)
    	_StarDensity ("StarDensity", float) = 1
    	_StarTwinkleFrequency ("StarTwinkleFrequency", float) = 1
    	_StarHeight ("StarHeight", range(0, 1)) = 0
    }
    SubShader
    {
        Tags{"Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" "RenderPipeline" = "UniversalPipeline"}

        Cull Off ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _MoonTex_ST;
            float4 _StarTex_ST;
            float4 _CloudNoiseTex_ST;
            float4 _SunColor;
            float4 _MoonColor;
            float4 _MoonGlowColor;
            float4 _SunSetColor;
            float4 _DayTopColor;
            float4 _DayBottomColor;
            float4 _NightTopColor;
            float4 _NightBottomColor;
            float4 _HorizonDayColor;
            float4 _HorizonNightColor;
            float4x4 _LtoW;
            float _SkyGradientDayColTime;
            float _SunSize;
            float _SunGlow;
            float _MoonSize;
            float _MoonGlowSize;

			float _PlanetRadius;
            float _AtmosphereHeight;
			float2 _DensityScaleHeight;
			float _MieG;
			float3 _ScatteringM;
			float3 _ExtinctionM;
            float4 _IncomingLight;

            float _StarDensity;
            float _StarTwinkleFrequency;
            float _StarHeight;

            TEXTURE2D(_MoonTex); SAMPLER(sampler_MoonTex);
            TEXTURE2D(_StarTex); SAMPLER(sampler_StarTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            	float3 tangent : TANGENT;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            //https://www.jianshu.com/p/1b008ed86627
            //TODO: 按照网页中的简化公式写一下
            //射线求交函数
            float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius)
			{
				rayOrigin -= sphereCenter;
				float a = dot(rayDir, rayDir);
				float b = 2.0 * dot(rayOrigin, rayDir);
				float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
				float d = b * b - 4 * a * c;
				if (d < 0)
				{
					return -1;
				}
				else
				{
					d = sqrt(d);
					return float2(-b - d, -b + d) / (2 * a);
				}
			}

            void ComputeOutLocalDensity(float3 position, float3 lightDir, out float localDPA, out float DPC)
			{
				float3 planetCenter = float3(0, -_PlanetRadius, 0);
				float height = length(position - planetCenter) - _PlanetRadius;
				localDPA = exp(-height / _DensityScaleHeight.y);
			
				DPC = 0;
			}

            float MiePhaseFunction(float cosAngle)
			{
				// m
				float g = _MieG;
				float g2 = g * g;
				float phase = (1.0 / (4.0 * PI)) * ((3.0 * (1.0 - g2)) / (2.0 * (2.0 + g2))) * ((1 + cosAngle * cosAngle) / (pow((1 + g2 - 2 * g * cosAngle), 3.0 / 2.0)));
				return phase;
			}
            
			float4 IntegrateInscattering(float3 rayStart,float3 rayDir,float rayLength, float3 lightDir,float sampleCount)
			{
				float3 stepVector = rayDir * (rayLength / sampleCount);
				float stepSize = length(stepVector);
			
				float3 scatterMie = 0;
			
				float densityCP = 0;
				float densityPA = 0;
				float localDPA = 0;
			
				float prevLocalDPA;
				float3 prevTransmittance;
				
				ComputeOutLocalDensity(rayStart,lightDir, localDPA, densityCP);
				
				densityPA += localDPA * (stepSize / 2);
				prevLocalDPA = localDPA;
			
				float Transmittance = exp(-densityPA * _ExtinctionM) * localDPA;
				
				prevTransmittance = Transmittance;
				
				[loop]
				for(float i = 1.0; i < sampleCount; i += 1.0)
				{
					float3 P = rayStart + stepVector * i;
					
					ComputeOutLocalDensity(P, lightDir, localDPA, densityCP);
					densityPA += (prevLocalDPA + localDPA) * (stepSize / 2);
			
					Transmittance = exp(-densityPA * _ExtinctionM) * localDPA;
			
					scatterMie += (prevTransmittance + Transmittance) * (stepSize / 2);
					
					prevTransmittance = Transmittance;
					prevLocalDPA = localDPA;
				}
			
				scatterMie = scatterMie * MiePhaseFunction(dot(rayDir, -lightDir.xyz));
			
				float3 lightInscatter = _ScatteringM * scatterMie * _IncomingLight.xyz;
			
				return float4(lightInscatter,1);
			}

            float3 ACESFilm(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
			}

            float4 frag (v2f i) : SV_Target
            {
                // float3 sunCol = lerp(_SunSetColor, _SunColor, smoothstep(-0.03, 0.03, _MainLightPosition.y)) * saturate(sunArea);

            	//SunAndMoon
            	float sunPoint = distance(i.uv, _MainLightPosition.xyz);
                float sunArea = 1.0 - smoothstep(0.0, _SunSize, sunPoint);
                sunArea *= _SunGlow;
                float3 sunUV = mul(i.uv.xyz, (float3x3)_LtoW);
                float2 moonUV = sunUV.xy * (1 / (_MoonSize + 0.001));
                float4 moonTex = SAMPLE_TEXTURE2D(_MoonTex, sampler_MoonTex, TRANSFORM_TEX(moonUV, _MoonTex));
				float3 sunCol = _SunColor.rgb * saturate(sunArea);
                float3 moonCol = moonTex.rgb * moonTex.a * step(0, sunUV.z) * _MoonColor.rgb;
				
                float3 sunAndMoonCol = sunCol + moonCol;

            	//MoonGlow
            	float moonPoint = distance(i.uv, -_MainLightPosition.xyz);
				float moonGlowMask = 1.0 - smoothstep(0.0, _MoonGlowSize, moonPoint);
            	float3 moonGlow = moonGlowMask * _MoonGlowColor.rgb;

            	//Sky
                float4 gradientDay = lerp(_DayBottomColor, _DayTopColor, saturate(i.uv.y));
                float4 gradientNight = lerp(_NightBottomColor, _NightTopColor, saturate(i.uv.y));
                float4 skyGradients = lerp(gradientNight, gradientDay, saturate(_MainLightPosition.y + _SkyGradientDayColTime));

            	//Star
                float startMask = lerp(0, 1, -_MainLightPosition.y) * step(_StarHeight, i.uv.y);
            	float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv.xz / i.uv.y + _Time.x * _StarTwinkleFrequency).r;
                float3 star = SAMPLE_TEXTURE2D(_StarTex, sampler_StarTex, i.uv.xz / i.uv.y * _StarDensity).rgb * noise;
                star = saturate(star * startMask);

            	//Mie scattering
				float3 scatteringColor = 0;
				
				float3 rayStart = float3(0,10,0);
				float3 rayDir = normalize(i.uv.xyz);
				
				float3 planetCenter = float3(0, -_PlanetRadius, 0);
				float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
				float rayLength = intersection.y;
				
				intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
				if (intersection.x > 0)
					rayLength = min(rayLength, intersection.x);
				
				float4 inscattering = IntegrateInscattering(rayStart, rayDir, rayLength, -_MainLightPosition.xyz, 16);

            	//Finally
                return float4(sunAndMoonCol + skyGradients.rgb + star + ACESFilm(inscattering) + moonGlow, 1);
            }
            ENDHLSL
        }
    }
}
