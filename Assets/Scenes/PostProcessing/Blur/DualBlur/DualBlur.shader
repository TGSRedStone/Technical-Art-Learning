Shader "PostProcessing/Blur/Dual Blur"
{
	HLSLINCLUDE 
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    
    float4 _MainTex_TexelSize;
    half _Offset;
    
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

	struct a2v
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};
    
    struct v2f_Down
	{
		float4 vertex: SV_POSITION;
		float2 uv: TEXCOORD0;
		float4 uv01: TEXCOORD1;
		float4 uv23: TEXCOORD2;
	};
	
	
	struct v2f_Up
	{
		float4 vertex: SV_POSITION;
		float2 uv: TEXCOORD0;
		float4 uv01: TEXCOORD1;
		float4 uv23: TEXCOORD2;
		float4 uv45: TEXCOORD3;
		float4 uv67: TEXCOORD4;
	};
	
	
	v2f_Down Vert_DownSample(a2v v)
	{
		v2f_Down o;
		o.vertex = TransformObjectToHClip(v.vertex.xyz);
		o.uv = v.uv;
		
		_MainTex_TexelSize *= 0.5;
		o.uv01.xy = o.uv - _MainTex_TexelSize * float2(1 + _Offset, 1 + _Offset);//top right
		o.uv01.zw = o.uv + _MainTex_TexelSize * float2(1 + _Offset, 1 + _Offset);//bottom left
		o.uv23.xy = o.uv - float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * float2(1 + _Offset, 1 + _Offset);//top left
		o.uv23.zw = o.uv + float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * float2(1 + _Offset, 1 + _Offset);//bottom right
		
		return o;
	}
	
	half4 Frag_DownSample(v2f_Down i): SV_Target
	{
		half4 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * 4;
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw);
		
		return sum * 0.125;
	}
	
	
	v2f_Up Vert_UpSample(a2v v)
	{
		v2f_Up o;
		o.vertex = TransformObjectToHClip(v.vertex.xyz);
		o.uv = v.uv;
		
		_MainTex_TexelSize *= 0.5;
		_Offset = float2(1 + _Offset, 1 + _Offset);
		o.uv01.xy = o.uv + float2(-_MainTex_TexelSize.x * 2, 0) * _Offset;
		o.uv01.zw = o.uv + float2(-_MainTex_TexelSize.x, _MainTex_TexelSize.y) * _Offset;
		o.uv23.xy = o.uv + float2(0, _MainTex_TexelSize.y * 2) * _Offset;
		o.uv23.zw = o.uv + _MainTex_TexelSize * _Offset;
		o.uv45.xy = o.uv + float2(_MainTex_TexelSize.x * 2, 0) * _Offset;
		o.uv45.zw = o.uv + float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _Offset;
		o.uv67.xy = o.uv + float2(0, -_MainTex_TexelSize.y * 2) * _Offset;
		o.uv67.zw = o.uv - _MainTex_TexelSize * _Offset;
		
		return o;
	}
	
	half4 Frag_UpSample(v2f_Up i): SV_Target
	{
		half4 sum = 0;
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw) * 2;
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw) * 2;
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.zw) * 2;
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv67.xy);
		sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv67.zw) * 2;
		
		return sum * 0.0833;
	}
	
	ENDHLSL
	
	SubShader
	{
		Cull Off ZWrite Off ZTest Always
		
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex Vert_DownSample
			#pragma fragment Frag_DownSample
			
			ENDHLSL
			
		}
		
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex Vert_UpSample
			#pragma fragment Frag_UpSample
			
			ENDHLSL
			
		}
	}
    Fallback Off
}
