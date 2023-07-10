//http://www.humus.name/index.php?page=3D&ID=80
//https://forum.unity.com/threads/interior-mapping.424676/
Shader "InteriorMapping/InteriorMapping"
{
    Properties
    {
        _RoomCube ("Room Cube Map", Cube) = "white" {}
        _RoomDepth ("RoomDepth", range(0.001, 0.999)) = 0.5
        [Toggle(_USEOBJECTSPACE)] _UseObjectSpace ("Use Object Space", Float) = 0.0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _USEOBJECTSPACE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _RoomDepth;
            float4 _RoomCube_ST;
            CBUFFER_END
            
            TEXTURECUBE(_RoomCube); SAMPLER(sampler_RoomCube);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            #ifdef _USEOBJECTSPACE
                float3 uvw : TEXCOORD0;
            #else
                float2 uv : TEXCOORD0;
            #endif
                float3 viewDir : TEXCOORD1;
            };

            // psuedo random
            float3 rand3(float co)
            {
                return frac(sin(co * float3(12.9898,78.233,43.2316)) * 43758.5453);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
            #ifdef _USEOBJECTSPACE
                // slight scaling adjustment to work around "noisy wall" when frac() returns a 0 on surface
                o.uvw = v.vertex * _RoomCube_ST.xyx * 0.999 + _RoomCube_ST.zwz;
 
                // get object space camera vector
                float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
                o.viewDir = v.vertex.xyz - objCam.xyz;
 
                // adjust for tiling
                o.viewDir *= _RoomCube_ST.xyx;
            #else
                // uvs
                o.uv = TRANSFORM_TEX(v.uv, _RoomCube);
                
                // get tangent space camera vector
                float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
                float3 viewDir = v.vertex.xyz - objCam.xyz;
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;
                o.viewDir = float3(
                    dot(viewDir, v.tangent.xyz),
                    dot(viewDir, bitangent),
                    dot(viewDir, v.normal)
                    );
 
                // adjust for tiling
                o.viewDir *= _RoomCube_ST.xyx;
            #endif
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // Specify depth manually
                float farFrac = _RoomDepth;
                
                //remap [0,1] to [+inf,0]
                //->if input _RoomDepth = 0    -> depthScale = 0      (inf depth room)
                //->if input _RoomDepth = 0.5  -> depthScale = 1
                //->if input _RoomDepth = 1    -> depthScale = +inf   (0 volume room)
                float depthScale = 1.0 / (1.0 - farFrac) - 1.0;
                i.viewDir.z *= depthScale;
            #ifdef _USEOBJECTSPACE
                // room uvws
                float3 roomUVW = frac(i.uvw);
 
                // raytrace box from object view dir
                float3 pos = roomUVW * 2.0 - 1.0;
                float3 id = 1.0 / i.viewDir;
                float3 k = abs(id) - pos * id;
                float kMin = min(min(k.x, k.y), k.z);
                pos += kMin * i.viewDir;
 
                // randomly flip & rotate cube map for some variety
                float3 flooredUV = floor(i.uvw);
                float3 r = rand3(flooredUV.x + flooredUV.y + flooredUV.z);
                float2 cubeflip = floor(r.xy * 2.0) * 2.0 - 1.0;
                pos.xz *= cubeflip;
                pos.xz = r.z > 0.5 ? pos.xz : pos.zx;
            #else
                // room uvs
                float2 roomUV = frac(i.uv);
 
                // raytrace box from tangent view dir
                float3 pos = float3(roomUV * 2.0 - 1.0, 1.0);
                float3 id = 1.0 / i.viewDir;
                float3 k = abs(id) - pos * id;
                float kMin = min(min(k.x, k.y), k.z);
                pos += kMin * i.viewDir;
 
                // randomly flip & rotate cube map for some variety
                float2 flooredUV = floor(i.uv);
                float3 r = rand3(flooredUV.x + 1.0 + flooredUV.y * (flooredUV.x + 1));
                float2 cubeflip = floor(r.xy * 2.0) * 2.0 - 1.0;
                pos.xz *= cubeflip;
                pos.xz = r.z > 0.5 ? pos.xz : pos.zx;
            #endif
                // sample room cube map
                float4 room = SAMPLE_TEXTURECUBE(_RoomCube, sampler_RoomCube, pos.xyz);
                return float4(room.rgb, 1.0);
            }
            ENDHLSL
        }
    }
}
