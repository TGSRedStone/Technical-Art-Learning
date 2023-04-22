Shader "PostProcessing/Bloom"
{
    HLSLINCLUDE
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
    TEXTURE2D(_SourceTex); SAMPLER(sampler_SourceTex);
    half _Intensity;
    half4 _Filter;
    float4 _MainTex_TexelSize;
    
    struct a2vBlur
    {
        float4 vertex : POSITION;
    	float2 uv : TEXCOORD0;
    };
    
    struct v2fBlur
    {
        float4 pos : SV_POSITION;
    	float2 uv : TEXCOORD0;
    };

    half3 Prefilter(half3 c)
    {
	    half brightness = max(c.r, max(c.g,c.b));
    	half soft = brightness - _Filter.y;
    	soft = clamp(soft, 0, 2 * _Filter.z);
    	soft = soft * soft / (4 * _Filter.w);
    	half contribution = max(soft, brightness - _Filter.x);
    	contribution /= max(brightness, 0.0001);
    	return c * contribution;
    }
    
	v2fBlur vertBlur(a2vBlur v)
    {
        v2fBlur o;
        o.pos = TransformObjectToHClip(v.vertex.xyz);
		o.uv = v.uv;
        return o;
    }

    half3 SimpleBoxFilterKernel(float2 uv, float delta)
	{
	    float4 o = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy;
	    half3 s = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + o.xy).xyz
	            + SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + o.zy).xyz
	    		+ SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + o.xw).xyz
				+ SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + o.zw).xyz;
		return s * 0.25f;
	}
	
	
    ENDHLSL
    
    SubShader
    {
        ZTest Always
        ZWrite Off
        Cull Off
    	
    	//0
    	pass
        {
            HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur

            half4 fragBlur(v2fBlur i) : SV_TARGET
    		{
    		    half3 col = Prefilter(SimpleBoxFilterKernel(i.uv, 1));
    		    return half4(col, 1);
    		}
            ENDHLSL
        }
        
    	//1
        pass
        {
            HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur

            half4 fragBlur(v2fBlur i) : SV_TARGET
    		{
    		    half3 col = SimpleBoxFilterKernel(i.uv, 1);
    		    return half4(col, 1);
    		}
            ENDHLSL
        }
    	
    	//2
    	pass
        {
	        HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur

            half4 fragBlur(v2fBlur i) : SV_TARGET
    		{
    		    half3 col = SimpleBoxFilterKernel(i.uv, 0.5f);
    		    return half4(col, 1);
    		}
            ENDHLSL
        }
    	
    	//3
		pass
        {
	        HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur

            half4 fragBlur(v2fBlur i) : SV_TARGET
    		{
    		    half4 col = SAMPLE_TEXTURE2D(_SourceTex, sampler_SourceTex, i.uv);
    			col.rgb += _Intensity * SimpleBoxFilterKernel(i.uv, 0.5f);
    		    return col;
    		}
            ENDHLSL
        }
    	
    	//4
    	pass
        {
	        HLSLPROGRAM
            #pragma vertex vertBlur
            #pragma fragment fragBlur

            half4 fragBlur(v2fBlur i) : SV_TARGET
    		{
    			return half4(_Intensity * SimpleBoxFilterKernel(i.uv, 0.5), 1);
    		}
            ENDHLSL
        }
    }
    Fallback Off
}
