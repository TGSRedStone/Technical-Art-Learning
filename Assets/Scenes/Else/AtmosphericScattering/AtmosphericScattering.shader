Shader "Else/AtmosphericScattering"
{
    Properties
    {
    	_PlanetRadius ("PlanetRadius", float) = 6357000
    	_AtmosphereHeight ("AtmosphereHeight", float) = 8500
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			float _PlanetRadius;
            float _AtmosphereHeight;

			float2 _DensityScaleHeight;
			
			float3 _ScatteringR;
			float3 _ScatteringM;
			float3 _ExtinctionR;
			float3 _ExtinctionM;
			
			float4 _IncomingLight;
			float _MieG;
			
			float _SunIntensity;
			float _DistanceScale;
			
			float3 _LightDir;

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

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

            //----- Input
			// position			视线采样点P
			// lightDir			光照方向
			
			//----- Output : 
			// opticalDepthCP:	dcp
			bool lightSampleing(
				float3 position,							// Current point within the atmospheric sphere
				float3 lightDir,							// Direction towards the sun
				out float2 opticalDepthCP)
			{
				opticalDepthCP = 0;
			
				float3 rayStart = position;
				float3 rayDir = -lightDir;
			
				float3 planetCenter = float3(0, -_PlanetRadius, 0);
				float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
				float3 rayEnd = rayStart + rayDir * intersection.y;
			
				// compute density along the ray
				float stepCount = 50;// 250;
				float3 step = (rayEnd - rayStart) / stepCount;
				float stepSize = length(step);
				float2 density = 0;
			
				for (float s = 0.5; s < stepCount; s += 1.0)
				{
					float3 position = rayStart + step * s;
					float height = abs(length(position - planetCenter) - _PlanetRadius);
					float2 localDensity = exp(-(height.xx / _DensityScaleHeight));
			
					density += localDensity * stepSize;
				}
			
				opticalDepthCP = density;
			
				return true;
			}
            //----- Input
			// position			视线采样点P
			// lightDir			光照方向
			
			//----- Output : 
			//dpa
			//dcp
			bool GetAtmosphereDensityRealtime(float3 position, float3 planetCenter, float3 lightDir, out float2 dpa, out float2 dpc)
			{
				float height = length(position - planetCenter) - _PlanetRadius;
				dpa = exp(-height.xx / _DensityScaleHeight.xy);
			
				bool bOverGround = lightSampleing(position, lightDir, dpc);
				return bOverGround;
			}
			//localDensity   rho(h)
            void ComputeLocalInscattering(float2 localDensity, float2 densityPA, float2 densityCP, out float3 localInscatterR, out float3 localInscatterM)
			{
				float2 densityCPA = densityCP + densityPA;
			
				float3 Tr = densityCPA.x * _ExtinctionR;
				float3 Tm = densityCPA.y * _ExtinctionM;
			
				float3 extinction = exp(-(Tr + Tm));
			
				localInscatterR = localDensity.x * extinction;
				localInscatterM = localDensity.y * extinction;
			}

            void ApplyPhaseFunction(inout float3 scatterR, inout float3 scatterM, float cosAngle)
			{
				// r
				float phase = (3.0 / (16.0 * PI)) * (1 + (cosAngle * cosAngle));
				scatterR *= phase;
			
				// m
				float g = _MieG;
				float g2 = g * g;
				phase = (1.0 / (4.0 * PI)) * ((3.0 * (1.0 - g2)) / (2.0 * (2.0 + g2))) * ((1 + cosAngle * cosAngle) / (pow((1 + g2 - 2 * g * cosAngle), 3.0 / 2.0)));
				scatterM *= phase;
			}

            //----- Input
			// rayStart		视线起点 A
			// rayDir		视线方向
			// rayLength		AB 长度
			// planetCenter		地球中心坐标
			// distanceScale	世界坐标的尺寸
			// lightdir		太阳光方向
			// sampleCount		AB 采样次数
			
			//----- Output : 
			// extinction       T(PA)
			// inscattering:	Inscatering
			float4 IntegrateInscatteringRealtime(float3 rayStart, float3 rayDir, float rayLength, float3 planetCenter, float distanceScale, float3 lightDir, float sampleCount, out float4 extinction)
			{
				float3 step = rayDir * (rayLength / sampleCount);
				float stepSize = length(step) * distanceScale;
			
				float2 densityPA = 0;
				float3 scatterR = 0;
				float3 scatterM = 0;
			
				float2 localDensity; 
				float2 densityCP;
			
				float2 prevLocalDensity;
				float3 prevLocalInscatterR, prevLocalInscatterM;
				GetAtmosphereDensityRealtime(rayStart, planetCenter, lightDir, prevLocalDensity, densityCP);
				ComputeLocalInscattering(prevLocalDensity, densityPA, densityCP, prevLocalInscatterR, prevLocalInscatterM);
			
				// P - current integration point
				// A - camera position
				// C - top of the atmosphere
				[loop]
				for (float s = 1.0; s < sampleCount; s += 1)
				{
					float3 p = rayStart + step * s;
			
					GetAtmosphereDensityRealtime(p, planetCenter, lightDir, localDensity, densityCP);
					densityPA += (localDensity + prevLocalDensity) * (stepSize / 2.0); //(stepSize / 2.0) = ds
					prevLocalDensity = localDensity;
					
					float3 localInscatterR, localInscatterM;
					ComputeLocalInscattering(localDensity, densityPA, densityCP, localInscatterR, localInscatterM);
			
					scatterR += (localInscatterR + prevLocalInscatterR) * (stepSize / 2.0);
					scatterM += (localInscatterM + prevLocalInscatterM) * (stepSize / 2.0);
			
					prevLocalInscatterR = localInscatterR;
					prevLocalInscatterM = localInscatterM;
				}
			
				float3 m = scatterM;
				// phase function
				ApplyPhaseFunction(scatterR, scatterM, dot(rayDir, -lightDir.xyz));
				//scatterR = 0;
				float3 lightInscatter = (scatterR * _ScatteringR + scatterM * _ScatteringM) * _IncomingLight.xyz;
				//lightInscatter += RenderSun(m, dot(rayDir, -lightDir.xyz)) * _SunIntensity;
				float3 lightExtinction = exp(-(densityCP.x * _ExtinctionR + densityCP.y * _ExtinctionM));
			
				extinction = float4(lightExtinction, 0);
				return float4(lightInscatter, 1);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float sceneRawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float3 worldPos = ComputeWorldSpacePosition(i.uv, sceneRawDepth, UNITY_MATRIX_I_VP);

            	float3 rayStart = _WorldSpaceCameraPos;
				float3 rayDir = worldPos - _WorldSpaceCameraPos;
				float rayLength = length(rayDir);
				rayDir /= rayLength;
				
				if (sceneRawDepth < 0.000001)
				{
					rayLength = 1e20;
				}
            	
            	float3 planetCenter = float3(0, -_PlanetRadius, 0);
				float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
			
				rayLength = min(intersection.y, rayLength);

				intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);							
				if (intersection.x > 0)
				{
				    rayLength = min(rayLength, intersection.x);
				}
			
				float4 extinction;
				_SunIntensity = 0;
			
				if (sceneRawDepth < 0.000001)
				{
					float4 inscattering = IntegrateInscatteringRealtime(rayStart, rayDir, rayLength, planetCenter, 1, _LightDir, 16, extinction);
					return inscattering;
				}
				else
				{
					float4 inscattering = IntegrateInscatteringRealtime(rayStart, rayDir, rayLength, planetCenter, _DistanceScale, _LightDir, 16, extinction);
    				float4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
				
    				return sceneColor * extinction + inscattering;
				}
					
				
            }
            ENDHLSL
        }
    }
}
