using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class KawaseBlurPostProcessing : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
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

        private KawaseBlurPostProcessingVolume kawaseBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private RenderTargetHandle tempColorTex;

        private string profilerTag;

        private int buffer0 = Shader.PropertyToID("buffer0");
        private const string _PixelOffset = "_PixelOffset";

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
             
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

            var stack = VolumeManager.instance.stack;
            kawaseBlurPostProcessingVolume = stack.GetComponent<KawaseBlurPostProcessingVolume>();

            if (kawaseBlurPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!kawaseBlurPostProcessingVolume.IsActive())
            {
                return;
            }

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
            
            int rtW = renderingData.cameraData.camera.scaledPixelWidth / kawaseBlurPostProcessingVolume.DownSample.value;
            int rtH = renderingData.cameraData.camera.scaledPixelHeight / kawaseBlurPostProcessingVolume.DownSample.value;
            
            cmd.GetTemporaryRT(buffer0, rtW,rtH,0,FilterMode.Bilinear, RenderTextureFormat.Default);
            cmd.Blit(source,buffer0);
            
            bool needSwitch = true;
            for (int i = 0; i < kawaseBlurPostProcessingVolume.BlurTimes.value; i++)
            {
                cmd.SetGlobalFloat(_PixelOffset, i / (float)kawaseBlurPostProcessingVolume.DownSample.value + kawaseBlurPostProcessingVolume.PixelOffset.value);
                cmd.Blit(needSwitch ? buffer0 : source, needSwitch ? source : buffer0, material, 0);
                needSwitch = !needSwitch;
            }

            cmd.SetGlobalFloat(_PixelOffset, kawaseBlurPostProcessingVolume.BlurTimes.value / (float)kawaseBlurPostProcessingVolume.DownSample.value + kawaseBlurPostProcessingVolume.PixelOffset.value);
            cmd.Blit(needSwitch ? buffer0 : source, dest, material, 0);
            
            cmd.ReleaseTemporaryRT(buffer0);
        }
    }
}
