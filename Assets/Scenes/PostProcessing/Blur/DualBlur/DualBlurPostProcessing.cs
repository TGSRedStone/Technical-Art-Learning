using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DualBlurPostProcessing : ScriptableRendererFeature
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

        private DualBlurPostProcessingVolume dualBlurPostProcessingVolume;
        
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }

        private string profilerTag;

        private int buffer0 = Shader.PropertyToID("buffer0");
        private int buffer1 = Shader.PropertyToID("buffer1");
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
            dualBlurPostProcessingVolume = stack.GetComponent<DualBlurPostProcessingVolume>();

            if (dualBlurPostProcessingVolume == null)
            {
                Debug.LogError("can't get volume");
                return;
            }
            
            if (!dualBlurPostProcessingVolume.IsActive())
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
        
        void KawaseBlur(CommandBuffer cmd)
        {
            bool needSwitch = true;
            for (int i = 0; i < dualBlurPostProcessingVolume.KawaseBlurTimes.value; i++)
            {
                cmd.SetGlobalFloat(_PixelOffset, i / (float)dualBlurPostProcessingVolume.DownSample.value + dualBlurPostProcessingVolume.PixelOffset.value);
                cmd.Blit(needSwitch ? buffer0 : buffer1, needSwitch ? buffer1 : buffer0, material, 0);
                needSwitch = !needSwitch;
            }

            cmd.SetGlobalFloat(_PixelOffset, dualBlurPostProcessingVolume.KawaseBlurTimes.value / (float)dualBlurPostProcessingVolume.DownSample.value + dualBlurPostProcessingVolume.PixelOffset.value);
            cmd.Blit(needSwitch ? buffer0 : buffer1, source, material, 0);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            cmd.SetGlobalTexture(mainTexId, source);

            int w = renderingData.cameraData.camera.scaledPixelWidth;
            int h = renderingData.cameraData.camera.scaledPixelHeight;

            cmd.GetTemporaryRT(buffer0, w,h,0,FilterMode.Bilinear, RenderTextureFormat.Default);
            cmd.GetTemporaryRT(buffer1, w,h,0,FilterMode.Bilinear, RenderTextureFormat.Default);
            cmd.Blit(source,buffer0);
            
            int Pow_2(float a)
            {
                return (int)Mathf.Pow(2, a);
            }

            for (int i = 0; i < dualBlurPostProcessingVolume.DualBlurTimes.value; i++) //降采样
            {
                KawaseBlur(cmd); //KawaseBlur

                cmd.ReleaseTemporaryRT(buffer1);
                cmd.GetTemporaryRT(buffer1, w / Pow_2(i + 1), h / Pow_2(i + 1)); //设置目标贴图
                cmd.Blit(source, buffer1);
                cmd.ReleaseTemporaryRT(buffer0);
                cmd.GetTemporaryRT(buffer0, w / Pow_2(i + 1), h / Pow_2(i + 1)); //设置目标贴图
                cmd.Blit(buffer1, buffer0);
            }

            for (int i = dualBlurPostProcessingVolume.DualBlurTimes.value - 1; i >= 0; i--) //升采样
            {
                KawaseBlur(cmd); //KawaseBlur

                cmd.ReleaseTemporaryRT(buffer1);
                cmd.GetTemporaryRT(buffer1, w / Pow_2(i), h / Pow_2(i)); //设置目标贴图
                cmd.Blit(source, buffer1);
                cmd.ReleaseTemporaryRT(buffer0);
                cmd.GetTemporaryRT(buffer0, w / Pow_2(i), h / Pow_2(i)); //设置目标贴图
                cmd.Blit(buffer1, buffer0);
            }
            
            cmd.Blit(buffer0, dest);
            cmd.ReleaseTemporaryRT(buffer0);
            cmd.ReleaseTemporaryRT(buffer1);
        }
    }
}
