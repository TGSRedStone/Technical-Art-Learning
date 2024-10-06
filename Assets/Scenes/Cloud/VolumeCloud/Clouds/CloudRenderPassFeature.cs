using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.Cloud.VolumeCloud.Clouds
{
    public class CloudRenderPassFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class Settings
        {
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
            [Header(" --- ")]
            [Range(1, 100)] public int lightSteps = 8;
            [Range(0, 1)] public float darknessThreshold = 0.5f;
            [Range(0, 4)] public float absorbedIntensity = 0.5f;
            public float cloudDensityMultiplier = 1f;
            public float randomDstTravelOffsetIntensity;
        
            [Header(" --- ")]
            public float baseCloudScale = 1;
            public Vector3 baseCloudOffset;
            public float detailCloudScale = 1;
            public Vector3 detailCloudOffset;
        
            [Header(" --- ")]
            public Vector4 baseShapeNoiseWeights;
            public float baseCloudDensityThreshold;
            public float detailCloudDensityThreshold;
        
            [Header(" --- ")]
            [Range(0, 0.99f)] public float scatterForward = 0.5f;
            [Range(0, 0.99f)] public float scatterBackward = 0.5f;
            [Range(0, 1)] public float scatterWeight = 0.5f;
        
            [Header(" --- ")]
            public Color colorDark;
            public Color colorCentral;
            public Color colorBright;
            [Range(0, 1)]public float colorCentralOffset;
        
            [Header(" --- ")]
            public Material material;
            public Transform transform;
            public Texture weatherMap;
            public Texture blueNoise;
            public Texture3D baseNoise;
            public Texture3D detailNoise;
        }
    
        class CloudRenderPass : ScriptableRenderPass
        {
            private string _profilerTag;
            private Settings _settings;
            private RenderTargetIdentifier _cameraColor;
            private RenderTargetHandle _tempRT;
            private readonly RenderTextureDescriptor _textureDescriptor;

            public CloudRenderPass(string profilerTag, Settings settings)
            {
                _profilerTag = profilerTag;
                _settings = settings;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                _cameraColor = renderingData.cameraData.renderer.cameraColorTarget;
                cmd.GetTemporaryRT(_tempRT.id, renderingData.cameraData.cameraTargetDescriptor);
            }

        
            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                
                CommandBuffer cmd = CommandBufferPool.Get(_profilerTag);
                using (new ProfilingScope(cmd, new ProfilingSampler(_profilerTag)))
                {
                    cmd.SetGlobalTexture("_ColorTexture", _cameraColor);
                    var position = _settings.transform.position;
                    var localScale = _settings.transform.localScale;
                    _settings.material.SetTexture("_BaseNoise", _settings.baseNoise);
                    _settings.material.SetTexture("_DetailNoise", _settings.detailNoise);
                    _settings.material.SetTexture("_WeatherMap", _settings.weatherMap);
                    _settings.material.SetTexture("_BlueNoise", _settings.blueNoise);

                    _settings.material.SetInt("LightSteps", _settings.lightSteps);
                    _settings.material.SetFloat("DarknessThreshold", _settings.darknessThreshold);
                    _settings.material.SetFloat("AbsorbedIntensity", _settings.absorbedIntensity);
                    _settings.material.SetFloat("CloudDensityMultiplier", _settings.cloudDensityMultiplier);
                    _settings.material.SetFloat("RandomDstTravelOffsetIntensity", _settings.randomDstTravelOffsetIntensity);
                
                    _settings.material.SetVector("BoundsMin", position - localScale / 2);
                    _settings.material.SetVector("BoundsMax", position + localScale / 2);
                
                    _settings.material.SetFloat("BaseCloudScale", _settings.baseCloudScale);
                    _settings.material.SetVector("BaseCloudOffset", _settings.baseCloudOffset);
                    _settings.material.SetFloat("DetailCloudScale", _settings.detailCloudScale);
                    _settings.material.SetVector("DetailCloudOffset", _settings.detailCloudOffset);
                
                    _settings.material.SetVector("BaseShapeNoiseWeights", _settings.baseShapeNoiseWeights);
                    _settings.material.SetFloat("BaseCloudDensityThreshold", _settings.baseCloudDensityThreshold);
                    _settings.material.SetFloat("DetailCloudDensityThreshold", _settings.detailCloudDensityThreshold);

                    _settings.material.SetFloat("ScatterForward", _settings.scatterForward);
                    _settings.material.SetFloat("ScatterBackward", _settings.scatterBackward);
                    _settings.material.SetFloat("ScatterWeight", _settings.scatterWeight);
                
                    _settings.material.SetVector("ColorDark", _settings.colorDark);
                    _settings.material.SetVector("ColorCentral", _settings.colorCentral);
                    _settings.material.SetVector("ColorBright", _settings.colorBright);
                    _settings.material.SetFloat("ColorCentralOffset", _settings.colorCentralOffset);
                
                    // SetDebugParams();
                
                    cmd.Blit(_cameraColor, _tempRT.Identifier(), _settings.material);
                    cmd.Blit(_tempRT.Identifier(), _cameraColor);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        
            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(_tempRT.id);
            }
        
            // void SetDebugParams () {
            //
            //     var noise = FindObjectOfType<NoiseGenerator> ();
            //     var weatherMapGen = FindObjectOfType<WeatherMapGenerator> ();
            //
            //     int debugModeIndex = 0;
            //     if (noise != null && noise.viewerEnabled) {
            //         debugModeIndex = (noise.currentNoiseType == NoiseGenerator.NoiseType.Base) ? 1 : 2;
            //         _settings.material.SetFloat ("debugNoiseSliceDepth", noise.viewerSliceDepth);
            //         _settings.material.SetFloat ("debugTileAmount", noise.viewerTileAmount);
            //         _settings.material.SetFloat ("viewerSize", noise.viewerSize);
            //         _settings.material.SetVector ("debugChannelWeight", noise.ChannelMask);
            //         _settings.material.SetInt ("debugGreyscale", (noise.viewerGreyscale) ? 1 : 0);
            //         _settings.material.SetInt ("debugShowAllChannels", (noise.viewerShowAllChannels) ? 1 : 0);
            //     }
            //     if (weatherMapGen != null && weatherMapGen.viewerEnabled) {
            //         debugModeIndex = 3;
            //         if (!Application.isPlaying) {
            //             weatherMapGen.GenerateWeatherMap();
            //         }
            //         _settings.material.SetTexture("_WeatherMap", weatherMapGen.weatherMap);
            //         _settings.material.SetFloat ("debugNoiseSliceDepth", noise.viewerSliceDepth);
            //         _settings.material.SetFloat ("debugTileAmount", noise.viewerTileAmount);
            //         _settings.material.SetFloat ("viewerSize", noise.viewerSize);
            //         _settings.material.SetVector ("debugChannelWeight", noise.ChannelMask);
            //         _settings.material.SetInt ("debugGreyscale", (noise.viewerGreyscale) ? 1 : 0);
            //         _settings.material.SetInt ("debugShowAllChannels", (noise.viewerShowAllChannels) ? 1 : 0);
            //     }
            //     _settings.material.SetInt ("debugViewMode", debugModeIndex);
            // }
        }
    
        private CloudRenderPass _cloudPass;
        public Settings settings;

        public override void Create()
        {
            _cloudPass = new CloudRenderPass(name, settings)
            {
                renderPassEvent = settings.renderPassEvent
            };
        }
    
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(_cloudPass);
        }
    }
}


