using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GaussianBlurPostProcessing : ScriptableRendererFeature
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

        private GaussianBlurPostProcessingVolume gaussianBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private RenderTargetHandle tempColorTex;

        private string profilerTag;

        private int buffer0 = Shader.PropertyToID("buffer0");
        private const string _BlurSize = "_BlurSize";

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
            gaussianBlurPostProcessingVolume = stack.GetComponent<GaussianBlurPostProcessingVolume>();

            if (gaussianBlurPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!gaussianBlurPostProcessingVolume.IsActive())
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

            int w = renderingData.cameraData.camera.scaledPixelWidth;
            int h = renderingData.cameraData.camera.scaledPixelHeight;
            
            int rtW = w / gaussianBlurPostProcessingVolume.DownSample.value;
            int rtH = h / gaussianBlurPostProcessingVolume.DownSample.value;
            
            cmd.GetTemporaryRT(buffer0, rtW,rtH,0, FilterMode.Bilinear);
            cmd.Blit(source,buffer0);
            
            for (int i = 0; i < gaussianBlurPostProcessingVolume.BlurTimes.value; i++)
            {
                cmd.SetGlobalVector(_BlurSize, new Vector4(gaussianBlurPostProcessingVolume.BlurSize.value / w, 0, 0, 0));
                cmd.Blit(buffer0, source, material, 0);
                cmd.SetGlobalVector(_BlurSize, new Vector4(0, gaussianBlurPostProcessingVolume.BlurSize.value / h, 0, 0));
                cmd.Blit(source, buffer0, material, 0);
            }
            
            cmd.Blit(buffer0, dest);
            cmd.ReleaseTemporaryRT(buffer0);
        }
    }
}
