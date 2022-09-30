using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthTex : ScriptableRendererFeature
{
    private class BlitPass : ScriptableRenderPass
    {
        public Material material = null;

        private static readonly int depthTextureID = Shader.PropertyToID("_CameraDepthTexture");

        private BlitSettings settings;

        private string profilerTag;

        RenderTexture m_depthTexture;//带 mipmap 的深度图
        public RenderTexture depthTexture => m_depthTexture;

        const RenderTextureFormat m_depthTextureFormat = RenderTextureFormat.RHalf;//深度取值范围0-1，单通道即可。

        int m_depthTextureSize = 0;
        public int depthTextureSize {
            get {
                if(m_depthTextureSize == 0)
                    m_depthTextureSize = Mathf.NextPowerOfTwo(Mathf.Max(Screen.width, Screen.height));
                return m_depthTextureSize;
            }
        }

        public BlitPass(RenderPassEvent renderPassEvent, BlitSettings settings, string tag)
        {
            this.renderPassEvent = renderPassEvent;
            material = settings.material;
            this.settings = settings;
            profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            if (settings.requireDepthNormals)
                ConfigureInput(ScriptableRenderPassInput.Normal);
            settings.depth = depthTexture;
            settings.size = depthTextureSize;
            InitDepthTexture();
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

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            Render(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        void InitDepthTexture() {
            if(m_depthTexture != null) return;
            m_depthTexture = new RenderTexture(depthTextureSize, depthTextureSize, 0, m_depthTextureFormat);
            m_depthTexture.autoGenerateMips = false;
            m_depthTexture.useMipMap = true;
            m_depthTexture.filterMode = FilterMode.Point;
            m_depthTexture.Create();
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            int w = m_depthTexture.width;
            int mipmapLevel = 0;

            RenderTexture currentRenderTexture = null;//当前mipmapLevel对应的mipmap
            RenderTexture preRenderTexture = null;//上一层的mipmap，即mipmapLevel-1对应的mipmap

            //如果当前的mipmap的宽高大于8，则计算下一层的mipmap
            while(w > 8) {
                currentRenderTexture = RenderTexture.GetTemporary(w, w, 0, m_depthTextureFormat);
                currentRenderTexture.filterMode = FilterMode.Point;
                if(preRenderTexture == null) {
                    //Mipmap[0]即copy原始的深度图
                    cmd.Blit(Shader.GetGlobalTexture(depthTextureID), currentRenderTexture);
                }
                else {
                    //将Mipmap[i] Blit到Mipmap[i+1]上
                    cmd.Blit(preRenderTexture, currentRenderTexture, material);
                    RenderTexture.ReleaseTemporary(preRenderTexture);
                }
                cmd.CopyTexture(currentRenderTexture, 0, 0, m_depthTexture, 0, mipmapLevel);
                preRenderTexture = currentRenderTexture;

                w /= 2;
                mipmapLevel++;

            }
            RenderTexture.ReleaseTemporary(preRenderTexture);
        }

        public override void FrameCleanup(CommandBuffer cmd) { }
    }

    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Material material = null;
        public int blitMaterialPassIndex = 0;
        public bool requireDepthNormals = false;
        public RenderTexture depth;
        public int size;
    }

    public BlitSettings settings = new BlitSettings();
    private BlitPass blitPass;

    public override void Create()
    {
        var passIndex = settings.material != null ? settings.material.passCount - 1 : 1;
        settings.blitMaterialPassIndex = Mathf.Clamp(settings.blitMaterialPassIndex, -1, passIndex);
        blitPass = new BlitPass(settings.Event, settings, name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        blitPass.Setup(renderer);
        renderer.EnqueuePass(blitPass);
    }
}