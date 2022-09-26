using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DirectionalBlurPostProcessing : ScriptableRendererFeature
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

        private DirectionalBlurPostProcessingVolume directionalBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private string profilerTag;

        private int buffer0 = Shader.PropertyToID("buffer0");
        private int Params = Shader.PropertyToID("_Params");

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
            directionalBlurPostProcessingVolume = stack.GetComponent<DirectionalBlurPostProcessingVolume>();

            if (directionalBlurPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!directionalBlurPostProcessingVolume.IsActive())
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
            
            int rtW = w / directionalBlurPostProcessingVolume.DownSample.value;
            int rtH = h / directionalBlurPostProcessingVolume.DownSample.value;
            
            cmd.GetTemporaryRT(buffer0, rtW,rtH,0, FilterMode.Bilinear);
            cmd.Blit(source,buffer0);
            
            float sinVal = (Mathf.Sin(directionalBlurPostProcessingVolume.BlurAngle.value) * directionalBlurPostProcessingVolume.BlurOffset.value * 0.05f) / directionalBlurPostProcessingVolume.BlurTimes.value;
            float cosVal = (Mathf.Cos(directionalBlurPostProcessingVolume.BlurAngle.value) * directionalBlurPostProcessingVolume.BlurOffset.value * 0.05f) / directionalBlurPostProcessingVolume.BlurTimes.value;        
            cmd.SetGlobalVector(Params, new Vector3(directionalBlurPostProcessingVolume.BlurTimes.value, sinVal, cosVal));

            cmd.Blit(buffer0, dest, material, 0);
            
            cmd.ReleaseTemporaryRT(buffer0);
        }
    }
}
