using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphericScatteringPostProcessing : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
        public Light Sun;


        [Range(1, 64)]
        public int SampleCount = 16;
        public float MaxRayLength = 400;

        [ColorUsage(false, true, 0, 10, 0, 10)]
        public Color IncomingLight = new Color(4, 4, 4, 4);
        [Range(0, 10.0f)]
        public float RayleighScatterCoef = 1;
        [Range(0, 10.0f)]
        public float RayleighExtinctionCoef = 1;
        [Range(0, 10.0f)]
        public float MieScatterCoef = 1;
        [Range(0, 10.0f)]
        public float MieExtinctionCoef = 1;
        [Range(0.0f, 0.999f)]
        public float MieG = 0.76f;
        public float DistanceScale = 1;


        public Color _sunColor;

        public float AtmosphereHeight = 80000.0f;
        public float PlanetRadius = 6371000.0f;
        public Vector4 DensityScale = new Vector4(7994.0f, 1200.0f, 0, 0);
        public Vector4 RayleighSct = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f;
        public Vector4 MieSct = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;
    }

    public BlitSettings Settings = new BlitSettings();
    private BlitPass blitPass;
    
    public override void Create()
    {
        if (Settings.Shader == null)
        {
            Debug.LogError("shader not exist");
            return;
        }
        blitPass = new BlitPass(Settings, name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        blitPass.Setup(renderer);
        renderer.EnqueuePass(blitPass);
    }

    private class BlitPass : ScriptableRenderPass
    {
        private Material material = null;
        private static readonly int mainTexId = Shader.PropertyToID("_MainTex");

        private BlitSettings settings;

        private GaussianBlurPostProcessingVolume gaussianBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private string profilerTag;

        private Camera Camera;

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            settings.Sun = FindObjectOfType<Light>();
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null)
            {
                Debug.LogError("material not created");
                return;
            }

            if (!renderingData.cameraData.postProcessEnabled)
            {
                return;
            }

            // var stack = VolumeManager.instance.stack;
            // gaussianBlurPostProcessingVolume = stack.GetComponent<GaussianBlurPostProcessingVolume>();
            //
            // if (gaussianBlurPostProcessingVolume == null)
            // {
            //     Debug.LogError("can't get volume");
            //     return;
            // }
            //
            // if (!gaussianBlurPostProcessingVolume.IsActive())
            // {
            //     return;
            // }

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            var renderer = renderingData.cameraData.renderer;
            source = renderer.cameraColorTarget;
            dest = renderer.cameraColorTarget;

            Render(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            cmd.SetGlobalTexture(mainTexId, source);

            int w = renderingData.cameraData.camera.scaledPixelWidth;
            int h = renderingData.cameraData.camera.scaledPixelHeight;
            
            // int rtW = w / gaussianBlurPostProcessingVolume.DownSample.value;
            // int rtH = h / gaussianBlurPostProcessingVolume.DownSample.value;
            
            material.SetFloat("_AtmosphereHeight", settings.AtmosphereHeight);
            material.SetFloat("_PlanetRadius", settings.PlanetRadius);
            material.SetVector("_DensityScaleHeight", settings.DensityScale);

            Vector4 scatteringR = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f;
            Vector4 scatteringM = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;

            material.SetVector("_ScatteringR", settings.RayleighSct * settings.RayleighScatterCoef);
            material.SetVector("_ScatteringM", settings.MieSct * settings.MieScatterCoef);
            material.SetVector("_ExtinctionR", settings.RayleighSct * settings.RayleighExtinctionCoef);
            material.SetVector("_ExtinctionM", settings.MieSct * settings.MieExtinctionCoef);

            material.SetColor("_IncomingLight", settings.IncomingLight);
            material.SetFloat("_MieG", settings.MieG);
            material.SetFloat("_DistanceScale", settings.DistanceScale);
            material.SetColor("_SunColor", settings._sunColor);

            //---------------------------------------------------

            material.SetVector("_LightDir", new Vector4(settings.Sun.transform.forward.x, settings.Sun.transform.forward.y, settings.Sun.transform.forward.z, 1.0f / (settings.Sun.range * settings.Sun.range)));
            material.SetVector("_LightColor", settings.Sun.color * settings.Sun.intensity);
            
            cmd.Blit(source, dest, material);
            
        }
    }
}
