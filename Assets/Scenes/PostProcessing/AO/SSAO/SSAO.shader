//reference : 
Shader "PostProcessing/AO/SSAO"
{

    HLSLINCLUDE
    
    #include "SSAO.hlsl"
    
    float _SampleCount;
    float _Radius;
    float _edgeCheck;
    float _BlurRadius;
    float _BilaterFilterFactor;
	float2 _AOTex_TexelSize;
    float4x4 _worldToCameraMatrix;
    float4x4 _projectionMatrix;
    
    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };
    
    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float4 screenPos : TEXCOORD1;
    };
    
    v2f vert (appdata v)
    {
        v2f o;
        o.vertex = TransformObjectToHClip(v.vertex.xyz);
        o.uv = v.uv;
        o.screenPos = ComputeScreenPos(o.vertex);
        return o;
    }
    
    float4 frag (v2f i) : SV_Target
    {
        float4 worldPos = GetWorldPos(i.uv);
        float3 worldNormal = GetWorldNormal(i.uv);
        float3 worldTangent = GetRandomVec(i.uv);
        float3 worldBitangent = cross(worldNormal, worldTangent);
        worldTangent = cross(worldBitangent, worldNormal);
        float3x3 TBN = float3x3(worldTangent, worldBitangent, worldNormal);
        
        float ao = 0;
        for (int x = 0; x < _SampleCount; x++)
        {
            float3 offDir = GetRandomVecHalf(x * i.uv);
            float scale = x / _SampleCount;
            scale = lerp(0.01, 1, scale * scale);
            offDir *= scale * _Radius;
            float weight = smoothstep(0.5, 0, length(offDir)); // 距离原始位置太远的点对最终效果贡献不大
            offDir = mul(offDir, TBN);
            
            float4 worldPosOff = float4(offDir, 0) + worldPos;
            float4 viewPosOff = mul(_worldToCameraMatrix, worldPosOff);
            float4 clipPosOff = mul(_projectionMatrix, viewPosOff);
            float2 ScreenPosOff = (clipPosOff.xy / clipPosOff.w) * 0.5 + 0.5;
            
            float depth = GetEyeDepth(ScreenPosOff);
            float offDepth = clipPosOff.w;
            
            float edgeCheck = smoothstep(0, 1.0, _Radius / abs(offDepth - depth) * _edgeCheck);
            float eyeDepth = GetEyeDepth(i.uv);
            float selfCheck = (depth < eyeDepth - 0.08) ?  1 : 0;
            
            ao += (depth < offDepth) ? 1 * weight * edgeCheck * selfCheck : 0;
        }
        ao = 1 - saturate(ao / _SampleCount);
        return ao;
    }

    float3 DecodeViewNormalStereo ( float4 enc4 )
	{
	    float kScale = 1.7777;
	    float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
	    float g = 2.0 / dot(nn.xyz,nn.xyz);
	    float3 n;
	    n.xy = g*nn.xy;
	    n.z = g-1;
	    return n;
	}

    float3 GetNormal(float2 uv)
    {
        float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
        return DecodeViewNormalStereo(cdn);
    }

    half CompareNormal(float3 nor1, float3 nor2)
    {
        return smoothstep(_BilaterFilterFactor, 1.0, dot(nor1, nor2));
    }

    float4 frag_Blur(v2f i) : SV_TARGET
    {
        float2 delta = _AOTex_TexelSize.xy * _BlurRadius.xx;

        float2 uv = i.uv;
		float2 uv0a = i.uv - delta;
		float2 uv0b = i.uv + delta;	
		float2 uv1a = i.uv - 2.0 * delta;
		float2 uv1b = i.uv + 2.0 * delta;
		float2 uv2a = i.uv - 3.0 * delta;
		float2 uv2b = i.uv + 3.0 * delta;
		
		float3 normal = GetNormal(uv);
		float3 normal0a = GetNormal(uv0a);
		float3 normal0b = GetNormal(uv0b);
		float3 normal1a = GetNormal(uv1a);
		float3 normal1b = GetNormal(uv1b);
		float3 normal2a = GetNormal(uv2a);
		float3 normal2b = GetNormal(uv2b);
		
		float4 col =   SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv);
		float4 col0a = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv0a);
		float4 col0b = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv0b);
		float4 col1a = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv1a);
		float4 col1b = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv1b);
		float4 col2a = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv2a);
		float4 col2b = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv2b);
		
		half w = 0.37004405286;
		half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
		half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		half w2b = CompareNormal(normal, normal2b) * 0.11453744493;
		
		half3 result;
		result = w * col.rgb;
		result += w0a * col0a.rgb;
		result += w0b * col0b.rgb;
		result += w1a * col1a.rgb;
		result += w1b * col1b.rgb;
		result += w2a * col2a.rgb;
		result += w2b * col2b.rgb;
		
		result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		return float4(result, 1.0);
    }

    float4 frag_Composite(v2f i) : SV_TARGET
    {
        float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
        float4 ao = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, i.uv);
        col.rgb *= ao.r;
        return col;
    }
    ENDHLSL
        
    SubShader
    {
        Cull Off
		ZTest Always
		ZWrite Off
        
        pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
        
        pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag_Blur
            ENDHLSL
        }
    	
    	pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag_Composite
            ENDHLSL
        }
        
    }
	FallBack off
}
